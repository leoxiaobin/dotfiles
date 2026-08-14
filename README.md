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
| Base       | `nvidia/cuda:<ver>-cudnn-devel-ubuntu24.04` (digest-pinned)      |
| Python     | Miniforge at `/opt/conda`, conda env `dev` on Python 3.12        |
| ML         | `torch 2.13.0` and `torchvision 0.28.0`, NCCL included           |
| Build      | `nvcc`, `cmake`, `ninja` for compiling CUDA extensions           |
| Dotfiles   | `zsh git tmux nvim lsd yazi starship` stowed from `/opt/dotfiles`|

### Choosing a CUDA variant

**Pick the variant by the GPUs and driver on your cluster, not by "newest".**
CUDA 13 gained Blackwell but dropped Volta and Pascal.

| Tag                     | CUDA | Kernels        | GPUs                            | Min driver |
|-------------------------|------|----------------|---------------------------------|------------|
| `pt2.13.0-cu126-v3`     | 12.6 | `sm_50`-`sm_90`  | P100/V100/T4/A100/L40S/H100     | 525.60.13  |
| `pt2.13.0-cu130-v1`     | 13.0 | `sm_75`-`sm_120` | T4/A100/L40S/H100 **+ Blackwell** | 580.65.06 |
| `pt2.13.0-cu132-v1`     | 13.2 | `sm_75`-`sm_120` | same as cu130, newer toolkit    | 580.65.06  |

`:latest` points at the cu126 image because it runs on the widest range of
drivers. **Pin an explicit tag in cluster jobs** rather than relying on it.

cu130 and cu132 cover the same GPUs; cu132 only ships a newer `nvcc` and CUDA
libraries. A `cu129` variant (CUDA 12.9: Blackwell while staying on the 12.x
driver line) is supported but not published: `./docker/build.sh --cuda cu129 --push`.

Check the driver on a node before choosing:

```bash
nvidia-smi --query-gpu=name,driver_version --format=csv
```

Ada cards (L40S, L4, RTX 4090) report `sm_89` and run the `sm_86` kernels: CUDA
cubins are compatible across minor revisions within a major version, but never
across major versions. That rule is why `sm_89` works everywhere above while a
`sm_70` V100 cannot run the CUDA 13 image. `verify-gpu.py` applies the same rule
and fails with an explicit message, so a mismatch never surfaces as a confusing
runtime crash.

### Building

```bash
# Build locally (always targets linux/amd64, the architecture GPU nodes run)
./docker/build.sh --cuda cu126

# Build and publish a new immutable revision
IMAGE_REVISION=v4 ./docker/build.sh --cuda cu126 --push

# Verify on a GPU node (versions, arch coverage, a kernel, and a NCCL all-reduce)
docker run --rm --gpus all --shm-size=8g \
  leoxiao/pytorch-dev:pt2.13.0-cu130-v1 \
  python /opt/dotfiles/docker/verify-gpu.py
```

Tags are composed as `pt<torch>-<cuda>-<revision>`. `--cuda` moves the base image
and the PyTorch wheel index together, which is the only safe way to change CUDA
version: the wheel index, not the version string, selects the CUDA build. The
build fails if the two ever disagree.

The conda env is on `PATH`, so `python` resolves correctly in non-interactive
platform jobs without sourcing a shell profile. Create isolated project
environments with `conda create -n myproject python=3.12` as usual.

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
