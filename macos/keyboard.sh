echo "==> Configuring keyboard"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

echo "==> Enabling press-and-hold for accented characters (É, À, Ç…)"
defaults write -g ApplePressAndHoldEnabled -bool true

echo "==> Disabling Fn key emoji picker"
defaults write com.apple.HIToolbox AppleFnUsageType -int 0

echo "==> Disabling input source switching shortcuts (⌃Space / ⌃⌥Space)"
type manual_step &>/dev/null || manual_step() { local l; for l in "$@"; do echo "$l"; done; }
manual_step \
  "    ⚠️  Manual step: System Settings → Keyboard → Keyboard Shortcuts → Input Sources" \
  "    Uncheck 'Select the previous input source' (⌃Space)" \
  "    Uncheck 'Select next source in input menu' (⌃⌥Space)"

manual_step \
  "    ⚠️  Manual step: Handy → Settings → Shortcut → set to ⌃⌥⌘D" \
  "    (⌘ left/right tap → Handy dictation is already configured in Karabiner)"

manual_step \
  "    ⚠️  Manual step: Homerow → Settings → set shortcuts:" \
  "    Click → ⌃⌥⌘H   |   Scroll → ⌃⌥⌘J" \
  "    (Hyper+U → click, Hyper+J → scroll are already configured in Karabiner)"
