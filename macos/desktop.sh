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
  set desktopCount to count of desktops
  repeat with i from 1 to desktopCount
    set displayName to display name of desktop i
    if displayName contains "intégré" or displayName contains "Built-in" then
      set picture of desktop i to "$SCRIPT_DIR/wallpapers/black.png"
    else
      set picture of desktop i to "$SCRIPT_DIR/wallpapers/white.png"
    end if
  end repeat
end tell
EOF

echo "==> Configuring Desktop & Stage Manager"
# Show items on desktop: ON
defaults write com.apple.finder CreateDesktop -bool true
# Sort desktop items by: Snap to Grid (keep items aligned)
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :DesktopViewSettings:IconViewSettings:arrangeBy string grid" ~/Library/Preferences/com.apple.finder.plist
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
