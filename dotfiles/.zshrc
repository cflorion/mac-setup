# -------
# Env
# -------

export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$HOME/.local/bin:$PNPM_HOME:$PATH"

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
alias lg="lazygit"
alias co="commit"
alias ll="eza -l -F --icons -a -b --no-permissions --no-user"
alias ls="eza -G -F --icons --git-ignore"
alias cat="bat --style header --style snip --style changes"
alias tree="eza -T -F -a --git-ignore -L=2"
alias dl="cd ~/Downloads"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias myip="curl http://ipecho.net/plain; echo"
alias brewup="brew update; brew upgrade; brew cleanup; brew doctor"
alias rm="trash"

# -------
# fnm node version manager
# -------

eval "$(fnm env --use-on-cd --shell zsh)"

# -------
# Shell tools (zoxide, starship, atuin)
# -------

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(atuin init zsh)"
