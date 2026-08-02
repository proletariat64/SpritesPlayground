extends RefCounted
class_name CreatorLabAuthoringDraft

const DocumentRules := preload("res://godot/scripts/prd_v0_3_document_rules.gd")

signal valid_snapshot_changed

var _bundle: Dictionary = {}
var _clean_bundle: Dictionary = {}
var _preview_bundle: Dictionary = {}
var _diagnostics: Array = []
var _dirty: bool = false
var _loaded: bool = false


func load_bundle(source: Dictionary) -> Array:
	var candidate := source.duplicate(true)
	var candidate_diagnostics := DocumentRules.validate_runtime_bundle(candidate)
	_bundle = candidate
	_clean_bundle = candidate.duplicate(true)
	_diagnostics = candidate_diagnostics.duplicate(true)
	_dirty = false
	_loaded = not candidate.is_empty()
	if _diagnostics.is_empty():
		var preview_changed := _preview_bundle != candidate
		_preview_bundle = candidate.duplicate(true)
		if preview_changed:
			valid_snapshot_changed.emit()
	return _diagnostics.duplicate(true)


func edit_move_scalar(move_id: String, field: String, value) -> bool:
	if not _has_editable_move(move_id):
		return false

	var candidate := _bundle.duplicate(true)
	var move: Dictionary = candidate["moves"][move_id]
	match field:
		"move_type":
			if typeof(value) != TYPE_STRING:
				return false
			move[field] = value
		"state_context_override":
			if typeof(value) != TYPE_STRING:
				return false
			if str(value).is_empty():
				move.erase(field)
			else:
				move[field] = value
		"frame_count", "startup_frames", "active_frames", "recovery_frames", "damage", "hitstop_frames":
			if typeof(value) != TYPE_INT:
				return false
			move[field] = value
		"multi_hit":
			if typeof(value) != TYPE_BOOL:
				return false
			move[field] = value
		_:
			return false
	return _commit_candidate(candidate)


func edit_move_rhythm(move_id: String, startup_frames, active_frames, recovery_frames) -> bool:
	if (
		not _has_editable_move(move_id)
		or typeof(startup_frames) != TYPE_INT
		or typeof(active_frames) != TYPE_INT
		or typeof(recovery_frames) != TYPE_INT
	):
		return false
	var candidate := _bundle.duplicate(true)
	var move: Dictionary = candidate["moves"][move_id]
	move["startup_frames"] = startup_frames
	move["active_frames"] = active_frames
	move["recovery_frames"] = recovery_frames
	return _commit_candidate(candidate)


func edit_move_active_window(move_id: String, start_frame, end_frame) -> bool:
	if (
		not _has_editable_move(move_id)
		or typeof(start_frame) != TYPE_INT
		or typeof(end_frame) != TYPE_INT
	):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["moves"][move_id]["active_window"] = {
		"start_frame": start_frame,
		"end_frame": end_frame,
	}
	return _commit_candidate(candidate)


func edit_first_hitbox(
	move_id: String,
	hitbox_id,
	start_frame,
	end_frame,
	rect
) -> bool:
	if (
		not _has_editable_move(move_id)
		or typeof(hitbox_id) != TYPE_STRING
		or not _is_hitbox_id(str(hitbox_id))
		or typeof(start_frame) != TYPE_INT
		or typeof(end_frame) != TYPE_INT
		or not _has_exact_numeric_fields(rect, ["x", "y", "w", "h"])
	):
		return false
	var hitboxes = _bundle["moves"][move_id].get("hitboxes", null)
	if typeof(hitboxes) != TYPE_ARRAY:
		return false
	var candidate := _bundle.duplicate(true)
	var candidate_hitboxes: Array = candidate["moves"][move_id]["hitboxes"]
	var next_hitbox := {
		"hitbox_id": hitbox_id,
		"active_window": {"start_frame": start_frame, "end_frame": end_frame},
		"rect": rect.duplicate(true),
	}
	if candidate_hitboxes.is_empty():
		candidate_hitboxes.append(next_hitbox)
	else:
		candidate_hitboxes[0] = next_hitbox
	return _commit_candidate(candidate)


func edit_first_attack_hurtbox(
	move_id: String,
	hurtbox_id,
	start_frame,
	end_frame,
	rect
) -> bool:
	if (
		not _has_editable_move(move_id)
		or typeof(hurtbox_id) != TYPE_STRING
		or not str(hurtbox_id).begins_with("hurt_")
		or typeof(start_frame) != TYPE_INT
		or typeof(end_frame) != TYPE_INT
		or not _has_exact_numeric_fields(rect, ["x", "y", "w", "h"])
	):
		return false
	var current_move: Dictionary = _bundle["moves"][move_id]
	if current_move.has("hurtboxes") and typeof(current_move["hurtboxes"]) != TYPE_ARRAY:
		return false
	var candidate := _bundle.duplicate(true)
	var move: Dictionary = candidate["moves"][move_id]
	if not move.has("hurtboxes"):
		move["hurtboxes"] = []
	var hurtboxes: Array = move["hurtboxes"]
	var next_hurtbox := {
		"hurtbox_id": hurtbox_id,
		"active_window": {"start_frame": start_frame, "end_frame": end_frame},
		"rect": rect.duplicate(true),
	}
	if hurtboxes.is_empty():
		hurtboxes.append(next_hurtbox)
	else:
		hurtboxes[0] = next_hurtbox
	return _commit_candidate(candidate)


func edit_move_events(move_id: String, events) -> bool:
	if not _has_editable_move(move_id) or not _is_safe_event_list(events):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["moves"][move_id]["events"] = events.duplicate(true)
	return _commit_candidate(candidate)


func edit_character_values(hp, walk_speed, run_speed) -> bool:
	if (
		not _loaded
		or typeof(hp) != TYPE_INT
		or not _is_finite_number(walk_speed)
		or not _is_finite_number(run_speed)
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
	):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["hp"] = hp
	candidate["template"]["walk_speed"] = walk_speed
	candidate["template"]["run_speed"] = run_speed
	return _commit_candidate(candidate)


func edit_hurtbox_rect(hurtbox_id, rect) -> bool:
	if (
		not _loaded
		or typeof(hurtbox_id) != TYPE_STRING
		or not str(hurtbox_id).begins_with("hurt_")
		or not _has_exact_numeric_fields(rect, ["x", "y", "w", "h"])
	):
		return false
	var template: Dictionary = _bundle.get("template", {})
	var hurtboxes = template.get("hurtboxes", null)
	if typeof(hurtboxes) != TYPE_DICTIONARY or not hurtboxes.has(hurtbox_id):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["hurtboxes"][hurtbox_id] = rect.duplicate(true)
	return _commit_candidate(candidate)


func edit_foot_collision(center, radius) -> bool:
	if (
		not _loaded
		or not _has_exact_numeric_fields(center, ["x", "y"])
		or not _has_exact_numeric_fields(radius, ["x", "y"])
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
	):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["foot_collision"] = {
		"center": center.duplicate(true),
		"radius": radius.duplicate(true),
	}
	return _commit_candidate(candidate)


func change_sprite_set(sprite_set_document) -> bool:
	if (
		not _loaded
		or not _is_sprite_set_document(sprite_set_document)
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
	):
		return false
	var sprite_set_id := str(sprite_set_document["sprite_set_id"])
	if not _is_snake_id(sprite_set_id):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["sprite_set_ref"] = sprite_set_id
	candidate["sprite_set"] = sprite_set_document.duplicate(true)
	return _commit_candidate(candidate)


func set_equipped_moves(move_ids, move_documents) -> bool:
	if (
		not _loaded
		or typeof(move_ids) != TYPE_ARRAY
		or typeof(move_documents) != TYPE_DICTIONARY
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
	):
		return false
	var unique_ids := {}
	for move_id in move_ids:
		if typeof(move_id) != TYPE_STRING or not _is_snake_id(str(move_id)) or unique_ids.has(move_id):
			return false
		unique_ids[move_id] = true
	for document_id in move_documents.keys():
		if (
			typeof(document_id) != TYPE_STRING
			or not unique_ids.has(document_id)
			or not _is_move_document(move_documents[document_id])
		):
			return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["equipped_moves"] = move_ids.duplicate(true)
	candidate["moves"] = move_documents.duplicate(true)
	return _commit_candidate(candidate)


func copy_template(next_template_id) -> bool:
	if (
		not _loaded
		or typeof(next_template_id) != TYPE_STRING
		or not _is_snake_id(str(next_template_id))
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
		or str(_bundle["template"].get("template_id", "")) == str(next_template_id)
	):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["template_id"] = str(next_template_id)
	return _commit_candidate(candidate)


func import_legacy_bundle(source) -> bool:
	if not _loaded or not _has_bundle_documents(source):
		return false
	# Import current legacy edits without resetting the original clean baseline.
	return _commit_candidate(source.duplicate(true))


func snapshot() -> Dictionary:
	var valid := _loaded and _diagnostics.is_empty()
	return {
		"bundle": _bundle.duplicate(true),
		"preview_bundle": _preview_bundle.duplicate(true),
		"dirty": _dirty,
		"diagnostics": _diagnostics.duplicate(true),
		"can_save": _dirty and valid,
		"can_apply": valid,
	}


func legacy_bundle_view() -> Dictionary:
	# Temporary detached bridge while Panel edits migrate behind Draft in #44-#46.
	return _bundle.duplicate(true)


func _commit_candidate(candidate: Dictionary) -> bool:
	var candidate_diagnostics := DocumentRules.validate_runtime_bundle(candidate)
	var preview_changed := candidate_diagnostics.is_empty() and _preview_bundle != candidate
	_bundle = candidate
	_diagnostics = candidate_diagnostics.duplicate(true)
	_dirty = _bundle != _clean_bundle
	if _diagnostics.is_empty():
		_preview_bundle = candidate.duplicate(true)
		if preview_changed:
			valid_snapshot_changed.emit()
	return true


func _has_bundle_documents(value) -> bool:
	return (
		typeof(value) == TYPE_DICTIONARY
		and typeof(value.get("template", null)) == TYPE_DICTIONARY
		and not value["template"].is_empty()
		and typeof(value.get("sprite_set", null)) == TYPE_DICTIONARY
		and not value["sprite_set"].is_empty()
		and typeof(value.get("moves", null)) == TYPE_DICTIONARY
		and not value["moves"].is_empty()
	)


func _has_editable_move(move_id: String) -> bool:
	if not _loaded or typeof(_bundle.get("moves", null)) != TYPE_DICTIONARY:
		return false
	var moves: Dictionary = _bundle["moves"]
	return moves.has(move_id) and typeof(moves[move_id]) == TYPE_DICTIONARY


func _is_sprite_set_document(value) -> bool:
	return (
		typeof(value) == TYPE_DICTIONARY
		and typeof(value.get("sprite_set_id", null)) == TYPE_STRING
	)


func _is_move_document(value) -> bool:
	return typeof(value) == TYPE_DICTIONARY


func _is_safe_event_list(value) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for event in value:
		if typeof(event) != TYPE_DICTIONARY:
			return false
		if event.has("frame") and not _is_integral_number(event["frame"]):
			return false
		if event.has("event_type") and typeof(event["event_type"]) != TYPE_STRING:
			return false
		if event.has("payload") and typeof(event["payload"]) != TYPE_DICTIONARY:
			return false
	return true


func _has_exact_numeric_fields(value, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field) or not _is_finite_number(value[field]):
			return false
	return true


func _is_finite_number(value) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return not is_nan(float(value)) and not is_inf(float(value))


func _is_integral_number(value) -> bool:
	return _is_finite_number(value) and is_equal_approx(float(value), roundf(float(value)))


func _is_snake_id(value: String) -> bool:
	if value.is_empty():
		return false
	var expression := RegEx.new()
	expression.compile("^[a-z][a-z0-9_]*$")
	return expression.search(value) != null


func _is_hitbox_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^hit_[a-z0-9_]+$")
	return expression.search(value) != null
