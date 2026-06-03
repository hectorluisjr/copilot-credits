import SwiftUI

/// Inline settings panel shown inside the menu bar popover.
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Allowance (credits)") {
                TextField("Allowance", value: $settings.allowanceCredits, format: .number)
                    .textFieldStyle(.roundedBorder)
            }

            Stepper("Recent chats: \(settings.recentChatsLimit)",
                    value: $settings.recentChatsLimit, in: 1...100)

            field("Log root override (optional)") {
                TextField("workspaceStorage path", text: $settings.logRootOverride)
                    .textFieldStyle(.roundedBorder)
                Text("Leave blank to auto-discover VS Code Copilot logs.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            HStack {
                Spacer()
                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
}
