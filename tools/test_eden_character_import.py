#!/usr/bin/env python3
"""Public-seam tests for deterministic Eden package character import."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools.import_eden_character import import_character, recolor_character


DEFAULT_MIDUO_PACKAGE = Path(
    "/home/ubuntu/app/eden-0.3.2/workspace/export/"
    "tsk_local_22c30f0eed014a34adc16a3f0b3805be/package"
)
MIDUO_BLUE_MAPPING = (
    Path(__file__).resolve().parents[1]
    / "data/recolor_presets/miduo_green_uniform_to_blue_v1.json"
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

            self.assertEqual(first_report, second_report)
            self.assertEqual(
                _snapshot_generated_files(Path(first_dir)),
                _snapshot_generated_files(Path(second_dir)),
            )

    def test_recolor_is_complete_selective_and_independent(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            project_root = Path(temp_dir)
            import_character(self.package_root, "Miduo", project_root)
            palette = _palette_from_document(MIDUO_BLUE_MAPPING)
            source_template = project_root / "data/v0_3/templates/miduo.json"
            source_move = project_root / "data/v0_3/moves/miduo_jab.json"
            source_template_before = source_template.read_bytes()
            source_move_before = source_move.read_bytes()

            report = recolor_character(
                project_root,
                "miduo",
                "Miduo Blue",
                palette,
                mapping_id="miduo_green_uniform_to_blue_v1",
            )

            self.assertEqual(report["status"], "complete")
            self.assertEqual(report["source_character_id"], "miduo")
            self.assertEqual(report["character_id"], "miduo_blue")
            self.assertEqual(report["frame_count"], 476)
            self.assertGreater(report["recolored_pixel_count"], 0)
            self.assertEqual(report["mapping_entry_count"], len(palette))

            target_frames = project_root / "godot/assets/frames/miduo_blue"
            self.assertEqual(len(list(target_frames.rglob("*.png"))), 476)
            _assert_only_palette_pixels_changed(
                self,
                project_root / "godot/assets/frames/miduo",
                target_frames,
                palette,
            )

            target_template = json.loads(
                (project_root / "data/v0_3/templates/miduo_blue.json").read_text()
            )
            target_sprite_set = json.loads(
                (project_root / "data/v0_3/sprite_sets/miduo_blue.json").read_text()
            )
            self.assertEqual(target_template["template_id"], "miduo_blue")
            self.assertEqual(target_template["sprite_set_ref"], "miduo_blue")
            self.assertEqual(target_sprite_set["sprite_set_id"], "miduo_blue")
            self.assertTrue(all(move.startswith("miduo_blue_") for move in target_template["equipped_moves"]))
            self.assertEqual(
                [move.removeprefix("miduo_blue_") for move in target_template["equipped_moves"]],
                [move.removeprefix("miduo_") for move in json.loads(source_template_before)["equipped_moves"]],
            )

            target_template["hp"] = 333
            target_template_path = project_root / "data/v0_3/templates/miduo_blue.json"
            target_template_path.write_text(json.dumps(target_template), encoding="utf-8")
            target_move_path = project_root / "data/v0_3/moves/miduo_blue_jab.json"
            target_move = json.loads(target_move_path.read_text())
            target_move["damage"] = 77
            target_move_path.write_text(json.dumps(target_move), encoding="utf-8")
            self.assertEqual(source_template.read_bytes(), source_template_before)
            self.assertEqual(source_move.read_bytes(), source_move_before)

    def test_same_recolor_inputs_produce_byte_identical_saved_data(self) -> None:
        outputs = []
        for _ in range(2):
            temp = tempfile.TemporaryDirectory()
            self.addCleanup(temp.cleanup)
            root = Path(temp.name)
            import_character(self.package_root, "Miduo", root)
            palette = _palette_from_document(MIDUO_BLUE_MAPPING)
            report = recolor_character(
                root,
                "miduo",
                "Miduo Blue",
                palette,
                mapping_id="miduo_green_uniform_to_blue_v1",
            )
            outputs.append((root, report))
        self.assertEqual(outputs[0][1], outputs[1][1])
        self.assertEqual(
            _snapshot_generated_files(outputs[0][0]),
            _snapshot_generated_files(outputs[1][0]),
        )


def _snapshot_generated_files(root: Path) -> dict[str, bytes]:
    """Capture every importer-owned output byte, including frames and provenance."""
    generated_roots = (
        root / "data/imports",
        root / "data/v0_3/moves",
        root / "data/v0_3/sprite_sets",
        root / "data/v0_3/templates",
        root / "godot/assets/frames",
    )
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for generated_root in generated_roots
        if generated_root.exists()
        for path in sorted(generated_root.rglob("*"))
        if path.is_file()
    }


def _palette_from_document(path: Path) -> dict[tuple[int, int, int, int], tuple[int, int, int, int]]:
    document = json.loads(path.read_text(encoding="utf-8"))
    return {
        tuple(entry["from_rgba"]): tuple(entry["to_rgba"])
        for entry in document["entries"]
    }


def _assert_only_palette_pixels_changed(
    case: unittest.TestCase,
    source_root: Path,
    target_root: Path,
    palette: dict[tuple[int, int, int, int], tuple[int, int, int, int]],
) -> None:
    changed = 0
    for source_path in sorted(source_root.rglob("*.png")):
        relative = source_path.relative_to(source_root)
        target_path = target_root / relative
        case.assertTrue(target_path.is_file(), str(relative))
        source_pixels = list(Image.open(source_path).convert("RGBA").getdata())
        target_pixels = list(Image.open(target_path).convert("RGBA").getdata())
        case.assertEqual(len(source_pixels), len(target_pixels))
        for source, target in zip(source_pixels, target_pixels):
            case.assertEqual(target[3], source[3])
            if source in palette:
                case.assertEqual(target, palette[source])
                changed += 1
            else:
                case.assertEqual(target, source)
    case.assertGreater(changed, 0)


if __name__ == "__main__":
    unittest.main()
