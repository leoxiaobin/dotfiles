#!/usr/bin/env python3
"""Audit Su theme colors against WCAG 2.2 contrast thresholds.

WCAG references:
- 1.4.3 Contrast (Minimum), Level AA: normal text >= 4.5:1,
  large-scale text >= 3:1.
- 1.4.11 Non-text Contrast, Level AA: UI components / graphical objects >= 3:1.

The syntax-color distance check is an extra theme-design guardrail, not a WCAG
criterion. It helps keep Su's semantic colors visually distinguishable.
"""

from __future__ import annotations

from dataclasses import dataclass
from itertools import combinations
from math import sqrt
from typing import Iterable


AA_NORMAL_TEXT = 4.5
AA_LARGE_TEXT = 3.0
AA_NON_TEXT = 3.0
MIN_SYNTAX_RGB_DISTANCE = 45.0


PALETTE = {
    "bg": "#f3eee1",
    "bg_soft": "#e9e1cf",
    "bg_code": "#eee6d5",
    "bg_hl": "#e3dac3",
    "sel": "#d6cbae",
    "border": "#ddd4bf",
    "fg": "#38342c",
    "fg_dim": "#5f584c",
    "comment": "#5f584c",
    "qinghua": "#295f8a",
    "tianqing": "#236b5c",
    "zhuqing": "#3f6428",
    "xiang": "#6a5d12",
    "zheshi": "#8f3c22",
    "zhusha": "#8c1234",
    "daizi": "#5a4685",
    "yanzhi": "#84394f",
    "ansi0": "#5a5447",
    "ansi1": "#8c1234",
    "ansi2": "#3f6428",
    "ansi3": "#6a5d12",
    "ansi4": "#295f8a",
    "ansi5": "#5a4685",
    "ansi6": "#236b5c",
    "ansi7": "#5f584c",
    "ansi8": "#5f584c",
    "ansi9": "#8c1234",
    "ansi10": "#3f6428",
    "ansi11": "#6a5d12",
    "ansi12": "#295f8a",
    "ansi13": "#5a4685",
    "ansi14": "#236b5c",
    "ansi15": "#38342c",
}

TEXT_BACKGROUNDS = ("bg", "bg_soft", "bg_code", "bg_hl")
TEXT_COLORS = tuple(
    name
    for name in PALETTE
    if name not in {"bg", "bg_soft", "bg_code", "bg_hl", "sel", "border"}
)
SYNTAX_COLORS = (
    "qinghua",
    "tianqing",
    "zhuqing",
    "xiang",
    "zheshi",
    "zhusha",
    "daizi",
    "yanzhi",
)
UI_PAIRS = (
    ("selection foreground", "fg", "sel"),
    ("tmux blue segment", "bg", "qinghua"),
    ("tmux mode/search", "bg", "xiang"),
    ("cursor/error", "bg", "zhusha"),
)


@dataclass(frozen=True)
class ContrastResult:
    name: str
    foreground: str
    background: str
    ratio: float
    threshold: float

    @property
    def passes(self) -> bool:
        # WCAG notes that computed values must not be rounded before comparing.
        return self.ratio >= self.threshold


def hex_to_rgb(hex_color: str) -> tuple[float, float, float]:
    value = hex_color.removeprefix("#")
    if len(value) != 6:
        raise ValueError(f"expected #RRGGBB color, got {hex_color!r}")
    return tuple(int(value[i : i + 2], 16) / 255 for i in (0, 2, 4))


def linearize(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_color: str) -> float:
    r, g, b = (linearize(channel) for channel in hex_to_rgb(hex_color))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(foreground: str, background: str) -> float:
    fg_lum = relative_luminance(foreground)
    bg_lum = relative_luminance(background)
    lighter = max(fg_lum, bg_lum)
    darker = min(fg_lum, bg_lum)
    return (lighter + 0.05) / (darker + 0.05)


def rgb_distance(left: str, right: str) -> float:
    left_rgb = tuple(channel * 255 for channel in hex_to_rgb(left))
    right_rgb = tuple(channel * 255 for channel in hex_to_rgb(right))
    return sqrt(sum((a - b) ** 2 for a, b in zip(left_rgb, right_rgb)))


def text_results() -> Iterable[ContrastResult]:
    for fg_name in TEXT_COLORS:
        for bg_name in TEXT_BACKGROUNDS:
            yield ContrastResult(
                name=f"{fg_name} on {bg_name}",
                foreground=fg_name,
                background=bg_name,
                ratio=contrast_ratio(PALETTE[fg_name], PALETTE[bg_name]),
                threshold=AA_NORMAL_TEXT,
            )


def ui_results() -> Iterable[ContrastResult]:
    for name, fg_name, bg_name in UI_PAIRS:
        yield ContrastResult(
            name=name,
            foreground=fg_name,
            background=bg_name,
            ratio=contrast_ratio(PALETTE[fg_name], PALETTE[bg_name]),
            threshold=AA_NON_TEXT,
        )


def print_contrast_table(results: Iterable[ContrastResult]) -> list[ContrastResult]:
    failures: list[ContrastResult] = []
    for result in results:
        status = "PASS" if result.passes else "FAIL"
        if not result.passes:
            failures.append(result)
        print(
            f"{status:4} {result.name:24} "
            f"{result.ratio:5.2f}:1 >= {result.threshold:.1f}:1 "
            f"({PALETTE[result.foreground]} on {PALETTE[result.background]})"
        )
    return failures


def print_syntax_distances() -> list[tuple[str, str, float]]:
    close_pairs: list[tuple[str, str, float]] = []
    for left, right in combinations(SYNTAX_COLORS, 2):
        distance = rgb_distance(PALETTE[left], PALETTE[right])
        status = "PASS" if distance >= MIN_SYNTAX_RGB_DISTANCE else "FAIL"
        if distance < MIN_SYNTAX_RGB_DISTANCE:
            close_pairs.append((left, right, distance))
        print(f"{status:4} {left:9} vs {right:9} distance={distance:5.1f}")
    return close_pairs


def main() -> int:
    print("WCAG 2.2 AA text contrast audit (normal text >= 4.5:1)")
    text_failures = print_contrast_table(text_results())

    print("\nWCAG 2.2 AA non-text/UI contrast audit (>= 3:1)")
    ui_failures = print_contrast_table(ui_results())

    print("\nLarge text threshold is 3:1; all normal-text passes also pass large text.")
    print(f"Configured large text threshold: {AA_LARGE_TEXT:.1f}:1")

    print("\nExtra Su syntax separability audit (RGB distance >= 45; not WCAG)")
    close_pairs = print_syntax_distances()

    if text_failures or ui_failures or close_pairs:
        print("\nAudit failed.")
        return 1

    print("\nAudit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
