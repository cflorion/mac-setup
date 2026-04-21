echo "==> Configuring keyboard"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

echo "==> Disabling Fn key emoji picker"
defaults write com.apple.HIToolbox AppleFnUsageType -int 0

echo "==> Disabling input source switching shortcuts (⌃Space / ⌃⌥Space)"
echo "    ⚠️  Manual step: System Settings → Keyboard → Keyboard Shortcuts → Input Sources"
echo "    Uncheck 'Select the previous input source' (⌃Space)"
echo "    Uncheck 'Select next source in input menu' (⌃⌥Space)"
