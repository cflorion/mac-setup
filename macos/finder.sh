echo "==> Configuring Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowRecentTags -bool false
type manual_step &>/dev/null || manual_step() { echo "$@"; }
manual_step "    ⚠️  Manual step: Finder > Settings > Sidebar — uncheck 'Récents' and everything under 'Partagé'"
