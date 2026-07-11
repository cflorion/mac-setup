DOTFILES_DIR := $(shell pwd)/dotfiles
CONFIG_DIR := $(HOME)/.config
OBSIDIAN_VAULT := $(HOME)/Library/Mobile Documents/iCloud~md~obsidian/Documents/Travail/.obsidian

UHK_AGENT_DIR := $(HOME)/Library/Application Support/uhk-agent

.PHONY: all install update link brew fuji-webcam open-pdf-studio npm-global mas macos node raycast backup restore-ssh sketchybar obsidian ollama pwa-helium uhk-backup wezterm \
	macos-finder macos-dock macos-keyboard macos-trackpad macos-mission-control macos-desktop macos-control-center macos-pointer macos-e-ink

all: install

# Full setup for a new machine
install: brew fuji-webcam open-pdf-studio node npm-global link sketchybar obsidian macos raycast mas ollama pwa-helium wezterm
	@echo "==> Setup complete!"

# Fast update for daily use
update: brew node link macos
	@echo "==> Updates applied!"

brew:
	@echo "==> Installing from Brewfile..."
	@brew bundle --file Brewfile

# Install FUJIFILM X Webcam — no Homebrew cask exists, so the .pkg is bundled
# in installers/. Needs sudo; restart afterwards to load the camera plugin.
fuji-webcam:
	@if [ -d "/Applications/FUJIFILM X Webcam 2.app" ]; then \
		echo "==> FUJIFILM X Webcam already installed, skipping"; \
	else \
		echo "==> Installing FUJIFILM X Webcam (needs sudo; restart afterwards)..."; \
		sudo installer -pkg installers/XWebcamIns220.pkg -target /; \
	fi

# Install Open PDF Studio — no Homebrew cask; downloads latest DMG from GitHub releases.
open-pdf-studio:
	@if [ -d "/Applications/Open PDF Studio.app" ]; then \
		echo "==> Open PDF Studio already installed, skipping"; \
	else \
		echo "==> Downloading Open PDF Studio..."; \
		gh release download --repo OpenAEC-Foundation/open-pdf-studio --pattern "*universal.dmg" --output /tmp/open-pdf-studio.dmg --clobber; \
		VOLUME=$$(hdiutil attach /tmp/open-pdf-studio.dmg -nobrowse | tail -1 | awk '{print $$NF}'); \
		cp -r "$$VOLUME/Open PDF Studio.app" /Applications/; \
		hdiutil detach "$$VOLUME" -quiet; \
		rm /tmp/open-pdf-studio.dmg; \
	fi

node:
	@echo "==> Installing Node.js LTS via fnm..."
	@eval "$$(fnm env)" && fnm install --lts && fnm default lts-latest

npm-global:
	@echo "==> Installing global npm packages..."
	@mkdir -p "$(HOME)/Library/pnpm"
	@PNPM_HOME="$(HOME)/Library/pnpm" PATH="$(HOME)/Library/pnpm:$(PATH)" pnpm add -g @fveauvy/cli @openai/codex

mas:
	@echo "==> Installing App Store apps..."
	@bash ./apps-mas.sh

macos:
	@echo "==> Applying macOS defaults..."
	@bash ./macos-defaults.sh

macos-finder:
	@bash -euo pipefail -c 'source ./macos/finder.sh && killall Finder || true'

macos-dock:
	@bash -euo pipefail -c 'source ./macos/dock.sh && killall Dock || true'

macos-keyboard:
	@bash -euo pipefail -c 'source ./macos/keyboard.sh'

macos-trackpad:
	@bash -euo pipefail -c 'source ./macos/trackpad.sh'

macos-mission-control:
	@bash -euo pipefail -c 'source ./macos/mission-control.sh && killall Dock || true'

macos-desktop:
	@bash -euo pipefail -c 'source ./macos/desktop.sh && killall Finder || true'

macos-control-center:
	@bash -euo pipefail -c 'source ./macos/control-center.sh && killall SystemUIServer || true'

macos-pointer:
	@bash -euo pipefail -c 'source ./macos/pointer.sh'

macos-e-ink:
	@bash -euo pipefail -c 'source ./macos/e-ink.sh && killall Finder || true'

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
	@cp -f $(DOTFILES_DIR)/../documents/popina-template.typ $(HOME)/templates/popina-pandoc.typ 2>/dev/null || true
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
	@# Link playbook repo into Obsidian vault (symlink so iCloud doesn't sync .git)
	@if [ -d "$(HOME)/code/playbook" ]; then \
		ln -sfnv $(HOME)/code/playbook "$(HOME)/Library/Mobile Documents/iCloud~md~obsidian/Documents/Travail/Projects/Budget"; \
	else \
		echo "  ~/code/playbook not found, skipping Obsidian playbook link"; \
	fi

# Copy Obsidian theme and plugins to vault (copy, not symlink, to avoid iCloud sync issues)
obsidian:
	@echo "==> Applying Obsidian config..."
	@if [ -d "$(OBSIDIAN_VAULT)" ]; then \
		cp -f $(DOTFILES_DIR)/obsidian/appearance.json "$(OBSIDIAN_VAULT)/appearance.json"; \
		cp -f $(DOTFILES_DIR)/obsidian/community-plugins.json "$(OBSIDIAN_VAULT)/community-plugins.json"; \
		mkdir -p "$(OBSIDIAN_VAULT)/themes/Vanilla AMOLED"; \
		cp -f "$(DOTFILES_DIR)/obsidian/themes/Vanilla AMOLED/manifest.json" "$(OBSIDIAN_VAULT)/themes/Vanilla AMOLED/manifest.json"; \
		cp -f "$(DOTFILES_DIR)/obsidian/themes/Vanilla AMOLED/theme.css" "$(OBSIDIAN_VAULT)/themes/Vanilla AMOLED/theme.css"; \
		cp -r $(DOTFILES_DIR)/obsidian/plugins/ "$(OBSIDIAN_VAULT)/plugins/"; \
		echo "  Obsidian config applied!"; \
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
	@# Install theme watcher: dark-notify triggers sketchybar --reload on appearance change
	@echo "  Installing theme watcher..."
	@mkdir -p $(HOME)/Library/LaunchAgents
	@sed "s|__HOME__|$(HOME)|g" launchd/com.user.sketchybar-theme.plist > $(HOME)/Library/LaunchAgents/com.user.sketchybar-theme.plist
	@launchctl bootout gui/$$(id -u) $(HOME)/Library/LaunchAgents/com.user.sketchybar-theme.plist 2>/dev/null || true
	@launchctl bootstrap gui/$$(id -u) $(HOME)/Library/LaunchAgents/com.user.sketchybar-theme.plist
	@# Start sketchybar service
	@brew services start sketchybar 2>/dev/null || true
	@echo "  Sketchybar ready!"

# Install WezTerm login helpers
# Cleans any stale unix-domain socket then daemonizes the mux server at login,
# so it is ready before WezTerm connects (avoids the "after spawning server
# failed to connect" notification caused by a boot-time race condition).
wezterm:
	@echo "==> Installing WezTerm login helpers..."
	@mkdir -p $(HOME)/Library/LaunchAgents
	@# Migrate: remove old socket-cleaner-only agent if present
	@launchctl bootout gui/$$(id -u) $(HOME)/Library/LaunchAgents/com.user.wezterm-clean-socket.plist 2>/dev/null || true
	@/bin/rm -f $(HOME)/Library/LaunchAgents/com.user.wezterm-clean-socket.plist
	@# Install mux-server agent (cleans socket then starts server atomically)
	@sed "s|__HOME__|$(HOME)|g" launchd/com.user.wezterm-mux-server.plist > $(HOME)/Library/LaunchAgents/com.user.wezterm-mux-server.plist
	@launchctl bootout gui/$$(id -u) $(HOME)/Library/LaunchAgents/com.user.wezterm-mux-server.plist 2>/dev/null || true
	@launchctl bootstrap gui/$$(id -u) $(HOME)/Library/LaunchAgents/com.user.wezterm-mux-server.plist
	@echo "  WezTerm mux server registered!"

# Install Helium PWAs — native Helium web apps (Google Chat, Google Meet).
# Their links open inside Helium instead of the default browser (unlike Chrome PWAs,
# whose external links bypass Finicky). Requires each PWA to be installed once via
# Helium's ⋮ menu > "Install app…"; the script regenerates the .app on re-runs.
pwa-helium:
	@bash ./pwa-helium.sh

# Pull Ollama models
ollama:
	@echo "==> Pulling Ollama models..."
	@ollama list | grep -q mistral-small3.2 || ollama pull mistral-small3.2 || true

# Snapshot the live UHK Agent user-config into the repo (re-imported manually via Agent)
uhk-backup:
	@echo "==> Backing up UHK config..."
	@latest=$$(ls -t "$(UHK_AGENT_DIR)"/*.json 2>/dev/null | head -1); \
	if [ -n "$$latest" ]; then \
		cp "$$latest" $(DOTFILES_DIR)/uhk/uhk-config.json; \
		echo "  Saved $$latest -> dotfiles/uhk/uhk-config.json"; \
	else \
		echo "  No UHK Agent config found (open UHK Agent at least once first)"; \
	fi

# Backup SSH keys before formatting
backup:
	@bash ./backup.sh

# Restore SSH keys from most recent backup
restore-ssh:
	@bash ./restore-ssh.sh
