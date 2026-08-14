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
    ZSH=/root/.oh-my-zsh \
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
      fzf \
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

# --- PyTorch (CUDA build from the pinned wheel index) -------------------------
# The plain PyPI torch now targets CUDA 13, so the index URL is what actually
# selects the CUDA build. nvidia-nccl-cu12 arrives as a torch dependency.
RUN pip install --no-cache-dir \
      --index-url "${TORCH_CUDA_INDEX}" \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCHVISION_VERSION}" \
  && python -c "import torch, torchvision; print('torch', torch.__version__, '| cuda', torch.version.cuda, '| nccl', torch.cuda.nccl.version()); print('torchvision', torchvision.__version__); assert torch.version.cuda, 'torch was built without CUDA support'"

# --- CUDA extension build tooling ---------------------------------------------
# torch.utils.cpp_extension needs ninja, and most CUDA extensions need cmake.
# Installed via pip so they land in the conda env that is already on PATH.
RUN pip install --no-cache-dir cmake ninja \
  && cmake --version | head -1 \
  && ninja --version \
  && python -c "from torch.utils.cpp_extension import is_ninja_available; assert is_ninja_available(), 'ninja not visible to torch'; print('torch sees ninja: True')"

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
    rm -f /tmp/nvim.tar.gz /tmp/starship.tar.gz /tmp/zoxide.tar.gz /tmp/lsd.tar.gz \
          /tmp/delta.tar.gz /tmp/lazygit.tar.gz /tmp/yazi.zip; \
    chmod +x /usr/local/bin/starship /usr/local/bin/zoxide /usr/local/bin/lsd \
             /usr/local/bin/delta /usr/local/bin/lazygit /usr/local/bin/yazi /usr/local/bin/ya; \
    nvim --version | head -1; \
    starship --version; zoxide --version; lsd --version; delta --version; lazygit --version | head -1; yazi --version

# --- Shell frameworks (pinned by commit) --------------------------------------
# .zshrc sets `zstyle ':omz:update' mode auto`, which takes precedence over
# DISABLE_AUTO_UPDATE. Dropping oh-my-zsh's git metadata makes its update check
# bail out, so the pinned commit stays pinned and interactive shells on a GPU
# node never block on network at startup. TPM keeps its metadata because it
# uses git to manage plugins.
RUN git clone --filter=blob:none https://github.com/ohmyzsh/ohmyzsh.git /root/.oh-my-zsh \
  && git -C /root/.oh-my-zsh checkout --quiet "${OMZ_COMMIT}" \
  && git clone --filter=blob:none https://github.com/zsh-users/zsh-syntax-highlighting.git \
       /root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
  && git -C /root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting checkout --quiet "${ZSH_SYNTAX_COMMIT}" \
  && rm -rf /root/.oh-my-zsh/.git \
  && mkdir -p /root/.tmux/plugins \
  && git clone --filter=blob:none https://github.com/tmux-plugins/tpm.git /root/.tmux/plugins/tpm \
  && git -C /root/.tmux/plugins/tpm checkout --quiet "${TPM_COMMIT}"

# --- Dotfiles -----------------------------------------------------------------
# Only container-relevant packages are stowed. ghostty/fontconfig configure host
# GUI apps, and doom is omitted to keep the image small.
COPY . ${DOTFILES_DIR}

RUN rm -rf "${DOTFILES_DIR}/.git" \
  && git config --system --add safe.directory '*' \
  && stow --dir "${DOTFILES_DIR}" --target /root --no-folding -R \
       zsh git tmux nvim lsd yazi starship \
  && test -L /root/.zshrc \
  && test -L /root/.gitconfig \
  && test -e /root/.tmux.conf \
  && test -e /root/.config/nvim/init.lua

# --- Container-specific shell glue --------------------------------------------
# Kept outside the stow packages so it never collides with the host dotfiles.
RUN set -eux; \
    mkdir -p /etc/zsh; \
    printf '%s\n' \
      'if [ -f /opt/conda/etc/profile.d/conda.sh ]; then' \
      '  . /opt/conda/etc/profile.d/conda.sh' \
      '  conda activate "${CONDA_ENV:-dev}" 2>/dev/null || true' \
      'fi' > /etc/profile.d/00-conda.sh; \
    printf '%s\n' \
      '# Non-interactive builds and job runners must never hit a compinit prompt.' \
      'export ZSH_DISABLE_COMPFIX=true' \
      'if [ -f /opt/conda/etc/profile.d/conda.sh ]; then' \
      '  . /opt/conda/etc/profile.d/conda.sh' \
      '  conda activate "${CONDA_ENV:-dev}" 2>/dev/null || true' \
      'fi' > /etc/zsh/zshrc; \
    printf '%s\n' \
      'for _fzf_dir in /usr/share/doc/fzf/examples /usr/share/fzf/shell /usr/share/fzf; do' \
      '  [ -f "$_fzf_dir/key-bindings.zsh" ] && source "$_fzf_dir/key-bindings.zsh"' \
      '  [ -f "$_fzf_dir/completion.zsh" ] && source "$_fzf_dir/completion.zsh"' \
      'done' \
      'unset _fzf_dir' > /root/.fzf.zsh; \
    chsh -s /usr/bin/zsh root

# --- Plugin bootstrap ---------------------------------------------------------
# Done at build time so the first shell on a GPU node is not blocked on network.
# This also validates that the tmux config parses.
RUN set -eux; \
    tmux -f /root/.tmux.conf new-session -d -s bootstrap; \
    /root/.tmux/plugins/tpm/bin/install_plugins; \
    tmux list-keys >/dev/null; \
    tmux kill-server 2>/dev/null || true; \
    test -d /root/.tmux/plugins/tmux-resurrect

RUN set -eux; \
    nvim --headless "+Lazy! sync" +qa 2>&1 | tail -30 || true; \
    test -d /root/.local/share/nvim/lazy/lazy.nvim; \
    test -d /root/.local/share/nvim/lazy/LazyVim; \
    ya pkg add yazi-rs/plugins:piper || echo "warning: yazi piper plugin unavailable; HTML preview disabled"

# --- Final checks -------------------------------------------------------------
# GPU assertions belong at runtime, not here: BuildKit has no GPU.
RUN set -eux; \
    zsh -ic 'echo "zsh startup OK"'; \
    git config --get core.pager; \
    test ! -d /root/.oh-my-zsh/.git; \
    command -v cmake; \
    command -v ninja; \
    python -c "import torch; print('torch', torch.__version__, torch.version.cuda)"; \
    python -c "import torch; print('arch list:', torch.cuda.get_arch_list())"

ARG IMAGE_VERSION=dev
ARG SOURCE_REVISION=unknown
ARG CUDA_BASE
LABEL org.opencontainers.image.title="pytorch-dev" \
      org.opencontainers.image.description="CUDA 12.6 + conda + PyTorch GPU development image with the leoxiaobin/dotfiles terminal setup" \
      org.opencontainers.image.source="https://github.com/leoxiaobin/dotfiles" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.base.name="${CUDA_BASE}"

ENV SHELL=/usr/bin/zsh
WORKDIR /workspace
CMD ["/usr/bin/zsh"]
