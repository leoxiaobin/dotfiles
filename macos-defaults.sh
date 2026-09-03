#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'error: macos-defaults.sh only supports macOS\n' >&2
  exit 1
fi

# Make held keys repeat at the fastest supported System Settings value.
defaults write NSGlobalDomain KeyRepeat -int 1

# Start key repetition after a short, predictable delay.
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Let held letter keys repeat instead of opening the accent-character picker.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Remove the Dock's slide-in delay when auto-hide is enabled.
defaults write com.apple.dock autohide-time-modifier -float 0

# Shorten Mission Control and Expose animations without disabling them entirely.
defaults write com.apple.dock expose-animation-duration -float 0.1

# Keep Spaces in a stable order instead of rearranging them by recent use.
defaults write com.apple.dock mru-spaces -bool false

# Show hidden files in Finder.
defaults write com.apple.finder AppleShowAllFiles -bool true

# Prevent Finder from writing .DS_Store metadata files to network volumes.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
