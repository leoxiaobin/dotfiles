-- Org-mode for Neovim
-- Uses the same ~/notes/ directory and files as Doom Emacs
return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      require("orgmode").setup({
        -- Scan the notebook files and working folders, not root test.org.
        org_agenda_files = {
          "~/notes/inbox.org",
          "~/notes/daily.org",
          "~/notes/research/*.org",
          "~/notes/experiments/*.org",
          "~/notes/engineering/*.org",
          "~/notes/meetings/*.org",
        },
        org_default_notes_file = "~/notes/inbox.org",
        org_startup_folded = "content",
        org_log_done = "time",

        org_capture_templates = {
          n = {
            description = "Quick note",
            template = "* %?\n%U\n",
            target = "~/notes/inbox.org",
            headline = "Notes",
          },
          t = {
            description = "Quick TODO",
            template = "* TODO %?\n%U\n",
            target = "~/notes/inbox.org",
            headline = "Notes",
          },
          d = {
            description = "Daily log",
            template = "* %U %?\n",
            target = "~/notes/daily.org",
          },
          m = {
            description = "Meeting note",
            template = "* %? :meeting:\n%U\n",
            target = "~/notes/meetings/log.org",
          },
          p = {
            description = "Coding prompt",
            template = "* %?\n%U\n",
            target = "~/notes/engineering/coding-prompts.org",
            headline = "Prompts",
          },
          i = {
            description = "Agent instruction",
            template = "* %?\n%U\n",
            target = "~/notes/engineering/agent-instructions.org",
            headline = "Instructions",
          },
          e = {
            description = "Experiment log",
            template = "* %? :experiment:\n%U\n",
            target = "~/notes/experiments/log.org",
          },
        },
      })
    end,
  },

}
