"""Portable config regressions using only the Python standard library."""

from __future__ import annotations

import contextlib
import io
import os
from pathlib import Path
import runpy
import shlex
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None


ROOT = Path(__file__).resolve().parents[1]
THEME = runpy.run_path(str(ROOT / "bin/theme-set"))


class IsolatedConfigTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.prefix = self.root / "prefix with spaces"
        self.bin = self.prefix / "bin"
        self.home.mkdir()
        self.bin.mkdir(parents=True)
        self.env = {
            "HOME": str(self.home),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "TERM": "xterm-256color",
            "HOMEBREW_PREFIX": str(self.prefix),
            "TEST_OS": "Linux",
            "TEST_KERNEL": "6.8.0",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
        }
        self.script(
            self.bin / "uname",
            'case "$1" in -r) printf "%s\\n" "$TEST_KERNEL";; '
            '*) printf "%s\\n" "$TEST_OS";; esac\n',
        )
        self.script(self.bin / "brew", 'printf "%s\\n" "$HOMEBREW_PREFIX"\n')
        self.write(
            self.prefix / "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh",
            "typeset -g TEST_HIGHLIGHT=loaded\n",
        )

    def write(self, path, contents):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")

    def script(self, path, contents):
        self.write(path, "#!/bin/sh\n" + contents)
        path.chmod(0o755)

    def tool(self, name):
        result = shutil.which(name)
        if result is None:
            self.fail(f"Required test tool is missing: {name}")
        return result

    def run_command(self, command, *, check=True):
        result = subprocess.run(
            command, cwd=ROOT, env=self.env, text=True,
            capture_output=True, timeout=30,
        )
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def shell(self, command):
        return self.run_command([
            self.tool("zsh"), "-f", "-c",
            f"source {shlex.quote(str(ROOT / 'zsh/.zshrc'))}\n{command}",
        ])


class ShellTests(IsolatedConfigTest):
    def test_platform_flags_and_homebrew_path(self):
        for platform, kernel, expected in (
            ("Darwin", "25.0.0", "true false"),
            ("Linux", "6.8.0", "false false"),
            ("Linux", "6.6.0-microsoft-standard-WSL2", "false true"),
        ):
            with self.subTest(platform=platform, kernel=kernel):
                self.env.update(TEST_OS=platform, TEST_KERNEL=kernel)
                result = self.shell('print -r -- "$IS_MACOS $IS_WSL"')
                self.assertEqual(result.stdout.strip(), expected)
                self.assertEqual(result.stderr, "")

        self.env.update(TEST_OS="Darwin", PATH="/usr/bin:/bin")
        # uname still needs to be mocked when testing a login PATH without brew.
        system_bin = self.root / "system-bin"
        system_bin.mkdir()
        shutil.copy2(self.bin / "uname", system_bin / "uname")
        self.env["PATH"] = f"{system_bin}:/usr/bin:/bin"
        result = self.shell('print -r -- "${commands[brew]}"')
        self.assertEqual(result.stdout.strip(), str(self.bin / "brew"))

    def test_modern_fzf_and_direnv(self):
        self.script(self.bin / "fzf", "printf 'typeset -g TEST_FZF=modern\\n'\n")
        self.script(self.bin / "direnv", "printf 'typeset -g TEST_DIRENV=loaded\\n'\n")
        result = self.shell('print -r -- "$TEST_FZF $TEST_DIRENV $TEST_HIGHLIGHT"')
        self.assertEqual(result.stdout.strip(), "modern loaded loaded")

    def test_homebrew_does_not_override_an_active_virtualenv(self):
        virtualenv = self.root / "project-venv/bin"
        self.script(virtualenv / "python3", "printf 'project-python\\n'\n")
        self.env.update(TEST_OS="Darwin", PATH=f"{virtualenv}:{self.env['PATH']}")
        result = self.shell("command python3")
        self.assertEqual(result.stdout.strip(), "project-python")

    def test_legacy_fzf_package_layouts(self):
        self.script(self.bin / "fzf", "exit 2\n")
        for layout in ("shell", "share/fzf", "share/fzf/shell", "share/doc/fzf/examples"):
            with self.subTest(layout=layout):
                directory = self.prefix / layout
                self.write(directory / "key-bindings.zsh", "typeset -g TEST_FZF=legacy\n")
                self.write(directory / "completion.zsh", "typeset -g TEST_COMPLETION=loaded\n")
                result = self.shell('print -r -- "$TEST_FZF $TEST_COMPLETION"')
                self.assertEqual(result.stdout.strip(), "legacy loaded")
                self.assertEqual(result.stderr, "")
                (directory / "key-bindings.zsh").unlink()
                (directory / "completion.zsh").unlink()

    def test_missing_fzf_integration_reports_problem(self):
        self.script(self.bin / "fzf", "exit 2\n")
        result = self.shell("true")
        self.assertIn("fzf shell integration is missing", result.stderr)

    def test_container_fzf_wrapper_is_preserved(self):
        self.write(self.home / ".fzf.zsh", "typeset -g TEST_FZF=wrapper\n")
        self.script(self.bin / "fzf", "exit 99\n")
        result = self.shell('print -r -- "$TEST_FZF"')
        self.assertEqual(result.stdout.strip(), "wrapper")

    def test_homebrew_sasl_is_macos_only_and_preserves_overrides(self):
        (self.prefix / "lib/sasl2").mkdir(parents=True)
        self.env["TEST_OS"] = "Darwin"
        result = self.shell('print -r -- "$SASL_PATH"')
        self.assertEqual(result.stdout.strip(), str(self.prefix / "lib/sasl2"))
        self.env["SASL_PATH"] = "/custom/sasl"
        result = self.shell('print -r -- "$SASL_PATH"')
        self.assertEqual(result.stdout.strip(), "/custom/sasl")
        del self.env["SASL_PATH"]
        self.env["TEST_OS"] = "Linux"
        result = self.shell('print -r -- "${SASL_PATH:-unset}"')
        self.assertEqual(result.stdout.strip(), "unset")

    def test_local_overrides_still_load(self):
        self.write(self.home / ".zshrc.local", "export TEST_LOCAL=preserved\n")
        result = self.shell('print -r -- "$TEST_LOCAL"')
        self.assertEqual(result.stdout.strip(), "preserved")


class SyncTests(IsolatedConfigTest):
    def setUp(self):
        super().setUp()
        self.script(self.bin / "stow", f"exec {shlex.quote(self.tool('stow'))} \"$@\"\n")

    def test_platform_packages_and_ghostty_fragment(self):
        for platform, fragment in (("Linux", "ghostty-linux"), ("Darwin", "ghostty-macos")):
            with self.subTest(platform=platform):
                self.env["TEST_OS"] = platform
                self.env["HOME"] = str(self.home / platform)
                Path(self.env["HOME"]).mkdir()
                result = self.run_command([str(ROOT / "sync.sh")])
                self.assertIn(fragment, result.stdout)
                home = Path(self.env["HOME"])
                self.assertTrue((home / ".zshrc").is_symlink())
                self.assertEqual(
                    (home / ".config/ghostty/platform.ghostty").resolve(),
                    ROOT / fragment / ".config/ghostty/platform.ghostty",
                )
                self.assertEqual((home / ".aerospace.toml").exists(), platform == "Darwin")

    def test_pull_preview_overrides_rebase_without_pulling(self):
        result = self.run_command([str(ROOT / "sync.sh"), "--pull", "--dry-run"])
        self.assertIn("pull --no-rebase --ff-only", result.stdout)
        self.assertFalse((self.home / ".zshrc").exists())

    def test_macos_scripts_refuse_linux(self):
        for script in ("macos-defaults.sh", "scripts/apply-su-macos.sh"):
            with self.subTest(script=script):
                result = self.run_command([str(ROOT / script)], check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("only supports macOS", result.stderr)

    def test_bootstrap_finds_homebrew_outside_path(self):
        system_bin = self.root / "system-bin"
        system_bin.mkdir()
        for name in ("uname", "stow"):
            shutil.copy2(self.bin / name, system_bin / name)
        self.env.update(TEST_OS="Darwin", PATH=f"{system_bin}:/usr/bin:/bin")
        result = self.run_command([str(ROOT / "bootstrap.sh"), "--dry-run"])
        self.assertIn("DRY-RUN: brew bundle", result.stdout)
        self.assertFalse((self.home / ".zshrc").exists())

    def test_disabled_aerospace_is_not_enabled_or_fatal(self):
        self.env["TEST_OS"] = "Darwin"
        self.script(self.bin / "pgrep", '[ "$2" = AeroSpace ]\n')
        self.script(
            self.bin / "aerospace",
            '[ "$1" = reload-config ] || exit 99\n'
            'echo "AeroSpace server is disabled and doesn\'t accept commands." >&2\nexit 2\n',
        )
        result = self.run_command([str(ROOT / "sync.sh")])
        self.assertIn("Skipped AeroSpace reload", result.stderr)
        self.assertTrue((self.home / ".zshrc").is_symlink())

    def test_other_aerospace_errors_remain_fatal(self):
        self.env["TEST_OS"] = "Darwin"
        self.script(self.bin / "pgrep", '[ "$2" = AeroSpace ]\n')
        self.script(self.bin / "aerospace", 'echo "Invalid configuration" >&2\nexit 2\n')
        result = self.run_command([str(ROOT / "sync.sh")], check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Invalid configuration", result.stderr)


class ThemeTests(IsolatedConfigTest):
    def test_legacy_reader_matches_current_palette_and_targets(self):
        for name in ("colors.toml", "targets.toml"):
            path = ROOT / "theme" / name
            actual = THEME["_load_simple_toml"](path)
            self.assertEqual(actual, THEME["load_toml"](path))
        self.assertEqual(THEME["_load_simple_toml"](ROOT / "theme/colors.toml")["colors"]["bg"],
                         "#f3eee1")

    def test_legacy_reader_handles_quoted_hashes_and_comments(self):
        path = self.root / "colors.toml"
        self.write(path, '[colors] # comment\n"bg" = "#123456" # another comment\n')
        self.assertEqual(THEME["_load_simple_toml"](path), {"colors": {"bg": "#123456"}})

    def test_legacy_reader_rejects_unsupported_or_duplicate_values(self):
        path = self.root / "invalid.toml"
        for content in ('[colors]\nbg = 5\n', '[colors]\nbg = "a"\nbg = "b"\n'):
            with self.subTest(content=content):
                self.write(path, content)
                with self.assertRaises(ValueError):
                    THEME["_load_simple_toml"](path)

    def test_linux_theme_reload_does_not_run_sketchybar(self):
        with mock.patch.object(THEME["sys"], "platform", "linux"), \
             mock.patch.object(THEME["shutil"], "which", return_value="/fake/sketchybar"), \
             mock.patch.object(THEME["subprocess"], "run") as run, \
             contextlib.redirect_stdout(io.StringIO()):
            THEME["hot_reload"]()
        run.assert_not_called()

    @unittest.skipIf(tomllib is None, "Full TOML parsing requires Python 3.11+")
    def test_yazi_html_has_portable_and_terminal_openers(self):
        config = tomllib.loads((ROOT / "yazi/.config/yazi/yazi.toml").read_text())
        for rule in config["open"]["prepend_rules"]:
            self.assertEqual(rule["use"][0], "open")
            self.assertIn("text-browser", rule["use"])
        self.assertEqual(config["opener"]["text-browser"][0]["for"], "unix")
        self.assertEqual(config["opener"]["chrome"][0]["for"], "macos")


class TmuxTests(IsolatedConfigTest):
    def test_clipboard_and_quoted_status_path(self):
        tmux = self.tool("tmux")
        socket = self.root / "tmux.sock"
        project = self.root / "project with spaces"
        project.mkdir()
        self.script(self.home / ".tmux/plugins/tpm/tpm", "exit 0\n")
        self.script(
            self.home / ".tmux/plugins/tmux-continuum/scripts/continuum_save.sh",
            "exit 0\n",
        )
        command = [tmux, "-S", str(socket)]
        try:
            self.run_command(command + [
                "-f", str(ROOT / "tmux/.tmux/.tmux.conf"),
                "new-session", "-d", "-s", "portability", "-c", str(project), "/bin/sh",
            ])
            result = self.run_command(command + ["list-keys", "-T", "copy-mode-vi"])
            self.assertRegex(
                result.stdout,
                r"(?m)^bind-key -T copy-mode-vi y\s+send-keys -X copy-selection-and-cancel$",
            )
            self.assertNotIn("xclip", result.stdout)
            result = self.run_command(command + ["show-options", "-gv", "status-right"])
            self.assertIn("#{q:pane_current_path}", result.stdout)
            result = self.run_command(command + ["display-message", "-p", "#{q:pane_current_path}"])
            self.assertEqual(shlex.split(result.stdout.strip()), [str(project.resolve())])
        finally:
            self.run_command(command + ["kill-server"], check=False)


class DoomTests(IsolatedConfigTest):
    def test_lisp_syntax_and_optional_mail_gate(self):
        expression = r"""
        (progn
          (require 'cl-lib)
          (dolist (file '("doom/.config/doom/init.el" "doom/.config/doom/config.el"))
            (with-temp-buffer
              (insert-file-contents file)
              (check-parens)))
          (defmacro doom! (&rest modules) `(setq test-modules ',modules))
          (load-file "doom/.config/doom/init.el")
          (let ((gate (cadr (memq :email test-modules))))
            (unless (eq (car gate) :if) (error "Mail must be optional"))
            (dolist (missing '(nil "mu" "mbsync" "msmtp"))
              (cl-letf (((symbol-function 'executable-find)
                         (lambda (name) (unless (equal name missing) "/test/bin"))))
                (unless (eq (not (null (eval (cadr gate)))) (null missing))
                  (error "Wrong mail gate for %s" missing))))))
        """
        self.run_command([self.tool("emacs"), "--batch", "-Q", "--eval", expression])


@unittest.skipUnless(shutil.which("ghostty"), "Ghostty is not installed")
class GhosttyTests(IsolatedConfigTest):
    def test_stowed_platform_include_resolves_through_symlinks(self):
        self.env["TEST_OS"] = "Darwin"
        self.env["XDG_CONFIG_HOME"] = str(self.home / ".config")
        self.script(self.bin / "stow", f"exec {shlex.quote(self.tool('stow'))} \"$@\"\n")
        self.run_command([str(ROOT / "sync.sh")])
        result = self.run_command([
            self.tool("ghostty"), "+show-config",
        ])
        self.assertIn("window-decoration = none", result.stdout)


if __name__ == "__main__":
    unittest.main()
