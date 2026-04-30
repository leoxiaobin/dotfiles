return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        actions = {
          copy_relative_path_to_tmux = function(_, item)
            local path = item and (item.file or item.path)
            if not path and Snacks and Snacks.picker and Snacks.picker.util then
              path = Snacks.picker.util.path(item)
            end
            if not path then
              Snacks.notify.warn("No path found")
              return
            end

            local value = vim.fn.fnamemodify(path, ":.") -- relative to :pwd

            if vim.env.TMUX then
              vim.fn.system({ "tmux", "set-buffer", value })
            end

            vim.fn.setreg('"', value)
            pcall(vim.fn.setreg, "+", value)

            Snacks.notify.info("Copied relative path: " .. value)
          end,

          copy_absolute_path_to_tmux = function(_, item)
            local path = item and (item.file or item.path)
            if not path and Snacks and Snacks.picker and Snacks.picker.util then
              path = Snacks.picker.util.path(item)
            end
            if not path then
              Snacks.notify.warn("No path found")
              return
            end

            local value = vim.fn.fnamemodify(path, ":p")

            if vim.env.TMUX then
              vim.fn.system({ "tmux", "set-buffer", value })
            end

            vim.fn.setreg('"', value)
            pcall(vim.fn.setreg, "+", value)

            Snacks.notify.info("Copied absolute path: " .. value)
          end,
        },

        sources = {
          explorer = {
            win = {
              list = {
                keys = {
                  ["Y"] = "copy_relative_path_to_tmux",
                  ["<M-y>"] = "copy_absolute_path_to_tmux",
                },
              },
            },
          },
        },
      },
    },
  },
}
