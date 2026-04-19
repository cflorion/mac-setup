echo "==> Configuring Control Center"
# Wi-Fi: show in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool true

# Bluetooth: do not show in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool false

# AirDrop: do not show in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible AirDrop" -bool false

# Focus/Concentration: show when active
defaults write com.apple.controlcenter "NSStatusItem Visible FocusModes" -bool true
defaults -currentHost write com.apple.controlcenter FocusModes 2

# Stage Manager: do not show in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible StageManager" -bool false

# Screen Mirroring: do not show in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible ScreenMirroring" -bool false

# Display/Brightness: do not show in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible Display" -bool false

# Sound: show when active
defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool true
defaults -currentHost write com.apple.controlcenter Sound 2

# Now Playing: do not show in menu bar
defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false

# Accessibility Shortcuts: hide from menu bar and control center
defaults -currentHost write com.apple.controlcenter AccessibilityShortcuts 0

# Keyboard Brightness: hide from menu bar and control center
defaults -currentHost write com.apple.controlcenter KeyboardBrightness 0

# Spotlight: do not show in menu bar
defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true

# Siri: do not show in menu bar
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri UserHasDeclinedEnable -bool true

# Time Machine: do not show in menu bar
defaults write com.apple.TimeMachine ShowStatusItem -bool false

# Weather: do not show in menu bar
defaults write com.apple.weather menuBarIconEnabled -bool false

# Battery: show in menu bar, not in control center, show percentage, show energy mode when active
defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool true
defaults -currentHost write com.apple.controlcenter Battery 1
defaults write com.apple.menuextra.battery ShowPercent -bool true
defaults write com.apple.menuextra.battery ShowTime -bool false
defaults write com.apple.menuextra.battery PowerModeShowOnlyOnBattery -bool true
