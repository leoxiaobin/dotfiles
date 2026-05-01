# Copilot instructions

This is a GNU Stow-managed dotfiles repository for a terminal-centric development environment. Top-level package directories mirror `$HOME`, and `sync.sh` is the supported entry point for applying them.

## Commands

| Task                               | Command                                                                         |
|------------------------------------|---------------------------------------------------------------------------------|
| Preview Stow changes               | `./sync.sh --dry-run`                                                           |
| Apply all managed dotfiles         | `./sync.sh`                                                                     |
| Pull and apply                     | `./sync.sh --pull`                                                              |
| Check zsh syntax for the repo file | `zsh -n zsh/.zshrc`                                                             |
| Check zsh syntax after syncing     | `zsh -n ~/.zshrc`                                                               |
| Lint one shell script              | `shellcheck sync.sh` or `shellcheck tmux/.tmux/custom/git_status.sh`            |
| Reload tmux after syncing          | `tmux source-file ~/.tmux.conf`                                                 |
| Validate Ghostty config            | `ghostty +validate-config --config-file=ghostty/.config/ghostty/config.ghostty` |
| Sync LazyVim plugins/config        | `nvim --headless "+Lazy! sync" +qa`                                             |
| Sync Doom Emacs after Doom changes | `doom sync --force --rebuild`                                                   |
| Check Doom Emacs health            | `PAGER=cat doom doctor`                                                         |

Use the narrowest relevant command above for the package being changed, then run `./sync.sh --dry-run` when a change affects Stow layout.

## Architecture

Each top-level directory is a Stow package: `zsh`, `git`, `tmux`, `doom`, `nvim`, `ghostty`, `fontconfig`, and `starship`. `sync.sh` hard-codes this package list and runs `stow --no-folding -R` into `$HOME`; add new managed packages there when adding a new top-level package.

`zsh/.zshrc` is the shell entry point. It sets cross-platform defaults, loads Oh My Zsh when present, initializes starship and zoxide opportunistically, lazy-loads nvm, provides tmux/yazi helpers, and exposes the `ai <tool>` launcher that starts AI CLIs at the current git root.

`tmux/.tmux.conf` is the user-facing tmux config and loads TPM plugins, Catppuccin, resurrect/continuum, post-plugin pane-border overrides, and the custom git branch status module. The git module is split between `tmux/.tmux/custom/git_branch.conf` and `tmux/.tmux/custom/git_status.sh`; layout helpers live in `tmux/.tmux/scripts/`.

Doom Emacs config is split by Doom convention: `doom/.config/doom/init.el` declares modules, `config.el` contains behavior/keybindings, and `packages.el` declares extra packages. The Doom config is terminal-AI oriented: vterm helpers open Claude, Codex, Copilot, or a generic AI terminal at the project root.

Neovim uses LazyVim. `nvim/.config/nvim/init.lua` boots `lua/config/lazy.lua`; LazyVim extras are tracked in `lazyvim.json`; local plugin overrides live under `lua/plugins/`; core options/keymaps/autocmds live under `lua/config/`. The enabled `copilot-native` extra requires Neovim `>= 0.12`.

Doom Emacs and Neovim share the `~/org/` workflow for notes, prompts, agent instructions, and experiment logs. Catppuccin Mocha, BlexMono Nerd Font Mono, and OSC 52 clipboard behavior are intentionally shared across terminal/editor configs.

## Conventions

Edit files in this repository, not the symlink targets in `$HOME`. Apply changes with `./sync.sh`; use raw `stow` only when debugging the sync script itself.

Keep machine-specific or secret material out of tracked files. Local overrides belong in `~/.zshrc.local`, `~/.gitconfig.local`, and `~/.config/ghostty/config`, with examples under `templates/`.

Keep platform-specific zsh behavior behind the existing `IS_WSL` and `IS_MACOS` checks. Preserve Debian/Ubuntu versus macOS command-name handling for tools like `bat`/`batcat` and `fd`/`fdfind`.

For Doom changes, update the appropriate Doom file and run `doom sync --force --rebuild`. For LazyVim changes, keep custom plugin specs in `lua/plugins/` and core LazyVim configuration in `lua/config/`.

For tmux changes, keep TPM initialization before post-plugin overrides, and keep the custom git branch module loaded after Catppuccin so theme variables exist.

The repo intentionally favors terminal/vterm/tmux AI workflows over checked-in API-key based editor integrations. Do not add API keys or account-specific identity settings to shared config files.
