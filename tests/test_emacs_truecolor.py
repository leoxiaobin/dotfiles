"""True-color setup must preserve capabilities and leave non-RGB hosts alone."""
import re
import shlex
from test_portability import IsolatedConfigTest, ROOT


class EmacsTruecolorTests(IsolatedConfigTest):
    def setUp(self):
        super().setUp()
        self.env.update(TERM="tmux-256color", TMUX="test")
        self.script(self.bin / "tmux", "printf 'RGB,clipboard\\n'\n")
        self.script(self.bin / "infocmp", f'case "$2" in *-emacs-rgb) exec {shlex.quote(self.tool("infocmp"))} "$@";; esac\n' + "cat <<'END'\ntmux-256color|test terminal,\n colors#256, cols#80, clear=\\E[H\\E[2J,\nEND\n")
        self.script(self.bin / "tic", f'exec {shlex.quote(self.tool("tic"))} "$@"\n')

    def setup_color(self, *args):
        return self.run_command([str(ROOT / "scripts/setup-emacs-truecolor.sh"), *args])

    def test_dry_run_does_not_write(self):
        self.assertIn("DRY-RUN", self.setup_color("--dry-run").stdout)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_install_preserves_original_and_adds_only_missing_capabilities(self):
        self.assertIn("Installed", self.setup_color().stdout)
        self.assertFalse((self.home / ".terminfo/74/tmux-256color").exists())
        self.assertFalse((self.home / ".terminfo/t/tmux-256color").exists())
        self.script(self.bin / "infocmp", f'exec {shlex.quote(self.tool("infocmp"))} "$@"\n')
        result = self.run_command([str(self.bin / "infocmp"), "-x", "tmux-256color-emacs-rgb"])
        for capability in ("setf24=", "setb24=", "clear="):
            self.assertIn(capability, result.stdout)
        colors = re.search(r"\bcolors#(0x[0-9a-fA-F]+|[0-9]+)", result.stdout)
        self.assertIsNotNone(colors)
        self.assertEqual(int(colors.group(1), 0), 256)
        self.assertEqual(self.setup_color().stdout, "")

    def test_non_rgb_client_prevents_install_even_with_colorterm(self):
        self.env["COLORTERM"] = "truecolor"
        self.script(self.bin / "tmux", "printf 'RGB,clipboard\\nclipboard\\n'\n")
        self.setup_color()
        self.assertEqual(list(self.home.iterdir()), [])

    def test_colorterm_alone_is_not_proof(self):
        del self.env["TMUX"]
        self.env["COLORTERM"] = "truecolor"
        self.setup_color()
        self.assertEqual(list(self.home.iterdir()), [])

    def test_missing_tic_warns_without_writing(self):
        (self.bin / "tic").unlink()
        (self.bin / "bash").symlink_to(self.tool("bash"))
        self.env["PATH"] = str(self.bin)
        result = self.setup_color()
        self.assertIn("install ncurses", result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_compile_failure_preserves_home(self):
        self.script(self.bin / "tic", "exit 1\n")
        self.assertIn("existing configuration was preserved", self.setup_color().stderr)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_rgb_then_non_rgb_selects_generic_terminal(self):
        self.setup_color()
        self.assertEqual(self.setup_color("--print-term").stdout.strip(), "tmux-256color-emacs-rgb")
        self.script(self.bin / "emacsclient", 'printf "%s\\n" "$TERM" "$@"\n')
        rgb = self.shell('e "path with spaces"').stdout.splitlines()
        self.assertEqual(rgb, ["tmux-256color-emacs-rgb", "-t", "-a", "", "path with spaces"])
        self.script(self.bin / "tmux", "printf 'clipboard\\n'\n")
        self.assertEqual(self.setup_color("--print-term").stdout, "")
        self.script(self.bin / "emacsclient", 'printf "%s\\n" "$TERM"\n')
        self.assertEqual(self.shell("e").stdout.strip(), "tmux-256color")

    def test_compiler_arguments_are_preserved(self):
        config = (ROOT / "doom/.config/doom/config.el").read_text()
        block = config.split(";; Emacs Plus may retain", 1)[1].split(";; Terminal-only hosts", 1)[0]
        block = block[block.index("(when"):]
        # Evaluate precisely the startup guard in an isolated Emacs environment.
        expression = """(let ((system-type 'darwin) (process-environment (copy-sequence process-environment)))
          (dolist (value '("/usr/bin/clang -arch arm64" "/bin/sh" "/missing/dotfiles-compiler"))
            (setenv "CC" value)
            REPLACE
            (unless (equal (getenv "CC") (unless (equal value "/missing/dotfiles-compiler") value))
              (error "Incorrect compiler cleanup: %s" value))))""".replace("REPLACE", block)
        self.run_command([self.tool("emacs"), "--batch", "-Q", "--eval", expression])
