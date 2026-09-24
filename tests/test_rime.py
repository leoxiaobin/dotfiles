"""Rime uses real Stow/rsync with temporary homes and a local Plum fixture."""
import shlex
from test_portability import IsolatedConfigTest, ROOT


class RimeTests(IsolatedConfigTest):
    def setUp(self):
        super().setUp()
        self.env["TEST_OS"] = "Darwin"
        for tool in ("stow", "rsync"):
            self.script(self.bin / tool, f'exec {shlex.quote(self.tool(tool))} "$@"\n')
        self.rime = self.home / "Library/Rime"

    def run_rime(self, *args, check=True):
        return self.run_command([str(ROOT / "scripts/rime.sh"), *args], check=check)

    def fixture_plum(self):
        self.script(self.home / "plum/rime-install", '''
[ "$1" = iDvel/rime-ice ] || exit 1
printf 'upstream schema\n' > "$rime_dir/rime_ice.schema.yaml"
printf 'upstream default\n' > "$rime_dir/default.yaml"
printf 'patch overwrite\n' > "$rime_dir/default.custom.yaml"
printf 'runtime overwrite\n' > "$rime_dir/user.yaml"
printf 'phrases overwrite\n' > "$rime_dir/custom_phrase.txt"
mkdir -p "$rime_dir/build" "$rime_dir/test.userdb"
printf 'generated\n' > "$rime_dir/build/example"
printf 'generated\n' > "$rime_dir/test.userdb/example"
''')

    def test_mac_links_only_patches_and_reruns(self):
        self.write(self.rime / "default.yaml", "upstream\n")
        for _ in range(2):
            self.run_command([str(ROOT / "sync.sh")])
        for name in ("default", "squirrel"):
            target = self.rime / f"{name}.custom.yaml"
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), ROOT / "rime/Library/Rime" / target.name)
        self.assertEqual((self.rime / "default.yaml").read_text(), "upstream\n")

    def test_conflicts_are_not_overwritten(self):
        target = self.rime / "default.custom.yaml"
        self.write(target, "user patch\n")
        result = self.run_command([str(ROOT / "sync.sh")], check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(target.is_symlink())
        self.assertEqual(target.read_text(), "user patch\n")

    def test_linux_sync_does_not_install_rime(self):
        self.env["TEST_OS"] = "Linux"
        self.run_command([str(ROOT / "sync.sh")])
        self.assertFalse(self.rime.exists())
        self.assertNotEqual(self.run_rime("install", check=False).returncode, 0)

    def test_bootstrap_dry_run_is_read_only(self):
        result = self.run_command([str(ROOT / "bootstrap.sh"), "--dry-run"])
        self.assertIn("brew bundle", result.stdout)
        self.assertIn("iDvel/rime-ice", result.stdout)
        self.assertIn("--reload", result.stdout)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_install_update_preserve_patches_runtime_and_phrases(self):
        self.fixture_plum()
        for name in ("default.custom.yaml", "user.yaml", "custom_phrase.txt", "test.userdb/example", "build/example"):
            self.write(self.rime / name, "user data\n")
        self.run_rime("install")
        schema = self.rime / "rime_ice.schema.yaml"
        self.assertEqual(schema.read_text(), "upstream schema\n")
        schema.write_text("unchanged on reinstall\n")
        self.run_rime("install")
        self.assertEqual(schema.read_text(), "unchanged on reinstall\n")
        self.run_rime("update")
        self.assertEqual(schema.read_text(), "upstream schema\n")
        for name in ("default.custom.yaml", "user.yaml", "custom_phrase.txt", "test.userdb/example", "build/example"):
            self.assertEqual((self.rime / name).read_text(), "user data\n")

    def test_existing_non_plum_directory_is_not_overwritten(self):
        self.write(self.home / "plum/my-file", "keep\n")
        self.assertNotEqual(self.run_rime("install", check=False).returncode, 0)
        self.assertEqual((self.home / "plum/my-file").read_text(), "keep\n")

    def test_update_never_writes_through_custom_symlinks(self):
        self.fixture_plum()
        source = self.root / "tracked-patch.yaml"
        source.write_text("my patch\n")
        self.rime.mkdir(parents=True)
        patch = self.rime / "default.custom.yaml"
        patch.symlink_to(source)
        self.run_rime("update")
        self.assertTrue(patch.is_symlink())
        self.assertEqual(source.read_text(), "my patch\n")

    def test_failed_plum_output_does_not_touch_user_directory(self):
        self.script(self.home / "plum/rime-install", "exit 0\n")
        self.assertNotEqual(self.run_rime("install", check=False).returncode, 0)
        self.assertFalse(self.rime.exists())
