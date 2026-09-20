"""SSH deployment regressions with isolated homes; no package installation."""
import shlex
import unittest

from test_portability import IsolatedConfigTest, ROOT, tomllib


class SSHProfileTests(IsolatedConfigTest):
    def setUp(self):
        super().setUp()
        self.script(self.bin / "stow", f'exec {shlex.quote(self.tool("stow"))} "$@"\n')
        self.profile = self.home / ".config/dotfiles/profile"

    def sync(self, *args, check=True):
        return self.run_command([str(ROOT / "sync.sh"), *args], check=check)

    def test_ssh_profile_is_remembered_and_avoids_desktop_packages(self):
        result = self.sync("--profile", "ssh")
        self.assertEqual(self.profile.read_text(), "ssh\n")
        self.assertTrue((self.home / ".config/doom/config.el").is_symlink())
        self.assertEqual((self.home / ".config/yazi/yazi.toml").resolve(),
                         ROOT / "yazi-ssh/.config/yazi/yazi.toml")
        for path in (".config/ghostty", ".config/fontconfig", ".aerospace.toml",
                     ".config/sketchybar", ".config/borders"):
            self.assertFalse((self.home / path).exists(), path)
        self.assertNotIn("latex is missing", result.stderr)
        self.assertNotIn("sudo apt install git emacs ", result.stderr)
        self.assertIn("Profile: ssh", self.sync().stdout)
        self.assertEqual(self.shell('print -r -- "$DOTFILES_PROFILE"').stdout.strip(), "ssh")

    def test_profile_switch_and_dry_run_preserve_local_files(self):
        self.sync()
        own = self.home / ".config/ghostty/local.conf"
        own.write_text("user-owned\n")
        self.sync("--profile", "ssh", "--dry-run")
        self.assertEqual(self.profile.read_text(), "desktop\n")
        self.assertTrue((self.home / ".config/ghostty/config.ghostty").is_symlink())
        self.sync("--profile", "ssh")
        self.assertFalse((self.home / ".config/ghostty/config.ghostty").exists())
        self.assertEqual(own.read_text(), "user-owned\n")
        self.sync("--profile", "desktop", "--dry-run")
        self.assertEqual(self.profile.read_text(), "ssh\n")
        self.sync("--profile", "desktop")
        self.assertEqual((self.home / ".config/yazi/yazi.toml").resolve(),
                         ROOT / "yazi/.config/yazi/yazi.toml")
        self.assertTrue((self.home / ".config/ghostty/config.ghostty").is_symlink())

    def test_real_desktop_files_are_not_removed(self):
        self.write(self.home / ".config/ghostty/config.ghostty", "user config\n")
        self.sync("--profile", "ssh")
        self.assertEqual((self.home / ".config/ghostty/config.ghostty").read_text(), "user config\n")

    def test_profile_is_explicit_and_invalid_values_do_not_mutate_home(self):
        self.env["SSH_CONNECTION"] = "192.0.2.1 1000 192.0.2.2 22"
        self.assertIn("Profile: desktop", self.sync("--dry-run").stdout)
        self.assertFalse(self.profile.exists())
        for args in (("--profile",), ("--profile", "unknown")):
            self.assertNotEqual(self.sync(*args, check=False).returncode, 0)
        self.env["TEST_OS"] = "Darwin"
        self.assertNotEqual(self.sync("--profile", "ssh", check=False).returncode, 0)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_pull_preserves_profile_without_network(self):
        self.script(self.bin / "git", "exit 0\n")
        self.sync("--pull", "--profile", "ssh")
        self.assertEqual(self.profile.read_text(), "ssh\n")
        self.assertFalse((self.home / ".config/ghostty").exists())

    def test_bootstrap_forwards_profile(self):
        self.run_command([str(ROOT / "bootstrap.sh"), "--skip-packages", "--profile", "ssh"])
        self.assertEqual(self.profile.read_text(), "ssh\n")

    def test_linux_installer_ssh_package_plan(self):
        # Give the actual installer a synthetic os-release on macOS too.
        repo = self.root / "installer"
        self.write(repo / "scripts/lib/profile.sh", (ROOT / "scripts/lib/profile.sh").read_text())
        release = self.root / "os-release"
        release.write_text("ID=ubuntu\n")
        script = repo / "install/linux.sh"
        self.write(script, (ROOT / "install/linux.sh").read_text().replace("/etc/os-release", str(release)))
        script.chmod(0o755)
        result = self.run_command([str(script), "--profile", "ssh", "--dry-run"])
        self.assertIn("--no-install-recommends", result.stdout)
        self.assertIn("emacs-nox", result.stdout)
        self.assertIn("poppler-utils", result.stdout)
        for package in ("emacs", "fontconfig", "xdg-utils"):
            self.assertNotIn(package, result.stdout.split())
        self.assertEqual(list(self.home.iterdir()), [])

    def test_doom_pdf_gate_uses_saved_profile(self):
        self.write(self.profile, "ssh\n")
        expression = r'''
        (progn
          (require 'subr-x)
          (defmacro doom! (&rest modules) `(setq test-modules ',modules))
          (load-file "doom/.config/doom/init.el")
          (unless my/ssh-only-p (error "SSH profile not detected"))
          (let ((gate (seq-find (lambda (x) (and (listp x) (memq 'pdf x))) test-modules)))
            (unless (and gate (eq (car gate) :if) (not (eval (cadr gate))))
              (error "PDF module must be disabled"))))
        '''
        self.run_command([self.tool("emacs"), "--batch", "-Q", "--eval", expression])

    @unittest.skipUnless(tomllib, "TOML parsing requires Python 3.11")
    def test_yazi_ssh_openers_never_launch_desktop_apps(self):
        config = tomllib.loads((ROOT / "yazi-ssh/.config/yazi/yazi.toml").read_text())
        self.assertIn("rules", config["open"])
        commands = " ".join(op["run"] for ops in config["opener"].values() for op in ops)
        for forbidden in ("xdg-open", "open -a", "google-chrome"):
            self.assertNotIn(forbidden, commands)
        for rule in config["open"]["rules"]:
            uses = rule["use"] if isinstance(rule["use"], list) else [rule["use"]]
            self.assertTrue(all(name in config["opener"] for name in uses))

    def test_tmux_helper_does_not_send_desktop_notifications_over_ssh(self):
        self.env.update(SSH_CONNECTION="192.0.2.1 1000 192.0.2.2 22", DISPLAY=":10")
        self.script(self.bin / "zoxide", 'if [ "$1" = init ]; then exit 0; fi; printf "/tmp/project\\n"\n')
        self.script(self.bin / "fzf", 'if [ "$1" = --zsh ]; then exit 0; fi; /bin/cat\n')
        self.script(self.bin / "tmux", 'exit 0\n')
        self.script(self.bin / "notify-send", 'touch "$HOME/notification"\n')
        self.shell("new_tmux")
        self.assertFalse((self.home / "notification").exists())
        del self.env["SSH_CONNECTION"]
        self.write(self.profile, "ssh\n")
        self.shell("new_tmux")
        self.assertFalse((self.home / "notification").exists())
        self.write(self.profile, "desktop\n")
        self.shell("new_tmux")
        self.assertTrue((self.home / "notification").exists())

    def test_git_diff_filter_falls_back_without_delta(self):
        config = ROOT / "git/.gitconfig"
        result = self.run_command([self.tool("git"), "config", "--file", str(config), "interactive.diffFilter"])
        import subprocess
        env = self.env.copy()
        # Isolate command lookup even on CI hosts that install delta system-wide.
        command_bin = self.root / "commands"
        command_bin.mkdir()
        (command_bin / "cat").symlink_to(self.tool("cat"))
        env["PATH"] = str(command_bin)
        proc = subprocess.run(["/bin/sh", "-c", result.stdout.strip()], input="diff fixture\n",
                              text=True, capture_output=True, env=env, timeout=5)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "diff fixture\n")
