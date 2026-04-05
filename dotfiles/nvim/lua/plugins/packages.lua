return {
  {
    "vuki656/package-info.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
      require("package-info").setup({
        package_manager = "pnpm",
        autostart = false,
        hide_up_to_date = true,
      })

      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "package.json",
        callback = function()
          if vim.bo.buftype ~= "" then
            return
          end

          local path = vim.api.nvim_buf_get_name(0)
          if path == "" or vim.fn.filereadable(path) ~= 1 then
            return
          end

          local dir = vim.fn.fnamemodify(path, ":h")
          if vim.fn.isdirectory(dir) ~= 1 then
            return
          end

          require("package-info").show()
        end,
      })
    end,
  },
}
