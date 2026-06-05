echo "==> Configuring Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowRecentTags -bool false
echo "    ⚠️  Manual step: Finder > Settings > Sidebar — uncheck 'Récents' and everything under 'Partagé'"
