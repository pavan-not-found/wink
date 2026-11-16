# Homebrew cask for Wink.
# To publish: create a repo named homebrew-tap under your GitHub account,
# put this file at Casks/wink.rb, and fill in the sha256 of the release's Wink.zip
# (it's in SHA256SUMS.txt on the release). Then anyone can run:
#   brew install --cask pavan-parallel/tap/wink
cask "wink" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_OF_Wink-1.0.0.zip"

  url "https://github.com/pavan-parallel/wink/releases/download/v#{version}/Wink-#{version}.zip"
  name "Wink"
  desc "Keep your Mac awake with the lid closed, on a timer, from the menu bar"
  homepage "https://github.com/pavan-parallel/wink"

  depends_on macos: ">= :sonoma"

  app "Wink.app"
  binary "#{appdir}/Wink.app/Contents/Resources/wink"

  uninstall_preflight do
    system_command "/usr/bin/osascript", args: ["-e", 'quit app "Wink"'], must_succeed: false
  end

  zap trash: [
    "~/Library/Preferences/app.wink.mac.plist",
  ]

  caveats <<~EOS
    Wink's lid-closed mode adds /etc/sudoers.d/wink the first time you use it.
    To remove it after uninstalling: sudo rm /etc/sudoers.d/wink
  EOS
end
