echo "==> Configuring keyboard"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

echo "==> Disabling Fn key emoji picker"
defaults write com.apple.HIToolbox AppleFnUsageType -int 0
