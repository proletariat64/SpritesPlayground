"""Proof for offline enemy curation, including immutable inputs and grid repair."""
import importlib.util
import tempfile
import unittest
from pathlib import Path
from statistics import median

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("enemy_art", ROOT / "tools/build_homeward_enemy_art.py")
assert SPEC and SPEC.loader
art = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(art)
SOURCE = ROOT / "godot/assets/homeward/source_art/batch2"
OUTPUT = ROOT / "godot/assets/homeward/enemies"


class HomewardEnemyArtTests(unittest.TestCase):
    def test_rebuild_matches_shipped_bytes_and_preserves_inputs(self):
        before = {p.name: p.read_bytes() for p in SOURCE.glob("*.png")}
        self.assertEqual(len(before), 13)
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / "out"
            art.build(SOURCE, out, Path(temp) / "proof")
            for file in out.iterdir():
                self.assertEqual(file.read_bytes(), (OUTPUT / file.name).read_bytes(), file.name)
        self.assertEqual(before, {p.name: p.read_bytes() for p in SOURCE.glob("*.png")})

    def test_all_240_poses_are_nonempty_binary_alpha_and_unclipped(self):
        for identity in art.IDENTITIES:
            with Image.open(OUTPUT / f"{identity}.png") as atlas:
                self.assertEqual(atlas.size, (480, 640))
                self.assertEqual(set(atlas.getchannel("A").tobytes()), {0, 255})
                for row in range(8):
                    poses = []
                    heights = []
                    for col in range(6):
                        cell = atlas.crop((col * 80, row * 80, (col + 1) * 80, (row + 1) * 80))
                        box = cell.getbbox()
                        self.assertIsNotNone(box)
                        assert box
                        self.assertGreaterEqual(min(box[:2]), 1)
                        self.assertLessEqual(max(box[2:]), 79)
                        if row in (0, 1, 2, 3, 6, 7):
                            self.assertLessEqual(abs(box[3] - 68), 1, (identity, row, col, box))
                        heights.append(box[3] - box[1])
                        poses.append(cell.tobytes())
                    if row == 0:
                        low, high = (58, 60) if identity in art.IDENTITIES[3:] else (50, 56)
                        self.assertGreaterEqual(median(heights), low)
                        self.assertLessEqual(median(heights), high)
                    self.assertGreater(len(set(poses)), 3, (identity, row))

    def test_captain_hand_is_recovered_without_foreign_hand_in_previous_cell(self):
        with Image.open(SOURCE / "crossroads_captain_core.png") as sheet:
            fallen = art.source_cell(sheet, "crossroads_captain", "core", 3, 5)
            previous = art.source_cell(sheet, "crossroads_captain", "core", 3, 4)
            self.assertEqual(fallen.size, (260, 256))
            self.assertIsNotNone(fallen.crop((0, 0, 4, 256)).getbbox())
            self.assertIsNone(previous.crop((252, 0, 256, 256)).getbbox())
            # No opaque fallen hand pixels are lost versus the expanded source.
            raw_alpha = sheet.crop((1276, 768, 1536, 1024)).getchannel("A")
            expected = raw_alpha.point([0] * 128 + [255] * 128)
            self.assertEqual(expected.tobytes(), fallen.getchannel("A").tobytes())


if __name__ == "__main__":
    unittest.main()
