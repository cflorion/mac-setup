# -------
# Env
# -------

export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"

export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# -------
# History
# -------

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY        # share history across sessions
setopt HIST_IGNORE_DUPS     # don't record duplicate consecutive entries
setopt HIST_IGNORE_SPACE    # don't record commands starting with a space

# -------
# Plugins (via brew)
# -------

source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# -------
# Aliases
# -------

alias c="cd ~/code"
alias vim="nvim"
alias dev="$HOME/.config/tmux/dev.sh"

# -------
# tmux — auto-attach to dev session
# -------

if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then
  tmux attach -t dev 2>/dev/null || tmux new -s dev
fi
