-- Custom plugins
-- Add plugin specs here: https://www.lazyvim.org/configuration/plugins

-- Detect macOS appearance and return "dark" or "light"
local function get_macos_appearance()
  local result = vim.fn.system("defaults read -g AppleInterfaceStyle 2>/dev/null")
  return result:match("Dark") and "dark" or "light"
end

-- Apply the correct tokyonight style based on current background
local function apply_theme()
  local bg = vim.o.background
  if bg == "dark" then
    vim.cmd("colorscheme tokyonight-night")
  else
    vim.cmd("colorscheme tokyonight-day")
  end
end

-- Sync vim.o.background with macOS appearance (only update if changed)
local function sync_appearance()
  local appearance = get_macos_appearance()
  if vim.o.background ~= appearance then
    vim.o.background = appearance
  end
end

return {
  -- Configure tokyonight with true black (dark) and true white (light) backgrounds
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    opts = {
      on_colors = function(colors)
        if vim.o.background == "dark" then
          colors.bg = "#000000"
          colors.bg_dark = "#000000"
          colors.bg_float = "#000000"
          colors.bg_popup = "#000000"
          colors.bg_sidebar = "#000000"
          colors.bg_statusline = "#000000"
        else
          colors.bg = "#ffffff"
          colors.bg_dark = "#ffffff"
          colors.bg_float = "#ffffff"
          colors.bg_popup = "#ffffff"
          colors.bg_sidebar = "#ffffff"
          colors.bg_statusline = "#ffffff"
        end
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)

      -- Apply theme whenever background option changes
      vim.api.nvim_create_autocmd("OptionSet", {
        pattern = "background",
        callback = apply_theme,
      })

      -- Initial sync on startup
      sync_appearance()
      apply_theme()

      -- Poll macOS appearance every 2 seconds
      local timer = vim.uv.new_timer()
      timer:start(2000, 2000, vim.schedule_wrap(sync_appearance))
    end,
  },

  -- Set tokyonight as the active colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-night",
    },
  },
}
