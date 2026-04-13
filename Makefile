DOTFILES_DIR := $(shell pwd)/dotfiles
CONFIG_DIR := $(HOME)/.config
OBSIDIAN_VAULT := $(HOME)/Library/Mobile Documents/iCloud~md~obsidian/Documents/Travail/.obsidian

.PHONY: all install update link brew npm-global mas macos node raycast backup restore-ssh sketchybar obsidian

all: install

# Full setup for a new machine
install: brew node npm-global link sketchybar obsidian macos raycast mas
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
	@mkdir -p $(HOME)/.local
	@mkdir -p $(HOME)/templates
	@# Install templates
	@cp -n $(DOTFILES_DIR)/../documents/popina-template.typ $(HOME)/templates/popina-pandoc.typ 2>/dev/null || true
	@# Link hidden files (e.g. .zshrc, .gitconfig) to HOME
	@find $(DOTFILES_DIR) -maxdepth 1 -name ".*" \
		-not -name "." -not -name ".." -not -name ".git" \
		-exec ln -sfnv {} $(HOME)/ \;
	@# Link starship.toml to ~/.config/starship.toml (special case: file, not directory)
	@ln -sfnv $(DOTFILES_DIR)/starship.toml $(CONFIG_DIR)/starship.toml
	@# Link zed/settings.json only (preserve Zed's own extensions, keymap, etc.)
	@mkdir -p $(CONFIG_DIR)/zed
	@ln -sfnv $(DOTFILES_DIR)/zed/settings.json $(CONFIG_DIR)/zed/settings.json
	@# Link Sublime Text preferences (lives in ~/Library, not ~/.config)
	@mkdir -p "$(HOME)/Library/Application Support/Sublime Text/Packages/User"
	@ln -sfnv $(DOTFILES_DIR)/sublime-text/Preferences.sublime-settings \
		"$(HOME)/Library/Application Support/Sublime Text/Packages/User/Preferences.sublime-settings"
	@# Link directories to ~/.config/ (except bin/, zed/, sublime-text/ which are handled above)
	@for dir in $(DOTFILES_DIR)/*/; do \
		name=$$(basename "$$dir"); \
		if [ "$$name" = "zed" ] || [ "$$name" = "sublime-text" ] || [ "$$name" = "obsidian" ]; then \
			continue; \
		elif [ "$$name" = "bin" ]; then \
			echo "  Linking $$dir -> $(HOME)/.local/bin"; \
			ln -sfnv "$$dir" "$(HOME)/.local/bin"; \
		else \
			target="$(CONFIG_DIR)/$$name"; \
			if [ -d "$$target" ] && [ ! -L "$$target" ]; then \
				echo "  Backing up $$target -> $$target.bak"; \
				mv "$$target" "$$target.bak"; \
			fi; \
			ln -sfnv "$$dir" "$$target"; \
		fi; \
	done

# Copy Obsidian theme to vault (copy, not symlink, to avoid iCloud sync issues)
obsidian:
	@echo "==> Applying Obsidian theme..."
	@if [ -d "$(OBSIDIAN_VAULT)" ]; then \
		cp -f $(DOTFILES_DIR)/obsidian/appearance.json "$(OBSIDIAN_VAULT)/appearance.json"; \
		mkdir -p "$(OBSIDIAN_VAULT)/themes/Vanilla AMOLED"; \
		cp -f "$(DOTFILES_DIR)/obsidian/themes/Vanilla AMOLED/manifest.json" "$(OBSIDIAN_VAULT)/themes/Vanilla AMOLED/manifest.json"; \
		cp -f "$(DOTFILES_DIR)/obsidian/themes/Vanilla AMOLED/theme.css" "$(OBSIDIAN_VAULT)/themes/Vanilla AMOLED/theme.css"; \
		echo "  Obsidian theme applied!"; \
	else \
		echo "  Obsidian vault not found, skipping (open Obsidian and create vault first)"; \
	fi

# Build and install sketchybar helpers (SbarLua, event providers, menus)
sketchybar:
	@echo "==> Setting up sketchybar..."
	@# Install SbarLua (Lua bindings for sketchybar)
	@if [ ! -d "$(HOME)/.local/share/sketchybar_lua" ]; then \
		echo "  Installing SbarLua..."; \
		rm -rf /tmp/SbarLua; \
		git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua; \
		cd /tmp/SbarLua && make install; \
		rm -rf /tmp/SbarLua; \
	fi
	@# Install sketchybar-app-font
	@if [ ! -f "$(HOME)/Library/Fonts/sketchybar-app-font.ttf" ]; then \
		echo "  Installing sketchybar-app-font..."; \
		curl -sL https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.5/sketchybar-app-font.ttf \
			-o "$(HOME)/Library/Fonts/sketchybar-app-font.ttf"; \
	fi
	@# Build event providers (cpu_load, network_load, menus)
	@echo "  Building sketchybar helpers..."
	@cd $(CONFIG_DIR)/sketchybar/helpers && make
	@# Start sketchybar service
	@brew services start sketchybar 2>/dev/null || true
	@echo "  Sketchybar ready!"

# Backup SSH keys before formatting
backup:
	@bash ./backup.sh

# Restore SSH keys from most recent backup
restore-ssh:
	@bash ./restore-ssh.sh
