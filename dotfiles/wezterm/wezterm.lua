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
    -- Tuned for color e-ink: strong contrast, saturated colors,
    -- softened black (ANSI 0) so the "black" backgrounds painted by
    -- some TUIs (lazygit, fzf, claude…) stay readable.
    day.background       = '#ffffff'
    day.foreground       = '#1a1a1a'
    day.cursor_bg        = '#1a1a1a'
    day.cursor_fg        = '#ffffff'
    day.cursor_border    = '#1a1a1a'
    day.selection_bg     = '#d8d8d8'
    day.selection_fg     = '#1a1a1a'
    day.ansi = {
      '#2a2a2a', -- 0 black: dark gray (avoids pure-black backgrounds)
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

-- unix domain: mux server survives WezTerm GUI restarts (live processes keep running)
config.unix_domains = {
  { name = 'unix' },
}

-- Attach to the mux server at startup, and let WezTerm's own `connect` path do
-- it. A `gui-startup` hook cannot: attaching the domain (or spawning into it)
-- is async, and while it awaits, WezTerm's "mux is still empty -> open a
-- default window" fallback fires. That extra local window is what opened next
-- to the mux one on every launch.
config.default_gui_startup_args = { 'connect', 'unix' }

-- =============================================================================
-- SESSION PERSISTENCE (survives reboots via resurrect.wezterm)
-- =============================================================================
local resurrect = wezterm.plugin.require('https://github.com/MLFlexer/resurrect.wezterm')

-- The panes live in the mux server, so a state must name the domain of the
-- process that will respawn it: `local` for the mux server (which restores at
-- boot), `unix` for the GUI (which sees the very same panes through the unix
-- domain). Rewrite it on the way out and back in.
local function set_domain(state, name)
  local function walk(node)
    if type(node) ~= 'table' then return end
    if node.domain then node.domain = name end
    walk(node.bottom)
    walk(node.right)
  end
  for _, window_state in ipairs(state.window_states or {}) do
    for _, tab in ipairs(window_state.tabs or {}) do
      walk(tab.pane_tree)
    end
  end
  return state
end

local function save_session()
  local state = resurrect.workspace_state.get_workspace_state()
  -- Never trade a real session for an empty one
  if #state.window_states == 0 then return end
  resurrect.state_manager.save_state(set_domain(state, 'local'))
  -- The pointer file resurrect_on_gui_startup() reads. Nothing writes it for
  -- us, and without it the restore below silently finds nothing to do.
  resurrect.state_manager.write_current_state(state.workspace, 'workspace')
end

-- Save every 5 minutes, from the GUI: wezterm.time timers only fire there, and
-- WezTerm has no shutdown event to save from (the `gui-shutdown` handler this
-- config used to carry was never called by anything).
if wezterm.gui then
  local function save_loop()
    wezterm.time.call_after(300, function()
      save_session()
      save_loop()
    end)
  end
  save_loop()
end

-- Restore a saved workspace into the current window (Ctrl+Cmd+R below).
local function restore_session(win, id)
  local name = id:match('([^/]+)$'):match('(.+)%..+$')
  local state = resurrect.state_manager.load_state(name, 'workspace')
  -- Spawn back into the mux server, not into the GUI's own domain, or the
  -- restored panes would die with the window.
  resurrect.workspace_state.restore_workspace(set_domain(state, 'unix'), {
    window = win:mux_window(),
    relative = true,
    restore_text = true,
    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
  })
end

-- Restore into the mux server as it starts up, which after a reboot happens
-- long before the GUI connects. Restoring from the GUI instead would race with
-- its own startup and open a second window.
wezterm.on('mux-startup', function()
  resurrect.state_manager.resurrect_on_gui_startup()
end)

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

-- Cursor: static to avoid the constant partial refresh on e-ink
config.default_cursor_style = 'SteadyBar'

-- Dim inactive panes: subtler in light mode so the background isn't grayed out
config.inactive_pane_hsb = is_dark
  and { saturation = 0.8,  brightness = 0.7  }
  or  { saturation = 0.85, brightness = 0.97 }

-- =============================================================================
-- TABS
-- =============================================================================

config.enable_tab_bar = true
config.use_fancy_tab_bar = false -- retro: no per-tab close button
config.tab_bar_at_bottom = true
-- Keep the bar always visible: its appearing/disappearing (1 vs N tabs)
-- triggers a WezTerm resize bug where TUIs (lazygit, nvim) get one extra
-- line and draw their bottom UNDER the bar, until the next reload.
-- See wezterm#3439 / #3705.
config.hide_tab_bar_if_only_one_tab = false
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
  -- -------------------------------------------------------------------------
  -- Panes / Splits
  -- -------------------------------------------------------------------------
  { key = 'd', mods = 'SUPER',       action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'd', mods = 'SUPER|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },

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

  -- Zoom / close pane
  { key = 'z', mods = 'SUPER|SHIFT', action = act.TogglePaneZoomState },
  { key = 'w', mods = 'SUPER|SHIFT', action = act.CloseCurrentPane { confirm = false } },

  -- -------------------------------------------------------------------------
  -- Copy mode (vim-style)
  -- -------------------------------------------------------------------------
  { key = 'x', mods = 'SUPER|SHIFT', action = act.ActivateCopyMode },

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

  -- -------------------------------------------------------------------------
  -- Session save / restore  (Ctrl+Cmd+S / Ctrl+Cmd+R)
  -- -------------------------------------------------------------------------
  -- Everything goes through the plugin's submodules: resurrect.save_state() and
  -- resurrect.resurrect(), which these bindings used to call, do not exist.
  { key = 's', mods = 'CTRL|SUPER', action = wezterm.action_callback(function(_, _)
      save_session()
    end)
  },
  { key = 'r', mods = 'CTRL|SUPER', action = wezterm.action_callback(function(win, pane)
      resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
        restore_session(win, id)
      end, { ignore_tabs = true, ignore_windows = true })
    end)
  },

  -- -------------------------------------------------------------------------
  -- Workspaces
  -- -------------------------------------------------------------------------
  { key = 's', mods = 'SUPER|SHIFT', action = act.ShowLauncherArgs { flags = 'WORKSPACES' } },
  { key = 'n', mods = 'SUPER|SHIFT', action = act.PromptInputLine {
      description = 'New workspace name:',
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:perform_action(act.SwitchToWorkspace { name = line }, pane)
        end
      end),
    },
  },
  { key = '[', mods = 'SUPER|SHIFT', action = act.SwitchWorkspaceRelative(-1) },
  { key = ']', mods = 'SUPER|SHIFT', action = act.SwitchWorkspaceRelative(1) },
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

-- Never prompt on close: skip_close_confirmation_for_processes_named cannot see
-- the foreground process of a mux pane, so every Cmd+Q popped a confirmation
-- dialog even over an idle shell. Nothing is lost anyway — the panes belong to
-- the mux server and keep running after the GUI closes.
config.window_close_confirmation = 'NeverPrompt'
config.default_prog = { '/bin/zsh', '-l' }
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'

-- Native macOS full screen (Cmd+Enter)
config.keys[#config.keys + 1] = {
  key = 'Enter', mods = 'SUPER', action = act.ToggleFullScreen,
}

return config
