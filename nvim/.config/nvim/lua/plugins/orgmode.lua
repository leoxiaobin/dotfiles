-- Org-mode for Neovim
-- Uses the same ~/notes/ directory and files as Doom Emacs
return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      require("orgmode").setup({
        -- Explicit notebook files exclude scratch notes and practice guides.
        org_agenda_files = {
          "~/notes/inbox.org",
          "~/notes/daily.org",
          "~/notes/projects.org",
          "~/notes/research.org",
          "~/notes/experiments.org",
          "~/notes/meetings.org",
          "~/notes/personal.org",
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
            target = "~/notes/meetings.org",
          },
          p = {
            description = "Project",
            template = "* %?\n%U\n",
            target = "~/notes/projects.org",
          },
          e = {
            description = "Experiment log",
            template = "* %? :experiment:\n%U\n",
            target = "~/notes/experiments.org",
          },
        },
      })
    end,
  },

}
