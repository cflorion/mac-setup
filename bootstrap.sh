#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking sudo access"
sudo -v

echo "==> Updating macOS"
sudo softwareupdate --install --all || true

echo "==> Installing Command Line Tools if missing"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo "Command Line Tools may require graphical confirmation."
  echo "Run this script again after installation if needed."
fi

echo "==> Installing Homebrew if missing"
if ! command -v brew >/dev/null 2>&1; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "==> Loading Homebrew into the shell"
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "==> Updating Homebrew"
brew update

echo "==> Installing from Brewfile"
brew bundle --file ./Brewfile

echo "==> Applying dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.config"
mkdir -p "$HOME/.config/nvim"
mkdir -p "$HOME/.config/ghostty"
mkdir -p "$HOME/.config/tmux"

ln -sfn "$SCRIPT_DIR/dotfiles/.zshrc" "$HOME/.zshrc"
ln -sfn "$SCRIPT_DIR/dotfiles/.gitconfig" "$HOME/.gitconfig"
ln -sfn "$SCRIPT_DIR/dotfiles/nvim/init.vim" "$HOME/.config/nvim/init.vim"
ln -sfn "$SCRIPT_DIR/dotfiles/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
ln -sfn "$SCRIPT_DIR/dotfiles/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"

echo "==> Applying macOS preferences"
bash ./macos-defaults.sh

echo "==> Apple Account / iCloud"
echo "Apple Account sign-in cannot be fully automated on macOS."
echo "The Apple Account settings page will now open."
echo "Please sign in to your Apple Account and complete iCloud setup if needed."
echo "Press Enter only after this step is fully complete."

# open "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane" || true
# read -r

echo "==> App Store authentication"
echo "The App Store will now open."
echo "Please sign in to the App Store with your Apple Account if needed."
echo "Press Enter once App Store sign-in is complete."

# open -a "App Store"
# read -r

echo "==> Mac App Store apps"
bash ./apps-mas.sh

echo "==> Creating code workspace"
mkdir -p "$HOME/code"

echo "==> Done. Some changes may require logging out or restarting."