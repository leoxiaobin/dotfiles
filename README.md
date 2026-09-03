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
| `sketchybar` | SketchyBar: AeroSpace workspaces, focused app, battery, and clock       |
| `aerospace`  | AeroSpace: keyboard-first window focus, movement, and workspaces       |
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

# Install dependencies and apply the platform-specific dotfiles
./bootstrap.sh

# Preview without installing or changing links
./bootstrap.sh --dry-run

# Apply dotfiles when dependencies are already installed
./sync.sh --dry-run
./sync.sh

# Optional: align macOS system appearance with the Su theme
scripts/apply-su-macos.sh

# Create local overrides (for secrets)
cp templates/zshrc.local.example ~/.zshrc.local
cp templates/gitconfig.local.example ~/.gitconfig.local
# Edit these ↑ with your machine-specific settings
```

`sync.sh` detects macOS, Linux, and WSL. Shared packages are applied on every
platform; AeroSpace and SketchyBar are applied only on macOS. The Linux
bootstrap currently supports Debian and Ubuntu, including WSL, and asks before
using `sudo`. Unsupported distributions fail with an explicit error instead of
guessing package names.

`Brewfile` is the macOS dependency manifest. `install/linux.sh` contains the
Debian/Ubuntu dependency list and installs a checksum-verified Neovim `v0.12.5`
under `~/.local` when the existing version is older than `0.12`. Some
cross-platform tools that aren't reliably available from apt (including
Starship, Yazi, and Ghostty) remain explicit post-install requirements on Linux.

Detailed coding-agent instructions live in [AGENTS.md](AGENTS.md). This README
stays focused on human setup, project overview, and daily workflow.

Ghostty reads `~/.config/ghostty/config.ghostty` from the `ghostty` stow package.
Keep machine-specific overrides in `~/.config/ghostty/config`; Ghostty loads that
after `config.ghostty`.

AeroSpace reads `~/.aerospace.toml` from the `aerospace` stow package. Launch
the app once to grant Accessibility permission; later config changes can be
applied with `aerospace reload-config`.

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
| GPU tools  | `nvidia-smi`, `nvitop`, `nvtop`                                  |
| Dotfiles   | `zsh git tmux nvim lsd yazi starship` stowed from `/opt/dotfiles`|

### Choosing a CUDA variant

**Pick the variant by the GPUs and driver on your cluster, not by "newest".**
CUDA 13 gained Blackwell but dropped Volta and Pascal.

| Tag                     | CUDA | Kernels        | GPUs                            | Min driver |
|-------------------------|------|----------------|---------------------------------|------------|
| `pt2.13.0-cu126-v7`     | 12.6 | `sm_50`-`sm_90`  | P100/V100/T4/A100/L40S/H100     | 525.60.13  |
| `pt2.13.0-cu130-v7`     | 13.0 | `sm_75`-`sm_120` | T4/A100/L40S/H100 **+ Blackwell** | 580.65.06 |
| `pt2.13.0-cu132-v7`     | 13.2 | `sm_75`-`sm_120` | same as cu130, newer toolkit    | 580.65.06  |

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

# Check a built image before publishing it
./docker/smoke-test.sh leoxiao/pytorch-dev:pt2.13.0-cu126-v7 cu126

# Build and publish a new immutable revision
IMAGE_REVISION=v8 ./docker/build.sh --cuda cu126 --push

# Verify on a GPU node (versions, arch coverage, a kernel, and a NCCL all-reduce)
docker run --rm --gpus all --shm-size=8g \
  leoxiao/pytorch-dev:pt2.13.0-cu130-v7 \
  python /opt/dotfiles/docker/verify-gpu.py
```

Tags are composed as `pt<torch>-<cuda>-<revision>`. `--cuda` moves the base image
and the PyTorch wheel index together, which is the only safe way to change CUDA
version: the wheel index, not the version string, selects the CUDA build. The
build fails if the two ever disagree.

`docker/smoke-test.sh` asserts the things that have actually broken before: the
dotfiles resolving inside a mounted home, `Ctrl-R`/`Ctrl-U` bound, `tput` under
`TERM=xterm-ghostty`, tmux starting, no dangling links, and provisioning
surviving an overridden entrypoint. It needs no GPU; `docker/verify-gpu.py`
covers what only a GPU node can answer.

The conda env is on `PATH`, so `python` resolves correctly in non-interactive
platform jobs without sourcing a shell profile. Create isolated project
environments with `conda create -n myproject python=3.12` as usual.

### Building on GitHub Actions

`.github/workflows/gpu-image.yml` builds and publishes the same image from CI.
GitHub's runners are amd64, so the build runs natively instead of under the
Rosetta emulation a local Apple Silicon build needs.

Two repository secrets are required (**Settings → Secrets and variables →
Actions**):

| Secret               | Value                                                     |
|----------------------|-----------------------------------------------------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username                                   |
| `DOCKERHUB_TOKEN`    | A Docker Hub **access token** with Read & Write permission |

Create the token at **Docker Hub → Account Settings → Personal access tokens**;
use a token rather than your password so it can be revoked on its own.

Run it from **Actions → GPU image → Run workflow**, or:

```bash
gh workflow run gpu-image.yml \
  -f variants='["cu126","cu130","cu132"]' -f revision=v7 -f push=true
```

The variants build in parallel, each one building, smoke-testing and only then
pushing. `:latest` follows cu126. Leaving `push` off gives a build-and-test dry
run.

A measured cu126 run took **6 minutes** end to end, against roughly an hour for
the same build on an Apple Silicon laptop, where every instruction goes through
Rosetta. CI is the faster way to cut a release; the local script stays for
iterating on the Dockerfile.

### Platform-mounted home directories

Training platforms commonly mount a shared, persistent home directory and point
`HOME` at it (for example `/home/felix.xiao`). Everything baked into `/root`
becomes unreachable at that point, so the shell would come up with no
oh-my-zsh, no prompt and no aliases.

The image handles this itself. It builds a skeleton home at `/opt/home-skel`
and mirrors it into whatever `HOME` the container is given, on first use:

- Directories become real directories, so your own files sit alongside ours.
- Files become **absolute** symlinks into `/opt/dotfiles`. Stow's own links are
  relative and only resolve from one directory depth, which is exactly why a
  plain `stow --target "$HOME"` does not work here.
- Bulk payloads (`.oh-my-zsh`, `.tmux/plugins`, `.local/share/nvim`,
  `.local/share/yazi`) are linked whole, so a network home does not receive tens
  of thousands of symlinks.
- Files you already have are never overwritten, and a `.dotfiles-init-stamp`
  makes repeat starts a no-op. Anything kept is listed in
  `.dotfiles-init-skipped`, and an interactive shell says so once so a
  pre-populated home does not look like the dotfiles silently failing.
- On an image upgrade, links left dangling by the previous revision are
  repaired and payload links the image no longer ships are dropped. This
  matters because the mounted home outlives the container. Only links pointing
  into `/opt` are ever reclaimed, so a link of your own that happens to dangle
  because this container did not mount its target is left alone and reported.
  `.dotfiles-init-manifest` records what the last run created, which is what
  lets a later revision clean up after itself.
- Concurrent starts are safe: one container per rank can race against the same
  networked home, and only one run provisions it.

Provisioning is triggered from `/etc/zsh/zshenv` (before `~/.zshrc`, so the
shell that triggers it still benefits), `/etc/profile.d`, `/etc/bash.bashrc`,
`BASH_ENV` and the entrypoint, so it happens however the job starts, including
`docker run IMAGE python train.py`.

If your platform replaces the entrypoint *and* starts the job with a plain
non-interactive `sh -c`, none of those hooks fire — dash has no non-interactive
hook. This is self-correcting rather than fatal, because the mounted home is
persistent: run `dotfiles-init` once (or start one shell) and the links stay
there for every later job. Re-provisioning only matters after an image upgrade.

Run it by hand any time:

```bash
dotfiles-init                 # provision $HOME
dotfiles-init --force         # replace existing files (backed up to ~/.dotfiles-backup)
dotfiles-init /home/someone   # provision a specific directory
```

### One-time setup in a persistent home

Nothing is required to get the dotfiles themselves. These are the things the
image deliberately does **not** ship, so they are worth creating once in a home
that survives the container:

```bash
git config --file ~/.gitconfig.local user.name  "Your Name"
git config --file ~/.gitconfig.local user.email "you@example.com"
```

`~/.ssh` is excluded from the skeleton, so keys and `~/.ssh/config` you put
there are yours and are never touched. Machine-local shell settings and secrets
go in `~/.zshrc.local`. Use `git config --file ~/.gitconfig.local`, not
`git config --global`, which writes through the symlink into `/opt/dotfiles`.

If your platform accepts per-job environment variables, these are supported:

```json
"env_vars": {
  "DOTFILES_AUTO_INIT": "1",
  "DOTFILES_HOME": "/home/felix.xiao"
}
```

| Variable             | Effect                                                      |
|----------------------|-------------------------------------------------------------|
| `DOTFILES_AUTO_INIT` | `0` disables automatic provisioning entirely                 |
| `DOTFILES_HOME`      | Provision this directory instead of `$HOME`                  |
| `DOTFILES_FORCE`     | `1` replaces existing files, backing them up first           |
| `DOTFILES_SKEL`      | Read the skeleton from somewhere other than `/opt/home-skel` |

None of these are required; the defaults already work. On an older image whose
entrypoint the platform overrides, adding `"BASH_ENV": "/etc/dotfiles-hook.sh"`
restores provisioning for non-interactive `bash -c` without a rebuild; from v6
it is baked in.

### Terminal keys over SSH

The image ships an `xterm-ghostty` terminfo entry, compiled into both the system
database and conda's (conda's `ncurses` provides its own `tput`/`clear`/`infocmp`
that read only `/opt/conda/envs/dev/share/terminfo` and ignore `TERMINFO_DIRS`).
Without it, `TERM=xterm-ghostty` leaves every key capability empty — `Ctrl-U`,
arrows, Home/End and Delete stop working — `tput` and `clear` fail, and tmux
refuses to start with `missing or unsuitable terminal`.

On the Ghostty side, `shell-integration-features = ssh-env,ssh-terminfo` makes
Ghostty install its terminfo on remote hosts over SSH and fall back to
`xterm-256color` when it cannot. `.zshrc` additionally downgrades an unknown
`TERM` to `xterm-256color` rather than leaving the shell with no capabilities.

### Notes and gotchas

- Building on Apple Silicon uses Rosetta emulation. Only the build is slower;
  the published image runs natively on x86_64 GPU nodes. The image is
  **linux/amd64 only** and will not run on an ARM GPU node such as GB200.
- Pass `--shm-size=8g` (or `--ipc=host`); the default 64 MB `/dev/shm` breaks
  NCCL and PyTorch dataloader workers.
- Mount your code at `/workspace`, not at `/root`. Mounting over `/root` hides
  the stowed dotfiles.
- The container runs as `root` with `HOME=/root` by default. A different `HOME`
  is provisioned automatically; see *Platform-mounted home directories* above.
- Neovim plugins and oh-my-zsh live inside the image and are linked into `$HOME`
  rather than copied. Runtime changes land in the container's writable layer and
  are lost when it exits, even when `$HOME` itself is persistent. Rebuild the
  image to change them.
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
├── aerospace/.aerospace.toml
├── yazi/.config/yazi/yazi.toml
├── fontconfig/.config/fontconfig/fonts.conf
├── starship/.config/starship.toml
├── templates/           # example local override files and snippets
├── scripts/             # helper scripts, not managed by Stow
├── docker/              # GPU development image (not a Stow package)
│   ├── Dockerfile
│   ├── build.sh         # build/push helper, pins linux/amd64
│   ├── dotfiles-init.sh # provisions the baked dotfiles into any $HOME
│   ├── dotfiles-hook.sh # shell-startup trigger for dotfiles-init
│   ├── entrypoint.sh    # provisions, then execs the command
│   ├── terminfo/        # xterm-ghostty description compiled into the image
│   └── verify-gpu.py    # runtime GPU/NCCL check
├── sync.sh              # re-stow packages after git pull
├── AGENTS.md            # canonical coding-agent instructions
├── CLAUDE.md            # Claude Code pointer to AGENTS.md
├── .github/copilot-instructions.md # Copilot native repo instructions
└── README.md            # this file
```

## License

Personal configuration files. Use freely.
