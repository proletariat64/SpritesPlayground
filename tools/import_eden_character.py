#!/usr/bin/env python3
"""Deterministically import an Eden package as a SpritesPlayground character.

The importer is intentionally file based: Pi supplies an Eden package directory and a
character name, and the resulting v0.3 template, sprite set, move defaults, copied
frames, provenance manifests, and audit report become the single saved character
result consumed by Creator Lab and Playground.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from PIL import Image


CANONICAL_BEHAVIORS = (
    "bhv_idle_breath",
    "bhv_walk_start",
    "bhv_walk_loop",
    "bhv_walk_stop",
    "bhv_walk_turn",
    "bhv_run_start",
    "bhv_run_loop",
    "bhv_run_stop",
    "bhv_run_turn",
    "bhv_dash",
    "bhv_jump_start",
    "bhv_jump_air",
    "bhv_land",
    "bhv_big_jump_start",
    "bhv_big_jump_air",
    "bhv_big_jump_land",
    "bhv_fall_down",
    "bhv_down",
    "bhv_get_up",
    "bhv_fight_idle",
    "bhv_jab",
    "bhv_cross_punch",
    "bhv_uppercut",
    "bhv_high_kick",
    "bhv_roundhouse_kick",
    "bhv_flying_kick",
    "bhv_sweep",
    "bhv_hurt",
    "bhv_pickup",
    "bhv_throw_object",
    "bhv_push",
    "bhv_pull",
)

ACTION_COMPOSITIONS: dict[str, tuple[str, ...]] = {
    "idle": ("bhv_idle_breath",),
    "walk": ("bhv_walk_start", "bhv_walk_loop", "bhv_walk_stop", "bhv_walk_turn"),
    "run": ("bhv_run_start", "bhv_run_loop", "bhv_run_stop", "bhv_run_turn"),
    "dash": ("bhv_dash",),
    "jump": ("bhv_jump_start", "bhv_jump_air", "bhv_land"),
    "big_jump": ("bhv_big_jump_start", "bhv_big_jump_air", "bhv_big_jump_land"),
    "knockdown": ("bhv_fall_down", "bhv_down", "bhv_get_up"),
    "fight_idle": ("bhv_fight_idle",),
    "jab": ("bhv_jab",),
    "cross_punch": ("bhv_cross_punch",),
    "uppercut": ("bhv_uppercut",),
    "high_kick": ("bhv_high_kick",),
    "roundhouse_kick": ("bhv_roundhouse_kick",),
    "flying_kick": ("bhv_flying_kick",),
    "sweep": ("bhv_sweep",),
    "hurt": ("bhv_hurt",),
    "dead": ("bhv_fall_down", "bhv_down"),
    "pickup": ("bhv_pickup",),
    "throw_object": ("bhv_throw_object",),
    "push": ("bhv_push",),
    "pull": ("bhv_pull",),
}

# Interaction systems remain outside #31. Uppercut stays canonical but Miduo has no art.
DEFAULT_EQUIPPED_ACTIONS = (
    "idle",
    "walk",
    "run",
    "dash",
    "jump",
    "big_jump",
    "knockdown",
    "fight_idle",
    "jab",
    "cross_punch",
    "high_kick",
    "roundhouse_kick",
    "flying_kick",
    "sweep",
    "hurt",
    "dead",
)

LOOP_ACTIONS = {"idle", "fight_idle"}
COMBAT_ACTIONS = {
    "jab",
    "cross_punch",
    "uppercut",
    "high_kick",
    "roundhouse_kick",
    "flying_kick",
    "sweep",
}
REACTION_ACTIONS = {"hurt", "knockdown", "dead"}
LOCOMOTION_ACTIONS = {"walk", "run", "dash", "jump", "big_jump"}
DAMAGE_DEFAULTS = {
    "jab": 6,
    "cross_punch": 10,
    "uppercut": 14,
    "high_kick": 10,
    "roundhouse_kick": 14,
    "flying_kick": 12,
    "sweep": 9,
}


class ImportFailure(RuntimeError):
    """Raised when package input cannot be imported without silent loss."""


@dataclass(frozen=True)
class FrameRecord:
    behavior_id: str
    direction_id: str
    index: int
    source_path: Path
    source_relative_path: str
    expected_sha256: str


@dataclass(frozen=True)
class BehaviorRecord:
    behavior_id: str
    manifest_path: Path
    manifest: dict[str, Any]
    directions: tuple[str, ...]
    frames: tuple[FrameRecord, ...]


def import_character(
    package_root: Path | str,
    target_name: str,
    project_root: Path | str,
    *,
    verify_hashes: bool = True,
) -> dict[str, Any]:
    """Import one Eden package and return its deterministic audit report."""

    package_root = Path(package_root).expanduser().resolve()
    project_root = Path(project_root).expanduser().resolve()
    character_id = _snake_id(target_name)
    package_manifest_path = package_root / "package.json"
    if not package_manifest_path.is_file():
        raise ImportFailure(f"missing Eden package manifest: {package_manifest_path}")

    package_manifest = _read_json(package_manifest_path)
    records = _load_behavior_records(package_root, package_manifest, verify_hashes)
    _validate_package_accounting(package_manifest, records)

    available_ids = {record.behavior_id for record in records}
    missing_behaviors = [
        behavior_id for behavior_id in CANONICAL_BEHAVIORS if behavior_id not in available_ids
    ]
    missing_actions = [
        action_id
        for action_id, behavior_ids in ACTION_COMPOSITIONS.items()
        if any(behavior_id not in available_ids for behavior_id in behavior_ids)
    ]
    equipped_actions = [
        action_id
        for action_id in DEFAULT_EQUIPPED_ACTIONS
        if action_id not in missing_actions
    ]
    unequipped_actions = [
        action_id
        for action_id in ACTION_COMPOSITIONS
        if action_id not in equipped_actions
    ]

    imported_root = project_root / "godot/assets/frames" / character_id
    provenance_root = project_root / "data/imports" / character_id
    template_path = project_root / "data/v0_3/templates" / f"{character_id}.json"
    sprite_set_path = project_root / "data/v0_3/sprite_sets" / f"{character_id}.json"
    report_path = provenance_root / "import_report.json"

    if imported_root.exists():
        shutil.rmtree(imported_root)
    if provenance_root.exists():
        shutil.rmtree(provenance_root)

    copied_paths = _copy_frames(records, imported_root, character_id)
    _copy_provenance(package_manifest_path, records, provenance_root)

    # Character-scoped move cleanup: remove stale outputs from earlier imports of
    # this character id without touching moves owned by other characters.
    moves_dir = project_root / "data/v0_3/moves"
    if moves_dir.is_dir():
        for stale in moves_dir.glob(f"{character_id}_*.json"):
            stale.unlink()

    sprite_set, clip_frame_counts = _build_sprite_set(
        character_id,
        records,
        copied_paths,
        equipped_actions,
    )
    # Move ids are character-scoped so imported data can never overwrite moves
    # owned by other characters sharing data/v0_3/moves.
    move_ids = {action_id: f"{character_id}_{action_id}" for action_id in equipped_actions}
    moves = {
        move_ids[action_id]: _build_move(
            move_ids[action_id], action_id, clip_frame_counts[action_id]
        )
        for action_id in equipped_actions
    }
    equipped_move_ids = [move_ids[action_id] for action_id in equipped_actions]
    template = _build_template(character_id, equipped_move_ids)

    _write_json(template_path, template)
    _write_json(sprite_set_path, sprite_set)
    for move_id, move in moves.items():
        _write_json(project_root / "data/v0_3/moves" / f"{move_id}.json", move)

    imported_rows = []
    for record in records:
        imported_rows.append(
            {
                "eden_behavior_id": record.behavior_id,
                "direction_units": len(record.directions),
                "frames": len(record.frames),
                "manifest": f"data/imports/{character_id}/behaviors/{record.behavior_id}.json",
                "manifest_sha256": _sha256(record.manifest_path),
            }
        )

    composed_rows = []
    for action_id, behavior_ids in ACTION_COMPOSITIONS.items():
        if action_id in missing_actions:
            continue
        composed_rows.append(
            {
                "action_id": action_id,
                "eden_behavior_ids": list(behavior_ids),
            }
        )

    report: dict[str, Any] = {
        "schema_version": 1,
        "status": "complete",
        "character_id": character_id,
        "character_name": target_name.strip(),
        "source": {
            "manifest_type": str(package_manifest.get("manifest_type", "eden_package")),
            "manifest_version": package_manifest.get("manifest_version"),
            "task_id": str(package_manifest.get("task_id", _first_task_id(records))),
            "package_manifest_sha256": _sha256(package_manifest_path),
        },
        "source_accounting": {
            "behavior_count": len(records),
            "direction_unit_count": sum(len(record.directions) for record in records),
            "frame_count": sum(len(record.frames) for record in records),
        },
        "imported": imported_rows,
        "composed": composed_rows,
        "defaulted": [
            "hp=100",
            "walk_speed=95",
            "run_speed=150",
            "combat_move_damage",
            "combat_move_hitboxes",
            "combat_move_timing",
            "hurtboxes",
            "foot_collision",
        ],
        "missing": [action.removeprefix("bhv_") for action in missing_behaviors],
        "unequipped": unequipped_actions,
        "unresolved": [],
        "equipped_moves": equipped_move_ids,
        "equipped_actions": equipped_actions,
        "outputs": {
            "template": template_path.relative_to(project_root).as_posix(),
            "sprite_set": sprite_set_path.relative_to(project_root).as_posix(),
            "report": report_path.relative_to(project_root).as_posix(),
            "frames": imported_root.relative_to(project_root).as_posix(),
            "provenance": provenance_root.relative_to(project_root).as_posix(),
        },
    }
    _write_json(report_path, report)
    return report


def recolor_character(
    project_root: Path | str,
    source_character_id: str,
    target_name: str,
    palette_mapping: dict[tuple[int, int, int, int], tuple[int, int, int, int]],
    *,
    mapping_id: str,
) -> dict[str, Any]:
    """Create an independent character using an explicit exact RGBA mapping.

    The caller owns clothing semantics: this API never guesses colors or broadens the
    supplied mapping. Alpha must remain unchanged for every replacement.
    """

    project_root = Path(project_root).expanduser().resolve()
    source_id = _snake_id(source_character_id)
    character_id = _snake_id(target_name)
    if character_id == source_id:
        raise ImportFailure("recolor target id must differ from source character id")
    normalized_mapping = _validate_palette_mapping(palette_mapping)
    if not mapping_id.strip():
        raise ImportFailure("palette mapping requires a stable mapping_id")

    source_frames = project_root / "godot/assets/frames" / source_id
    source_template_path = project_root / "data/v0_3/templates" / f"{source_id}.json"
    source_sprite_set_path = project_root / "data/v0_3/sprite_sets" / f"{source_id}.json"
    source_report_path = project_root / "data/imports" / source_id / "import_report.json"
    for required in (source_frames, source_template_path, source_sprite_set_path, source_report_path):
        if not required.exists():
            raise ImportFailure(f"missing imported source character input: {required}")

    target_frames = project_root / "godot/assets/frames" / character_id
    target_template_path = project_root / "data/v0_3/templates" / f"{character_id}.json"
    target_sprite_set_path = project_root / "data/v0_3/sprite_sets" / f"{character_id}.json"
    provenance_root = project_root / "data/imports" / character_id
    report_path = provenance_root / "recolor_report.json"
    palette_path = provenance_root / "palette_mapping.json"
    if target_frames.exists():
        shutil.rmtree(target_frames)
    if provenance_root.exists():
        shutil.rmtree(provenance_root)

    source_paths = sorted(source_frames.rglob("*.png"))
    if not source_paths:
        raise ImportFailure(f"source character has no frames: {source_id}")
    recolored_pixels = 0
    used_sources: set[tuple[int, int, int, int]] = set()
    for source_path in source_paths:
        target_path = target_frames / source_path.relative_to(source_frames)
        target_path.parent.mkdir(parents=True, exist_ok=True)
        image = Image.open(source_path).convert("RGBA")
        output = []
        for pixel in image.getdata():
            replacement = normalized_mapping.get(pixel)
            if replacement is None:
                output.append(pixel)
            else:
                output.append(replacement)
                used_sources.add(pixel)
                recolored_pixels += 1
        image.putdata(output)
        image.save(target_path, format="PNG", optimize=False, compress_level=9)
    unused_sources = sorted(set(normalized_mapping) - used_sources)
    if unused_sources:
        raise ImportFailure(
            f"palette mapping contains {len(unused_sources)} unused source colors"
        )
    if recolored_pixels == 0:
        raise ImportFailure("palette mapping did not recolor any pixels")

    source_template = _read_json(source_template_path)
    source_sprite_set = _read_json(source_sprite_set_path)
    source_report = _read_json(source_report_path)
    source_moves = [str(move_id) for move_id in source_template.get("equipped_moves", [])]
    target_moves = [
        _scoped_variant_move_id(move_id, source_id, character_id)
        for move_id in source_moves
    ]
    target_template = json.loads(json.dumps(source_template))
    target_template["template_id"] = character_id
    target_template["sprite_set_ref"] = character_id
    target_template["equipped_moves"] = target_moves

    target_sprite_set = json.loads(json.dumps(source_sprite_set))
    target_sprite_set["sprite_set_id"] = character_id
    for sequence in target_sprite_set.get("frame_sequences", {}).values():
        for index, path in enumerate(sequence):
            sequence[index] = str(path).replace(
                f"res://godot/assets/frames/{source_id}/",
                f"res://godot/assets/frames/{character_id}/",
            )
    source_mapping = target_sprite_set.get("required_moves_mapping", {})
    target_sprite_set["required_moves_mapping"] = {
        _scoped_variant_move_id(str(move_id), source_id, character_id): clip_id
        for move_id, clip_id in source_mapping.items()
    }

    moves_dir = project_root / "data/v0_3/moves"
    for stale in moves_dir.glob(f"{character_id}_*.json"):
        stale.unlink()
    for source_move_id, target_move_id in zip(source_moves, target_moves):
        source_move_path = moves_dir / f"{source_move_id}.json"
        source_move = _read_json(source_move_path)
        target_move = json.loads(json.dumps(source_move))
        target_move["move_id"] = target_move_id
        _write_json(moves_dir / f"{target_move_id}.json", target_move)

    _write_json(target_template_path, target_template)
    _write_json(target_sprite_set_path, target_sprite_set)
    _copy_variant_provenance(
        project_root / "data/imports" / source_id,
        provenance_root,
        source_report_path,
    )
    palette_document = {
        "schema_version": 1,
        "mapping_id": mapping_id.strip(),
        "source_character_id": source_id,
        "target_character_id": character_id,
        "entries": [
            {"from_rgba": list(source), "to_rgba": list(normalized_mapping[source])}
            for source in sorted(normalized_mapping)
        ],
    }
    _write_json(palette_path, palette_document)

    report = {
        "schema_version": 1,
        "status": "complete",
        "source_character_id": source_id,
        "character_id": character_id,
        "character_name": target_name.strip(),
        "mapping_id": mapping_id.strip(),
        "mapping_entry_count": len(normalized_mapping),
        "recolored_pixel_count": recolored_pixels,
        "frame_count": len(source_paths),
        "source_accounting": source_report.get("source_accounting", {}),
        "equipped_actions": source_report.get("equipped_actions", []),
        "equipped_moves": target_moves,
        "missing": source_report.get("missing", []),
        "unequipped": source_report.get("unequipped", []),
        "unresolved": [],
        "source_import_report_sha256": _sha256(source_report_path),
        "outputs": {
            "template": target_template_path.relative_to(project_root).as_posix(),
            "sprite_set": target_sprite_set_path.relative_to(project_root).as_posix(),
            "report": report_path.relative_to(project_root).as_posix(),
            "palette_mapping": palette_path.relative_to(project_root).as_posix(),
            "frames": target_frames.relative_to(project_root).as_posix(),
            "provenance": provenance_root.relative_to(project_root).as_posix(),
        },
    }
    _write_json(report_path, report)
    return report


def _validate_palette_mapping(
    palette_mapping: dict[tuple[int, int, int, int], tuple[int, int, int, int]],
) -> dict[tuple[int, int, int, int], tuple[int, int, int, int]]:
    if not palette_mapping:
        raise ImportFailure("recolor requires an explicit non-empty palette mapping")
    result = {}
    for source, target in palette_mapping.items():
        if len(source) != 4 or len(target) != 4:
            raise ImportFailure("palette entries must contain exact RGBA tuples")
        normalized_source = tuple(int(channel) for channel in source)
        normalized_target = tuple(int(channel) for channel in target)
        if any(channel < 0 or channel > 255 for channel in normalized_source + normalized_target):
            raise ImportFailure("palette RGBA channels must be within 0..255")
        if normalized_source[3] != normalized_target[3]:
            raise ImportFailure("palette mapping cannot change alpha")
        if normalized_source == normalized_target:
            raise ImportFailure("palette mapping entries must change RGB")
        result[normalized_source] = normalized_target
    return result


def _scoped_variant_move_id(move_id: str, source_id: str, target_id: str) -> str:
    prefix = f"{source_id}_"
    if not move_id.startswith(prefix):
        raise ImportFailure(f"source move is not character scoped: {move_id}")
    return f"{target_id}_{move_id.removeprefix(prefix)}"


def _copy_variant_provenance(
    source_root: Path,
    target_root: Path,
    source_report_path: Path,
) -> None:
    target_root.mkdir(parents=True, exist_ok=True)
    # Variant provenance keeps immutable Eden manifests and references the source
    # import report. Identical preview PNG copies would create duplicate Godot UIDs.
    for name in ("eden_package.json", "behaviors"):
        source = source_root / name
        target = target_root / name
        if source.is_dir():
            shutil.copytree(
                source,
                target,
                ignore=shutil.ignore_patterns("*.import", "*.uid"),
            )
        elif source.is_file():
            shutil.copyfile(source, target)
    shutil.copyfile(source_report_path, target_root / "source_import_report.json")


def _load_behavior_records(
    package_root: Path,
    package_manifest: dict[str, Any],
    verify_hashes: bool,
) -> list[BehaviorRecord]:
    rows = package_manifest.get("behaviors")
    if not isinstance(rows, list):
        raise ImportFailure("package.json behaviors must be an array")

    records: list[BehaviorRecord] = []
    seen: set[str] = set()
    for row in rows:
        behavior_id = str(row.get("behavior_id", ""))
        manifest_relative = str(row.get("manifest", ""))
        if not behavior_id or behavior_id in seen:
            raise ImportFailure(f"invalid or duplicate behavior id: {behavior_id!r}")
        seen.add(behavior_id)
        manifest_path = package_root / manifest_relative
        if not manifest_path.is_file():
            raise ImportFailure(f"missing behavior manifest: {manifest_relative}")
        if verify_hashes:
            _verify_sha256(manifest_path, str(row.get("manifest_sha256", "")))
        manifest = _read_json(manifest_path)
        declared_id = str(manifest.get("behavior", {}).get("behavior_id", ""))
        if declared_id != behavior_id:
            raise ImportFailure(
                f"behavior id mismatch: package={behavior_id} manifest={declared_id}"
            )
        if not bool(manifest.get("coverage", {}).get("complete", False)):
            raise ImportFailure(f"behavior coverage is incomplete: {behavior_id}")

        directions: list[str] = []
        frames: list[FrameRecord] = []
        for direction in manifest.get("directions", []):
            direction_id = str(direction.get("direction_id", ""))
            if not direction_id or direction_id in directions:
                raise ImportFailure(
                    f"invalid or duplicate direction for {behavior_id}: {direction_id!r}"
                )
            directions.append(direction_id)
            for frame in direction.get("frames", []):
                frame_relative = str(frame.get("file", ""))
                frame_path = manifest_path.parent / frame_relative
                if not frame_path.is_file():
                    raise ImportFailure(
                        f"missing frame: {behavior_id}/{direction_id}/{frame_relative}"
                    )
                expected_sha256 = str(frame.get("sha256", ""))
                if verify_hashes:
                    _verify_sha256(frame_path, expected_sha256)
                frames.append(
                    FrameRecord(
                        behavior_id=behavior_id,
                        direction_id=direction_id,
                        index=int(frame.get("index", -1)),
                        source_path=frame_path,
                        source_relative_path=frame_relative,
                        expected_sha256=expected_sha256,
                    )
                )
        records.append(
            BehaviorRecord(
                behavior_id=behavior_id,
                manifest_path=manifest_path,
                manifest=manifest,
                directions=tuple(directions),
                frames=tuple(frames),
            )
        )
    return records


def _validate_package_accounting(
    package_manifest: dict[str, Any], records: list[BehaviorRecord]
) -> None:
    expected_order = [str(item) for item in package_manifest.get("behavior_order", [])]
    actual_order = [record.behavior_id for record in records]
    if expected_order and expected_order != actual_order:
        raise ImportFailure("package behavior order does not match behavior manifests")

    coverage = package_manifest.get("coverage", {})
    if not bool(coverage.get("complete", False)):
        raise ImportFailure("package coverage is incomplete")
    expected_units = [str(item) for item in coverage.get("exported_unit_keys", [])]
    actual_units = [
        f"{record.behavior_id}__{direction_id}"
        for record in records
        for direction_id in record.directions
    ]
    if expected_units and expected_units != actual_units:
        missing = sorted(set(expected_units) - set(actual_units))
        extra = sorted(set(actual_units) - set(expected_units))
        raise ImportFailure(
            f"direction-unit accounting mismatch; missing={missing} extra={extra}"
        )

    for record in records:
        direction_order = [
            str(item) for item in record.manifest.get("behavior", {}).get("direction_order", [])
        ]
        if direction_order != list(record.directions):
            raise ImportFailure(f"direction order mismatch: {record.behavior_id}")
        for direction_id in record.directions:
            indices = sorted(
                frame.index for frame in record.frames if frame.direction_id == direction_id
            )
            if indices != list(range(len(indices))):
                raise ImportFailure(
                    f"non-contiguous frame indices: {record.behavior_id}/{direction_id}"
                )


def _copy_frames(
    records: list[BehaviorRecord], imported_root: Path, character_id: str
) -> dict[tuple[str, str], list[str]]:
    copied: dict[tuple[str, str], list[str]] = {}
    for record in records:
        for direction_id in record.directions:
            selected = sorted(
                (frame for frame in record.frames if frame.direction_id == direction_id),
                key=lambda frame: frame.index,
            )
            paths: list[str] = []
            for frame in selected:
                target = (
                    imported_root
                    / record.behavior_id
                    / direction_id
                    / f"{frame.index:03d}.png"
                )
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(frame.source_path, target)
                paths.append(
                    "res://godot/assets/frames/"
                    f"{character_id}/{record.behavior_id}/{direction_id}/{frame.index:03d}.png"
                )
            copied[(record.behavior_id, direction_id)] = paths
    return copied


def _copy_provenance(
    package_manifest_path: Path,
    records: list[BehaviorRecord],
    provenance_root: Path,
) -> None:
    provenance_root.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(package_manifest_path, provenance_root / "eden_package.json")
    behavior_root = provenance_root / "behaviors"
    behavior_root.mkdir(parents=True, exist_ok=True)
    preview_root = provenance_root / "previews"
    preview_root.mkdir(parents=True, exist_ok=True)
    for record in records:
        shutil.copyfile(record.manifest_path, behavior_root / f"{record.behavior_id}.json")
        # Segment contact sheets give reviewers visual provenance without Godot.
        segment = record.manifest_path.parent / "segment.png"
        if segment.is_file():
            shutil.copyfile(segment, preview_root / f"{record.behavior_id}.png")


def _build_sprite_set(
    character_id: str,
    records: list[BehaviorRecord],
    copied_paths: dict[tuple[str, str], list[str]],
    equipped_actions: list[str],
) -> tuple[dict[str, Any], dict[str, int]]:
    records_by_id = {record.behavior_id: record for record in records}
    clips: dict[str, Any] = {}
    sequences: dict[str, list[str]] = {}
    mapping: dict[str, str] = {}
    action_frame_counts: dict[str, int] = {}

    # Preserve every Eden behavior/direction as an addressable raw clip.
    for record in records:
        playback = str(record.manifest.get("behavior", {}).get("playback", {}).get("type", "once"))
        for direction_id in record.directions:
            clip_id = _raw_clip_id(record.behavior_id, direction_id)
            clips[clip_id] = {
                "clip_id": clip_id,
                "frame_sequence_ref": clip_id,
                "loop": playback == "loop",
            }
            sequences[clip_id] = copied_paths[(record.behavior_id, direction_id)]

    for action_id, behavior_ids in ACTION_COMPOSITIONS.items():
        if any(behavior_id not in records_by_id for behavior_id in behavior_ids):
            continue
        directions = _common_direction_order(behavior_ids, records_by_id)
        for direction_id in directions:
            sequence: list[str] = []
            for behavior_id in behavior_ids:
                sequence.extend(copied_paths[(behavior_id, direction_id)])
            suffix = direction_id.removeprefix("dir_")
            clip_id = action_id if directions == ["dir_e"] else f"{action_id}_{suffix}"
            if len(directions) == 2 and direction_id == "dir_e":
                clip_id = action_id
            sequence_id = f"{clip_id}_full" if action_id in {"walk", "run"} else clip_id
            clips[sequence_id] = {
                "clip_id": sequence_id,
                "frame_sequence_ref": sequence_id,
                "loop": action_id in LOOP_ACTIONS,
            }
            sequences[sequence_id] = sequence
            if direction_id == "dir_e":
                mapping[action_id] = sequence_id
                action_frame_counts[action_id] = len(sequence)

        # Runtime locomotion aliases intentionally use loop material. #33 adds phase switching.
        if action_id in {"walk", "run"}:
            loop_behavior = f"bhv_{action_id}_loop"
            loop_record = records_by_id[loop_behavior]
            for direction_id in loop_record.directions:
                suffix = direction_id.removeprefix("dir_")
                alias = f"{action_id}_{suffix}"
                clips[alias] = {
                    "clip_id": alias,
                    "frame_sequence_ref": alias,
                    "loop": True,
                }
                sequences[alias] = copied_paths[(loop_behavior, direction_id)]

    # required_moves_mapping is keyed by the character-scoped equipped move ids so
    # the v0.3 runtime-bundle contract holds without claiming shared move ids.
    scoped_mapping = {
        f"{character_id}_{action_id}": mapping[action_id]
        for action_id in equipped_actions
        if action_id in mapping
    }
    return (
        {
            "schema_version": "0.3",
            "sprite_set_id": character_id,
            "animation_clips": dict(sorted(clips.items())),
            "frame_sequences": dict(sorted(sequences.items())),
            "required_moves_mapping": dict(sorted(scoped_mapping.items())),
        },
        action_frame_counts,
    )


def _common_direction_order(
    behavior_ids: Iterable[str], records_by_id: dict[str, BehaviorRecord]
) -> list[str]:
    ordered = list(records_by_id[next(iter(behavior_ids))].directions)
    common = [
        direction_id
        for direction_id in ordered
        if all(direction_id in records_by_id[behavior_id].directions for behavior_id in behavior_ids)
    ]
    if "dir_e" in common:
        return common
    raise ImportFailure(f"composition has no east direction: {list(behavior_ids)}")


def _build_template(character_id: str, equipped_move_ids: list[str]) -> dict[str, Any]:
    return {
        "schema_version": "0.3",
        "template_id": character_id,
        "sprite_set_ref": character_id,
        "hurtboxes": {
            "hurt_head": {"x": -12, "y": -64, "w": 24, "h": 18},
            "hurt_upper_body": {"x": -16, "y": -46, "w": 32, "h": 24},
            "hurt_lower_body": {"x": -14, "y": -22, "w": 28, "h": 22},
        },
        "foot_collision": {
            "center": {"x": 0, "y": -4},
            "radius": {"x": 18, "y": 8},
        },
        "hp": 100,
        "walk_speed": 95.0,
        "run_speed": 150.0,
        "equipped_moves": equipped_move_ids,
    }


def _build_move(move_id: str, action_id: str, frame_count: int) -> dict[str, Any]:
    move_type = "utility"
    state_context: str | None = "idle"
    if action_id in LOCOMOTION_ACTIONS:
        move_type = "locomotion"
        state_context = "jump" if "jump" in action_id else ("dash" if action_id == "dash" else "walk")
    elif action_id in COMBAT_ACTIONS:
        move_type = "combat"
        state_context = "jump" if action_id == "flying_kick" else "idle"
    elif action_id in REACTION_ACTIONS:
        move_type = "reaction"
        state_context = "dead" if action_id == "dead" else "hurt"

    active_start = 0
    active_end = max(0, frame_count - 1)
    hitboxes: list[dict[str, Any]] = []
    events: list[dict[str, Any]] = []
    damage = DAMAGE_DEFAULTS.get(action_id, 0)
    hitstop = 0
    if action_id in COMBAT_ACTIONS:
        active_start = max(1, frame_count // 3)
        active_end = min(frame_count - 1, active_start + max(1, frame_count // 4))
        hitbox_id = f"hit_{action_id}"
        hitboxes = [
            {
                "hitbox_id": hitbox_id,
                "active_window": {
                    "start_frame": active_start,
                    "end_frame": active_end,
                },
                "rect": _default_hitbox(action_id),
            }
        ]
        hitstop = 3
        events = [
            {
                "frame": active_start,
                "event_type": "enable_hitbox",
                "payload": {"hitbox_id": hitbox_id},
            },
            {
                "frame": active_end,
                "event_type": "disable_hitbox",
                "payload": {"hitbox_id": hitbox_id},
            },
            {
                "frame": active_end,
                "event_type": "apply_hitstop",
                "payload": {"frames": hitstop},
            },
        ]

    result: dict[str, Any] = {
        "schema_version": "0.3",
        "move_id": move_id,
        "move_type": move_type,
        "frame_count": frame_count,
        "startup_frames": active_start,
        "active_frames": active_end - active_start + 1,
        "recovery_frames": max(0, frame_count - active_end - 1),
        "active_window": {
            "start_frame": active_start,
            "end_frame": active_end,
        },
        "damage": damage,
        "hitstop_frames": hitstop,
        "hitboxes": hitboxes,
        "multi_hit": False,
        "events": events,
    }
    if state_context is not None:
        result["state_context_override"] = state_context
    return result


def _default_hitbox(action_id: str) -> dict[str, int]:
    if action_id == "sweep":
        return {"x": 8, "y": -22, "w": 34, "h": 16}
    if "kick" in action_id:
        return {"x": 10, "y": -48, "w": 36, "h": 20}
    return {"x": 12, "y": -50, "w": 28, "h": 18}


def _raw_clip_id(behavior_id: str, direction_id: str) -> str:
    return f"eden_{behavior_id.removeprefix('bhv_')}_{direction_id.removeprefix('dir_')}"


def _snake_id(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    if not normalized or not re.fullmatch(r"[a-z][a-z0-9_]*", normalized):
        raise ImportFailure(f"target character name cannot form a valid id: {value!r}")
    return normalized


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ImportFailure(f"cannot read JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise ImportFailure(f"JSON root must be an object: {path}")
    return value


def _write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    path.write_text(text, encoding="utf-8")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def _verify_sha256(path: Path, expected: str) -> None:
    actual = _sha256(path)
    if not expected or actual != expected:
        raise ImportFailure(
            f"sha256 mismatch for {path}: expected={expected!r} actual={actual}"
        )


def _first_task_id(records: list[BehaviorRecord]) -> str:
    if not records:
        return ""
    return str(records[0].manifest.get("task_id", ""))


def _generate_spriteframes(project_root: Path, character_id: str, godot: str) -> None:
    # Import PNGs first so SpriteFrames stores external Texture2D references instead of
    # embedding hundreds of raw ImageTextures in an oversized .tres file.
    import_command = [
        godot,
        "--headless",
        "--editor",
        "--path",
        str(project_root),
        "--quit",
    ]
    imported = subprocess.run(
        import_command, check=False, text=True, capture_output=True
    )
    if imported.returncode != 0:
        raise ImportFailure(
            "Godot asset import failed\n"
            f"stdout:\n{imported.stdout}\n"
            f"stderr:\n{imported.stderr}"
        )

    command = [
        godot,
        "--headless",
        "--path",
        str(project_root),
        "--script",
        "tools/generate_imported_spriteframes.gd",
        "--",
        character_id,
    ]
    result = subprocess.run(command, check=False, text=True, capture_output=True)
    if result.returncode != 0:
        raise ImportFailure(
            "SpriteFrames generation failed\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )


def _load_palette_mapping(path: Path) -> tuple[str, dict[tuple[int, int, int, int], tuple[int, int, int, int]]]:
    document = _read_json(path)
    mapping_id = str(document.get("mapping_id", "")).strip()
    mapping = {}
    for entry in document.get("entries", []):
        source = tuple(int(channel) for channel in entry.get("from_rgba", []))
        target = tuple(int(channel) for channel in entry.get("to_rgba", []))
        mapping[source] = target
    return mapping_id, _validate_palette_mapping(mapping)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", nargs="?", type=Path, help="Eden package directory")
    parser.add_argument("character_name", help="target character name")
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="SpritesPlayground repository root (default: cwd)",
    )
    parser.add_argument(
        "--skip-hash-verification",
        action="store_true",
        help="unsafe test-only mode; do not verify Eden manifest hashes",
    )
    parser.add_argument(
        "--skip-spriteframes",
        action="store_true",
        help="write import data without invoking Godot SpriteFrames generation",
    )
    parser.add_argument("--godot", default="godot", help="Godot executable")
    parser.add_argument(
        "--recolor-from",
        help="create a variant from an already imported character id",
    )
    parser.add_argument(
        "--palette-mapping",
        type=Path,
        help="explicit exact-RGBA palette mapping JSON (required with --recolor-from)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(sys.argv[1:] if argv is None else argv)
    try:
        if args.recolor_from:
            if args.palette_mapping is None:
                raise ImportFailure("--recolor-from requires --palette-mapping")
            mapping_id, mapping = _load_palette_mapping(args.palette_mapping)
            report = recolor_character(
                args.project_root,
                args.recolor_from,
                args.character_name,
                mapping,
                mapping_id=mapping_id,
            )
        else:
            if args.package is None:
                raise ImportFailure("Eden package is required for a base import")
            report = import_character(
                args.package,
                args.character_name,
                args.project_root,
                verify_hashes=not args.skip_hash_verification,
            )
        if not args.skip_spriteframes:
            _generate_spriteframes(
                args.project_root.resolve(), report["character_id"], args.godot
            )
    except ImportFailure as error:
        print(f"import failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
