#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: apply-su-macos.sh only supports macOS" >&2
  exit 1
fi

su_bg="#f3eee1"       # 宣纸
su_bg_soft="#e9e1cf" # 面板
su_sel_rgb="0.839216 0.796078 0.682353" # #d6cbae

wallpaper_dir="$HOME/Pictures/Su Theme"
wallpaper_ppm="$wallpaper_dir/su-wallpaper.ppm"
wallpaper_png="$wallpaper_dir/su-wallpaper.png"

mkdir -p "$wallpaper_dir"

python3 - "$wallpaper_ppm" <<'PY'
import sys

path = sys.argv[1]
width, height = 3200, 2000
top = (0xF3, 0xEE, 0xE1)
bottom = (0xE9, 0xE1, 0xCF)

with open(path, "wb") as f:
    f.write(f"P6\n{width} {height}\n255\n".encode("ascii"))
    for y in range(height):
        t = y / (height - 1)
        row = bytes(
            round(top[i] * (1 - t) + bottom[i] * t)
            for _ in range(width)
            for i in range(3)
        )
        f.write(row)
PY

sips -s format png "$wallpaper_ppm" --out "$wallpaper_png" >/dev/null
rm -f "$wallpaper_ppm"

# Su is a light theme: use fixed light appearance, not automatic dark switching.
defaults delete -g AppleInterfaceStyle >/dev/null 2>&1 || true
defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false

# macOS accent colors are predefined; blue is closest to Su's 青花 structural accent.
defaults write -g AppleAccentColor -int 4

# Use Su selection color for text highlight where macOS honors custom highlight colors.
defaults write -g AppleHighlightColor -string "$su_sel_rgb"

# Keep windows visually closer to paper panels instead of translucent wallpaper-tinted glass.
defaults write -g AppleReduceDesktopTinting -bool true
if ! defaults write com.apple.universalaccess reduceTransparency -bool true; then
  echo "warning: could not set Reduce Transparency automatically; enable it manually in System Settings > Accessibility > Display if desired" >&2
fi

if osascript >/dev/null <<OSA
tell application "System Events"
  tell every desktop
    set picture to "$wallpaper_png"
  end tell
end tell
OSA
then
  echo "Set Su wallpaper: $wallpaper_png"
else
  echo "warning: could not set wallpaper automatically; set it manually to $wallpaper_png" >&2
fi

cat <<EOF
Applied Su macOS settings:
- Appearance: Light
- Accent: Blue, closest built-in match for 青花
- Highlight: #d6cbae selection tone
- Window tinting/transparency: reduced for stable paper panels
- Wallpaper: $su_bg → $su_bg_soft rice-paper gradient

Some apps may need to be restarted, or you may need to log out and back in, before all settings repaint.
EOF
