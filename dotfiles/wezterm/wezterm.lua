-- WezTerm configuration
-- Replaces Ghostty + tmux
-- Docs: https://wezfurlong.org/wezterm/config/files.html

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- =============================================================================
-- MUX SERVER (persistent sessions)
-- =============================================================================

-- Connect to the mux server on startup so sessions survive WezTerm restarts
config.unix_domains = {
  { name = 'unix' },
}
-- Uncomment to auto-connect to mux server on launch:
-- config.default_gui_startup_args = { 'connect', 'unix' }

-- =============================================================================
-- APPEARANCE
-- =============================================================================

config.color_scheme = 'Tokyo Night'

config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Regular' })
config.font_size = 13.5

-- Window
config.window_decorations = 'RESIZE' -- no macOS title bar
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 0,
}

-- Cursor
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 500

-- Dim inactive panes
config.inactive_pane_hsb = {
  saturation = 0.8,
  brightness = 0.7,
}

-- =============================================================================
-- TABS
-- =============================================================================

config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 32
config.show_tab_index_in_tab_bar = true

-- Tab bar colors (Tokyo Night)
config.colors = {
  tab_bar = {
    background = '#1a1b26',
    active_tab = {
      bg_color = '#7aa2f7',
      fg_color = '#1a1b26',
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = '#1a1b26',
      fg_color = '#565f89',
    },
    inactive_tab_hover = {
      bg_color = '#24283b',
      fg_color = '#a9b1d6',
    },
    new_tab = {
      bg_color = '#1a1b26',
      fg_color = '#565f89',
    },
    new_tab_hover = {
      bg_color = '#24283b',
      fg_color = '#7aa2f7',
    },
  },
}

-- =============================================================================
-- STATUS BAR (right)
-- =============================================================================

wezterm.on('update-right-status', function(window, pane)
  local workspace = window:active_workspace()
  local date = wezterm.strftime '%H:%M'
  window:set_right_status(wezterm.format {
    { Foreground = { Color = '#565f89' } },
    { Text = ' ' .. workspace .. '  ' .. date .. ' ' },
  })
end)

-- =============================================================================
-- KEYBINDINGS
-- =============================================================================

-- Disable default keybindings and define our own
config.disable_default_key_bindings = true

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

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
