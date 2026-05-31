-- WezTerm configuration
-- Replaces Ghostty + tmux
-- Docs: https://wezfurlong.org/wezterm/config/files.html

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Detect system light/dark appearance (auto-reloads on change)
local function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end
  return 'Dark'
end

local function scheme_for_appearance(appearance)
  if appearance:find('Dark') then
    local mocha = wezterm.color.get_builtin_schemes()['Catppuccin Mocha']
    mocha.background = '#000000'
    mocha.tab_bar.background = '#000000'
    mocha.tab_bar.inactive_tab.bg_color = '#0f0f0f'
    mocha.tab_bar.new_tab.bg_color = '#0f0f0f'
    config.color_schemes = {
      ['Catppuccin Mocha OLED'] = mocha,
    }
    return 'Catppuccin Mocha OLED'
  else
    local day = wezterm.color.get_builtin_schemes()['Tokyo Night Day']
    -- Adapté pour e-ink couleur: contraste fort, couleurs saturées,
    -- noir adouci (ANSI 0) pour que les fonds "noirs" peints par
    -- certains TUI (lazygit, fzf, claude…) soient lisibles.
    day.background       = '#ffffff'
    day.foreground       = '#1a1a1a'
    day.cursor_bg        = '#1a1a1a'
    day.cursor_fg        = '#ffffff'
    day.cursor_border    = '#1a1a1a'
    day.selection_bg     = '#d8d8d8'
    day.selection_fg     = '#1a1a1a'
    day.ansi = {
      '#2a2a2a', -- 0 black: gris foncé (anti-fond-noir)
      '#c43d3d', -- 1 red
      '#1f7a1f', -- 2 green
      '#a06a00', -- 3 yellow (assombri pour fond blanc)
      '#1a4faa', -- 4 blue
      '#8a2d8a', -- 5 magenta
      '#0e6e6e', -- 6 cyan
      '#bfbfbf', -- 7 white (gris clair)
    }
    day.brights = {
      '#4a4a4a', -- 8  bright black
      '#d63d3d', -- 9  bright red
      '#2f9a2f', -- 10 bright green
      '#c08000', -- 11 bright yellow
      '#2a6acc', -- 12 bright blue
      '#9a3d9a', -- 13 bright magenta
      '#1a9a9a', -- 14 bright cyan
      '#1a1a1a', -- 15 bright white -> fg fort
    }
    day.tab_bar.background = '#ffffff'
    day.tab_bar.inactive_tab.bg_color = '#f0f0f0'
    day.tab_bar.new_tab.bg_color = '#f0f0f0'
    config.color_schemes = {
      ['Tokyo Night Day White'] = day,
    }
    return 'Tokyo Night Day White'
  end
end

local is_dark = get_appearance():find('Dark')

-- =============================================================================
-- MUX SERVER (persistent sessions)
-- =============================================================================

-- Connect to the mux server on startup so sessions survive WezTerm restarts
config.unix_domains = {
  { name = 'unix' },
}
config.default_gui_startup_args = { 'connect', 'unix' }

-- =============================================================================
-- APPEARANCE
-- =============================================================================

config.color_scheme = scheme_for_appearance(get_appearance())

config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Regular' })
config.font_size = 14.5
config.line_height = 1.2

-- Window
config.window_decorations = 'RESIZE' -- no macOS title bar
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 0,
}

-- Cursor: statique pour éviter le refresh partiel constant sur e-ink
config.default_cursor_style = 'SteadyBar'

-- Dim inactive panes: plus subtil en light mode pour ne pas griser le fond
config.inactive_pane_hsb = is_dark
  and { saturation = 0.8,  brightness = 0.7  }
  or  { saturation = 0.85, brightness = 0.97 }

-- =============================================================================
-- TABS
-- =============================================================================

config.enable_tab_bar = true
config.use_fancy_tab_bar = false -- retro: no per-tab close button
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 42
config.show_tab_index_in_tab_bar = true
config.show_new_tab_button_in_tab_bar = false

-- Detect tool from foreground process path (substring match, more specific first)
local function tab_icon(pane)
  local raw = (pane.foreground_process_name or ''):lower()
  local checks = {
    { 'claude',  '󰚩' }, -- robot
    { 'lazygit', '󰊢' }, -- github
    { 'nvim',    '\u{e6ae}' }, -- neovim devicon
    { 'vim',     '\u{e62b}' }, -- vim devicon
    { 'docker',  '󰡨' },
    { 'python',  '󰌠' },
    { 'ruby',    '󰴭' },
    { 'yazi',    '󰉋' },
    { 'htop',    '󰍛' },
    { 'btop',    '󰍛' },
    { 'bun',     '󰟂' },
    { 'node',    '󰎙' },
    { 'ssh',     '󰒋' },
    { 'git',     '󰊢' },
    { 'fish',    '󰆍' },
    { 'bash',    '󰆍' },
    { 'zsh',     '󰆍' },
    { 'make',    '󰒓' },
  }
  for _, c in ipairs(checks) do
    if raw:find(c[1], 1, true) then return c[2] end
  end
  return '󰆍' -- console-line
end

-- Title: user-set > cwd basename > pane title
local function tab_title(tab)
  if tab.tab_title and #tab.tab_title > 0 then return tab.tab_title end
  local pane = tab.active_pane
  local cwd = pane.current_working_dir
  if cwd then
    local path = cwd.file_path or tostring(cwd):gsub('^file://[^/]*', '')
    local base = path:gsub('/$', ''):match('([^/]+)$')
    if base and #base > 0 then return base end
  end
  return pane.title or 'shell'
end

local bar_bg      = is_dark and '#000000' or '#ffffff'
local pill_bg     = is_dark and '#ffffff' or '#000000'
local pill_fg     = is_dark and '#000000' or '#ffffff'
local inactive_fg = is_dark and '#888888' or '#666666'
local accent      = is_dark and '#cba6f7' or '#7c3aed' -- Catppuccin mauve

wezterm.on('format-tab-title', function(tab, _tabs, _panes, _cfg, _hover, max_width)
  local title = tab_title(tab)
  local icon = tab_icon(tab.active_pane)
  local num = tostring(tab.tab_index + 1)
  if #title > max_width - 8 then
    title = title:sub(1, max_width - 9) .. '…'
  end

  if tab.is_active then
    return {
      { Background = { Color = bar_bg } },
      { Foreground = { Color = pill_bg } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = ' ▍' .. num .. ' ' .. icon .. '  ' .. title .. '  ' },
    }
  end

  -- Inactive: everything dim
  return {
    { Background = { Color = bar_bg } },
    { Foreground = { Color = inactive_fg } },
    { Text = '  ' .. num .. ' ' .. icon .. '  ' .. title .. '  ' },
  }
end)

-- =============================================================================
-- STATUS BAR (right)
-- =============================================================================

wezterm.on('update-right-status', function(window, pane)
  local workspace = window:active_workspace()
  if workspace == 'default' then
    window:set_right_status ''
    return
  end
  local fg = is_dark and '#6c7086' or '#6172b0'
  window:set_right_status(wezterm.format {
    { Foreground = { Color = fg } },
    { Text = ' ' .. workspace .. ' ' },
  })
end)

-- =============================================================================
-- KEYBINDINGS
-- =============================================================================

-- Disable default keybindings and define our own
config.disable_default_key_bindings = true

config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {

  -- -------------------------------------------------------------------------
  -- Clipboard
  -- -------------------------------------------------------------------------
  { key = 'c', mods = 'SUPER',       action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'SUPER',       action = act.PasteFrom 'Clipboard' },

  -- -------------------------------------------------------------------------
  -- Tabs
  -- -------------------------------------------------------------------------
  { key = 't', mods = 'SUPER',       action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'SUPER',       action = act.CloseCurrentTab { confirm = false } },
  { key = 'LeftArrow',  mods = 'SUPER', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'SUPER', action = act.ActivateTabRelative(1) },
  { key = '1', mods = 'SUPER',       action = act.ActivateTab(0) },
  { key = '2', mods = 'SUPER',       action = act.ActivateTab(1) },
  { key = '3', mods = 'SUPER',       action = act.ActivateTab(2) },
  { key = '4', mods = 'SUPER',       action = act.ActivateTab(3) },
  { key = '5', mods = 'SUPER',       action = act.ActivateTab(4) },
  { key = '6', mods = 'SUPER',       action = act.ActivateTab(5) },
  { key = '7', mods = 'SUPER',       action = act.ActivateTab(6) },
  { key = '8', mods = 'SUPER',       action = act.ActivateTab(7) },
  { key = '9', mods = 'SUPER',       action = act.ActivateTab(8) },
  -- Rename tab
  { key = 'e', mods = 'SUPER|SHIFT', action = act.PromptInputLine {
      description = 'Rename tab:',
      action = wezterm.action_callback(function(window, _, line)
        if line then window:active_tab():set_title(line) end
      end),
    },
  },
  { key = 'r', mods = 'LEADER',      action = act.PromptInputLine {
      description = 'Rename tab:',
      action = wezterm.action_callback(function(window, _, line)
        if line then window:active_tab():set_title(line) end
      end),
    },
  },

  -- -------------------------------------------------------------------------
  -- Panes / Splits
  -- -------------------------------------------------------------------------
  -- Split
  { key = '\\', mods = 'LEADER',     action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-',  mods = 'LEADER',     action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },

  -- Navigate panes (vim-style)
  { key = 'h', mods = 'CTRL',        action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'CTRL',        action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'CTRL',        action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'CTRL',        action = act.ActivatePaneDirection 'Right' },

  -- Resize panes
  { key = 'h', mods = 'CTRL|SHIFT',  action = act.AdjustPaneSize { 'Left',  5 } },
  { key = 'j', mods = 'CTRL|SHIFT',  action = act.AdjustPaneSize { 'Down',  5 } },
  { key = 'k', mods = 'CTRL|SHIFT',  action = act.AdjustPaneSize { 'Up',    5 } },
  { key = 'l', mods = 'CTRL|SHIFT',  action = act.AdjustPaneSize { 'Right', 5 } },

  -- Zoom pane (toggle fullscreen for a single pane)
  { key = 'z', mods = 'LEADER',      action = act.TogglePaneZoomState },

  -- Close pane
  { key = 'x', mods = 'LEADER',      action = act.CloseCurrentPane { confirm = false } },

  -- -------------------------------------------------------------------------
  -- Copy mode (vim-style)
  -- -------------------------------------------------------------------------
  { key = '[', mods = 'LEADER',      action = act.ActivateCopyMode },

  -- -------------------------------------------------------------------------
  -- Font size
  -- -------------------------------------------------------------------------
  { key = '+', mods = 'SUPER',       action = act.IncreaseFontSize },
  { key = '-', mods = 'SUPER',       action = act.DecreaseFontSize },
  { key = '0', mods = 'SUPER',       action = act.ResetFontSize },

  -- -------------------------------------------------------------------------
  -- Misc
  -- -------------------------------------------------------------------------
  { key = 'q', mods = 'SUPER',       action = act.QuitApplication },
  { key = 'r', mods = 'SUPER|SHIFT', action = act.ReloadConfiguration },
  { key = 'f', mods = 'SUPER',       action = act.Search { CaseSensitiveString = '' } },
  { key = 'p', mods = 'SUPER',       action = act.ActivateCommandPalette },

  -- Workspaces (mux)
  { key = 's', mods = 'LEADER',      action = act.ShowLauncherArgs { flags = 'WORKSPACES' } },
  { key = 'n', mods = 'LEADER',      action = act.PromptInputLine {
      description = 'New workspace name:',
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:perform_action(act.SwitchToWorkspace { name = line }, pane)
        end
      end),
    },
  },
  { key = 'Tab', mods = 'LEADER',    action = act.SwitchWorkspaceRelative(1) },
}

-- Copy mode: vim keybindings
config.key_tables = {
  copy_mode = {
    { key = 'q',          mods = 'NONE', action = act.CopyMode 'Close' },
    { key = 'Escape',     mods = 'NONE', action = act.CopyMode 'Close' },
    { key = 'h',          mods = 'NONE', action = act.CopyMode 'MoveLeft' },
    { key = 'j',          mods = 'NONE', action = act.CopyMode 'MoveDown' },
    { key = 'k',          mods = 'NONE', action = act.CopyMode 'MoveUp' },
    { key = 'l',          mods = 'NONE', action = act.CopyMode 'MoveRight' },
    { key = 'w',          mods = 'NONE', action = act.CopyMode 'MoveForwardWord' },
    { key = 'b',          mods = 'NONE', action = act.CopyMode 'MoveBackwardWord' },
    { key = '0',          mods = 'NONE', action = act.CopyMode 'MoveToStartOfLine' },
    { key = '$',          mods = 'NONE', action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = 'g',          mods = 'NONE', action = act.CopyMode 'MoveToScrollbackTop' },
    { key = 'G',          mods = 'NONE', action = act.CopyMode 'MoveToScrollbackBottom' },
    { key = 'v',          mods = 'NONE', action = act.CopyMode { SetSelectionMode = 'Cell' } },
    { key = 'V',          mods = 'NONE', action = act.CopyMode { SetSelectionMode = 'Line' } },
    { key = 'y',          mods = 'NONE', action = act.Multiple {
        act.CopyTo 'ClipboardAndPrimarySelection',
        act.CopyMode 'Close',
      },
    },
    { key = 'PageUp',     mods = 'NONE', action = act.CopyMode 'PageUp' },
    { key = 'PageDown',   mods = 'NONE', action = act.CopyMode 'PageDown' },
  },
}

-- =============================================================================
-- SHELL & MISC
-- =============================================================================

config.default_prog = { '/bin/zsh', '-l' }
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'

-- Native macOS full screen (Cmd+Enter)
config.keys[#config.keys + 1] = {
  key = 'Enter', mods = 'SUPER', action = act.ToggleFullScreen,
}

return config
