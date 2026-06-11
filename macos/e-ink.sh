echo "==> Configuring for e-ink display"

# Disable subpixel font smoothing — e-ink has no subpixels, antialiasing makes text blurry
defaults write -g AppleFontSmoothing -int 0

# Remove transparency/blur from sidebars, menu bar, Dock
defaults write com.apple.universalaccess reduceTransparency -bool true

# Sharpen UI borders and reduce semi-transparent shadows (aggressive: changes some system colors)
defaults write com.apple.universalaccess increaseContrast -bool true
