return {
  { "catppuccin/nvim", name = "catppuccin", lazy = true },

  {
    "maxmx03/solarized.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      variant = "winter",
    },
    config = function(_, opts)
      vim.o.background = "light"
      require("solarized").setup(opts)
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "solarized",
    },
  },
}
