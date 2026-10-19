"""Documentation checks use temporary files only; no Godot/player storage."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

CHECKER = Path(__file__).resolve().parents[1] / "tools/check_docs.py"


class DocumentationChecks(unittest.TestCase):
    def setUp(self):
        self.assertTrue(CHECKER.is_file(), "documentation checker has not been implemented")
        spec = importlib.util.spec_from_file_location("check_docs", CHECKER)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.doc = self.root / "contract.md"

    def errors(self, text, metadata=False):
        self.doc.write_text(text, encoding="utf-8")
        return self.module.validate_document(self.doc, self.root, "v25", metadata)

    def test_missing_relative_target_fails(self):
        self.assertTrue(self.errors("[rule](missing.md)"))

    def test_valid_encoded_relative_target_and_web_link(self):
        (self.root / "other file.md").touch()
        self.assertEqual(self.errors("[rule](other%20file.md#part) [web](https://example.com/)"), [])

    def test_missing_example_link_inside_fenced_code_is_ignored(self):
        self.assertEqual(self.errors("```markdown\n[example](missing.md)\n```\n"), [])

    def test_current_contract_requires_current_version_and_review_date(self):
        self.assertTrue(self.errors("# Contract", metadata=True))
        self.assertTrue(self.errors("<!-- doc-status: current; doc-role: contract; content-version: v24; reviewed: 2026-10-19 -->", metadata=True))
        self.assertEqual(self.errors("<!-- doc-status: current; doc-role: contract; content-version: v25; reviewed: 2026-10-19 -->", metadata=True), [])

    def test_removed_source_link_and_current_version_claim_fail(self):
        self.assertTrue(self.errors("[old](core/campaign_rules.gd)"))
        metadata = "<!-- doc-status: current; doc-role: contract; content-version: v25; reviewed: 2026-10-19 -->\n"
        errors = self.errors(metadata + "当前内容版本为 `godot-flow-v02-11`。", metadata=True)
        self.assertTrue(any("stale current-version claim" in error for error in errors))

    def test_unregistered_history_is_not_forced_to_current_version(self):
        self.assertEqual(self.errors("当前内容版本为 `godot-flow-v02-11`。"), [])

    def test_current_repository_documents_and_sources(self):
        errors, documents, contracts = self.module.check_project(CHECKER.parents[1])
        self.assertGreater(documents, 0)
        self.assertGreater(contracts, 0)
        self.assertEqual(errors, [])

    def test_manifest_sources_must_exist(self):
        self.assertTrue(self.module.validate_sources(self.root, ["core/missing.gd"]))
        (self.root / "core").mkdir()
        (self.root / "core/game_session.gd").touch()
        self.assertEqual(self.module.validate_sources(self.root, ["core/game_session.gd"]), [])


if __name__ == "__main__":
    unittest.main()
