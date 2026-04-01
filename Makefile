DOTFILES_DIR := $(shell pwd)/dotfiles
CONFIG_DIR := $(HOME)/.config

.PHONY: all install update link brew npm-global mas macos node raycast

all: install

# Full setup for a new machine
install: brew node npm-global link macos raycast mas
	@echo "==> Setup complete!"

# Fast update for daily use
update: brew node link macos
	@echo "==> Updates applied!"

brew:
	@echo "==> Installing from Brewfile..."
	@brew bundle --file Brewfile

node:
	@echo "==> Installing Node.js LTS via fnm..."
	@eval "$$(fnm env)" && fnm install --lts && fnm default lts-latest

npm-global:
	@echo "==> Installing global npm packages..."
	@mkdir -p "$(HOME)/Library/pnpm"
	@PNPM_HOME="$(HOME)/Library/pnpm" PATH="$(HOME)/Library/pnpm:$(PATH)" pnpm add -g @fveauvy/cli

mas:
	@echo "==> Installing App Store apps..."
	@bash ./apps-mas.sh

macos:
	@echo "==> Applying macOS defaults..."
	@bash ./macos-defaults.sh

raycast:
	@echo "==> Configuring Raycast..."
	@bash ./raycast.sh

# Smart symlink: dotfiles/.* -> ~, dotfiles/<dir> -> ~/.config/<dir>
link:
	@echo "==> Linking dotfiles..."
	@mkdir -p $(CONFIG_DIR)
	@# Link hidden files (e.g. .zshrc, .gitconfig) to HOME
	@find $(DOTFILES_DIR) -maxdepth 1 -name ".*" \
		-not -name "." -not -name ".." -not -name ".git" \
		-exec ln -sfnv {} $(HOME)/ \;
	@# Link directories (e.g. nvim, tmux, ghostty) to ~/.config/
	@for dir in $(DOTFILES_DIR)/*/; do \
		name=$$(basename "$$dir"); \
		target="$(CONFIG_DIR)/$$name"; \
		if [ -d "$$target" ] && [ ! -L "$$target" ]; then \
			echo "  Backing up $$target -> $$target.bak"; \
			mv "$$target" "$$target.bak"; \
		fi; \
		ln -sfnv "$$dir" "$$target"; \
	done
	@chmod +x "$(CONFIG_DIR)/tmux/dev.sh"
