#!/usr/bin/env python3
"""Public-seam tests for deterministic Eden package character import."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

from tools.import_eden_character import import_character


DEFAULT_MIDUO_PACKAGE = Path(
    "/home/ubuntu/app/eden-0.3.2/workspace/export/"
    "tsk_local_22c30f0eed014a34adc16a3f0b3805be/package"
)


class EdenCharacterImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.package_root = Path(
            os.environ.get("MIDUO_EDEN_PACKAGE", DEFAULT_MIDUO_PACKAGE)
        )
        if not (cls.package_root / "package.json").is_file():
            raise unittest.SkipTest(
                "Set MIDUO_EDEN_PACKAGE to the completed Miduo64 Eden package"
            )

    def test_imports_complete_miduo_package_without_manual_organization(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            project_root = Path(temp_dir)
            # Pre-existing shared moves owned by other characters must survive import.
            shared_move = project_root / "data/v0_3/moves/idle.json"
            shared_move.parent.mkdir(parents=True)
            shared_move.write_text('{"move_id": "idle"}\n', encoding="utf-8")

            report = import_character(
                self.package_root,
                "Miduo",
                project_root,
            )

            self.assertEqual(report["status"], "complete")
            self.assertEqual(report["character_id"], "miduo")
            self.assertEqual(report["source_accounting"]["behavior_count"], 31)
            self.assertEqual(report["source_accounting"]["direction_unit_count"], 116)
            self.assertEqual(report["source_accounting"]["frame_count"], 476)
            self.assertEqual(len(report["imported"]), 31)
            self.assertEqual(report["unresolved"], [])

            source_ids = {item["eden_behavior_id"] for item in report["imported"]}
            self.assertIn("bhv_idle_breath", source_ids)
            self.assertIn("bhv_walk_loop", source_ids)
            self.assertIn("bhv_roundhouse_kick", source_ids)

            self.assertIn("uppercut", report["missing"])
            self.assertIn("uppercut", report["unequipped"])
            self.assertNotIn("uppercut", report["equipped_moves"])
            self.assertNotIn("miduo_uppercut", report["equipped_moves"])
            self.assertIn("miduo_jab", report["equipped_moves"])
            self.assertIn("jab", report["equipped_actions"])

            # Character-scoped move files exist; shared move files are untouched.
            self.assertTrue(
                (project_root / "data/v0_3/moves/miduo_jab.json").is_file()
            )
            self.assertFalse((project_root / "data/v0_3/moves/jab.json").exists())
            self.assertEqual(
                shared_move.read_text(encoding="utf-8"), '{"move_id": "idle"}\n'
            )

            template_path = project_root / report["outputs"]["template"]
            sprite_set_path = project_root / report["outputs"]["sprite_set"]
            report_path = project_root / report["outputs"]["report"]
            self.assertTrue(template_path.is_file())
            self.assertTrue(sprite_set_path.is_file())
            self.assertTrue(report_path.is_file())

            template = json.loads(template_path.read_text(encoding="utf-8"))
            sprite_set = json.loads(sprite_set_path.read_text(encoding="utf-8"))
            self.assertEqual(template["template_id"], "miduo")
            self.assertEqual(template["sprite_set_ref"], "miduo")
            self.assertEqual(template["equipped_moves"], report["equipped_moves"])
            self.assertEqual(sprite_set["sprite_set_id"], "miduo")
            mapping = sprite_set["required_moves_mapping"]
            for move_id in template["equipped_moves"]:
                self.assertIn(move_id, mapping)
                self.assertIn(mapping[move_id], sprite_set["animation_clips"])

            # Provenance: Eden manifests and segment previews are preserved.
            provenance = project_root / report["outputs"]["provenance"]
            self.assertTrue((provenance / "eden_package.json").is_file())
            self.assertEqual(
                len(list((provenance / "behaviors").glob("bhv_*.json"))), 31
            )
            self.assertEqual(
                len(list((provenance / "previews").glob("bhv_*.png"))), 31
            )

            imported_frames = list(
                (project_root / "godot/assets/frames/miduo").rglob("*.png")
            )
            self.assertEqual(len(imported_frames), 476)

    def test_same_inputs_produce_byte_identical_saved_data(self) -> None:
        with tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
            first_report = import_character(
                self.package_root,
                "Miduo",
                Path(first_dir),
            )
            second_report = import_character(
                self.package_root,
                "Miduo",
                Path(second_dir),
            )

            for output_key in ("template", "sprite_set", "report"):
                first = Path(first_dir) / first_report["outputs"][output_key]
                second = Path(second_dir) / second_report["outputs"][output_key]
                self.assertEqual(first.read_bytes(), second.read_bytes())


if __name__ == "__main__":
    unittest.main()
