#!/usr/bin/env python3
"""Offline curation of the fixed batch-2 Homeward sheets; never calls a provider.

Rows: walk, punch, kick, hurt/fall, run, dash, source idle, fall/get-up.
The runtime deliberately holds punch[0] as guard, not the stepping source idle.
All placement uses the source cell's x=128 stance anchor (not each pose bbox).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import median

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "godot/assets/homeward"
IDENTITIES = ("red_jacket_brawler", "track_sprinter", "violet_kicker", "iron_leg", "crossroads_captain")
CELL = 80
BASELINE = 68


def source_cell(sheet: Image.Image, identity: str, section: str, row: int, col: int) -> Image.Image:
    """Hard alpha, transparent RGB zero, and one explicitly bounded hand repair."""
    left = col * 256
    if identity == "crossroads_captain" and section == "core" and row == 3 and col == 5:
        left -= 4  # Include the original fallen hand crossing the left grid boundary.
    cell = sheet.crop((left, row * 256, (col + 1) * 256, (row + 1) * 256)).convert("RGBA")
    alpha = cell.getchannel("A").point([0] * 128 + [255] * 128)
    if identity == "crossroads_captain" and section == "core" and row == 3 and col == 4:
        # Only foreign hand pixels live in this four-pixel edge; own body ends far earlier.
        ImageDraw.Draw(alpha).rectangle((252, 0, 255, 255), fill=0)
    cell.putalpha(alpha)
    clean = Image.new("RGBA", cell.size)
    clean.paste(cell, mask=alpha)
    return clean


def prepare(identity: str, source: Path) -> tuple[Image.Image, dict]:
    cells = []
    for section in ("core", "extended"):
        with Image.open(source / f"{identity}_{section}.png") as sheet:
            if sheet.size != (1536, 1024):
                raise ValueError(f"Unexpected sheet dimensions: {identity}/{section}")
            cells.extend(source_cell(sheet, identity, section, r, c) for r in range(4) for c in range(6))
    boxes = [cell.getbbox() for cell in cells]
    if any(box is None for box in boxes):
        raise ValueError(f"Empty source pose: {identity}")
    standing_height = median(box[3] - box[1] for box in boxes[:6])
    standing_foot = median(box[3] for box in boxes[:6])
    target_height = 59 if identity in IDENTITIES[3:] else 53
    scale = target_height / standing_height
    # Keep a two-pixel guard around even extended limbs, without per-pose rescaling.
    for index, box in enumerate(boxes):
        origin = 132 if identity == "crossroads_captain" and index == 23 else 128
        scale = min(scale, 38 / max(origin - box[0], box[2] - origin))
        scale = min(scale, 65 / (box[3] - box[1]))
    atlas = Image.new("RGBA", (480, 640))
    for index, (cell, box) in enumerate(zip(cells, boxes, strict=True)):
        origin = 132 if identity == "crossroads_captain" and index == 23 else 128
        # Align each grounded pose's lowest pixel to the shared floor. Running/dash
        # retain source lift relative to median standing foot, preserving authored motion.
        row = index // 6
        foot = standing_foot if row in (4, 5) else box[3]
        crop = cell.crop(box)
        width = max(1, round(crop.width * scale))
        height = max(1, round(crop.height * scale))
        pose = crop.resize((width, height), Image.Resampling.NEAREST)
        x = round(40 + (box[0] - origin) * scale)
        y = round(BASELINE + (box[1] - foot) * scale)
        if x < 1 or y < 1 or x + width > 79 or y + height > 79:
            raise ValueError(f"Pose would clip: {identity}/{index}: {(x, y, width, height)}")
        atlas.paste(pose, (index % 6 * CELL + x, row * CELL + y))
    return atlas, {"identity": identity, "scale": scale, "source_standing_foot": standing_foot,
                   "source_standing_height": standing_height, "guard_source": "core row 1 col 0"}


def build(source: Path, output: Path, evidence: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    metadata = {"cell_size": 80, "baseline": BASELINE, "alpha_threshold": 128,
                "resample": "NEAREST", "rows": ["walk", "punch", "kick", "hurt3_fall3", "run", "dash", "source_idle_not_runtime", "fall3_getup3"],
                "characters": []}
    for identity in IDENTITIES:
        atlas, info = prepare(identity, source)
        atlas.save(output / f"{identity}.png")
        metadata["characters"].append(info)
        contact = Image.new("RGB", (480, 8 * 96), "#b9bdc7")
        draw = ImageDraw.Draw(contact)
        for row, name in enumerate(metadata["rows"]):
            draw.text((2, row * 96), name, fill="#20202b")
            strip = atlas.crop((0, row * 80, 480, (row + 1) * 80))
            contact.paste(strip, (0, row * 96 + 16), strip)
        contact.save(evidence / f"{identity}_frames.png")
    (output / "curation.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ART / "source_art/batch2")
    parser.add_argument("--output", type=Path, default=ART / "enemies")
    parser.add_argument("--evidence", type=Path, default=ROOT / "docs/06_testing/evidence/homeward-enemies")
    args = parser.parse_args()
    build(args.source, args.output, args.evidence)


if __name__ == "__main__":
    main()
