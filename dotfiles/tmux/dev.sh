#!/usr/bin/env bash
# -------------------------------------------------------
# dev.sh — Lance ou attache la session tmux "dev"
#
# Fenêtres :
#   1. nvim     → ouvre neovim à la racine du projet
#   2. apps     → ~/code/pragma-web/apps
#   3. apis     → ~/code/pragma-web/apis
#   4. db       → racine (cockroach sql, logs, etc.)
#   5. git      → lazygit
# -------------------------------------------------------

PROJECT="$HOME/code/pragma-web"
SESSION="dev"

# Si la session existe déjà, on s'y attache directement
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# Fenêtre 1 : nvim
tmux new-session  -d -s "$SESSION" -n "nvim"  -c "$PROJECT"
tmux send-keys    -t "$SESSION:nvim" "nvim ." Enter

# Fenêtre 2 : apps (Next.js)
tmux new-window   -t "$SESSION" -n "apps" -c "$PROJECT/apps"

# Fenêtre 3 : apis (Node/TypeScript backend)
tmux new-window   -t "$SESSION" -n "apis" -c "$PROJECT/apis"

# Fenêtre 4 : db (CockroachDB)
tmux new-window   -t "$SESSION" -n "db" -c "$PROJECT"

# Fenêtre 5 : git (lazygit)
tmux new-window   -t "$SESSION" -n "git" -c "$PROJECT"
tmux send-keys    -t "$SESSION:git" "lazygit" Enter

# Focus sur nvim au démarrage
tmux select-window -t "$SESSION:nvim"

exec tmux attach -t "$SESSION"
