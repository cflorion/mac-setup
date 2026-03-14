#!/usr/bin/env bash
# -------------------------------------------------------
# dev.sh — Lance ou attache la session tmux "dev"
#
# Fenêtres :
#   1. editor   → nvim (plein écran)
#   2. apps     → [pane gauche] pnpm dev  |  [pane droit] logs Next.js
#   3. apis     → [pane gauche] pnpm dev  |  [pane droit] logs Node API
#   4. db       → [pane gauche] cockroach sql  |  [pane droit] docker logs
#   5. git      → lazygit (plein écran)
#   6. scratch  → shell libre
# -------------------------------------------------------

PROJECT="$HOME/code/pragma-web"
SESSION="dev"

# Si la session existe déjà, on s'y attache directement
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# ----------------------------------------------------------
# Fenêtre 1 : editor — nvim plein écran
# ----------------------------------------------------------
tmux new-session -d -s "$SESSION" -n "editor" -c "$PROJECT"
tmux send-keys   -t "$SESSION:editor" "nvim ." Enter

# ----------------------------------------------------------
# Fenêtre 2 : apps — Next.js
#   pane gauche (60%) : commande dev
#   pane droit  (40%) : logs live
# ----------------------------------------------------------
tmux new-window  -t "$SESSION" -n "apps" -c "$PROJECT"
tmux send-keys   -t "$SESSION:apps" "pnpm dev" Enter
tmux split-window -t "$SESSION:apps" -h -p 40 -c "$PROJECT"
# pane droit prêt pour les logs (ex: tail -f, pnpm logs, etc.)

# ----------------------------------------------------------
# Fenêtre 3 : apis — Node/TypeScript backend
#   pane gauche (60%) : commande dev
#   pane droit  (40%) : logs live
# ----------------------------------------------------------
tmux new-window  -t "$SESSION" -n "apis" -c "$PROJECT"
tmux send-keys   -t "$SESSION:apis" "pnpm dev" Enter
tmux split-window -t "$SESSION:apis" -h -p 40 -c "$PROJECT"

# ----------------------------------------------------------
# Fenêtre 4 : db — CockroachDB
#   pane gauche (60%) : cockroach sql REPL
#   pane droit  (40%) : docker logs cockroachdb
# ----------------------------------------------------------
tmux new-window   -t "$SESSION" -n "db" -c "$PROJECT"
tmux send-keys    -t "$SESSION:db" "cockroach sql --insecure --host=localhost" Enter
tmux split-window -t "$SESSION:db" -h -p 40 -c "$PROJECT"
tmux send-keys    -t "$SESSION:db" "docker logs -f cockroachdb 2>&1" Enter

# ----------------------------------------------------------
# Fenêtre 5 : git — lazygit plein écran
# ----------------------------------------------------------
tmux new-window  -t "$SESSION" -n "git" -c "$PROJECT"
tmux send-keys   -t "$SESSION:git" "lazygit" Enter

# ----------------------------------------------------------
# Fenêtre 6 : scratch — shell libre
# ----------------------------------------------------------
tmux new-window  -t "$SESSION" -n "scratch" -c "$PROJECT"

# Focus sur editor au démarrage
tmux select-window -t "$SESSION:editor"

exec tmux attach -t "$SESSION"
