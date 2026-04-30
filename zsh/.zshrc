# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH="$HOME/.local/bin:$PATH"
[[ -d /snap/bin ]] && export PATH="$PATH:/snap/bin"

# Enable 24-bit true color for terminal apps (Emacs, Neovim, etc.)
export COLORTERM=truecolor

# Timezone
export TZ="America/Los_Angeles"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="robbyrussell"
# ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_THEME=""

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git)
plugins=(git zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias rb='rcall-brix'
alias b='brix'


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# ─── Platform Detection ──────────────────────────────────────────────
if [[ "$(uname -r)" == *microsoft* ]]; then
  IS_WSL=true
elif [[ "$(uname)" == "Darwin" ]]; then
  IS_MACOS=true
fi

# WSL-only tools
[[ $IS_WSL == true ]] && alias tailscale="/mnt/c/Program\ Files/Tailscale/tailscale.exe"

# Lazy-load nvm — only initializes when you first run node/npm/npx/nvm
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  nvm "$@"
}
node() { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; node "$@"; }
npm() { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; npm "$@"; }
npx() { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; npx "$@"; }
# Add node to PATH without loading nvm (for tools like copilot that need node)
[ -d "$NVM_DIR/versions/node" ] && PATH="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d | sort -V | tail -1)/bin:$PATH"


function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# Cross-platform aliases: bat/fd have different names on Debian/Ubuntu vs macOS/Arch
if (( $+commands[fdfind] )); then alias fd=fdfind; fi
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# Zoxide — smarter cd (replaces autojump)
eval "$(zoxide init zsh)"

typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

eval "$(starship init zsh)"

# ─── Local overrides (secrets, machine-specific) ────────────────────
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# LSD
alias l='lsd -l'
alias ll='lsd -l'
alias la='lsd -a'
alias lla='lsd -la'
alias lt='lsd --tree'
if (( $+commands[batcat] )); then alias cat='batcat'; elif (( $+commands[bat] )); then alias cat='bat'; fi

# Tmux
new_tmux () {
  session_dir=$(zoxide query --list | fzf)
  session_name=$(basename "$session_dir")

  if tmux has-session -t $session_name 2>/dev/null; then
    if [ -n "$TMUX" ]; then
      tmux switch-client -t "$session_name"
    else
      tmux attach -t "$session_name"
    fi
    notification="tmux attached to $session_name"
  else
    if [ -n "$TMUX" ]; then
      tmux new-session -d -c "$session_dir" -s "$session_name" && tmux switch-client -t "$session_name"
      notification="new tmux session INSIDE TMUX: $session_name"
    else
      tmux new-session -c "$session_dir" -s "$session_name"
      notification="new tmux session: $session_name"
    fi
  fi

  if [[ -n "$notification" ]]; then
    if (( $+commands[notify-send] )); then
      notify-send "$notification"
    elif [[ "$IS_MACOS" == true ]] && (( $+commands[osascript] )); then
      osascript -e 'on run argv' \
                -e 'display notification (item 1 of argv) with title "tmux"' \
                -e 'end run' \
                "$notification"
    fi
  fi
}

alias tm=new_tmux

# ─── AI CLI ──────────────────────────────────────────────────────────

# Short aliases (safe — only run if the command exists)
(( $+commands[claude] )) && alias cc='claude'
(( $+commands[codex] ))  && alias cx='codex'
alias ghcp='copilot'

# Project-scoped AI launcher: cd to git root, then start the tool
ai () {
  local tool="$1"
  if [[ -z "$tool" ]]; then
    echo "Usage: ai <claude|codex|copilot>"
    echo ""
    echo "Available:"
    (( $+commands[claude] ))  && echo "  claude   (cc)" || echo "  claude   — not installed"
    (( $+commands[codex] ))   && echo "  codex    (cx)" || echo "  codex    — not installed"
    (( $+commands[copilot] )) && echo "  copilot  (ghcp)" || echo "  copilot  — not installed"
    return 0
  fi

  if ! command -v "$tool" &>/dev/null; then
    echo "Error: '$tool' is not installed or not in PATH"
    return 1
  fi

  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$root" ]]; then
    echo "→ cd $root"
    cd "$root"
  fi

  "$tool" "${@:2}"
}

# Doom Emacs
export PATH="$HOME/.config/emacs/bin:$PATH"

# Terminal Emacs renders themes poorly when TERM is only xterm-color.
if [[ "$TERM" == "xterm-color" ]]; then
  export TERM=xterm-256color
fi
