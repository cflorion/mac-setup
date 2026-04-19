echo "==> Configuring Trackpad (Pointer & Click)"
# Tracking speed (~75% — value range 0-3)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.5

# Click pressure: medium (1)
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 1
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad FirstClickThreshold -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad SecondClickThreshold -int 1

# Silent clicking: ON
defaults write com.apple.AppleMultitouchTrackpad ActuationStrength -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad ActuationStrength -int 0

# Force click and haptic feedback: ON
defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad ForceSuppressed -bool false

# Look up & data detectors: off (0 = disabled)
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0

# Secondary click: click or tap with 2 fingers (1)
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Tap to click: ON (built-in trackpad)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
# Tap to click: ON (Magic Trackpad)
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
# Tap to click: current user
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
# Tap to click: login screen
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

echo "==> Configuring Trackpad (More Gestures)"
# Swipe between pages: disabled (0)
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 0

# Swipe between full-screen apps: disabled (0)
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 0

# Notification Center: ON (swipe left from right edge with 2 fingers)
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3

# Mission Control gesture: disabled (0)
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 0

# App Exposé gesture: disabled (0)
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 0

# Launchpad (pinch with thumb and 3 fingers): OFF
defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFiveFingerPinchGesture -int 0

# Show Desktop (spread with thumb and 3 fingers): ON
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerPinchGesture -int 2
