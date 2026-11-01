echo "==> Configuring Mission Control"
# Do not auto-rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false
# Do not switch to a Space with open windows when switching apps
defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool false
# Group windows by application
defaults write com.apple.dock expose-group-apps -bool true
# Give each display its own Spaces (required by FlashSpace)
defaults write com.apple.spaces spans-displays -bool false
# Do not drag windows to top of screen to trigger Mission Control
defaults write com.apple.dock mcx-expose-disabled -bool true
