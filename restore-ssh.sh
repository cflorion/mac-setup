#!/usr/bin/env bash
#
# restore-ssh.sh - Restore SSH keys from the most recent backup.
# Usage: make restore-ssh
#
set -euo pipefail

# Find the most recent backup containing ssh/
LATEST="$(ls -dt backup/*/ssh 2>/dev/null | head -1)"

if [ -z "$LATEST" ]; then
  echo "==> No SSH backup found in backup/*/ssh/"
  echo "    Copy your backup/ folder into this repo first."
  exit 1
fi

echo "==> Found SSH backup: $LATEST"

mkdir -p "$HOME/.ssh"

# Copy all files from the backup
cp -R "$LATEST/"* "$HOME/.ssh/"

# Fix permissions
chmod 700 "$HOME/.ssh"
find "$HOME/.ssh" -type f -name "*.pub" -exec chmod 644 {} \;
find "$HOME/.ssh" -type f ! -name "*.pub" ! -name "known_hosts" ! -name "config" -exec chmod 600 {} \;
chmod 644 "$HOME/.ssh/known_hosts" 2>/dev/null || true
chmod 644 "$HOME/.ssh/config" 2>/dev/null || true

echo "==> SSH keys restored to ~/.ssh/"
echo ""
echo "    Restored files:"
ls -la "$HOME/.ssh/"
echo ""
echo "==> Test with: ssh -T git@github.com"
