# AGENTS.md — Coding Agent Instructions

This is the canonical instruction file for coding agents working in this repo.
It complements `README.md`: the README is for humans, with a concise project
overview, quick start, and daily workflow; this file contains the extra
operational context agents need, including setup runbooks, validation commands,
repository conventions, and known pitfalls.

Discovery entry points:

- Claude Code starts from the root `CLAUDE.md` compatibility file, which points here.
- Codex discovers `AGENTS.md` directly.
- GitHub Copilot uses `.github/copilot-instructions.md` for concise native
  instructions that point back to this canonical guide.

Keep human-facing documentation in `README.md`. Keep detailed agent guidance,
build/test commands, and repository-specific implementation rules here.

## Response Marker

After loading these instructions, start user-facing replies with
`✅ [dotfiles]` when practical. For very short replies, `✅` is enough.
This visible marker helps confirm that the agent found and is following
`AGENTS.md`, especially during long-running conversations.

## What This Repo Is

A GNU Stow-managed dotfiles repo for a terminal-centric dev workflow.
Covers: zsh, git, tmux, Doom Emacs, LazyVim (Neovim), Ghostty, lsd, Yazi, fontconfig, starship.

## Directory Structure

Each top-level folder is a "stow package" that mirrors `$HOME`:

```
dotfiles/
  zsh/.zshrc                          → ~/.zshrc
  git/.gitconfig                      → ~/.gitconfig
  tmux/.tmux.conf                     → ~/.tmux.conf
  tmux/.tmux/.tmux.conf               → ~/.tmux/.tmux.conf
  tmux/.tmux/custom/                  → ~/.tmux/custom/
  tmux/.tmux/scripts/                 → ~/.tmux/scripts/
  doom/.config/doom/{init,config,packages}.el → ~/.config/doom/
  nvim/.config/nvim/init.lua          → ~/.config/nvim/init.lua
  nvim/.config/nvim/lazyvim.json      → ~/.config/nvim/lazyvim.json
  nvim/.config/nvim/stylua.toml       → ~/.config/nvim/stylua.toml
  nvim/.config/nvim/lua/              → ~/.config/nvim/lua/
  ghostty/.config/ghostty/config.ghostty → ~/.config/ghostty/config.ghostty
  lsd/.config/lsd/{config,colors}.yaml → ~/.config/lsd/
  yazi/.config/yazi/yazi.toml          → ~/.config/yazi/yazi.toml
  fontconfig/.config/fontconfig/      → ~/.config/fontconfig/
  starship/.config/starship.toml      → ~/.config/starship.toml
  templates/                          → example local override files
  scripts/apply-su-macos.sh           → apply Su-aligned macOS appearance defaults
  docker/Dockerfile                   → GPU development image (not a Stow package)
  docker/build.sh                     → build/push helper for the GPU image
  docker/verify-gpu.py                → runtime GPU/NCCL verification
  sync.sh                             → re-stow packages after git pull
```

## Agent Runbook: Setup on a New Machine

### 1. Prerequisites

Install these tools first. Use the platform's package manager.

**Ubuntu/Debian (apt):**
```bash
sudo apt install -y git zsh stow tmux emacs neovim fontconfig curl unzip direnv nodejs npm shellcheck markdown fonts-symbola pandoc python3-pip python3-venv
```

**macOS (brew):**
```bash
brew doctor
test -w /opt/homebrew || echo "Homebrew is not writable. Run: sudo chown -R $USER /opt/homebrew && chmod -R u+w /opt/homebrew"
brew install git zsh stow tmux emacs neovim fontconfig curl direnv node shellcheck discount pandoc python pipenv pytest isort pipx
```

The Neovim config currently enables `lazyvim.plugins.extras.ai.copilot-native`,
which requires Neovim `>= 0.12`. On macOS, upgrade before running LazyVim sync:

```bash
brew upgrade neovim
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
# - w3m (Yazi HTML preview): apt install w3m / brew install w3m
# - lazygit                : go install github.com/jesseduffield/lazygit@latest / brew install lazygit
# - nvm (node manager)     : curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
# - direnv (project envs)  : apt install direnv / brew install direnv
# - node/npm (LSP servers) : apt install nodejs npm / brew install node
# - shellcheck (sh lint)   : apt install shellcheck / brew install shellcheck
# - markdown compiler      : apt install markdown pandoc / brew install discount pandoc
# - pipenv (Python envs)   : apt install pipenv / brew install pipenv
# - pytest/isort           : apt install python3-pytest isort / brew install pytest isort
# - nose (legacy tests)    : pipx install nose
#   NOTE: Homebrew Python is externally managed by PEP 668. Prefer brew/pipx
#   over `python3 -m pip install --user ...` on macOS.
```

### 3. Install framework-level dependencies

Install these before syncing so their installers do not overwrite symlinked
dotfiles.

```bash
# oh-my-zsh (do not generate/overwrite .zshrc)
RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# Doom Emacs framework (not tracked in this repo)
[ -d ~/.config/emacs ] || git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs

# tmux plugin manager
[ -d ~/.tmux/plugins/tpm ] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

### 4. Clone and sync

```bash
# If multiple GitHub accounts are used, configure github-leoxiaobin first.
# See templates/ssh-config.github.example.
git clone git@github-leoxiaobin:leoxiaobin/dotfiles.git ~/dotfiles
# git clone https://github.com/leoxiaobin/dotfiles.git ~/dotfiles
cd ~/dotfiles
./sync.sh --dry-run
./sync.sh
```

On an existing machine, `stow` will refuse to overwrite real files already at
the target paths. If `./sync.sh --dry-run` reports conflicts, back them up
before syncing:

```bash
backup_dir="$HOME/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

for path in \
  .zshrc .gitconfig .tmux.conf .tmux/.tmux.conf \
  .config/starship.toml \
  .config/yazi/yazi.toml \
  .config/doom/config.el .config/doom/init.el .config/doom/packages.el \
  .config/nvim/init.lua .config/nvim/lazyvim.json .config/nvim/stylua.toml \
  .config/nvim/lua/config/autocmds.lua \
  .config/nvim/lua/config/keymaps.lua \
  .config/nvim/lua/config/lazy.lua \
  .config/nvim/lua/config/options.lua \
  .config/nvim/lua/plugins/colorscheme.lua \
  .config/nvim/lua/plugins/orgmode.lua
do
  target="$HOME/$path"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$backup_dir/$(dirname "$path")"
    mv "$target" "$backup_dir/$path"
  fi
done
```

### 5. Create local override files

```bash
cp ~/dotfiles/templates/zshrc.local.example ~/.zshrc.local
cp ~/dotfiles/templates/gitconfig.local.example ~/.gitconfig.local
# Edit these with machine-specific secrets and credential helpers
```

### 6. Post-sync setup

```bash
tmux start-server \; source-file ~/.tmux.conf
~/.tmux/plugins/tpm/bin/install_plugins

# Doom Emacs
# Emacs prefers ~/.emacs.d over ~/.config/emacs; make it point at Doom.
if [ -e ~/.emacs.d ] && [ ! -L ~/.emacs.d ]; then
  mv ~/.emacs.d ~/.emacs.d.backup-$(date +%Y%m%d-%H%M%S)
fi
[ ! -L ~/.emacs.d ] || rm ~/.emacs.d
[ ! -e ~/.doom.d ] || mv ~/.doom.d ~/.doom.d.backup-$(date +%Y%m%d-%H%M%S)
ln -sfn "$HOME/.config/emacs" "$HOME/.emacs.d"
~/.config/emacs/bin/doom install
export PATH="$HOME/.config/emacs/bin:$PATH"
doom sync --force --rebuild
PAGER=cat doom doctor

# LazyVim bootstrap (lazy.nvim auto-installs on first Neovim launch)
nvim --headless "+Lazy! sync" +qa

# Yazi HTML text previewer (requires w3m)
ya pkg add yazi-rs/plugins:piper

# Fonts: install terminal/editor fonts
if [[ "$(uname)" == "Darwin" ]]; then
  brew install --cask font-maple-mono-nf-cn
else
  mkdir -p ~/.local/share/fonts
  # Download the NF-CN archive from https://github.com/subframe7536/maple-font/releases
  # and extract its font files into ~/.local/share/fonts/.
  fc-cache -fv
fi
```

Known long-running steps:

- `doom sync --force --rebuild` can take 10-15 minutes on a fresh or upgraded setup.
- If `doom upgrade` appears stuck for many minutes while fetching recipe repos,
  stop it, make sure no orphaned `git fetch` children are still running, then use
  `doom sync --force --rebuild`.
- macOS+Ghostty: if a tty `emacsclient -t` frame (the `e` alias) renders
  terminal themes with incorrect backgrounds while plain `emacs` (GUI) looks correct,
  the cause is Ghostty exporting `TERMINFO=/Applications/Ghostty.app/...`
  whose terminfo db only contains `xterm-ghostty`. Inside tmux this breaks
  ncurses lookup for `tmux-256color`. The zshrc now unsets that TERMINFO on
  macOS, but Doom may have cached it: edit `~/.config/emacs/.local/env` and
  remove the `TERMINFO=...` line, then restart the daemon.

- If Doom fails with `Could not find package git-commit`, add this package
  override to `doom/.config/doom/packages.el` and rerun sync:

```elisp
(package! git-commit
  :recipe (:host github :repo "magit/magit"
           :files ("lisp/git-commit.el" "lisp/git-commit-pkg.el")))
```

## Platform Notes

- **WSL**: Set Windows Terminal font to "Maple Mono NF CN" at 16pt.
  It includes Chinese and Nerd Font glyphs, so tmux/starship icons render correctly.
  Clipboard uses OSC 52 (no xclip needed).
- **macOS**: Ghostty uses Maple Mono NF CN at 16pt from `ghostty/.config/ghostty/config.ghostty`.
  For iTerm2/Alacritty/etc., use Maple Mono NF CN 16pt for consistent icons.
  `bat` and `fd` use native names (no alias needed). For better Emacs performance,
  consider `emacs-plus@30 --with-native-comp`.
  Doom doctor may warn about the legacy Symbola fallback font. Homebrew may not
  provide `font-symbola`; this is not blocking when Symbols Nerd Font Mono is
  present.
- **Linux**: Font and clipboard should work automatically with modern terminal emulators.
- **Ghostty**: Shared settings live in `~/.config/ghostty/config.ghostty`.
  Put machine-specific overrides in `~/.config/ghostty/config`, which Ghostty loads afterward.
- **Terminal Emacs**: Themes render poorly if `TERM=xterm-color`; `.zshrc` upgrades it
  to `xterm-256color` and exports `COLORTERM=truecolor`.

## GPU Development Image

`docker/` builds a container image of this environment for NVIDIA GPU servers.
It is **not** a Stow package and `sync.sh` must not manage it.

Composition:

- Base `nvidia/cuda:<ver>-cudnn-devel-ubuntu24.04`, pinned by digest and chosen
  by the CUDA variant (see below).
- Miniforge at `/opt/conda` with conda env `dev` (Python 3.12).
- `torch==2.13.0` + `torchvision==0.28.0` from the matching `cuNNN` wheel index.
- `cmake` and `ninja` via pip so `torch.utils.cpp_extension` can build CUDA
  extensions. `is_ninja_available()` is asserted at build time.
- Dotfiles copied to `/opt/dotfiles` and stowed into `/root` for the
  container-relevant packages only: `zsh git tmux nvim lsd yazi starship`.

Commands:

```bash
./docker/build.sh --cuda cu126                      # build linux/amd64 locally
IMAGE_REVISION=v4 ./docker/build.sh --cuda cu126 --push
./docker/build.sh --cuda cu130 --push               # CUDA 13 / Blackwell image
shellcheck docker/build.sh
python3 -m py_compile docker/verify-gpu.py
docker run --rm --gpus all --shm-size=8g IMAGE python /opt/dotfiles/docker/verify-gpu.py
```

CUDA variants:

- Supported variants live in one place: `base_for_variant()` in
  `docker/build.sh`, which pairs each `cuNNN` with a digest-pinned base image.
  `--cuda` sets **both** the base and the wheel index; never set one alone.
- Tags are composed as `pt<torch>-<cuda>-<revision>`, e.g. `pt2.13.0-cu130-v1`.
  `IMAGE_REVISION` bumps the revision; `IMAGE_VERSION` overrides the whole tag.
- Adding a version means: confirm the wheel index has matching `torch` and
  `torchvision` for cp312, confirm an `nvidia/cuda:<x.y.z>-cudnn-devel-ubuntu24.04`
  tag exists, record its **amd64** digest, then add a `base_for_variant()` case.
- Arch coverage differs per variant and is not monotonic. Verified build output:
  `cu126` -> `sm_50..sm_90` (no Blackwell); `cu130` and `cu132` -> `sm_75..sm_120`
  (gain Blackwell, **lose Volta and Pascal**). Never assume a newer CUDA is a
  superset. Published: `pt2.13.0-cu126-v3`, `pt2.13.0-cu130-v1`,
  `pt2.13.0-cu132-v1`; `:latest` tracks cu126 for widest driver support. CUDA 12.x needs driver >= 525.60.13, CUDA 13.x needs >= 580.65.06.
- The torch install layer asserts that `nvcc`'s CUDA major matches
  `torch.version.cuda`'s major, which catches a base/index mismatch at build time
  instead of shipping an image where extensions compile against the wrong CUDA.

Rules and pitfalls:

- The CUDA build of PyTorch is selected by `--index-url`, not by the version
  string. Plain PyPI `torch` now targets CUDA 13 and needs a much newer driver.
- `torchaudio` is deliberately absent: its newest `cu126` build is 2.11, so
  installing it would downgrade `torch` to 2.11.
- Never assert `torch.cuda.is_available()` in a `RUN` step; BuildKit has no GPU.
  Build-time checks are limited to imports, versions, and `torch.version.cuda`.
- `ENV PATH` puts the conda env first so non-interactive platform jobs resolve
  `python` correctly without sourcing a shell rc. Keep it that way.
- Conda shell glue lives in `/etc/zsh/zshrc` and `/etc/profile.d/00-conda.sh`,
  deliberately outside the Stow packages so it cannot collide with host dotfiles.
- Mount workspaces at `/workspace`. Mounting over `/root` hides the stowed
  symlinks and breaks the shell setup.
- NCCL arrives via the `nvidia-nccl-cu12` torch dependency; the image also
  installs `rdma-core`/`libibverbs1`/`librdmacm1`/`ibverbs-providers` so NCCL can
  use InfiniBand or RoCE instead of falling back to TCP. Runtime still needs
  `--shm-size` raised (or `--ipc=host`).
- Framework repos without releases (oh-my-zsh, zsh-syntax-highlighting, TPM) are
  pinned by commit ARG. Bump those ARGs deliberately rather than drifting.
- Treat published tags as immutable: bump `IMAGE_VERSION` instead of re-pushing.
  `docker/build.sh` fails fast when the target tag already exists remotely;
  `--force` is the deliberate escape hatch.
- Every variant compiles cubins with **no PTX fallback**, so an uncovered
  architecture cannot be JIT-rescued. Use `--cuda` rather than editing
  `CUDA_BASE`/`TORCH_CUDA_INDEX` by hand. `verify-gpu.py` checks device
  capability against `torch.cuda.get_arch_list()` and fails with an explicit
  message.
  Compare architectures by `(major, minor)` with the minor-forward rule, never by
  exact string: `sm_89` (L40S/L4/4090) legitimately runs the `sm_86` kernels, and
  an exact match would reject working hardware. Arch strings can carry `a`/`f`
  suffixes (`sm_90a`, `compute_120f`), so they must be parsed, not sliced.
- `zsh/.zshrc` sets `zstyle ':omz:update' mode auto`, which takes precedence over
  `DISABLE_AUTO_UPDATE` and cannot be overridden from `/etc/zsh/zshrc` (the
  zstyle runs before `oh-my-zsh.sh` is sourced). The image therefore deletes
  `/root/.oh-my-zsh/.git` so the update check bails out and the pinned commit
  stays pinned. Keep TPM's `.git`; it needs git to manage plugins. The only
  side effect is that a manual `omz update` inside the container prints git
  errors; rebuild the image instead of updating in place.
- Inside the container, `git config --global` writes through the symlink into
  `/opt/dotfiles/git/.gitconfig` and dirties the repo copy. Use
  `git config --file ~/.gitconfig.local` instead. Build steps that must set git
  config use `git config --system`; using `--global` in a `RUN` creates
  `/root/.gitconfig` and makes the later `stow` step abort.
- `conda activate` requires an initialised shell, so it fails in a plain
  non-interactive `bash -c`. `PATH` already points at the env; use `conda run -n dev`
  when an explicit activation is needed.
- The image runs as root with `HOME=/root`. If a platform overrides UID or HOME,
  the dotfiles remain readable at `/opt/dotfiles` and can be re-stowed there.
- No credentials belong in any layer. `.dockerignore` excludes `.git`, `*.local`,
  key material, `.env`, `.netrc`, `.npmrc`, and cloud credential directories;
  runtime config is mounted.

## Design Principles

- **No API keys in configs.** Secrets go in `~/.zshrc.local` / `~/.gitconfig.local`.
- **Terminal-first AI workflow.** Claude Code, Codex, and Copilot CLI run in tmux/vterm; editor AI extras are optional and account-authenticated.
- **Su** theme everywhere (Windows Terminal/Ghostty, tmux, Emacs, Neovim, git delta, lsd, fzf, Starship).
- **Maple Mono NF CN 16pt** in terminals, Emacs, and fontconfig.
- **OSC 52** clipboard (works over SSH, tmux, WSL).
- **Keyboard-first.** Minimal mouse usage.

## Key Keybindings

### tmux (prefix: C-q)
- `C-q v/b` — split vertical/horizontal
- `C-q h/j/k/l` — navigate panes; active pane gets an MAI ochre `ACTIVE` border label
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
- Run `./sync.sh` after adding or changing managed dotfiles
- To sync another machine after changes are pushed: `cd ~/dotfiles && git pull --ff-only && ./sync.sh`
- Agents may use `./sync.sh --pull` to pull and sync in one step, or `./sync.sh --dry-run` to preview
- Prefer `./sync.sh` over raw `stow`; use direct `stow` only when debugging the sync script itself
- Preserve local override files (`~/.zshrc.local`, `~/.gitconfig.local`, `~/.config/ghostty/config`)
- After running `./sync.sh`, verify the synced environment before reporting success:
  - `zsh -n ~/.zshrc`
  - `test -L ~/.tmux.conf`
  - `tmux source-file ~/.tmux.conf` when tmux is installed
  - `ghostty +validate-config --config-file=~/.config/ghostty/config.ghostty` when Ghostty is installed
  - `nvim --headless "+Lazy! sync" +qa`
  - `doom sync --force --rebuild`
  - `PAGER=cat doom doctor`
- Test with `zsh -n ~/.zshrc` (syntax check) before committing
- After Doom changes: `doom sync --force --rebuild`, then restart the daemon:
  `emacsclient -e '(kill-emacs)' && emacs --daemon`
  (The running daemon won't pick up newly installed packages until restarted.)
- After tmux changes: `C-q r` to reload
- Keep platform-specific logic behind `IS_WSL` / `IS_MACOS` checks in .zshrc
