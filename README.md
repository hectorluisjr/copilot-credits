# Copilot Credits — macOS Menu Bar App

A menu bar app that shows your GitHub Copilot credit usage against your allowance,
aggregated across the Copilot clients that log locally.

```
Copilot 278 / 7500
```

Implements **Phases 1–3** of the plan in
`TKPlanner-iOS/scripts/copilot-credits-toolbar-app-plan.md` plus **multi-source
aggregation**: app skeleton, editable allowance, billing-window scoping, live
updates, named recent chats, and totals summed across **VS Code Copilot Chat +
the Copilot CLI**.

## Install

**One-liner** — downloads the latest prebuilt build, de-quarantines it, and launches:

```bash
curl -fsSL https://raw.githubusercontent.com/hectorluisjr/copilot-credits/main/install.sh | bash
```

> Private repo? Install the GitHub CLI first (`brew install gh && gh auth login`) —
> the installer uses it to fetch the release. Public repo works with no auth.

**From source** (needs the Xcode toolchain) — builds a universal `.app`, installs it, launches:

```bash
git clone https://github.com/hectorluisjr/copilot-credits.git
cd copilot-credits && ./install.sh
```

**Homebrew** (optional) — see [`packaging/homebrew/copilot-credits.rb`](packaging/homebrew/copilot-credits.rb).

After installing, set your **Allowance** via the ⚙ menu (your number is at
github.com → **Billing & licensing → AI usage**). The installer removes the
Gatekeeper quarantine, so no right-click-to-open is needed.

Releases are built by [`.github/workflows/release.yml`](.github/workflows/release.yml):
push a `v*` tag and a macOS runner builds the universal `.app` and attaches it to
the GitHub Release.

## Requirements

- macOS 13+ (uses SwiftUI `MenuBarExtra`)
- The **Xcode** Swift toolchain. Build with `xcrun swift …` so the compiler
  matches the macOS SDK. A standalone swiftly / swift.org `swift` on your `PATH`
  (e.g. 6.0.3) may fail with *"this SDK is not supported by the compiler"* — the
  `xcrun` prefix sidesteps that.

## Run it

```bash
xcrun swift run                 # dev: menu bar item appears
# or build a real app:
./bundle.sh && open "dist/Copilot Credits.app"
```

`bundle.sh` produces an `LSUIElement` (no Dock icon) **universal** (arm64 +
x86_64) bundle under `dist/`. Drag it into `/Applications` and add it to
**System Settings → General → Login Items** to launch at startup.

## How it works

### Sources (each Copilot client logs separately)

- **VS Code Copilot Chat** — `~/Library/Application Support/Code/User/workspaceStorage/*/GitHub.copilot-chat/debug-logs/*/main.jsonl`.
  GPT models are priced via `attrs.copilotUsageNanoAiu` on `type == "llm_request"`.
  (Claude requests here carry only token counts — no credit field — so they're
  priced from the CLI source instead, never double-counted.)
- **Copilot CLI / agentic** — `~/.copilot/session-state/<uuid>/events.jsonl`.
  Priced via `data.modelMetrics.<model>.totalNanoAiu` on `session.shutdown`
  events. These are **per-segment** (a resumed session emits several shutdowns),
  so they're summed. This is where Claude (Opus/Sonnet) usage lives.

### Computation

- **Credits** — `credits = nanoAiu / 1e9` everywhere (`CreditConstants.nanoAiuToCreditsScale`).
- **Billing exclusions** — internal helper calls GitHub doesn't bill are dropped
  so the total matches the admin panel: `debugName` in
  `{title, summarizeVirtualTools}` (`UsageParser.nonBillableDebugNames`).
- **Billing window** — `BillingPeriodCalculator` derives the monthly period; the
  allowance resets on the **1st** (calendar month, `monthlyResetDay`). Only
  events at/after the period start count toward "used".
- **Aggregation** — sums in-period credits across all sources (all-time kept for
  reference), groups events into recent chats by session id.
- **Chat titles** — VS Code: Copilot's generated title from the sibling
  `title-*.jsonl`, else first-`user_message` preview. CLI: first `user.message`
  preview, else the session `cwd` basename. Else `Chat <id-prefix>`.
- **Live updates** — `FileWatcher` (FSEvents) on every source root fires a
  **debounced** (0.6s) re-scan when a relevant path changes; a 5-min heartbeat
  backstops missed events. A green **● Live** badge shows when active.
- **Warnings** — credits show as whole numbers. The progress bar turns orange at
  75% and red at 90%; the panel shows a warning banner ("Approaching limit" /
  "Almost out" / "Over your limit") and the menu bar title gains a ⚠ prefix at 90%+.

## Verifying the numbers

A hidden diagnostic runs the real pipeline and prints totals (no UI):

```bash
xcrun swift build && ./.build/debug/CopilotCreditsMenuBar --print-total
```

Compare against **github.com → Billing & licensing → AI usage** (filter to your
user). They should match to the cent.

## Settings

| Setting | Default | Notes |
| --- | --- | --- |
| Allowance (credits) | `7500` | Generic per-seat default; set yours from the admin panel |
| Recent chats | `20` | How many chats to list |
| Log root override | _(blank)_ | Point at a non-default VS Code workspaceStorage |

Stored in `UserDefaults` under `copilot.*`. The monthly reset is fixed at the 1st
(`BillingPeriodCalculator.monthlyResetDay`). To see the warning states, set the
allowance low (e.g. `300`) temporarily.

## Sharing with coworkers (portability)

The app is **per-user, not machine-specific** — it resolves the current user's
home directory and hardcodes no usernames or absolute paths, so it runs as-is on
any coworker's Mac. Caveats:

- **macOS only** (SwiftUI `MenuBarExtra`, AppKit, FSEvents).
- **VS Code stable path is assumed.** Insiders / VSCodium / Cursor use a
  different `workspaceStorage` — point the **Log root override** there. The
  Copilot CLI path (`~/.copilot`) is standard.
- **Reset day is fixed to the 1st** (your org's plan). A coworker whose plan
  resets on a different day would see the wrong period boundary.
- **Allowance** defaults to a generic `7500` — each person sets their own.
- **Distribution.** The `.app` is universal (arm64 + x86_64) but only *ad-hoc*
  signed, so Gatekeeper flags it on another Mac. The recipient right-clicks →
  **Open** once (or runs `xattr -dr com.apple.quarantine "Copilot Credits.app"`).
  Frictionless distribution needs a Developer ID signature + notarization;
  building from source instead needs the Xcode toolchain.

## Source layout

```
Sources/CopilotCreditsMenuBar/
  CopilotCreditsMenuBarApp.swift   @main + MenuBarExtra scene
  AppDelegate.swift                accessory policy + initial scan
  Diagnostics.swift                --print-total CLI check
  Models/                          CreditConstants, UsageEvent, ChatSummary
  Services/                        LogDiscoveryService, UsageParser, LogScanner,
                                   CopilotCLIScanner, AggregationStore,
                                   BillingPeriod, FileWatcher
  Settings/SettingsStore.swift     UserDefaults-backed, observable
  ViewModels/MenuBarViewModel.swift multi-source scan + live watching, off-main
  Views/                           MenuContentView, SettingsView
  Support/Format.swift             display formatting
```

## Known limitations

- **Some clients can't be read locally.** Covered: VS Code Copilot Chat +
  Copilot CLI — together these reconstruct the admin total exactly when they're
  your only clients. **Copilot for Xcode keeps no usage data on disk** — its
  conversation DBs (`~/.config/github-copilot/xcode/…`) record `modelName` and
  `billingMultiplier` but no tokens or credits, and `copilot-xcode.db` is just
  settings — so its spend is server-side only. The **cloud coding agent** also
  runs server-side. If you use either heavily, the app undercounts; the only
  complete source would be the GitHub billing API (needs a token — not built).
- **Claude pricing depends on the CLI log format.** Only newer CLI builds write
  `totalNanoAiu`; older sessions have token counts only and stay unpriced (those
  are out of the current period here anyway).
- **Full re-read on each change.** Live updates re-scan all logs (debounced)
  rather than byte-offset incremental reads — trivial at this scale; byte-offset
  tailing is a Phase 4 perf option.

## Roadmap

- ✅ **Phase 2** — live updates: FSEvents watcher + debounced re-scan + heartbeat.
- ✅ **Phase 3** — named recent chats.
- ✅ **Multi-source** — VS Code Copilot Chat + Copilot CLI, matching the admin panel.
- **Copilot for Xcode** — investigated; it stores no usage locally, so it can't
  be priced offline (would require the GitHub billing API).
- **Phase 4** — byte-offset tailing, log rotation/truncation handling, startup
  cache, parser/aggregation tests.
