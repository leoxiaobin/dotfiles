return {
  {
    "LazyVim/LazyVim",
    keys = {
      {
        "<leader>jl",
        function()
          vim.cmd("new")
          vim.cmd("read !jq -s . " .. vim.fn.shellescape(vim.fn.expand("#:p")))
          vim.cmd("setfiletype json")
        end,
        desc = "Pretty view JSONL as JSON array",
      },
      {
        "<leader>jj",
        function()
          vim.cmd(".!jq .")
        end,
        desc = "Pretty print current JSONL line",
      },
    },
  },
}
