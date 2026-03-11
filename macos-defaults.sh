#!/usr/bin/env bash
set -euo pipefail

echo "==> Réglages Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo "==> Réglages Dock"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 60

echo "==> Réglages clavier"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

echo "==> Configuring Dock"

if command -v dockutil >/dev/null 2>&1; then
dockutil --no-restart --remove all
dockutil --no-restart --add /Applications/Safari.app
dockutil --no-restart --add /Applications/Visual\ Studio\ Code.app
dockutil --no-restart --add /Applications/iTerm.app
dockutil --no-restart --add "$HOME/Downloads" --view grid --display folder
killall Dock
else
  echo "dockutil not installed, skipping Dock configuration"
fi

echo "==> Redémarrage des services"
killall Finder || true
killall SystemUIServer || true





# Réglage toucher pour cliquer
# Autoriser apps externes
# Accessibilité: Filtre de couleurs niveaux de gris à 100%
# Accessibilité: augmenter le contrast
# Accessibilité: réduire la transparence
# Accessibilité: taille du pointeur un peu plus grande
# Accessibilité: différencier sans couleur
# Accessibilité: réduire animations


# DisplayBuddy
# Zoom
# Obsidian
# DisplayBuddy
# StillColor / script
# Adobe Acrobat Reader