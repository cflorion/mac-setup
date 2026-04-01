#!/usr/bin/env bash
#
# backup.sh - Backup critical files before formatting.
# Usage: make backup
#
set -euo pipefail

TIMESTAMP="$(date +%Y-%m-%d_%H%M%S)"
BACKUP_DIR="backup/$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

# --- SSH keys ---
if [ -d "$HOME/.ssh" ]; then
  echo "==> Backing up SSH keys..."
  rsync -a --exclude='agent/' "$HOME/.ssh/" "$BACKUP_DIR/ssh/"
  echo "    Saved to $BACKUP_DIR/ssh/"
else
  echo "==> No ~/.ssh directory found, skipping."
fi

# --- Summary ---
echo ""
echo "==> Backup complete: $BACKUP_DIR"
echo ""
echo "=== RAPPELS ==="
echo "  - [ ] Sauvegarder le dossier ~/Downloads sur un support externe"
echo "  - [ ] Copier le dossier backup/ sur un support chiffre"
echo ""
