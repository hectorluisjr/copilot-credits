# Homebrew cask for Copilot Credits.
#
# Optional alternative to install.sh. To use it, publish a release (the Release
# workflow does this on a `v*` tag), then host this file in a tap repo named
# `homebrew-tap` under your account:
#
#   github.com/hectorluisjr/homebrew-tap/Casks/copilot-credits.rb
#
# Then coworkers run:
#
#   brew install --cask hectorluisjr/tap/copilot-credits
#
# Bump `version` to match the release tag (without the leading "v").
# `sha256 :no_check` is used because the build is ad-hoc signed, not notarized;
# the postflight step removes the Gatekeeper quarantine so it launches cleanly.

cask "copilot-credits" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/hectorluisjr/copilot-credits/releases/download/v#{version}/Copilot-Credits.app.zip"
  name "Copilot Credits"
  desc "Menu bar tracker for GitHub Copilot credit usage"
  homepage "https://github.com/hectorluisjr/copilot-credits"

  app "Copilot Credits.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Copilot Credits.app"]
  end

  uninstall quit: "com.local.copilotcreditsmenubar"
end
