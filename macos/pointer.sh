echo "==> Configuring pointer"
# Shake to locate pointer: OFF
defaults write NSGlobalDomain CGDisableCursorLocationMagnification -bool true
# Pointer size: ~1.5 (range 1.0 normal to 4.0 large)
sudo defaults write com.apple.universalaccess mouseDriverCursorSize -float 1.5

echo "==> Accessibility settings"
type manual_step &>/dev/null || manual_step() { local l; for l in "$@"; do echo "$l"; done; }
manual_step \
  "    ⚠️  Manual step: System Settings > Accessibility > Display" \
  "    - Increase contrast: ON" \
  "    - Reduce transparency: ON"
