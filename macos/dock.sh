echo "==> Configuring Dock"
defaults write com.apple.dock tilesize -int 64
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock orientation -string "bottom"
defaults write com.apple.dock mineffect -string "genie"
defaults write com.apple.dock dblclickbehavior -string "Zoom"
defaults write com.apple.dock minimize-to-application -bool false
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock show-process-indicators -bool false
defaults write com.apple.dock show-recents -bool false

echo "==> Configuring hot corners"
defaults write com.apple.dock wvous-tl-corner -int 1
defaults write com.apple.dock wvous-tr-corner -int 4
defaults write com.apple.dock wvous-bl-corner -int 1
defaults write com.apple.dock wvous-br-corner -int 1
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-modifier -int 0
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-modifier -int 0

echo "==> Rebuilding Dock"
if command -v dockutil >/dev/null 2>&1; then
  dockutil --no-restart --remove all
  dockutil --no-restart --add "$HOME/Downloads" --view grid --display stack
  dockutil --no-restart --add "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Notes de frais" --view grid --display stack
else
  echo "dockutil not installed, skipping Dock configuration"
fi
