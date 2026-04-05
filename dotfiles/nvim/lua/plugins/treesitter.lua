return {
  -- Auto-close/rename HTML and JSX tags
  {
    "windwp/nvim-ts-autotag",
    ft = {
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "html",
      "svelte",
    },
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },

  -- Additional treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "windwp/nvim-ts-autotag" },
    opts = {
      highlight = { enable = true },
      autotag = { enable = true },
      indent = { enable = true },
      autopairs = { enable = true },
      ensure_installed = {
        "bash",
        "dockerfile",
        "html",
        "http",
        "javascript",
        "jsdoc",
        "json",
        "jsonc",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "query",
        "regex",
        "tsx",
        "typescript",
        "prisma",
        "vim",
        "vimdoc",
        "yaml",
      },
    },
  },
}
