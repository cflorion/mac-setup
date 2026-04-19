echo "==> Configuring menu bar"
# Auto-hide menu bar: always
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# Recent documents, apps, servers: none (0)
defaults write NSGlobalDomain NSRecentDocumentsLimit -int 0
defaults write com.apple.recentitems RecentDocuments -dict MaxAmount 0
defaults write com.apple.recentitems RecentApplications -dict MaxAmount 0
defaults write com.apple.recentitems RecentServers -dict MaxAmount 0

echo "==> Setting wallpaper"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
osascript <<EOF
tell application "System Events"
  tell every desktop
    set picture to "$SCRIPT_DIR/wallpapers/black-white-dynamic.heic"
  end tell
end tell
EOF

echo "==> Configuring Desktop & Stage Manager"
# Show items on desktop: ON
defaults write com.apple.finder CreateDesktop -bool true
# Show items in Stage Manager: OFF
defaults write com.apple.windowmanager AutoHide -bool false
# Click wallpaper to reveal desktop: only in Stage Manager
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
# Stage Manager: OFF
defaults write com.apple.WindowManager GloballyEnabled -bool false
# Show recent apps in Stage Manager: OFF
defaults write com.apple.WindowManager HideDesktop -bool false
defaults write com.apple.WindowManager ShowRecentApps -bool false
# Show app windows: all at once (En une fois)
defaults write com.apple.WindowManager AppWindowGroupingBehavior -bool false
