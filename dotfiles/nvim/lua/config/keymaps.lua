-- Additional keymaps
-- Default keymaps: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- Prettify JSON with jq
map("n", "<leader>j", "<cmd>%!jq '.'<cr>", { desc = "Prettify JSON" })

-- Select all
map("n", "<C-a>", "ggVG", { desc = "Select all" })

-- Replace word under cursor
map("n", "<leader>cw", "*``cgn", { desc = "Replace word under cursor" })

-- package-info keymaps
map("n", "<leader>cpt", "<cmd>lua require('package-info').toggle()<cr>", { silent = true, noremap = true, desc = "Toggle" })
map("n", "<leader>cpd", "<cmd>lua require('package-info').delete()<cr>", { silent = true, noremap = true, desc = "Delete package" })
map("n", "<leader>cpu", "<cmd>lua require('package-info').update()<cr>", { silent = true, noremap = true, desc = "Update package" })
map("n", "<leader>cpi", "<cmd>lua require('package-info').install()<cr>", { silent = true, noremap = true, desc = "Install package" })
map("n", "<leader>cpc", "<cmd>lua require('package-info').change_version()<cr>", { silent = true, noremap = true, desc = "Change package version" })
