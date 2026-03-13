export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

alias c="cd ~/code"
alias vim="nvim"

if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
  tmux attach || tmux new
fi
