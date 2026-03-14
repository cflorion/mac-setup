-- LazyVim extras
-- https://www.lazyvim.org/extras

return {
  -- TypeScript / Node LSP + ESLint
  { import = "lazyvim.plugins.extras.lang.typescript" },

  -- JSON avec schémas (package.json, tsconfig.json, etc.)
  { import = "lazyvim.plugins.extras.lang.json" },

  -- Tailwind CSS
  { import = "lazyvim.plugins.extras.lang.tailwind" },

  -- Prettier via conform.nvim (TS, TSX, JSON, CSS, HTML, Markdown)
  { import = "lazyvim.plugins.extras.formatting.prettier" },

}
