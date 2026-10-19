"""Exercise the real Bash setup in isolated directories, without changing HOME."""

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "codex"
START = "<!-- understanding-workflow:start -->"
END = "<!-- understanding-workflow:end -->"


def snapshot(root):
    return {str(path.relative_to(root)): path.read_bytes()
            for path in root.rglob("*") if path.is_file()}


class UnderstandingSetup(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="understanding-setup-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.codex = self.root / "codex with spaces"
        self.codex.mkdir()
        self.memory = self.codex / "understanding" / "default" / "memory.md"

    def run_setup(self, expect_success=True):
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; setup_understanding "$2" "$3"', "setup-check",
             str(SOURCE / "understanding.sh"), str(SOURCE), str(self.codex)],
            capture_output=True, text=True,
        )
        if expect_success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_empty_setup_creates_private_memory_without_example_claims(self):
        self.run_setup()
        self.assertEqual(self.memory.stat().st_mode & 0o777, 0o600)
        content = self.memory.read_text()
        self.assertIn("Profile: default", content)
        self.assertEqual(content.count("None recorded."), 2)
        self.assertNotIn("State:", content)
        routing = (self.codex / "AGENTS.md").read_text()
        self.assertIn("Understanding memory file: `understanding/default/memory.md`", routing)
        self.assertEqual(routing.count(START), 1)

    def test_reinstallation_preserves_memory_and_existing_instructions(self):
        original = "# Existing rules\nPrefer the repo's check command.\n"
        agents = self.codex / "AGENTS.md"
        agents.write_text(original)
        self.run_setup()
        self.memory.write_text(self.memory.read_text().replace("None recorded.", "Owner-edited preference.", 1))
        before = snapshot(self.root)
        self.run_setup()
        self.assertEqual(before, snapshot(self.root))
        self.assertTrue(agents.read_text().startswith(original))

    def test_refreshes_only_the_marked_block_in_its_existing_position(self):
        agents = self.codex / "AGENTS.md"
        agents.write_text("# Before\n" + START + "\nOld framework route.\n" + END + "\n# After\n")
        self.run_setup()
        text = agents.read_text()
        self.assertTrue(text.startswith("# Before\n"))
        self.assertTrue(text.endswith("# After\n"))
        self.assertNotIn("Old framework route.", text)
        self.assertEqual(text.count(START), 1)
        self.assertEqual(text.count(END), 1)

    def test_active_override_is_updated_without_changing_inactive_guidance(self):
        agents = self.codex / "AGENTS.md"
        override = self.codex / "AGENTS.override.md"
        agents.write_text("# Inactive global instructions\n")
        override.write_text("# Active global instructions\n")
        self.run_setup()
        self.assertEqual(agents.read_text(), "# Inactive global instructions\n")
        self.assertIn(START, override.read_text())

    def test_empty_override_does_not_hide_regular_guidance(self):
        override = self.codex / "AGENTS.override.md"
        override.write_text("")
        self.run_setup()
        self.assertEqual(override.read_bytes(), b"")
        self.assertIn(START, (self.codex / "AGENTS.md").read_text())

    def test_existing_instruction_symlink_and_permissions_are_preserved(self):
        original = self.root / "managed-guidance.md"
        original.write_text("# Linked guidance\n")
        original.chmod(0o640)
        live = self.codex / "AGENTS.md"
        live.symlink_to(original)
        self.run_setup()
        self.assertTrue(live.is_symlink())
        self.assertEqual(live.resolve(), original)
        self.assertEqual(original.stat().st_mode & 0o777, 0o640)
        self.assertIn(START, original.read_text())

    def test_damaged_routing_refuses_without_creating_memory_or_editing_guidance(self):
        agents = self.codex / "AGENTS.md"
        for text in (START + "\nUnclosed block.\n", END + "\nOrphaned end.\n",
                     START + "\n" + END + "\n" + START + "\n" + END + "\n"):
            with self.subTest(text=text):
                agents.write_text(text)
                before = snapshot(self.root)
                self.run_setup(expect_success=False)
                self.assertEqual(before, snapshot(self.root))
                self.assertFalse(self.memory.exists())

    def test_other_profile_refuses_without_overwriting_personal_memory(self):
        self.memory.parent.mkdir(parents=True)
        content = (SOURCE / "understanding-memory.template.md").read_text().replace(
            "Profile: default", "Profile: another-user"
        )
        self.memory.write_text(content)
        before = snapshot(self.root)
        self.run_setup(expect_success=False)
        self.assertEqual(before, snapshot(self.root))

    def test_incompatible_format_refuses_without_repairing_or_overwriting(self):
        self.memory.parent.mkdir(parents=True)
        self.memory.write_text("# Owner notes in a different format\n")
        before = snapshot(self.root)
        self.run_setup(expect_success=False)
        self.assertEqual(before, snapshot(self.root))


class BundleReferences(unittest.TestCase):
    def test_memory_contracts_are_identical(self):
        copies = [(ROOT / "skills" / name / "references" / "memory-contract.md").read_bytes()
                  for name in ("respond-for-understanding", "learning-retro")]
        self.assertEqual(copies[0], copies[1])


if __name__ == "__main__":
    unittest.main()
