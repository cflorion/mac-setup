echo "==> Configuring keyboard"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

echo "==> Enabling press-and-hold for accented characters (É, À, Ç…)"
defaults write -g ApplePressAndHoldEnabled -bool true

echo "==> Disabling Fn key emoji picker"
defaults write com.apple.HIToolbox AppleFnUsageType -int 0

echo "==> Disabling input source switching shortcuts (⌃Space / ⌃⌥Space)"
echo "    ⚠️  Manual step: System Settings → Keyboard → Keyboard Shortcuts → Input Sources"
echo "    Uncheck 'Select the previous input source' (⌃Space)"
echo "    Uncheck 'Select next source in input menu' (⌃⌥Space)"

echo "    ⚠️  Manual step: Handy → Settings → Shortcut → set to ⌃⌥⌘D"
echo "    (⌘ left/right tap → Handy dictation is already configured in Karabiner)"

echo "    ⚠️  Manual step: Homerow → Settings → set shortcuts:"
echo "    Click → ⌃⌥⌘H   |   Scroll → ⌃⌥⌘J"
echo "    (Hyper+U → click, Hyper+J → scroll are already configured in Karabiner)"
