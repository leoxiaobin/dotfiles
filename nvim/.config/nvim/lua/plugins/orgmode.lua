-- Org-mode for Neovim
-- Uses the same ~/org/ directory and files as Doom Emacs
return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      require("orgmode").setup({
        org_agenda_files = "~/org/**/*",
        org_default_notes_file = "~/org/inbox.org",
        org_startup_folded = "content",
        org_log_done = "time",

        org_capture_templates = {
          n = {
            description = "Quick note",
            template = "* %?\n%U\n",
            target = "~/org/inbox.org",
            headline = "Notes",
          },
          p = {
            description = "Coding prompt",
            template = "* %?\n%U\n#+begin_src\n\n#+end_src\n",
            target = "~/org/coding-prompts.org",
            headline = "Prompts",
          },
          i = {
            description = "Agent instruction",
            template = "* %?\n%U\n",
            target = "~/org/agent-instructions.org",
            headline = "Instructions",
          },
          e = {
            description = "Experiment log",
            template = "* %? :experiment:\n%U\n** Goal\n\n** Setup\n\n** Result\n\n** Notes\n",
            target = "~/org/experiments.org",
            headline = "Log",
          },
        },
      })
    end,
  },

}
