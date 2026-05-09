return {
  {
    "hat0uma/csvview.nvim",
    ft = { "csv", "tsv" },
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle", "CsvViewInfo" },
    keys = {
      { "<leader>uc", "<cmd>CsvViewToggle<cr>", desc = "Toggle CSV View" },
    },
    init = function()
      vim.filetype.add({
        extension = {
          csv = "csv",
          tsv = "tsv",
        },
      })
    end,
    opts = {
      parser = {
        comments = { "#", "//" },
        delimiter = {
          ft = {
            csv = ",",
            tsv = "\t",
          },
          fallbacks = { ",", "\t", ";", "|", ":" },
        },
      },
      view = {
        display_mode = "border",
        header_lnum = true,
        sticky_header = {
          enabled = true,
          separator = "-",
        },
      },
      keymaps = {
        textobject_field_inner = { "if", mode = { "o", "x" } },
        textobject_field_outer = { "af", mode = { "o", "x" } },
        jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
        jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
        jump_next_row = { "<Enter>", mode = { "n", "v" } },
        jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
      },
    },
    config = function(_, opts)
      require("csvview").setup(opts)

      local group = vim.api.nvim_create_augroup("user_csvview_auto_enable", { clear = true })
      local function enable_csvview(bufnr)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_call(bufnr, function()
              vim.cmd("CsvViewEnable")
            end)
          end
        end)
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "csv", "tsv" },
        callback = function(args)
          enable_csvview(args.buf)
        end,
      })

      if vim.tbl_contains({ "csv", "tsv" }, vim.bo.filetype) then
        enable_csvview(vim.api.nvim_get_current_buf())
      end
    end,
  },
}
