echo "==> Configuring pointer"
# Shake to locate pointer: OFF
defaults write NSGlobalDomain CGDisableCursorLocationMagnification -bool true
# Pointer size: ~1.5 (range 1.0 normal to 4.0 large)
sudo defaults write com.apple.universalaccess mouseDriverCursorSize -float 1.5

echo "==> Accessibility settings (manual)"
echo "    Please configure in System Settings > Accessibility > Display:"
echo "    - Increase contrast: ON"
echo "    - Reduce transparency: ON"
echo "    - Display contrast: 50% (midpoint)"
