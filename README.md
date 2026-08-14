# Dotfiles

Terminal-centric development environment managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Inside

| Package      | What it configures                                                     |
|--------------|------------------------------------------------------------------------|
| `zsh`        | Shell: oh-my-zsh, starship prompt, aliases, AI CLI helpers             |
| `git`        | Git: aliases, delta pager, histogram diff, rerere                      |
| `tmux`       | Tmux: C-q prefix, Su status, git status, resurrect                     |
| `doom`       | Doom Emacs: LSP, vterm, org capture, magit, AI helpers                 |
| `nvim`       | LazyVim: Su theme, org-mode, OSC 52 clipboard                          |
| `ghostty`    | Ghostty terminal: Su palette, Maple Mono NF CN 16pt                    |
| `lsd`        | `lsd` listing colors tuned for light and dark terminals                |
| `yazi`       | Yazi file openers, including HTML files in Google Chrome               |
| `fontconfig` | Font fallback: Maple Mono NF CN                                        |
| `starship`   | Starship prompt config                                                 |
| `scripts`    | Helper scripts, including macOS Su system appearance setup             |

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

# Optional: align macOS system appearance with the Su theme
scripts/apply-su-macos.sh

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

For Windows Terminal/WSL, use the `Su` color scheme and `Maple Mono NF CN`
at 16pt; see `templates/windows-terminal-profile.example.jsonc`.

If `github-leoxiaobin` is not configured yet, copy the example from
`templates/ssh-config.github.example` into `~/.ssh/config`, then adjust the
`IdentityFile` path to your personal GitHub key.

## GPU Development Image

`docker/Dockerfile` packages this environment for NVIDIA GPU servers and ML
platforms that run jobs from a container image.

| Layer      | Contents                                                        |
|------------|-----------------------------------------------------------------|
| Base       | `nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04` (digest-pinned)     |
| Python     | Miniforge at `/opt/conda`, conda env `dev` on Python 3.12        |
| ML         | `torch 2.13.0+cu126` and `torchvision 0.28.0`, NCCL included     |
| Build      | `nvcc`, `cmake`, `ninja` for compiling CUDA extensions           |
| Dotfiles   | `zsh git tmux nvim lsd yazi starship` stowed from `/opt/dotfiles`|

```bash
# Build locally (always targets linux/amd64, the architecture GPU nodes run)
./docker/build.sh

# Build and publish a new immutable version tag
IMAGE_VERSION=pt2.13.0-cu126-v4 ./docker/build.sh --push

# Verify on a GPU node (versions, arch coverage, a kernel, and a NCCL all-reduce)
docker run --rm --gpus all --shm-size=8g \
  leoxiao/pytorch-dev:pt2.13.0-cu126-v3 \
  python /opt/dotfiles/docker/verify-gpu.py
```

The conda env is on `PATH`, so `python` resolves correctly in non-interactive
platform jobs without sourcing a shell profile. Create isolated project
environments with `conda create -n myproject python=3.12` as usual.

### GPU compatibility

The cu126 wheels ship kernels for `sm_50` through `sm_90`, so **Pascal through
Hopper (P100, V100, T4, A100, L40S, H100/H200) work**. There is no PTX fallback,
so **Blackwell (B200/GB200, `sm_100`/`sm_120`) will not run this image**. For
Blackwell, rebuild against CUDA 13.x:

```bash
IMAGE_VERSION=pt2.13.0-cu130-v1 \
CUDA_BASE=nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04 \
TORCH_CUDA_INDEX=https://download.pytorch.org/whl/cu130 \
  ./docker/build.sh --push
```

Ada cards (L40S, L4, RTX 4090) are `sm_89` and run the `sm_86` kernels: CUDA
cubins are compatible across minor revisions within a major version, but never
across major versions, which is exactly why Blackwell is excluded.
`verify-gpu.py` applies that same rule and fails with an explicit message when a
device is genuinely uncovered, so this never shows up as a confusing runtime crash.

### Notes and gotchas

- Building on Apple Silicon uses Rosetta emulation. Only the build is slower;
  the published image runs natively on x86_64 GPU nodes. The image is
  **linux/amd64 only** and will not run on an ARM GPU node such as GB200.
- Pass `--shm-size=8g` (or `--ipc=host`); the default 64 MB `/dev/shm` breaks
  NCCL and PyTorch dataloader workers.
- Mount your code at `/workspace`, not at `/root`. Mounting over `/root` hides
  the stowed dotfiles.
- The container runs as `root` with `HOME=/root`. If your platform forces a
  different UID or `HOME`, the dotfiles are still readable at `/opt/dotfiles`
  and can be re-stowed with `stow -d /opt/dotfiles -t "$HOME" zsh git tmux nvim`.
- `cmake` is 4.x. Older CUDA projects that declare
  `cmake_minimum_required(VERSION <3.5)` fail against it; in that env run
  `pip install "cmake<4"`.
- Inside the container use `git config --file ~/.gitconfig.local ...`.
  `git config --global` writes through the symlink into `/opt/dotfiles` and
  dirties the repo copy.
- `conda activate` needs an initialised shell. In a non-interactive
  `docker exec ... bash -c`, either rely on `PATH` (already correct) or use
  `conda run -n dev python ...`.
- The image contains no credentials. Mount `~/.gitconfig.local` and any tokens
  at runtime.
- Never re-push an existing version tag; bump `IMAGE_VERSION` instead.
  `docker/build.sh` refuses to overwrite a tag that already exists remotely.

## Design Philosophy

- **Editors for editing, terminals for AI.** Claude Code / Codex / Copilot CLI primarily run in tmux/vterm.
- **No API keys in config.** Secrets stay in `~/.zshrc.local` and `~/.gitconfig.local` (not tracked).
- **One theme, one font family.** Su colors everywhere; terminals/editors use Maple Mono NF CN 16pt where possible.
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

| Key               | Action                      |
|-------------------|-----------------------------|
| `C-q v` / `C-q b` | Split vertical / horizontal |
| `C-q h/j/k/l`     | Navigate panes (vim-style)  |
| `C-q z`           | Zoom/unzoom pane            |
| `C-q c`           | New window                  |
| `C-q C-s`         | Save session                |
| `C-q C-r`         | Restore session             |

Status bar shows: directory | windows `[pane-count]` | git branch | session | time.
Pane borders show each pane number/command, and the active pane gets a bright
`ACTIVE` label.

### Org Notes

Shared `~/org/` directory accessible from both Doom Emacs and LazyVim:

| File                           | Purpose                    |
|--------------------------------|----------------------------|
| `~/org/inbox.org`              | Quick capture              |
| `~/org/coding-prompts.org`     | AI prompts                 |
| `~/org/agent-instructions.org` | Agent system prompts       |
| `~/org/research.org`           | Research notes             |
| `~/org/workflow.org`           | This setup's documentation |

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
├── yazi/.config/yazi/yazi.toml
├── fontconfig/.config/fontconfig/fonts.conf
├── starship/.config/starship.toml
├── templates/           # example local override files and snippets
├── scripts/             # helper scripts, not managed by Stow
├── docker/              # GPU development image (not a Stow package)
│   ├── Dockerfile
│   ├── build.sh         # build/push helper, pins linux/amd64
│   └── verify-gpu.py    # runtime GPU/NCCL check
├── sync.sh              # re-stow packages after git pull
├── AGENTS.md            # canonical coding-agent instructions
├── CLAUDE.md            # Claude Code pointer to AGENTS.md
├── .github/copilot-instructions.md # Copilot native repo instructions
└── README.md            # this file
```

## License

Personal configuration files. Use freely.
