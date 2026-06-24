extends RefCounted
class_name CreatorLabActionCoverage

const Catalog := preload("res://godot/scripts/creator_lab_action_catalog.gd")

const MISSING_ANIMATION := "MISSING_ANIMATION"
const PLACEHOLDER_ANIMATION := "PLACEHOLDER_ANIMATION"
const DUPLICATE_IDLE_FOR_DAMAGE_STATE := "DUPLICATE_IDLE_FOR_DAMAGE_STATE"
const DUPLICATE_IDLE_FOR_DEAD_STATE := "DUPLICATE_IDLE_FOR_DEAD_STATE"
const DUPLICATE_IDLE_FOR_KNOCKDOWN_STATE := "DUPLICATE_IDLE_FOR_KNOCKDOWN_STATE"
const WRONG_FRAME_COUNT := "WRONG_FRAME_COUNT"
const MISSING_FRAME_SEQUENCE := "MISSING_FRAME_SEQUENCE"
const MISSING_VISUAL_ROLE := "MISSING_VISUAL_ROLE"
const INVALID_SPRITE_MAPPING := "INVALID_SPRITE_MAPPING"

const FAIL_WARNINGS := {
	MISSING_ANIMATION: true,
	WRONG_FRAME_COUNT: true,
	MISSING_FRAME_SEQUENCE: true,
	MISSING_VISUAL_ROLE: true,
	INVALID_SPRITE_MAPPING: true,
}


static func analyze(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> Dictionary:
	return analyze_entries(Catalog.required_actions(), template, sprite_set, moves)


static func analyze_entries(entries: Array, template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> Dictionary:
	var rows: Array = []
	var summary := {"ok": 0, "warning": 0, "fail": 0}
	var idle_signature := _clip_signature("idle", sprite_set)
	for entry in entries:
		var row := _analyze_entry(entry, template, sprite_set, moves, idle_signature)
		rows.append(row)
		match str(row["status"]):
			"FAIL":
				summary["fail"] += 1
			"WARNING":
				summary["warning"] += 1
			_:
				summary["ok"] += 1
	return {
		"rows": rows,
		"summary": summary,
	}


static func warnings_for_row(row: Dictionary) -> Array:
	return row.get("warnings", []).duplicate()


static func is_placeholder_sequence(sequence: Array) -> bool:
	for frame_path in sequence:
		if str(frame_path).begins_with("placeholder://"):
			return true
	return false


static func _analyze_entry(entry: Dictionary, _template: Dictionary, sprite_set: Dictionary, moves: Dictionary, idle_signature: String) -> Dictionary:
	var action_id := str(entry.get("action_id", ""))
	var warnings: Array = []
	var mapping: Dictionary = sprite_set.get("required_moves_mapping", {})
	var clips: Dictionary = sprite_set.get("animation_clips", {})
	var sequences: Dictionary = sprite_set.get("frame_sequences", {})
	var clip_id := ""
	var clip_exists := false
	var sequence_ref := ""
	var sequence_exists := false
	var sequence: Array = []

	if not mapping.has(action_id) or str(mapping.get(action_id, "")).strip_edges().is_empty():
		warnings.append(INVALID_SPRITE_MAPPING)
		warnings.append(MISSING_ANIMATION)
	else:
		clip_id = str(mapping[action_id])
		clip_exists = clips.has(clip_id)
		if not clip_exists:
			warnings.append(INVALID_SPRITE_MAPPING)
			warnings.append(MISSING_ANIMATION)
		else:
			var clip: Dictionary = clips[clip_id]
			sequence_ref = str(clip.get("frame_sequence_ref", ""))
			sequence_exists = sequences.has(sequence_ref)
			if sequence_exists:
				sequence = sequences[sequence_ref]
			else:
				warnings.append(MISSING_FRAME_SEQUENCE)

	var backing_move_id := Catalog.backing_move_id(entry)
	var move_exists := moves.has(backing_move_id)
	var move_frame_count := 0
	if move_exists:
		move_frame_count = int(moves[backing_move_id].get("frame_count", 0))
	if move_exists and sequence_exists and move_frame_count != sequence.size():
		warnings.append(WRONG_FRAME_COUNT)
	if sequence_exists and is_placeholder_sequence(sequence):
		warnings.append(PLACEHOLDER_ANIMATION)
	if str(entry.get("visual_role", "")).strip_edges().is_empty():
		warnings.append(MISSING_VISUAL_ROLE)

	var action_signature := "%s::%s" % [clip_id, sequence_ref]
	if sequence_exists and not idle_signature.is_empty() and action_signature == idle_signature:
		match action_id:
			"hurt_light", "hurt_heavy":
				warnings.append(DUPLICATE_IDLE_FOR_DAMAGE_STATE)
			"dead":
				warnings.append(DUPLICATE_IDLE_FOR_DEAD_STATE)
			"knockdown":
				warnings.append(DUPLICATE_IDLE_FOR_KNOCKDOWN_STATE)

	warnings = _unique_strings(warnings)
	var status := _status_for_warnings(warnings)
	if not move_exists and Catalog.backing_kind(entry) == "move":
		status = "FAIL"

	return {
		"action_id": action_id,
		"category": str(entry.get("category", "")),
		"state_context": str(entry.get("state_context", "")),
		"backing": str(entry.get("backing", "")),
		"backing_kind": Catalog.backing_kind(entry),
		"backing_move_id": backing_move_id,
		"move_exists": move_exists,
		"clip_id": clip_id,
		"clip_exists": clip_exists,
		"frame_sequence_ref": sequence_ref,
		"frame_sequence_exists": sequence_exists,
		"sequence_frame_count": sequence.size(),
		"move_frame_count": move_frame_count,
		"visual_role": str(entry.get("visual_role", "")),
		"warnings": warnings,
		"status": status,
	}


static func _clip_signature(action_id: String, sprite_set: Dictionary) -> String:
	var mapping: Dictionary = sprite_set.get("required_moves_mapping", {})
	var clips: Dictionary = sprite_set.get("animation_clips", {})
	if not mapping.has(action_id):
		return ""
	var clip_id := str(mapping[action_id])
	if not clips.has(clip_id):
		return ""
	return "%s::%s" % [clip_id, str(clips[clip_id].get("frame_sequence_ref", ""))]


static func _status_for_warnings(warnings: Array) -> String:
	if warnings.is_empty():
		return "OK"
	for warning in warnings:
		if FAIL_WARNINGS.has(str(warning)):
			return "FAIL"
	return "WARNING"


static func _unique_strings(values: Array) -> Array:
	var seen := {}
	var result: Array = []
	for value in values:
		var text := str(value)
		if seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	return result
