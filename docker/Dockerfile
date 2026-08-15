# syntax=docker/dockerfile:1
#
# GPU development image: CUDA + Miniforge (conda) + PyTorch + this dotfiles setup.
#
# Build from the repository root so the dotfiles packages are in the build context:
#   docker build --platform linux/amd64 -f docker/Dockerfile -t leoxiao/pytorch-dev:TAG .
#
# The base is digest-pinned. Override with --build-arg CUDA_BASE=... to move CUDA
# versions, and remember to move TORCH_CUDA_INDEX to the matching wheel index.

ARG CUDA_BASE=nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04@sha256:0f8250615943f311785f9ce6379a49520a4b53c124d22b42ba859edf93af3991
FROM ${CUDA_BASE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# --- Versions -----------------------------------------------------------------
ARG MINIFORGE_VERSION=26.3.2-3
ARG PYTHON_VERSION=3.12
ARG CONDA_ENV=dev
ARG TORCH_VERSION=2.13.0
ARG TORCHVISION_VERSION=0.28.0
ARG TORCH_CUDA_INDEX=https://download.pytorch.org/whl/cu126

ARG NVIM_VERSION=v0.12.4
ARG NODE_VERSION=v24.19.0
ARG STARSHIP_VERSION=v1.26.0
ARG ZOXIDE_VERSION=v0.10.0
ARG LSD_VERSION=v1.2.0
ARG DELTA_VERSION=0.19.2
ARG LAZYGIT_VERSION=v0.64.1
ARG YAZI_VERSION=v26.5.6
# fzf comes from upstream rather than apt: the base image strips /usr/share/doc,
# which is where the Debian package hides key-bindings.zsh, so the apt build
# silently loses Ctrl-R and Ctrl-T. Upstream also supports `fzf --zsh`.
ARG FZF_VERSION=v0.74.2

# Framework repos have no releases, so pin them by commit.
ARG OMZ_COMMIT=b54a71977574cfcf659cc2f15a5e6422f17a8da7
ARG ZSH_SYNTAX_COMMIT=c4d95591843d49838b7ad30081e7aba3135a6703
ARG TPM_COMMIT=e261deb1b47614eed3400089ce7197dc68acc4eb

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    COLORTERM=truecolor \
    CONDA_DIR=/opt/conda \
    CONDA_ENV=${CONDA_ENV} \
    DOTFILES_DIR=/opt/dotfiles \
    DOTFILES_SKEL=/opt/home-skel \
    ZSH=/opt/home-skel/.oh-my-zsh \
    DISABLE_AUTO_UPDATE=true

# The conda env goes on PATH directly so non-interactive jobs (the way an ML
# platform launches work) get the right python without sourcing a shell rc.
ENV PATH=${CONDA_DIR}/envs/${CONDA_ENV}/bin:${CONDA_DIR}/condabin:/opt/nvim/bin:/opt/node/bin:${PATH}

# --- System packages ----------------------------------------------------------
# rdma-core/libibverbs/librdmacm/ibverbs-providers let NCCL use InfiniBand or
# RoCE. Without them NCCL silently falls back to TCP on cluster fabrics.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bat \
      build-essential \
      ca-certificates \
      curl \
      fd-find \
      git \
      git-lfs \
      gnupg \
      htop \
      ibverbs-providers \
      jq \
      less \
      libibverbs1 \
      librdmacm1 \
      locales \
      man-db \
      ncurses-term \
      nvtop \
      openssh-client \
      pkg-config \
      procps \
      rdma-core \
      ripgrep \
      rsync \
      stow \
      sudo \
      tar \
      tmux \
      tree \
      tzdata \
      unzip \
      w3m \
      wget \
      xz-utils \
      zsh \
  && rm -rf /var/lib/apt/lists/*

# --- Miniforge (conda-forge defaults; avoids Anaconda channel licensing) ------
RUN curl -fsSL -o /tmp/miniforge.sh \
      "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh" \
  && bash /tmp/miniforge.sh -b -p "${CONDA_DIR}" \
  && rm -f /tmp/miniforge.sh \
  && "${CONDA_DIR}/bin/conda" config --system --set auto_activate_base false \
  && "${CONDA_DIR}/bin/conda" create -y -n "${CONDA_ENV}" "python=${PYTHON_VERSION}" \
  && "${CONDA_DIR}/bin/conda" clean -afy

# --- Terminal descriptions ----------------------------------------------------
# Ghostty's TERM is `xterm-ghostty`, which ships in no distro's terminfo yet. On
# a host without the entry, tput and clear fail, tmux refuses to start, and every
# arrow/Home/End/Delete key resolves to an empty capability. The entry is
# installed into two databases on purpose: zsh, tmux and nvim use the system
# ncurses, while tput/clear/infocmp resolve to conda's ncurses, which reads only
# its own directory and ignores TERMINFO_DIRS.
COPY docker/terminfo/xterm-ghostty.src /tmp/xterm-ghostty.src
RUN set -eux; \
    /usr/bin/tic -x -o /usr/share/terminfo /tmp/xterm-ghostty.src; \
    "${CONDA_DIR}/envs/${CONDA_ENV}/bin/tic" -x \
      -o "${CONDA_DIR}/envs/${CONDA_ENV}/share/terminfo" /tmp/xterm-ghostty.src; \
    rm -f /tmp/xterm-ghostty.src; \
    TERM=xterm-ghostty /usr/bin/tput cuu1 >/dev/null; \
    TERM=xterm-ghostty "${CONDA_DIR}/envs/${CONDA_ENV}/bin/tput" cuu1 >/dev/null

# --- PyTorch (CUDA build from the pinned wheel index) -------------------------
# The plain PyPI torch now targets CUDA 13, so the index URL is what actually
# selects the CUDA build. NCCL arrives as a torch dependency.
# The last step guards the one combination that silently produces a broken
# image: a base image and a wheel index built against different CUDA majors,
# where nvcc and torch disagree and extensions compile but misbehave.
RUN pip install --no-cache-dir \
      --index-url "${TORCH_CUDA_INDEX}" \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCHVISION_VERSION}" \
  && python -c "import torch, torchvision; print('torch', torch.__version__, '| cuda', torch.version.cuda, '| nccl', torch.cuda.nccl.version()); print('torchvision', torchvision.__version__); assert torch.version.cuda, 'torch was built without CUDA support'" \
  && nvcc_cuda="$(nvcc --version | sed -n 's/.*release \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')" \
  && torch_cuda="$(python -c 'import torch; print(torch.version.cuda)')" \
  && echo "nvcc CUDA ${nvcc_cuda} / torch CUDA ${torch_cuda}" \
  && if [ "${nvcc_cuda%%.*}" != "${torch_cuda%%.*}" ]; then \
       echo "ERROR: CUDA_BASE provides ${nvcc_cuda} but TORCH_CUDA_INDEX provides ${torch_cuda}." >&2; \
       echo "These must move together. Use docker/build.sh --cuda <variant>." >&2; \
       exit 1; \
     fi

# --- CUDA extension build tooling ---------------------------------------------
# torch.utils.cpp_extension needs ninja, and most CUDA extensions need cmake.
# Installed via pip so they land in the conda env that is already on PATH.
RUN pip install --no-cache-dir cmake ninja \
  && cmake --version | head -1 \
  && ninja --version \
  && python -c "from torch.utils.cpp_extension import is_ninja_available; assert is_ninja_available(), 'ninja not visible to torch'; print('torch sees ninja: True')"

# --- GPU monitoring -----------------------------------------------------------
# nvitop is a Python package, so it goes in the conda env next to torch, where
# it can also resolve which processes belong to which env. nvtop is a compiled
# binary and comes from apt above. Neither can be exercised at build time, since
# BuildKit has no GPU; both only need to import and answer --help here.
RUN pip install --no-cache-dir nvitop \
  && python -c "import nvitop; print('nvitop', nvitop.__version__)" \
  && nvitop --help >/dev/null \
  && nvtop --version

# --- Node (required by LazyVim LSP tooling and the copilot-native extra) ------
RUN curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz" \
      -o /tmp/node.tar.xz \
  && mkdir -p /opt/node \
  && tar -xJf /tmp/node.tar.xz -C /opt/node --strip-components=1 \
  && rm -f /tmp/node.tar.xz \
  && node --version && npm --version

# --- Terminal tooling expected by the dotfiles --------------------------------
RUN set -eux; \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" -o /tmp/nvim.tar.gz; \
    mkdir -p /opt/nvim; \
    tar -xzf /tmp/nvim.tar.gz -C /opt/nvim --strip-components=1; \
    \
    curl -fsSL "https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/starship.tar.gz; \
    tar -xzf /tmp/starship.tar.gz -C /usr/local/bin starship; \
    \
    curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION#v}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/zoxide.tar.gz; \
    tar -xzf /tmp/zoxide.tar.gz -C /usr/local/bin zoxide; \
    \
    curl -fsSL "https://github.com/lsd-rs/lsd/releases/download/${LSD_VERSION}/lsd-${LSD_VERSION}-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/lsd.tar.gz; \
    tar -xzf /tmp/lsd.tar.gz -C /usr/local/bin --strip-components=1 --wildcards '*/lsd'; \
    \
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/delta.tar.gz; \
    tar -xzf /tmp/delta.tar.gz -C /usr/local/bin --strip-components=1 --wildcards '*/delta'; \
    \
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION#v}_linux_x86_64.tar.gz" -o /tmp/lazygit.tar.gz; \
    tar -xzf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit; \
    \
    curl -fsSL "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip" -o /tmp/yazi.zip; \
    unzip -q -j /tmp/yazi.zip '*/yazi' '*/ya' -d /usr/local/bin; \
    \
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/fzf-${FZF_VERSION#v}-linux_amd64.tar.gz" -o /tmp/fzf.tar.gz; \
    tar -xzf /tmp/fzf.tar.gz -C /usr/local/bin fzf; \
    \
    rm -f /tmp/nvim.tar.gz /tmp/starship.tar.gz /tmp/zoxide.tar.gz /tmp/lsd.tar.gz \
          /tmp/delta.tar.gz /tmp/lazygit.tar.gz /tmp/yazi.zip /tmp/fzf.tar.gz; \
    chmod +x /usr/local/bin/starship /usr/local/bin/zoxide /usr/local/bin/lsd \
             /usr/local/bin/delta /usr/local/bin/lazygit /usr/local/bin/yazi /usr/local/bin/ya \
             /usr/local/bin/fzf; \
    nvim --version | head -1; \
    starship --version; zoxide --version; lsd --version; delta --version; lazygit --version | head -1; yazi --version; \
    fzf --version; \
    fzf --zsh >/dev/null

# --- Skeleton home ------------------------------------------------------------
# Everything below builds into /opt/home-skel rather than /root. The training
# platform mounts a shared home directory and points HOME at it, so a layout
# baked into /root is unreachable at runtime. dotfiles-init mirrors this skeleton
# into whatever HOME the container is handed. Pointing HOME here for the rest of
# the build lets the stow, tmux and nvim steps populate it with no special casing.
ENV HOME=${DOTFILES_SKEL}
RUN mkdir -p "${DOTFILES_SKEL}"

# --- Shell frameworks (pinned by commit) --------------------------------------
# .zshrc sets `zstyle ':omz:update' mode auto`, which takes precedence over
# DISABLE_AUTO_UPDATE. Dropping oh-my-zsh's git metadata makes its update check
# bail out, so the pinned commit stays pinned and interactive shells on a GPU
# node never block on network at startup. TPM keeps its metadata because it
# uses git to manage plugins.
RUN git clone --filter=blob:none https://github.com/ohmyzsh/ohmyzsh.git "${DOTFILES_SKEL}/.oh-my-zsh" \
  && git -C "${DOTFILES_SKEL}/.oh-my-zsh" checkout --quiet "${OMZ_COMMIT}" \
  && git clone --filter=blob:none https://github.com/zsh-users/zsh-syntax-highlighting.git \
       "${DOTFILES_SKEL}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" \
  && git -C "${DOTFILES_SKEL}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" checkout --quiet "${ZSH_SYNTAX_COMMIT}" \
  && rm -rf "${DOTFILES_SKEL}/.oh-my-zsh/.git" \
  && mkdir -p "${DOTFILES_SKEL}/.tmux/plugins" \
  && git clone --filter=blob:none https://github.com/tmux-plugins/tpm.git "${DOTFILES_SKEL}/.tmux/plugins/tpm" \
  && git -C "${DOTFILES_SKEL}/.tmux/plugins/tpm" checkout --quiet "${TPM_COMMIT}"

# --- Dotfiles -----------------------------------------------------------------
# Only container-relevant packages are stowed. ghostty/fontconfig configure host
# GUI apps, and doom is omitted to keep the image small.
COPY . ${DOTFILES_DIR}

RUN rm -rf "${DOTFILES_DIR}/.git" \
  && git config --system --add safe.directory '*' \
  && stow --dir "${DOTFILES_DIR}" --target "${DOTFILES_SKEL}" --no-folding -R \
       zsh git tmux nvim lsd yazi starship \
  && test -L "${DOTFILES_SKEL}/.zshrc" \
  && test -L "${DOTFILES_SKEL}/.gitconfig" \
  && test -e "${DOTFILES_SKEL}/.tmux.conf" \
  && test -e "${DOTFILES_SKEL}/.config/nvim/init.lua"

# --- Provisioning tooling -----------------------------------------------------
RUN install -m 0755 "${DOTFILES_DIR}/docker/dotfiles-init.sh" /usr/local/bin/dotfiles-init \
  && install -m 0755 "${DOTFILES_DIR}/docker/entrypoint.sh" /usr/local/bin/docker-entrypoint.sh \
  && install -m 0644 "${DOTFILES_DIR}/docker/dotfiles-hook.sh" /etc/dotfiles-hook.sh

# --- Container-specific shell glue --------------------------------------------
# Kept outside the stow packages so it never collides with the host dotfiles.
# The provisioning hook is sourced from zshenv (every zsh, and crucially before
# ~/.zshrc, so the shell that triggers it still picks up the result), profile.d
# (login shells) and bash.bashrc (interactive bash). Between those and the
# entrypoint, a platform-mounted HOME is provisioned however the job starts.
RUN set -eux; \
    mkdir -p /etc/zsh; \
    printf '%s\n' \
      '. /etc/dotfiles-hook.sh' >> /etc/zsh/zshenv; \
    printf '%s\n' \
      '. /etc/dotfiles-hook.sh' \
      'if [ -f /opt/conda/etc/profile.d/conda.sh ]; then' \
      '  . /opt/conda/etc/profile.d/conda.sh' \
      '  conda activate "${CONDA_ENV:-dev}" 2>/dev/null || true' \
      'fi' > /etc/profile.d/00-conda.sh; \
    printf '%s\n' \
      '# Non-interactive builds and job runners must never hit a compinit prompt.' \
      'export ZSH_DISABLE_COMPFIX=true' \
      '# A platform that pre-populates the home directory leaves its own files in' \
      '# place, since provisioning never overwrites them. Say so once per change,' \
      '# otherwise it looks exactly like the dotfiles failing to apply at all.' \
      'if [[ -s "${HOME:-/root}/.dotfiles-init-skipped" ]] &&' \
      '   [[ ! "${HOME:-/root}/.dotfiles-init-notified" -nt "${HOME:-/root}/.dotfiles-init-skipped" ]]; then' \
      '  print -u2 "dotfiles: kept pre-existing files in $HOME (listed in ~/.dotfiles-init-skipped)."' \
      '  print -u2 "dotfiles: run dotfiles-init --force to use the image versions; backups go to ~/.dotfiles-backup."' \
      '  : > "$HOME/.dotfiles-init-notified" 2>/dev/null || true' \
      'fi' \
      'if [ -f /opt/conda/etc/profile.d/conda.sh ]; then' \
      '  . /opt/conda/etc/profile.d/conda.sh' \
      '  conda activate "${CONDA_ENV:-dev}" 2>/dev/null || true' \
      'fi' > /etc/zsh/zshrc; \
    printf '%s\n' '. /etc/dotfiles-hook.sh' >> /etc/bash.bashrc; \
    printf '%s\n' \
      '# Upstream fzf ships its shell integration through `fzf --zsh`. The apt' \
      '# build hides the same files under /usr/share/doc, which this base image' \
      '# strips, so Ctrl-R and Ctrl-T silently disappear.' \
      'if (( $+commands[fzf] )); then' \
      '  source <(fzf --zsh)' \
      'fi' > "${DOTFILES_SKEL}/.fzf.zsh"; \
    chsh -s /usr/bin/zsh root

# --- Plugin bootstrap ---------------------------------------------------------
# Done at build time so the first shell on a GPU node is not blocked on network.
# This also validates that the tmux config parses.
RUN set -eux; \
    tmux -f "${DOTFILES_SKEL}/.tmux.conf" new-session -d -s bootstrap; \
    "${DOTFILES_SKEL}/.tmux/plugins/tpm/bin/install_plugins"; \
    tmux list-keys >/dev/null; \
    tmux kill-server 2>/dev/null || true; \
    test -d "${DOTFILES_SKEL}/.tmux/plugins/tmux-resurrect"

RUN set -eux; \
    nvim --headless "+Lazy! sync" +qa 2>&1 | tail -30 || true; \
    test -d "${DOTFILES_SKEL}/.local/share/nvim/lazy/lazy.nvim"; \
    test -d "${DOTFILES_SKEL}/.local/share/nvim/lazy/LazyVim"; \
    ya pkg add yazi-rs/plugins:piper || echo "warning: yazi piper plugin unavailable; HTML preview disabled"

# --- Skeleton cleanup and default home ----------------------------------------
# Build caches and machine-specific state must never be mirrored into a user's
# home. Everything left is made world-readable so a job running as a non-root
# uid can still read the skeleton, and the payload directories that tools write
# into at runtime are made world-writable so such a job can install a treesitter
# parser or an LSP server. Those writes land in the container's own layer, so
# they cannot leak between containers. /root is then provisioned from the
# skeleton so a plain `docker run` behaves exactly like a job that mounts its
# own home.
#
# DOTFILES_VERSION tracks the source revision rather than the image tag so that
# the same commit built for different CUDA variants produces the same stamp, and
# a persistent home is not re-provisioned just because the job switched variants.
# It is declared here, below the pinned framework clones, so that a new commit
# does not invalidate their cache and force a network fetch on every build.
ARG SOURCE_REVISION=unknown
ENV DOTFILES_VERSION=${SOURCE_REVISION}
RUN set -eux; \
    rm -rf "${DOTFILES_SKEL}/.cache" "${DOTFILES_SKEL}/.npm" "${DOTFILES_SKEL}/.conda" \
           "${DOTFILES_SKEL}/.local/state" \
           "${DOTFILES_SKEL}/.bashrc" "${DOTFILES_SKEL}/.profile" "${DOTFILES_SKEL}/.ssh"; \
    rm -f "${DOTFILES_SKEL}"/.zcompdump*; \
    rm -rf /root/.local/state /root/.cache /root/.npm; \
    chmod -R a+rX "${DOTFILES_SKEL}" "${DOTFILES_DIR}"; \
    chmod -R a+rwX "${DOTFILES_SKEL}/.local/share/nvim" \
                   "${DOTFILES_SKEL}/.local/share/yazi" \
                   "${DOTFILES_SKEL}/.tmux/plugins" 2>/dev/null || true; \
    HOME=/root dotfiles-init /root; \
    test -L /root/.zshrc; \
    test "$(readlink -f /root/.zshrc)" = "${DOTFILES_DIR}/zsh/.zshrc"; \
    test ! -e /root/.dotfiles-init-skipped

ENV HOME=/root

# --- Final checks -------------------------------------------------------------
# GPU assertions belong at runtime, not here: BuildKit has no GPU. The probe home
# is the regression test for the bug this layout exists to fix: a HOME that the
# image has never seen must still come up fully configured.
RUN set -eux; \
    zsh -ic 'echo "zsh startup OK"'; \
    zsh -ic 'test ${+functions[fzf-history-widget]} -eq 1 && echo "fzf keybindings OK"'; \
    git config --get core.pager; \
    test ! -d "${DOTFILES_SKEL}/.oh-my-zsh/.git"; \
    command -v cmake; \
    command -v ninja; \
    TERM=xterm-ghostty tput cuu1 >/dev/null; \
    TERM=xterm-ghostty tmux -f /dev/null new-session -d -s terminfocheck; \
    tmux kill-server 2>/dev/null || true; \
    python -c "import torch; print('torch', torch.__version__, torch.version.cuda)"; \
    python -c "import torch; print('arch list:', torch.cuda.get_arch_list())"; \
    HOME=/home/probe zsh -ic 'test -n "$ZSH_VERSION" && echo "probe home zsh OK"'; \
    HOME=/home/probe zsh -ic 'test ${+functions[omz_urlencode]} -eq 1 && echo "probe home oh-my-zsh OK"'; \
    HOME=/home/probe zsh -ic 'test ${+functions[fzf-history-widget]} -eq 1 && echo "probe home fzf OK"'; \
    test "$(readlink -f /home/probe/.zshrc)" = "${DOTFILES_DIR}/zsh/.zshrc"; \
    test -d /home/probe/.oh-my-zsh; \
    test -f /home/probe/.config/nvim/init.lua; \
    rm -rf /home/probe

ARG IMAGE_VERSION=dev
ARG CUDA_BASE
LABEL org.opencontainers.image.title="pytorch-dev" \
      org.opencontainers.image.description="CUDA + conda + PyTorch GPU development image with the leoxiaobin/dotfiles terminal setup" \
      org.opencontainers.image.source="https://github.com/leoxiaobin/dotfiles" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.base.name="${CUDA_BASE}"

ENV SHELL=/usr/bin/zsh
# A platform that overrides the entrypoint and runs a non-interactive `bash -c`
# reaches none of the shell hooks: bash reads /etc/bash.bashrc only when
# interactive, and /etc/profile only for login shells. BASH_ENV is the one hook
# bash honours in that case, so provisioning survives an entrypoint override.
#
# Deliberately declared after every RUN: this Dockerfile sets SHELL to bash, so
# an earlier declaration would fire the hook during the build itself, where HOME
# is the skeleton the hook provisions from.
#
# Cost on an already-provisioned home is a single builtin read of the stamp, and
# a plain `sh -c` still gets nothing, since dash has no non-interactive hook at
# all. That residual gap is covered by the home being persistent: whichever
# process provisions it first, the links are there for every later job.
ENV BASH_ENV=/etc/dotfiles-hook.sh
WORKDIR /workspace
# The entrypoint provisions HOME for jobs that exec a binary directly and never
# source a shell rc. It ends in `exec "$@"`, so `docker run IMAGE python train.py`
# keeps working. Set DOTFILES_AUTO_INIT=0 to turn the behaviour off.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/zsh"]
