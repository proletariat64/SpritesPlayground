from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ACTIVE_SOURCE_ROOTS = (
    ROOT / "godot",
    ROOT / "tools",
    ROOT / ".pi" / "skills" / "import-eden-character",
    ROOT / "data" / "imports",
)
ACTIVE_SOURCE_FILES = (
    ROOT / "docs" / "02_prd" / "prd-20260626-sprites-playground-product-v0-6.md",
)


class AuthoredDataRootTests(unittest.TestCase):
    def test_v0_6_is_the_only_checked_in_authored_data_root(self) -> None:
        for section in ("templates", "moves", "sprite_sets"):
            self.assertTrue((ROOT / "data" / "v0_6" / section).is_dir())
            self.assertFalse((ROOT / "data" / section).exists())
        self.assertFalse((ROOT / "data" / "v0_3").exists())

    def test_active_sources_do_not_reference_retired_authored_roots(self) -> None:
        forbidden = (
            "data/" + "v0_3/",
            "res://data/" + "templates",
            "res://data/" + "moves",
            "res://data/" + "sprite_sets",
        )
        candidates = list(ACTIVE_SOURCE_FILES)
        for source_root in ACTIVE_SOURCE_ROOTS:
            candidates.extend(
                path
                for path in source_root.rglob("*")
                if path.suffix in {".gd", ".json", ".md", ".py"}
            )
        failures = []
        for path in candidates:
            if path == Path(__file__):
                continue
            text = path.read_text(encoding="utf-8")
            for retired_root in forbidden:
                if retired_root in text:
                    failures.append(f"{path.relative_to(ROOT)} references {retired_root}")
        self.assertEqual([], failures, "\n".join(failures))


if __name__ == "__main__":
    unittest.main()
