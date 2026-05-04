# Dotfiles

Terminal-centric development environment managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Inside

| Package      | What it configures                                    |
|--------------|-------------------------------------------------------|
| `zsh`        | Shell: oh-my-zsh, starship prompt, aliases, AI CLI helpers |
| `git`        | Git: aliases, delta pager, histogram diff, rerere     |
| `tmux`       | Tmux: C-q prefix, catppuccin, git status, resurrect   |
| `doom`       | Doom Emacs: LSP, vterm, org capture, magit, AI helpers |
| `nvim`       | LazyVim: catppuccin, org-mode, OSC 52 clipboard       |
| `ghostty`    | Ghostty terminal: catppuccin, BlexMono Nerd Font Mono 16pt |
| `fontconfig` | Font fallback: BlexMono Nerd Font Mono                |
| `starship`   | Starship prompt config                                |

## Quick Start

```bash
# Clone
# If you use multiple GitHub accounts, configure the github-leoxiaobin SSH alias first.
git clone git@github-leoxiaobin:leoxiaobin/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Install GNU Stow
sudo apt install stow   # Debian/Ubuntu
brew install stow        # macOS

# Apply managed dotfiles
./sync.sh

# Create local overrides (for secrets)
cp templates/zshrc.local.example ~/.zshrc.local
cp templates/gitconfig.local.example ~/.gitconfig.local
# Edit these ↑ with your machine-specific settings
```

Detailed coding-agent instructions live in [AGENTS.md](AGENTS.md). This README
stays focused on human setup, project overview, and daily workflow.

Ghostty reads `~/.config/ghostty/config.ghostty` from the `ghostty` stow package.
Keep machine-specific overrides in `~/.config/ghostty/config`; Ghostty loads that
after `config.ghostty`.

For Windows Terminal/WSL, use `BlexMono Nerd Font Mono` at 16pt. It is the
Nerd Font-patched IBM Plex Mono family, so tmux/starship icons render correctly;
see `templates/windows-terminal-profile.example.jsonc`.

If `github-leoxiaobin` is not configured yet, copy the example from
`templates/ssh-config.github.example` into `~/.ssh/config`, then adjust the
`IdentityFile` path to your personal GitHub key.

## Design Philosophy

- **Editors for editing, terminals for AI.** Claude Code / Codex / Copilot CLI primarily run in tmux/vterm.
- **No API keys in config.** Secrets stay in `~/.zshrc.local` and `~/.gitconfig.local` (not tracked).
- **One theme, one font family.** Catppuccin Mocha everywhere; terminals/editors use BlexMono Nerd Font Mono 16pt where possible.
- **Cross-platform.** Works on Linux, WSL, and macOS with conditional aliases.
- **Keyboard-first.** Optimized for terminal + tmux workflows.

## Daily Workflow

### AI Coding

```bash
ai copilot          # launch Copilot CLI at git root
ai claude           # launch Claude Code at git root
cc                  # short alias for claude
ghcp                # short alias for copilot
```

In Doom Emacs: `SPC a c` (Claude), `SPC a x` (Codex), `SPC a p` (Copilot).

### Navigation

```bash
z project           # zoxide: jump to project directory
tm                  # fuzzy tmux session picker
y                   # yazi file manager
```

### Git Review

```bash
git d               # diff with delta (side-by-side, syntax-highlighted)
git ds              # staged diff
git lg              # pretty log graph
lazygit             # TUI git client
```

In Doom Emacs: `SPC g g` for Magit.

### Tmux

| Key              | Action                              |
|------------------|-------------------------------------|
| `C-q v` / `C-q b` | Split vertical / horizontal       |
| `C-q h/j/k/l`   | Navigate panes (vim-style)          |
| `C-q z`          | Zoom/unzoom pane                    |
| `C-q c`          | New window                          |
| `C-q C-s`        | Save session                        |
| `C-q C-r`        | Restore session                     |

Status bar shows: directory | windows `[pane-count]` | git branch | session | time.
Pane borders show each pane number/command, and the active pane gets a bright
`ACTIVE` label.

### Org Notes

Shared `~/org/` directory accessible from both Doom Emacs and LazyVim:

| File                       | Purpose                |
|----------------------------|------------------------|
| `~/org/inbox.org`          | Quick capture          |
| `~/org/coding-prompts.org` | AI prompts             |
| `~/org/agent-instructions.org` | Agent system prompts |
| `~/org/research.org`       | Research notes         |
| `~/org/workflow.org`       | This setup's documentation |

Doom capture: `SPC X` then select template.

## Updating Configs

```bash
cd ~/dotfiles
# Edit files here (not the symlink targets)
nvim zsh/.zshrc

# Apply local changes to this machine
./sync.sh

# On another machine, after pushing/pulling:
git pull --ff-only
./sync.sh

# Preview changes first:
./sync.sh --dry-run

# After Doom Emacs changes:
doom sync

# After tmux changes:
# Press C-q r inside tmux
```

## Structure

```
~/dotfiles/
├── zsh/.zshrc
├── git/.gitconfig
├── tmux/
│   ├── .tmux.conf      # symlink to .tmux/.tmux.conf
│   └── .tmux/
│       ├── .tmux.conf
│       ├── custom/      # git status bar module
│       └── scripts/     # helper scripts
├── doom/.config/doom/
│   ├── init.el          # module declarations
│   ├── config.el        # main configuration
│   └── packages.el      # package declarations
├── nvim/.config/nvim/
│   ├── init.lua         # LazyVim bootstrap
│   ├── lazyvim.json     # enabled LazyVim extras
│   ├── stylua.toml
│   └── lua/
│       ├── config/      # LazyVim core config
│       └── plugins/     # plugin specs
├── ghostty/.config/ghostty/config.ghostty
├── fontconfig/.config/fontconfig/fonts.conf
├── starship/.config/starship.toml
├── templates/           # example local override files and snippets
├── sync.sh              # re-stow packages after git pull
├── AGENTS.md            # canonical coding-agent instructions
├── CLAUDE.md            # Claude Code pointer to AGENTS.md
├── .github/copilot-instructions.md # Copilot native repo instructions
└── README.md            # this file
```

## License

Personal configuration files. Use freely.
