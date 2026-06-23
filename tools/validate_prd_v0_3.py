#!/usr/bin/env python3
"""Validate PRD v0.3 schema files and example data fixtures."""

from __future__ import annotations

import json
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator
from referencing import Registry, Resource


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_DIR = ROOT / "data" / "schemas" / "v0_3"
DATA_DIR = ROOT / "data" / "v0_3"

FORBIDDEN_KEYS = {
    "action",
    "actions",
    "attack",
    "base_action_set",
    "base_actions",
    "base_attack_moves",
    "duration_seconds",
    "cooldown_seconds",
    "seconds",
}

SCHEMA_FILES = {
    "character": SCHEMA_DIR / "character_template.schema.json",
    "move": SCHEMA_DIR / "move_template.schema.json",
    "sprite_set": SCHEMA_DIR / "sprite_set.schema.json",
    "frame_event": SCHEMA_DIR / "frame_event.schema.json",
}


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def schema_registry() -> Registry:
    resources = []
    for path in SCHEMA_FILES.values():
        schema = load_json(path)
        resources.append((schema["$id"], Resource.from_contents(schema)))
    return Registry().with_resources(resources)


def validate_file(path: Path, schema_path: Path, registry: Registry) -> list[str]:
    schema = load_json(schema_path)
    instance = load_json(path)
    validator = Draft202012Validator(schema, registry=registry)
    errors = []
    for error in sorted(validator.iter_errors(instance), key=lambda item: list(item.path)):
        location = ".".join(str(part) for part in error.path) or "<root>"
        errors.append(f"{path}: {location}: {error.message}")
    return errors


def scan_forbidden_keys(value: Any, path: Path, json_path: str = "<root>") -> list[str]:
    errors = []
    if isinstance(value, dict):
        for key, child in value.items():
            child_path = f"{json_path}.{key}" if json_path != "<root>" else key
            if key in FORBIDDEN_KEYS:
                errors.append(f"{path}: {child_path}: forbidden legacy key")
            errors.extend(scan_forbidden_keys(child, path, child_path))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            errors.extend(scan_forbidden_keys(child, path, f"{json_path}[{index}]"))
    return errors


def validate_references() -> list[str]:
    errors = []
    templates = {path.stem: load_json(path) for path in sorted((DATA_DIR / "templates").glob("*.json"))}
    moves = {path.stem: load_json(path) for path in sorted((DATA_DIR / "moves").glob("*.json"))}
    sprite_sets = {path.stem: load_json(path) for path in sorted((DATA_DIR / "sprite_sets").glob("*.json"))}

    for template_id, template in templates.items():
        sprite_set_ref = template["sprite_set_ref"]
        if sprite_set_ref not in sprite_sets:
            errors.append(f"template {template_id}: missing sprite_set_ref {sprite_set_ref}")
            continue

        required_moves = set(template["equipped_moves"])
        missing_moves = sorted(required_moves - set(moves))
        if missing_moves:
            errors.append(f"template {template_id}: missing moves {missing_moves}")

        mapping = sprite_sets[sprite_set_ref]["required_moves_mapping"]
        missing_mapping = sorted(required_moves - set(mapping))
        if missing_mapping:
            errors.append(f"sprite_set {sprite_set_ref}: missing required_moves_mapping {missing_mapping}")

        missing_clips = sorted({mapping[move_id] for move_id in required_moves if move_id in mapping} - set(sprite_sets[sprite_set_ref]["animation_clips"]))
        if missing_clips:
            errors.append(f"sprite_set {sprite_set_ref}: missing animation_clips {missing_clips}")

        missing_sequences = sorted(
            sequence_id
            for sequence_id in (
                str(clip.get("frame_sequence_ref", ""))
                for clip in sprite_sets[sprite_set_ref]["animation_clips"].values()
            )
            if sequence_id not in sprite_sets[sprite_set_ref]["frame_sequences"]
        )
        if missing_sequences:
            errors.append(f"sprite_set {sprite_set_ref}: missing frame_sequences {missing_sequences}")

    return errors


def validate_move_semantics(path: Path, move: dict[str, Any]) -> list[str]:
    errors = []
    frame_count = move["frame_count"]
    window = move["active_window"]
    errors.extend(_validate_window(path, "active_window", window, frame_count))
    for index, hitbox in enumerate(move.get("hitboxes", [])):
        errors.extend(_validate_window(path, f"hitboxes[{index}].active_window", hitbox["active_window"], frame_count))
    for index, event in enumerate(move.get("events", [])):
        if event["frame"] >= frame_count:
            errors.append(f"{path}: events[{index}].frame: must be < frame_count")
    return errors


def _validate_window(path: Path, label: str, window: dict[str, Any], frame_count: int) -> list[str]:
    errors = []
    start_frame = window["start_frame"]
    end_frame = window["end_frame"]
    if start_frame > end_frame:
        errors.append(f"{path}: {label}: start_frame must be <= end_frame")
    if end_frame >= frame_count:
        errors.append(f"{path}: {label}: end_frame must be < frame_count")
    return errors


def validate_negative_legacy_field_rejection(registry: Registry) -> list[str]:
    errors = []
    cases = [
        ("character", DATA_DIR / "templates" / "combat_gray_s64.json", "base_actions", ["idle"]),
        ("move", DATA_DIR / "moves" / "basic_punch.json", "duration_seconds", 0.25),
        ("sprite_set", DATA_DIR / "sprite_sets" / "combat_gray_s64.json", "seconds", 1),
    ]
    for schema_key, fixture_path, key, value in cases:
        schema = load_json(SCHEMA_FILES[schema_key])
        instance = load_json(fixture_path)
        instance[key] = value
        validator = Draft202012Validator(schema, registry=registry)
        schema_errors = list(validator.iter_errors(instance))
        scan_errors = scan_forbidden_keys(instance, Path(f"<negative_{schema_key}_{key}>"))
        if not schema_errors:
            errors.append(f"negative legacy-field schema check did not reject {schema_key}.{key}")
        if not scan_errors:
            errors.append(f"negative legacy-field scan check did not reject {schema_key}.{key}")
    return errors


def validate_negative_contract_rejection(registry: Registry) -> list[str]:
    errors = []
    move_schema = load_json(SCHEMA_FILES["move"])
    character_schema = load_json(SCHEMA_FILES["character"])
    move = load_json(DATA_DIR / "moves" / "basic_punch.json")
    character = load_json(DATA_DIR / "templates" / "combat_gray_s64.json")

    bad_payload = deepcopy(move)
    bad_payload["events"][0]["payload"] = {}
    if not list(Draft202012Validator(move_schema, registry=registry).iter_errors(bad_payload)):
        errors.append("negative payload schema check did not reject missing hitbox_id")

    bad_payload_extra = deepcopy(move)
    bad_payload_extra["events"][0]["payload"]["extra"] = True
    if not list(Draft202012Validator(move_schema, registry=registry).iter_errors(bad_payload_extra)):
        errors.append("negative payload schema check did not reject extra payload key")

    bad_event_type = deepcopy(move)
    bad_event_type["events"][0]["event_type"] = "play_sound"
    if not list(Draft202012Validator(move_schema, registry=registry).iter_errors(bad_event_type)):
        errors.append("negative event schema check did not reject unsupported event_type")

    bad_idle = deepcopy(character)
    bad_idle["equipped_moves"] = ["walk"]
    if not list(Draft202012Validator(character_schema, registry=registry).iter_errors(bad_idle)):
        errors.append("negative character schema check did not reject missing idle")

    bad_window = deepcopy(move)
    bad_window["active_window"] = {"start_frame": 6, "end_frame": 2}
    if not validate_move_semantics(Path("<negative_bad_window>"), bad_window):
        errors.append("negative semantic check did not reject reversed active_window")

    bad_event = deepcopy(move)
    bad_event["events"][0]["frame"] = bad_event["frame_count"]
    if not validate_move_semantics(Path("<negative_bad_event>"), bad_event):
        errors.append("negative semantic check did not reject event frame >= frame_count")

    return errors


def main() -> int:
    registry = schema_registry()
    errors: list[str] = []

    for path in sorted((DATA_DIR / "templates").glob("*.json")):
        errors.extend(validate_file(path, SCHEMA_FILES["character"], registry))
        errors.extend(scan_forbidden_keys(load_json(path), path))

    for path in sorted((DATA_DIR / "moves").glob("*.json")):
        errors.extend(validate_file(path, SCHEMA_FILES["move"], registry))
        move = load_json(path)
        errors.extend(scan_forbidden_keys(move, path))
        errors.extend(validate_move_semantics(path, move))

    for path in sorted((DATA_DIR / "sprite_sets").glob("*.json")):
        errors.extend(validate_file(path, SCHEMA_FILES["sprite_set"], registry))
        errors.extend(scan_forbidden_keys(load_json(path), path))

    errors.extend(validate_references())
    errors.extend(validate_negative_legacy_field_rejection(registry))
    errors.extend(validate_negative_contract_rejection(registry))

    if errors:
        print("PRD v0.3 validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("PRD v0.3 validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
