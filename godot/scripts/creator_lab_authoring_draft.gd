extends RefCounted
class_name CreatorLabAuthoringDraft

const DocumentRules := preload("res://godot/scripts/prd_v0_3_document_rules.gd")
const ActionCatalog := preload("res://godot/scripts/creator_lab_action_catalog.gd")

signal valid_snapshot_changed

var _bundle: Dictionary = {}
var _clean_bundle: Dictionary = {}
var _preview_bundle: Dictionary = {}
var _diagnostics: Array = []
var _dirty: bool = false
var _loaded: bool = false
var _last_operation_error: String = ""


func load_bundle(source: Dictionary) -> Array:
	if _dirty:
		return ["cannot load bundle while Authoring Draft has unsaved changes"]
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


func accept_persisted_bundle(saved_bundle: Dictionary) -> Array:
	var candidate := saved_bundle.duplicate(true)
	var candidate_diagnostics := DocumentRules.validate_runtime_bundle(candidate)
	if not candidate_diagnostics.is_empty():
		return candidate_diagnostics.duplicate(true)
	var preview_changed := _preview_bundle != candidate
	_bundle = candidate
	_clean_bundle = candidate.duplicate(true)
	_preview_bundle = candidate.duplicate(true)
	_diagnostics = []
	_dirty = false
	_loaded = true
	if preview_changed:
		valid_snapshot_changed.emit()
	return []


func discard_changes() -> bool:
	if not _loaded or _clean_bundle.is_empty():
		return false
	var candidate := _clean_bundle.duplicate(true)
	var candidate_diagnostics := DocumentRules.validate_runtime_bundle(candidate)
	if not candidate_diagnostics.is_empty():
		return false
	var preview_changed := _preview_bundle != candidate
	_bundle = candidate
	_preview_bundle = candidate.duplicate(true)
	_diagnostics = candidate_diagnostics.duplicate(true)
	_dirty = false
	if preview_changed:
		valid_snapshot_changed.emit()
	return true


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


func insert_frame_slot(sequence_id, frame_index, slot, shift_timing) -> bool:
	_last_operation_error = ""
	if typeof(shift_timing) != TYPE_BOOL:
		return _reject_frame_operation("frame insert blocked: choose shift timing")
	if not _has_editable_frame_sequence(sequence_id):
		return _reject_frame_operation("frame insert failed: missing or invalid sequence")
	if typeof(frame_index) != TYPE_INT:
		return _reject_frame_operation("frame insert failed: frame out of range")
	var sequence: Array = _bundle["sprite_set"]["frame_sequences"][sequence_id]
	if frame_index < 0 or frame_index > sequence.size():
		return _reject_frame_operation("frame insert failed: frame out of range")
	if not _is_supported_slot_uri(slot):
		return _reject_frame_operation("frame insert failed: unsupported frame slot URI")
	var mapping_context = _frame_mapping_context(str(sequence_id))
	if mapping_context == null:
		return _reject_frame_operation("frame insert failed: invalid sprite mapping metadata")
	var related_move_ids: Array = mapping_context["move_ids"]
	var ambiguous_move_ids: Array = mapping_context["ambiguous_move_ids"]
	if shift_timing and not ambiguous_move_ids.is_empty():
		return _reject_frame_operation(
			"frame timing shift blocked: move %s maps to multiple frame sequences"
				% str(ambiguous_move_ids[0])
		)
	if shift_timing and not _can_shift_moves(related_move_ids):
		return _reject_frame_operation("frame insert failed: invalid timing metadata")

	var candidate := _bundle.duplicate(true)
	candidate["sprite_set"]["frame_sequences"][sequence_id].insert(frame_index, slot)
	if shift_timing:
		for move_id in related_move_ids:
			_shift_move_after_insert(candidate["moves"][move_id], frame_index)
	return _commit_candidate(candidate)


func delete_frame_slot(sequence_id, frame_index) -> bool:
	_last_operation_error = ""
	if not _has_editable_frame_sequence(sequence_id):
		return _reject_frame_operation("frame remove failed: missing or invalid sequence")
	if typeof(frame_index) != TYPE_INT:
		return _reject_frame_operation("frame remove failed: frame out of range")
	var sequence: Array = _bundle["sprite_set"]["frame_sequences"][sequence_id]
	if frame_index < 0 or frame_index >= sequence.size():
		return _reject_frame_operation("frame remove failed: frame out of range")
	if sequence.size() <= 1:
		return _reject_frame_operation("frame remove blocked: sequence requires one frame")
	var mapping_context = _frame_mapping_context(str(sequence_id))
	if mapping_context == null:
		return _reject_frame_operation("frame remove failed: invalid sprite mapping metadata")
	var related_move_ids: Array = mapping_context["move_ids"]
	var ambiguous_move_ids: Array = mapping_context["ambiguous_move_ids"]
	if not ambiguous_move_ids.is_empty():
		return _reject_frame_operation(
			"frame timing shift blocked: move %s maps to multiple frame sequences"
				% str(ambiguous_move_ids[0])
		)
	if not _can_shift_moves(related_move_ids):
		return _reject_frame_operation("frame remove failed: invalid timing metadata")
	for move_id in related_move_ids:
		var move: Dictionary = _bundle["moves"][move_id]
		if _move_references_frame(move, frame_index):
			return _reject_frame_operation(
				"frame remove blocked: timing metadata references frame %d" % frame_index
			)
		if not _can_delete_move_frame(move, frame_index):
			return _reject_frame_operation("frame remove blocked: timing phase minimum")

	var candidate := _bundle.duplicate(true)
	candidate["sprite_set"]["frame_sequences"][sequence_id].remove_at(frame_index)
	for move_id in related_move_ids:
		_shift_move_after_delete(candidate["moves"][move_id], frame_index)
	return _commit_candidate(candidate)


func replace_frame_slot(sequence_id, frame_index, slot) -> bool:
	_last_operation_error = ""
	if not _has_editable_frame_sequence(sequence_id):
		return _reject_frame_operation("frame edit failed: missing or invalid sequence")
	if typeof(frame_index) != TYPE_INT:
		return _reject_frame_operation("frame edit failed: frame out of range")
	var sequence: Array = _bundle["sprite_set"]["frame_sequences"][sequence_id]
	if frame_index < 0 or frame_index >= sequence.size():
		return _reject_frame_operation("frame edit failed: frame out of range")
	if not _is_supported_slot_uri(slot):
		return _reject_frame_operation("frame edit failed: unsupported frame slot URI")
	var candidate := _bundle.duplicate(true)
	candidate["sprite_set"]["frame_sequences"][sequence_id][frame_index] = slot
	return _commit_candidate(candidate)


func mark_frame_slot(sequence_id, frame_index, status) -> bool:
	_last_operation_error = ""
	if not _has_editable_frame_sequence(sequence_id):
		return _reject_frame_operation("frame mark failed: missing or invalid sequence")
	if typeof(frame_index) != TYPE_INT:
		return _reject_frame_operation("frame mark failed: frame out of range")
	var sequence: Array = _bundle["sprite_set"]["frame_sequences"][sequence_id]
	if frame_index < 0 or frame_index >= sequence.size():
		return _reject_frame_operation("frame mark failed: frame out of range")
	if typeof(status) != TYPE_STRING or not ["empty", "missing", "placeholder"].has(status):
		return _reject_frame_operation("frame mark failed: invalid slot state")
	var sprite_set_id = _bundle["sprite_set"].get("sprite_set_id", null)
	if typeof(sprite_set_id) != TYPE_STRING or str(sprite_set_id).is_empty():
		return _reject_frame_operation("frame mark failed: invalid sprite set id")
	var candidate := _bundle.duplicate(true)
	candidate["sprite_set"]["frame_sequences"][sequence_id][frame_index] = (
		"%s://%s/%s/frame_%03d.png" % [status, sprite_set_id, sequence_id, frame_index]
	)
	return _commit_candidate(candidate)


func last_operation_error() -> String:
	return _last_operation_error


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


func _reject_frame_operation(message: String) -> bool:
	_last_operation_error = message
	return false


func _has_editable_frame_sequence(sequence_id) -> bool:
	if not _loaded or typeof(sequence_id) != TYPE_STRING:
		return false
	var sprite_set = _bundle.get("sprite_set", null)
	if typeof(sprite_set) != TYPE_DICTIONARY:
		return false
	var sequences = sprite_set.get("frame_sequences", null)
	return (
		typeof(sequences) == TYPE_DICTIONARY
		and sequences.has(sequence_id)
		and typeof(sequences[sequence_id]) == TYPE_ARRAY
	)


func _frame_mapping_context(sequence_id: String):
	var sprite_set = _bundle.get("sprite_set", null)
	var moves = _bundle.get("moves", null)
	if typeof(sprite_set) != TYPE_DICTIONARY or typeof(moves) != TYPE_DICTIONARY:
		return null
	var mapping = sprite_set.get("required_moves_mapping", null)
	var clips = sprite_set.get("animation_clips", null)
	if typeof(mapping) != TYPE_DICTIONARY or typeof(clips) != TYPE_DICTIONARY:
		return null
	var target_move_ids := {}
	var sequence_ids_by_move := {}
	for action_id in mapping.keys():
		if typeof(action_id) != TYPE_STRING or typeof(mapping[action_id]) != TYPE_STRING:
			return null
		var clip_id: String = mapping[action_id]
		if not clips.has(clip_id):
			return null
		if typeof(clips[clip_id]) != TYPE_DICTIONARY:
			return null
		var sequence_ref = clips[clip_id].get("frame_sequence_ref", null)
		if typeof(sequence_ref) != TYPE_STRING:
			return null
		var move_id := _mapped_move_id_for_action(str(action_id))
		if move_id.is_empty() or not moves.has(move_id):
			continue
		if typeof(moves[move_id]) != TYPE_DICTIONARY:
			return null
		var move_sequence_ids: Dictionary = sequence_ids_by_move.get(move_id, {})
		move_sequence_ids[str(sequence_ref)] = true
		sequence_ids_by_move[move_id] = move_sequence_ids
		if str(sequence_ref) == sequence_id:
			target_move_ids[move_id] = true
	var related_move_ids: Array = target_move_ids.keys()
	related_move_ids.sort()
	var ambiguous_move_ids: Array = []
	for move_id in related_move_ids:
		if sequence_ids_by_move.get(move_id, {}).size() > 1:
			ambiguous_move_ids.append(move_id)
	return {
		"move_ids": related_move_ids,
		"ambiguous_move_ids": ambiguous_move_ids,
	}


func _mapped_move_id_for_action(action_id: String) -> String:
	var catalog_entry := ActionCatalog.action_for(action_id)
	if catalog_entry.is_empty():
		return action_id
	return ActionCatalog.backing_move_id(catalog_entry)


func _can_shift_moves(move_ids: Array) -> bool:
	for move_id in move_ids:
		if not _is_shiftable_move(_bundle["moves"][move_id]):
			return false
	return true


func _is_shiftable_move(move: Dictionary) -> bool:
	if not _is_integral_number(move.get("frame_count", null)):
		return false
	if not _is_frame_window(move.get("active_window", null)):
		return false
	for collection_name in ["hitboxes", "hurtboxes"]:
		var boxes = move.get(collection_name, [])
		if typeof(boxes) != TYPE_ARRAY:
			return false
		for box in boxes:
			if typeof(box) != TYPE_DICTIONARY or not _is_frame_window(box.get("active_window", null)):
				return false
	var events = move.get("events", [])
	if typeof(events) != TYPE_ARRAY:
		return false
	for event in events:
		if typeof(event) != TYPE_DICTIONARY or not _is_integral_number(event.get("frame", null)):
			return false
	var rhythm_fields := ["startup_frames", "active_frames", "recovery_frames"]
	var rhythm_count := 0
	for field in rhythm_fields:
		if move.has(field):
			rhythm_count += 1
			if not _is_integral_number(move[field]):
				return false
	return rhythm_count == 0 or rhythm_count == rhythm_fields.size()


func _is_frame_window(value) -> bool:
	return (
		typeof(value) == TYPE_DICTIONARY
		and _is_integral_number(value.get("start_frame", null))
		and _is_integral_number(value.get("end_frame", null))
	)


func _is_supported_slot_uri(value) -> bool:
	if typeof(value) != TYPE_STRING or str(value) != str(value).strip_edges():
		return false
	for prefix in ["res://", "user://", "empty://", "missing://", "placeholder://"]:
		if str(value).begins_with(prefix) and str(value).length() > prefix.length():
			return true
	return false


func _move_references_frame(move: Dictionary, frame_index: int) -> bool:
	if _frame_window_contains(move["active_window"], frame_index):
		return true
	for collection_name in ["hitboxes", "hurtboxes"]:
		for box in move.get(collection_name, []):
			if _frame_window_contains(box["active_window"], frame_index):
				return true
	for event in move.get("events", []):
		if int(event["frame"]) == frame_index:
			return true
	return false


func _frame_window_contains(window: Dictionary, frame_index: int) -> bool:
	return frame_index >= int(window["start_frame"]) and frame_index <= int(window["end_frame"])


func _can_delete_move_frame(move: Dictionary, frame_index: int) -> bool:
	if int(move["frame_count"]) <= 1 or frame_index >= int(move["frame_count"]):
		return false
	if not move.has("startup_frames"):
		return true
	var startup_frames := int(move["startup_frames"])
	var active_frames := int(move["active_frames"])
	var recovery_frames := int(move["recovery_frames"])
	if frame_index < startup_frames:
		return startup_frames > 0
	if frame_index < startup_frames + active_frames:
		return active_frames > 1
	return recovery_frames > 0


func _shift_move_after_insert(move: Dictionary, frame_index: int) -> void:
	move["frame_count"] = int(move["frame_count"]) + 1
	_shift_rhythm_after_insert(move, frame_index)
	_shift_frame_window_after_insert(move["active_window"], frame_index)
	for collection_name in ["hitboxes", "hurtboxes"]:
		for box in move.get(collection_name, []):
			_shift_frame_window_after_insert(box["active_window"], frame_index)
	for event in move.get("events", []):
		if int(event["frame"]) >= frame_index:
			event["frame"] = int(event["frame"]) + 1


func _shift_move_after_delete(move: Dictionary, frame_index: int) -> void:
	move["frame_count"] = int(move["frame_count"]) - 1
	_shift_rhythm_after_delete(move, frame_index)
	_shift_frame_window_after_delete(move["active_window"], frame_index)
	for collection_name in ["hitboxes", "hurtboxes"]:
		for box in move.get(collection_name, []):
			_shift_frame_window_after_delete(box["active_window"], frame_index)
	for event in move.get("events", []):
		if int(event["frame"]) > frame_index:
			event["frame"] = int(event["frame"]) - 1


func _shift_rhythm_after_insert(move: Dictionary, frame_index: int) -> void:
	if not move.has("startup_frames"):
		return
	var startup_frames := int(move["startup_frames"])
	var active_frames := int(move["active_frames"])
	if frame_index <= startup_frames:
		move["startup_frames"] = startup_frames + 1
	elif frame_index < startup_frames + active_frames:
		move["active_frames"] = active_frames + 1
	else:
		move["recovery_frames"] = int(move["recovery_frames"]) + 1


func _shift_rhythm_after_delete(move: Dictionary, frame_index: int) -> void:
	if not move.has("startup_frames"):
		return
	var startup_frames := int(move["startup_frames"])
	var active_frames := int(move["active_frames"])
	if frame_index < startup_frames:
		move["startup_frames"] = startup_frames - 1
	elif frame_index < startup_frames + active_frames:
		move["active_frames"] = active_frames - 1
	else:
		move["recovery_frames"] = int(move["recovery_frames"]) - 1


func _shift_frame_window_after_insert(window: Dictionary, frame_index: int) -> void:
	if int(window["start_frame"]) >= frame_index:
		window["start_frame"] = int(window["start_frame"]) + 1
	if int(window["end_frame"]) >= frame_index:
		window["end_frame"] = int(window["end_frame"]) + 1


func _shift_frame_window_after_delete(window: Dictionary, frame_index: int) -> void:
	if int(window["start_frame"]) > frame_index:
		window["start_frame"] = int(window["start_frame"]) - 1
	if int(window["end_frame"]) > frame_index:
		window["end_frame"] = int(window["end_frame"]) - 1


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
