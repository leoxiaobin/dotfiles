# CLAUDE.md — AI Agent Bootstrap Instructions

This file tells AI coding agents (Claude Code, Codex, Copilot) how to set up
and work with this dotfiles repository.

## What This Repo Is

A GNU Stow-managed dotfiles repo for a terminal-centric dev workflow.
Covers: zsh, git, tmux, Doom Emacs, LazyVim (Neovim), fontconfig, starship.

## Directory Structure

Each top-level folder is a "stow package" that mirrors `$HOME`:

```
dotfiles/
  zsh/.zshrc                          → ~/.zshrc
  git/.gitconfig                      → ~/.gitconfig
  tmux/.tmux/.tmux.conf               → ~/.tmux/.tmux.conf
  tmux/.tmux/custom/                  → ~/.tmux/custom/
  tmux/.tmux/scripts/                 → ~/.tmux/scripts/
  doom/.config/doom/{init,config,packages}.el → ~/.config/doom/
  nvim/.config/nvim/lua/              → ~/.config/nvim/lua/
  ghostty/.config/ghostty/config.ghostty → ~/.config/ghostty/config.ghostty
  fontconfig/.config/fontconfig/      → ~/.config/fontconfig/
  starship/.config/starship.toml      → ~/.config/starship.toml
  templates/                          → example local override files
```

## Setup on a New Machine

### 1. Prerequisites

Install these tools first. Use the platform's package manager.

**Ubuntu/Debian (apt):**
```bash
sudo apt install -y git zsh stow tmux emacs neovim fontconfig curl unzip direnv nodejs npm shellcheck pandoc python3-pip python3-venv
```

**macOS (brew):**
```bash
brew install git zsh stow tmux emacs neovim fontconfig curl direnv node shellcheck pandoc python
```

**Ghostty terminal (optional but recommended):**
```bash
brew install --cask ghostty
# Linux: install from https://ghostty.org/docs/install/binary
```

### 2. Required CLI tools

```bash
# These are expected by the configs:
# - starship (prompt)      : curl -sS https://starship.rs/install.sh | sh
# - fzf (fuzzy finder)     : apt install fzf / brew install fzf
# - zoxide (smart cd)      : curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
# - lsd (ls replacement)   : apt install lsd / brew install lsd
# - bat (cat replacement)  : apt install bat / brew install bat
#   NOTE: On Debian/Ubuntu the binary is 'batcat', the config aliases it to 'cat'
# - fd (find replacement)  : apt install fd-find / brew install fd
#   NOTE: On Debian/Ubuntu the binary is 'fdfind', the config aliases it to 'fd'
# - ripgrep (grep)         : apt install ripgrep / brew install ripgrep
# - delta (git pager)      : download from https://github.com/dandavison/delta/releases
# - yazi (file manager)    : cargo install yazi-fm / brew install yazi
# - lazygit                : go install github.com/jesseduffield/lazygit@latest / brew install lazygit
# - nvm (node manager)     : curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
# - direnv (project envs)  : apt install direnv / brew install direnv
# - node/npm (LSP servers) : apt install nodejs npm / brew install node
# - shellcheck (sh lint)   : apt install shellcheck / brew install shellcheck
# - pandoc (markdown)      : apt install pandoc / brew install pandoc
# - pipenv (Python envs)   : python3 -m pip install --user pipenv
# - nose (legacy tests)    : python3 -m pip install --user nose
#   NOTE: If pip is externally managed, use pipx/apt/brew packages instead.
```

### 3. Clone and stow

```bash
# Use git@github.com:... once SSH keys are configured; otherwise use HTTPS.
git clone git@github.com:leoxiaobin/dotfiles.git ~/dotfiles
# git clone https://github.com/leoxiaobin/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow zsh git tmux doom nvim ghostty fontconfig starship
```

### 4. Create local override files

```bash
cp ~/dotfiles/templates/zshrc.local.example ~/.zshrc.local
cp ~/dotfiles/templates/gitconfig.local.example ~/.gitconfig.local
# Edit these with machine-specific secrets and credential helpers
```

### 5. Post-stow setup

```bash
# tmux: the config expects ~/.tmux.conf → ~/.tmux/.tmux.conf
ln -sf ~/.tmux/.tmux.conf ~/.tmux.conf

# tmux plugins (TPM)
[ -d ~/.tmux/plugins/tpm ] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
tmux new-session -d && tmux source-file ~/.tmux.conf
~/.tmux/plugins/tpm/bin/install_plugins

# oh-my-zsh
RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
# install zsh-syntax-highlighting plugin
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# Doom Emacs
# Emacs prefers ~/.emacs.d over ~/.config/emacs; move old configs aside first.
[ ! -e ~/.emacs.d ] || mv ~/.emacs.d ~/.emacs.d.backup-$(date +%Y%m%d-%H%M%S)
[ ! -e ~/.doom.d ] || mv ~/.doom.d ~/.doom.d.backup-$(date +%Y%m%d-%H%M%S)
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
~/.config/emacs/bin/doom install
export PATH="$HOME/.config/emacs/bin:$PATH"
doom sync
PAGER=cat doom doctor

# LazyVim bootstrap (lazy.nvim auto-installs on first nvim launch)
nvim --headless "+Lazy! sync" +qa

# Fonts: install JetBrainsMono Nerd Font
if [[ "$(uname)" == "Darwin" ]]; then
  brew install --cask font-jetbrains-mono-nerd-font
else
  mkdir -p ~/.local/share/fonts
  curl -fLo /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/
  fc-cache -fv
fi
```

## Platform Notes

- **WSL**: Set terminal font to "JetBrainsMono Nerd Font Mono" in Windows Terminal settings.
  Clipboard uses OSC 52 (no xclip needed).
- **macOS**: Set terminal font in iTerm2/Alacritty/etc. to "JetBrainsMono Nerd Font Mono".
  `bat` and `fd` use native names (no alias needed). For better Emacs performance,
  consider `emacs-plus@30 --with-native-comp`.
- **Linux**: Font and clipboard should work automatically with modern terminal emulators.
- **Ghostty**: Shared settings live in `~/.config/ghostty/config.ghostty`.
  Put machine-specific overrides in `~/.config/ghostty/config`, which Ghostty loads afterward.
- **Terminal Emacs**: Themes render poorly if `TERM=xterm-color`; `.zshrc` upgrades it
  to `xterm-256color` and exports `COLORTERM=truecolor`.

## Design Principles

- **No API keys in configs.** Secrets go in `~/.zshrc.local` / `~/.gitconfig.local`.
- **No heavy AI packages in editors.** AI runs in terminal (Claude Code, Codex, Copilot CLI).
- **Catppuccin Mocha** theme everywhere (Emacs, Neovim, tmux, terminal).
- **JetBrainsMono Nerd Font Mono** everywhere.
- **OSC 52** clipboard (works over SSH, tmux, WSL).
- **Keyboard-first.** Minimal mouse usage.

## Key Keybindings

### tmux (prefix: C-q)
- `C-q v/b` — split vertical/horizontal
- `C-q h/j/k/l` — navigate panes; active pane gets a bright `ACTIVE` border label
- `C-q z` — zoom pane (status shows `[N] 󰊓` when zoomed)
- `C-q C-s` — save session (resurrect)
- `C-q C-r` — restore session (resurrect)

### Doom Emacs (leader: SPC)
- `SPC a c` — open Claude Code in vterm
- `SPC a x` — open Codex in vterm
- `SPC a p` — open Copilot CLI in vterm
- `SPC a a` — open generic AI terminal
- `SPC g g` — Magit status

### Shell
- `ai <tool>` — launch AI CLI at git root
- `cc` / `cx` / `ghcp` — short aliases for claude / codex / copilot
- `tm` — fuzzy tmux session picker (zoxide + fzf)
- `y` — yazi file manager with cd-on-exit

## When Modifying These Configs

- Edit files in `~/dotfiles/`, not the symlink targets
- Run `stow <package>` after adding new files to a package
- Test with `zsh -n ~/.zshrc` (syntax check) before committing
- After Doom changes: `doom sync`
- After tmux changes: `C-q r` to reload
- Keep platform-specific logic behind `IS_WSL` / `IS_MACOS` checks in .zshrc
