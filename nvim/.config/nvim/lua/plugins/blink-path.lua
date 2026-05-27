local function reopen_path_after_directory(item, cmp)
  if item and item.data and item.data.type == "directory" then
    vim.schedule(function()
      cmp.show({ providers = { "path" } })
    end)
  end
end

return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.keymap = opts.keymap or {}

      opts.keymap["<CR>"] = {
        function(cmp)
          local item = cmp.get_selected_item()
          return cmp.accept({
            callback = function()
              reopen_path_after_directory(item, cmp)
            end,
          })
        end,
        "fallback",
      }

      opts.keymap["<C-y>"] = {
        function(cmp)
          local item = cmp.get_selected_item() or cmp.get_items()[1]
          return cmp.select_and_accept({
            callback = function()
              reopen_path_after_directory(item, cmp)
            end,
          })
        end,
        "fallback",
      }
    end,
  },
}
