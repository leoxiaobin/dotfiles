local profile_file = vim.fn.expand("~/.config/dotfiles/profile")
local ssh_only = vim.fn.filereadable(profile_file) == 1
  and vim.fn.readfile(profile_file)[1] == "ssh"

return {
  {
    "iamcco/markdown-preview.nvim",
    optional = true,
    enabled = not ssh_only,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        markdown = {},
        ["markdown.mdx"] = {},
      },
    },
  },
}
