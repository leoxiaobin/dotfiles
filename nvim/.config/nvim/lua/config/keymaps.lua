-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>jp", function()
  local line = vim.api.nvim_get_current_line()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "json"
  local result = vim.fn.system(
    'python3 -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read().strip()), indent=2))"',
    line -- pass line as stdin instead of shell-escaping it
  )
  local lines = vim.split(result, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, buf)
end, { desc = "Preview JSONL line as JSON" })

-- Toggle one persistent floating terminal with Ctrl+/
vim.keymap.set({ "n", "t" }, "<C-/>", function()
  Snacks.terminal.toggle(nil, {
    win = {
      position = "float",
    },
  })
end, { desc = "Toggle Floating Terminal" })

-- Some terminals report Ctrl+/ as Ctrl+_
vim.keymap.set({ "n", "t" }, "<C-_>", function()
  Snacks.terminal.toggle(nil, {
    win = {
      position = "float",
    },
  })
end, { desc = "Toggle Floating Terminal" })

-- ~/.config/nvim/lua/config/keymaps.lua
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])
