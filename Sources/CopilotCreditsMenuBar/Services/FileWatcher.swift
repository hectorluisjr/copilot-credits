import Foundation
import CoreServices

/// Watches a directory subtree via FSEvents and invokes `onChange` (on a
/// background queue) when a created/modified path satisfies `matches`.
///
/// Used to watch the VS Code workspaceStorage tree for Copilot log writes.
/// FSEvents already coalesces bursts (see the latency arg); callers should
/// still debounce before doing expensive work.
final class FileWatcher {
    private let path: String
    private let matches: (String) -> Bool
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "copilot.filewatcher")
    private var stream: FSEventStreamRef?

    init(path: String, matches: @escaping (String) -> Bool, onChange: @escaping () -> Void) {
        self.path = path
        self.matches = matches
        self.onChange = onChange
    }

    func start() {
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            watcher.handle(paths: paths)
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,            // latency seconds — FSEvents coalesces within this window
            flags
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func handle(paths: [String]) {
        if paths.contains(where: matches) {
            onChange()
        }
    }

    deinit { stop() }
}
