#!/usr/bin/env python3
"""Read-only contract checker for import-eden-character skill outputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops


class ContractError(RuntimeError):
    pass


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ContractError(f"cannot read JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise ContractError(f"JSON root must be an object: {path}")
    return value


def digest(path: Path) -> str:
    value = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                value.update(chunk)
    except OSError as error:
        raise ContractError(f"cannot hash {path}: {error}") from error
    return f"sha256:{value.hexdigest()}"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def require_list(value: Any, message: str) -> list[Any]:
    if not isinstance(value, list):
        raise ContractError(message)
    return value


def require_dict(value: Any, message: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ContractError(message)
    return value


def project_path(root: Path, value: str) -> Path:
    path = Path(value)
    require(not path.is_absolute() and ".." not in path.parts, f"unsafe output path: {value}")
    return root / path


def load_importer(root: Path):
    sys.path.insert(0, str(root))
    try:
        from tools import import_eden_character as importer
    except ImportError as error:
        raise ContractError(f"cannot import project importer: {error}") from error
    return importer


def package_records(package: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    package_document = read_json(package / "package.json")
    rows = require_list(
        package_document.get("behaviors"), "package behaviors must be an array"
    )
    records: list[dict[str, Any]] = []
    seen: set[str] = set()
    units: list[str] = []
    for row in rows:
        require(isinstance(row, dict), "package behavior row must be an object")
        behavior_id = str(row.get("behavior_id", ""))
        require(bool(behavior_id) and behavior_id not in seen, f"invalid behavior id: {behavior_id!r}")
        seen.add(behavior_id)
        manifest_path = package / str(row.get("manifest", ""))
        require(manifest_path.is_file(), f"missing package manifest: {manifest_path}")
        require(digest(manifest_path) == row.get("manifest_sha256"), f"package manifest hash mismatch: {behavior_id}")
        manifest = read_json(manifest_path)
        require(manifest.get("behavior", {}).get("behavior_id") == behavior_id, f"behavior identity mismatch: {behavior_id}")
        directions = require_list(
            manifest.get("directions"), f"directions must be an array: {behavior_id}"
        )
        direction_ids: list[str] = []
        frames: list[dict[str, Any]] = []
        for direction in directions:
            direction_id = str(direction.get("direction_id", ""))
            require(bool(direction_id) and direction_id not in direction_ids, f"invalid direction: {behavior_id}/{direction_id}")
            direction_ids.append(direction_id)
            units.append(f"{behavior_id}__{direction_id}")
            direction_frames = direction.get("frames")
            require(isinstance(direction_frames, list), f"frames must be an array: {behavior_id}/{direction_id}")
            indices = [int(frame.get("index", -1)) for frame in direction_frames]
            require(indices == list(range(len(indices))), f"non-contiguous frames: {behavior_id}/{direction_id}")
            for frame in direction_frames:
                source = manifest_path.parent / str(frame.get("file", ""))
                require(source.is_file(), f"missing source frame: {source}")
                require(digest(source) == frame.get("sha256"), f"source frame hash mismatch: {source}")
                frames.append({"direction_id": direction_id, "index": int(frame["index"]), "source": source})
        expected_directions = manifest.get("behavior", {}).get("direction_order", [])
        require(expected_directions == direction_ids, f"direction order mismatch: {behavior_id}")
        records.append({
            "behavior_id": behavior_id,
            "manifest_path": manifest_path,
            "manifest": manifest,
            "directions": direction_ids,
            "frames": frames,
        })
    expected_order = package_document.get("behavior_order", [])
    if expected_order:
        require(expected_order == [record["behavior_id"] for record in records], "package behavior order mismatch")
    coverage = package_document.get("coverage", {})
    require(coverage.get("complete") is True, "package coverage is incomplete")
    if coverage.get("exported_unit_keys"):
        require(coverage["exported_unit_keys"] == units, "package exported direction-unit accounting mismatch")
    return package_document, records


def required_category_arrays(report: dict[str, Any]) -> None:
    for key in ("missing", "unequipped", "unresolved", "equipped_actions", "equipped_moves"):
        require(isinstance(report.get(key), list), f"report {key} must be an array")


def check_common_outputs(root: Path, character_id: str, report: dict[str, Any]) -> None:
    outputs = require_dict(
        report.get("outputs"), "report outputs must be an object"
    )
    expected = {
        "template": f"data/v0_6/templates/{character_id}.json",
        "sprite_set": f"data/v0_6/sprite_sets/{character_id}.json",
        "frames": f"godot/assets/frames/{character_id}",
        "provenance": f"data/imports/{character_id}",
    }
    for key, value in expected.items():
        require(outputs.get(key) == value, f"unexpected {key} output: {outputs.get(key)!r}")
        require(project_path(root, value).exists(), f"missing {key} output: {value}")
    template = read_json(project_path(root, outputs["template"]))
    sprite_set = read_json(project_path(root, outputs["sprite_set"]))
    require(template.get("template_id") == character_id, "template identity mismatch")
    require(template.get("sprite_set_ref") == character_id, "template sprite-set identity mismatch")
    require(sprite_set.get("sprite_set_id") == character_id, "sprite-set identity mismatch")
    moves = require_list(
        template.get("equipped_moves"), "template equipped moves must be an array"
    )
    require(moves == report.get("equipped_moves"), "template/report equipped moves mismatch")
    mapping = sprite_set.get("required_moves_mapping", {})
    for move_id in moves:
        require(str(move_id).startswith(f"{character_id}_"), f"move is not character scoped: {move_id}")
        move_path = root / "data/v0_6/moves" / f"{move_id}.json"
        require(move_path.is_file(), f"missing equipped move: {move_path}")
        require(read_json(move_path).get("move_id") == move_id, f"move identity mismatch: {move_id}")
        require(move_id in mapping, f"missing sprite-set mapping: {move_id}")
    spriteframes = root / "godot/resources/sprite_frames" / f"{character_id}.tres"
    require(spriteframes.is_file(), f"missing generated SpriteFrames: {spriteframes}")


def validate_import(root: Path, package: Path, character_id: str, importer: Any) -> dict[str, Any]:
    report_path = root / "data/imports" / character_id / "import_report.json"
    report = read_json(report_path)
    require(report.get("status") == "complete", "import status is not complete")
    require(report.get("character_id") == character_id, "import report identity mismatch")
    require(report.get("outputs", {}).get("report") == report_path.relative_to(root).as_posix(), "import report output path mismatch")
    required_category_arrays(report)
    require(isinstance(report.get("imported"), list), "report imported must be an array")
    require(isinstance(report.get("composed"), list), "report composed must be an array")
    require(isinstance(report.get("defaulted"), list), "report defaulted must be an array")

    package_document, records = package_records(package)
    source = report.get("source", {})
    require(source.get("package_manifest_sha256") == digest(package / "package.json"), "source package hash mismatch")
    require(source.get("manifest_type") == str(package_document.get("manifest_type", "eden_package")), "source manifest type mismatch")
    require(source.get("manifest_version") == package_document.get("manifest_version"), "source manifest version mismatch")
    copied_package = root / "data/imports" / character_id / "eden_package.json"
    require(digest(copied_package) == digest(package / "package.json"), "copied package provenance mismatch")

    accounting = {
        "behavior_count": len(records),
        "direction_unit_count": sum(len(record["directions"]) for record in records),
        "frame_count": sum(len(record["frames"]) for record in records),
    }
    require(report.get("source_accounting") == accounting, "source accounting mismatch")
    imported = report["imported"]
    require(len(imported) == len(records), "imported behavior count mismatch")
    for row, record in zip(imported, records):
        behavior_id = record["behavior_id"]
        expected_manifest = f"data/imports/{character_id}/behaviors/{behavior_id}.json"
        require(row == {
            "eden_behavior_id": behavior_id,
            "direction_units": len(record["directions"]),
            "frames": len(record["frames"]),
            "manifest": expected_manifest,
            "manifest_sha256": digest(record["manifest_path"]),
        }, f"imported accounting row mismatch: {behavior_id}")
        copied_manifest = root / expected_manifest
        require(digest(copied_manifest) == digest(record["manifest_path"]), f"behavior provenance mismatch: {behavior_id}")
        segment = record["manifest_path"].parent / "segment.png"
        if segment.is_file():
            preview = root / "data/imports" / character_id / "previews" / f"{behavior_id}.png"
            require(digest(preview) == digest(segment), f"preview provenance mismatch: {behavior_id}")
        for frame in record["frames"]:
            target = root / "godot/assets/frames" / character_id / behavior_id / frame["direction_id"] / f'{frame["index"]:03d}.png'
            require(digest(target) == digest(frame["source"]), f"imported frame mismatch: {target.relative_to(root)}")
    frame_files = list((root / "godot/assets/frames" / character_id).rglob("*.png"))
    require(len(frame_files) == accounting["frame_count"], "imported output frame count mismatch")

    available = {record["behavior_id"] for record in records}
    missing_behaviors = [item for item in importer.CANONICAL_BEHAVIORS if item not in available]
    missing_actions = [
        action for action, behaviors in importer.ACTION_COMPOSITIONS.items()
        if any(behavior not in available for behavior in behaviors)
    ]
    equipped_actions = [
        action for action in importer.DEFAULT_EQUIPPED_ACTIONS if action not in missing_actions
    ]
    unequipped = [
        action for action in importer.ACTION_COMPOSITIONS if action not in equipped_actions
    ]
    composed = [
        {"action_id": action, "eden_behavior_ids": list(behaviors)}
        for action, behaviors in importer.ACTION_COMPOSITIONS.items()
        if action not in missing_actions
    ]
    require(report["missing"] == [item.removeprefix("bhv_") for item in missing_behaviors], "missing accounting mismatch")
    require(report["unequipped"] == unequipped, "unequipped accounting mismatch")
    require(report["equipped_actions"] == equipped_actions, "equipped action accounting mismatch")
    require(report["composed"] == composed, "composition accounting mismatch")
    require(report["unresolved"] == [], "import contains unresolved items")
    expected_defaults = [
        "hp=100", "walk_speed=95", "run_speed=150", "combat_move_damage",
        "combat_move_hitboxes", "combat_move_timing", "hurtboxes", "foot_collision",
    ]
    require(report["defaulted"] == expected_defaults, "default accounting mismatch")
    check_common_outputs(root, character_id, report)
    return {"kind": "import", "report": report_path.relative_to(root).as_posix(), **accounting}


def validate_recolor(root: Path, package: Path, character_id: str, source_id: str) -> dict[str, Any]:
    report_path = root / "data/imports" / character_id / "recolor_report.json"
    report = read_json(report_path)
    require(report.get("status") == "complete", "recolor status is not complete")
    require(report.get("character_id") == character_id, "recolor report identity mismatch")
    require(report.get("source_character_id") == source_id, "recolor source identity mismatch")
    require(character_id != source_id, "recolor target is not independent")
    require(report.get("outputs", {}).get("report") == report_path.relative_to(root).as_posix(), "recolor report output path mismatch")
    required_category_arrays(report)

    source_report_path = root / "data/imports" / source_id / "import_report.json"
    source_report = read_json(source_report_path)
    require(report.get("source_import_report_sha256") == digest(source_report_path), "source import report provenance mismatch")
    require(report.get("source_accounting") == source_report.get("source_accounting"), "recolor source accounting mismatch")
    for key in ("missing", "unequipped", "equipped_actions"):
        require(report.get(key) == source_report.get(key), f"recolor {key} accounting mismatch")
    require(report.get("unresolved") == [], "recolor contains unresolved items")

    palette_path = root / "data/imports" / character_id / "palette_mapping.json"
    palette = read_json(palette_path)
    require(palette.get("mapping_id") == report.get("mapping_id"), "palette mapping identity mismatch")
    require(palette.get("source_character_id") == source_id, "palette source identity mismatch")
    require(palette.get("target_character_id") == character_id, "palette target identity mismatch")
    entries = require_list(palette.get("entries"), "palette entries must be an array")
    require(bool(entries), "palette entries are empty")
    require(len(entries) == report.get("mapping_entry_count"), "palette entry accounting mismatch")
    mapping: dict[tuple[int, int, int, int], tuple[int, int, int, int]] = {}
    for entry in entries:
        source_values = require_list(entry.get("from_rgba"), "palette source must be an array")
        target_values = require_list(entry.get("to_rgba"), "palette target must be an array")
        require(len(source_values) == len(target_values) == 4, "palette entry is not exact RGBA")
        source = (
            int(source_values[0]), int(source_values[1]),
            int(source_values[2]), int(source_values[3]),
        )
        target = (
            int(target_values[0]), int(target_values[1]),
            int(target_values[2]), int(target_values[3]),
        )
        require(source[3] == target[3] and source != target, "palette entry changes alpha or is a no-op")
        require(source not in mapping, "palette contains duplicate source color")
        mapping[source] = target

    source_frames = root / "godot/assets/frames" / source_id
    target_frames = root / "godot/assets/frames" / character_id
    source_paths = sorted(source_frames.rglob("*.png"))
    target_paths = sorted(target_frames.rglob("*.png"))
    require(len(source_paths) == len(target_paths) == report.get("frame_count"), "recolor frame accounting mismatch")
    changed = 0
    used_sources: set[tuple[int, int, int, int]] = set()
    for source_path in source_paths:
        target_path = target_frames / source_path.relative_to(source_frames)
        require(target_path.is_file(), f"missing recolor frame: {target_path.relative_to(root)}")
        source_image = Image.open(source_path).convert("RGBA")
        target_image = Image.open(target_path).convert("RGBA")
        require(source_image.size == target_image.size, f"recolor dimensions mismatch: {target_path.relative_to(root)}")
        # ImageChops finds the changed region in C. Pixel-level mapping checks then
        # inspect only that usually-small sprite region, not every transparent pixel.
        difference = ImageChops.difference(
            source_image.convert("RGB"), target_image.convert("RGB")
        )
        changed_box = difference.getbbox()
        if changed_box is None:
            continue
        source_pixels = source_image.crop(changed_box).getdata()
        target_pixels = target_image.crop(changed_box).getdata()
        for source_pixel, target_pixel in zip(source_pixels, target_pixels):
            expected = mapping.get(source_pixel, source_pixel)
            require(target_pixel == expected, f"unexpected recolor pixel: {target_path.relative_to(root)}")
            if target_pixel != source_pixel:
                changed += 1
                used_sources.add(source_pixel)
    require(used_sources == set(mapping), "palette usage accounting mismatch")
    require(changed == report.get("recolored_pixel_count") and changed > 0, "recolored pixel accounting mismatch")

    source_provenance = root / "data/imports" / source_id
    target_provenance = root / "data/imports" / character_id
    for source_path in sorted((source_provenance / "behaviors").glob("*.json")):
        target_path = target_provenance / "behaviors" / source_path.name
        require(digest(target_path) == digest(source_path), f"recolor behavior provenance mismatch: {source_path.name}")
    copied_source_report = target_provenance / "source_import_report.json"
    require(digest(copied_source_report) == digest(source_report_path), "copied source report provenance mismatch")
    package_document, records = package_records(package)
    require(source_report.get("source", {}).get("package_manifest_sha256") == digest(package / "package.json"), "recolor source package mismatch")
    require(len(records) == report["source_accounting"]["behavior_count"], "recolor package behavior accounting mismatch")
    require(package_document.get("coverage", {}).get("complete") is True, "recolor package coverage incomplete")
    check_common_outputs(root, character_id, report)
    return {
        "kind": "recolor",
        "report": report_path.relative_to(root).as_posix(),
        "source_character_id": source_id,
        "frame_count": len(target_paths),
        "mapping_entry_count": len(mapping),
        "recolored_pixel_count": changed,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--source-character-id")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.project_root.expanduser().resolve()
    package = args.package.expanduser().resolve()
    try:
        require((root / "tools/import_eden_character.py").is_file(), f"not a SpritesPlayground root: {root}")
        require((package / "package.json").is_file(), f"not an Eden package: {package}")
        importer = load_importer(root)
        if args.source_character_id:
            summary = validate_recolor(root, package, args.character_id, args.source_character_id)
        else:
            summary = validate_import(root, package, args.character_id, importer)
    except ContractError as error:
        print(f"import_eden_character_skill_check=FAIL: {error}", file=sys.stderr)
        return 1
    print("import_eden_character_skill_check=PASS")
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
