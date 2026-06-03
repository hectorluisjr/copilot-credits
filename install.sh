#!/usr/bin/env bash
#
# Copilot Credits installer.
#
#   Remote (prebuilt):  curl -fsSL https://raw.githubusercontent.com/hectorluisjr/copilot-credits/main/install.sh | bash
#   Local (from clone): ./install.sh          # builds a universal .app from source
#
# Downloads the latest release .app (or builds from source when run inside a
# checkout), installs it to /Applications, strips the Gatekeeper quarantine, and
# launches it. macOS 13+.
#
set -euo pipefail

OWNER="${COPILOT_CREDITS_OWNER:-hectorluisjr}"
REPO="${COPILOT_CREDITS_REPO:-copilot-credits}"
APP_NAME="Copilot Credits"
APP="${APP_NAME}.app"

err() { echo "Error: $*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || err "macOS only."
ver="$(sw_vers -productVersion)"; major="${ver%%.*}"
[ "${major:-0}" -ge 13 ] 2>/dev/null || err "Requires macOS 13+ (found $ver)."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

if [ -f "$SCRIPT_DIR/Package.swift" ] && [ "${1:-}" != "--download" ]; then
    echo "Building $APP_NAME from source…"
    command -v xcrun >/dev/null 2>&1 || err "Xcode toolchain not found. Install Xcode, or run the remote installer to fetch a prebuilt build."
    ( cd "$SCRIPT_DIR" && ./bundle.sh )
    SRC_APP="$SCRIPT_DIR/dist/$APP"
else
    echo "Fetching latest release of $OWNER/$REPO…"
    zip="$workdir/app.zip"
    if command -v gh >/dev/null 2>&1; then
        gh release download --repo "$OWNER/$REPO" --pattern '*.zip' --dir "$workdir" \
            || err "gh release download failed (no release yet, or no access)."
        zip="$(/bin/ls "$workdir"/*.zip 2>/dev/null | head -1)"
    else
        url="$(curl -fsSL "https://api.github.com/repos/$OWNER/$REPO/releases/latest" \
                | grep -o '"browser_download_url"[^,]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
        [ -n "${url:-}" ] || err "No public release asset found. For a private repo: 'brew install gh && gh auth login', then re-run. Or build from source."
        curl -fsSL "$url" -o "$zip"
    fi
    [ -n "${zip:-}" ] && [ -f "$zip" ] || err "Download failed."
    ditto -x -k "$zip" "$workdir/unpacked"
    SRC_APP="$(/usr/bin/find "$workdir/unpacked" -maxdepth 2 -name "$APP" -print -quit)"
    [ -n "${SRC_APP:-}" ] || err "Could not find $APP in the downloaded archive."
fi

echo "Installing to $DEST/$APP…"
rm -rf "$DEST/$APP"
ditto "$SRC_APP" "$DEST/$APP"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

# Replace any running instance.
pkill -f "$APP/Contents/MacOS/CopilotCreditsMenuBar" 2>/dev/null || true
open "$DEST/$APP"

echo
echo "✅ Installed to $DEST/$APP and launched."
echo "   • Look in the menu bar (top-right) for 'Copilot …'."
echo "   • Set your allowance: menu bar item → ⚙ → Allowance"
echo "     (your number is at github.com → Billing & licensing → AI usage)."
echo "   • To run at login: System Settings → General → Login Items."
