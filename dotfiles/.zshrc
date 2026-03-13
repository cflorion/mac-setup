alias c="cd ~/code"
alias vim="nvim"

if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
  tmux attach || tmux new
fi
