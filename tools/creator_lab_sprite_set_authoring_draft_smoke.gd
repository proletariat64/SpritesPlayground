extends SceneTree

const DraftScript := preload("res://godot/scripts/creator_lab_authoring_draft.gd")

const SHARED_SEQUENCE := "shared"
const ALIASED_JUMP_SEQUENCE := "jump_alias_shared"
const UNRELATED_SEQUENCE := "unrelated"
const MOVE_IDS := ["idle", "followup"]
const INSERTED_SLOT := "empty://draft_sprite_test/shared/frame_inserted.png"

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var draft = DraftScript.new()
	var missing_methods: Array = []
	for method_name in [
		"insert_frame_slot",
		"delete_frame_slot",
		"replace_frame_slot",
		"mark_frame_slot",
		"last_operation_error",
	]:
		if not draft.has_method(method_name):
			missing_methods.append(method_name)
			_expect(false, "Authoring Draft exposes public %s" % method_name)

	if missing_methods.is_empty():
		_run_insert_decision_slice()
		_run_unrelated_keep_slice()
		_run_insert_shift_slice(1, [4, 2, 3], [4, 5], [3, 6], [4, 5, 5], "before active")
		_run_insert_shift_slice(3, [4, 2, 3], [4, 5], [2, 6], [4, 5, 5], "at startup boundary")
		_run_insert_shift_slice(4, [3, 3, 3], [3, 5], [2, 6], [3, 5, 5], "inside active")
		_run_insert_shift_slice(5, [3, 2, 4], [3, 4], [2, 6], [3, 4, 4], "at startup plus active boundary")
		_run_insert_shift_slice(7, [3, 2, 4], [3, 4], [2, 5], [3, 4, 4], "after active")
		_run_ambiguous_aliased_action_rejection_slice()
		_run_delete_slices()
		_run_replace_and_mark_slices()
		_run_source_copy_slice()

	if _errors.is_empty():
		print("creator_lab_sprite_set_authoring_draft_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_sprite_set_authoring_draft_smoke=FAIL")
		quit(1)


func _run_insert_decision_slice() -> void:
	var draft = _new_draft()
	var before: Dictionary = draft.snapshot()
	_expect(
		draft.insert_frame_slot(SHARED_SEQUENCE, 1, INSERTED_SLOT, false),
		"frame insertion accepts an explicit no-shift decision"
	)
	var unshifted: Dictionary = draft.snapshot()
	_expect(_sequence(unshifted).size() == 9, "explicit no-shift insertion grows only the frame sequence")
	_expect(_sequence(unshifted)[1] == INSERTED_SLOT, "explicit no-shift insertion preserves the requested slot")
	_expect(
		unshifted.get("bundle", {}).get("moves", {}) == before.get("bundle", {}).get("moves", {}),
		"explicit no-shift insertion leaves every related Move byte/deep-equal"
	)
	_expect(bool(unshifted.get("dirty", false)), "explicit no-shift insertion marks the Draft dirty")
	_expect(not unshifted.get("diagnostics", []).is_empty(), "related no-shift insertion exposes the sequence/timing mismatch")
	_expect(not bool(unshifted.get("can_save", true)), "related no-shift insertion blocks Save")
	_expect(not bool(unshifted.get("can_apply", true)), "related no-shift insertion blocks Apply")
	_expect(
		unshifted.get("preview_bundle", {}) == before.get("preview_bundle", {}),
		"related no-shift insertion retains the latest valid Preview"
	)

	draft = _new_draft()
	before = draft.snapshot()
	_expect(
		not draft.insert_frame_slot(SHARED_SEQUENCE, 1, INSERTED_SLOT, "shift"),
		"frame insertion rejects a non-boolean timing-shift decision"
	)
	_expect(str(draft.last_operation_error()).contains("shift timing"), "non-boolean insertion explains the required timing-shift decision")
	_expect(draft.snapshot() == before, "malformed shift decision leaves the complete Draft unchanged")

	draft = _new_draft()
	before = draft.snapshot()
	_expect(
		not draft.insert_frame_slot(SHARED_SEQUENCE, 1, INSERTED_SLOT, null),
		"frame insertion rejects a null timing-shift decision"
	)
	_expect(str(draft.last_operation_error()).contains("shift timing"), "null insertion explains the required timing-shift decision")
	_expect(draft.snapshot() == before, "null shift decision leaves the complete Draft unchanged")


func _run_unrelated_keep_slice() -> void:
	var draft = _new_draft()
	_expect(
		draft.insert_frame_slot(UNRELATED_SEQUENCE, 1, INSERTED_SLOT, false),
		"no-shift insertion accepts an unrelated frame sequence"
	)
	var snapshot: Dictionary = draft.snapshot()
	_expect(_sequence_for(snapshot, UNRELATED_SEQUENCE).size() == 9, "unrelated no-shift insertion grows its sequence")
	_expect(snapshot.get("diagnostics", []).is_empty(), "unrelated no-shift insertion remains valid")
	_expect(bool(snapshot.get("can_save", false)), "unrelated no-shift insertion remains Save eligible")
	_expect(bool(snapshot.get("can_apply", false)), "unrelated no-shift insertion remains Apply eligible")
	_expect(
		snapshot.get("preview_bundle", {}) == snapshot.get("bundle", {}),
		"unrelated no-shift insertion advances the trusted Preview"
	)


func _run_insert_shift_slice(
	frame_index: int,
	expected_rhythm: Array,
	expected_active_window: Array,
	expected_hurt_window: Array,
	expected_event_frames: Array,
	label: String
) -> void:
	var draft = _new_draft()
	_expect(
		draft.insert_frame_slot(SHARED_SEQUENCE, frame_index, INSERTED_SLOT, true),
		"frame insertion %s succeeds with an explicit shift decision" % label
	)
	var snapshot: Dictionary = draft.snapshot()
	var sequence: Array = _sequence(snapshot)
	_expect(sequence.size() == 9, "frame insertion %s grows the shared sequence once" % label)
	_expect(sequence[frame_index] == INSERTED_SLOT, "frame insertion %s preserves the requested slot" % label)
	for move_id in MOVE_IDS:
		var move: Dictionary = _move(snapshot, move_id)
		_expect(int(move.get("frame_count", -1)) == 9, "%s frame count shifts for insertion %s" % [move_id, label])
		_expect(_rhythm(move) == expected_rhythm, "%s rhythm shifts for insertion %s" % [move_id, label])
		_expect(_window(move.get("active_window", {})) == expected_active_window, "%s Move window shifts for insertion %s" % [move_id, label])
		_expect(_window(move.get("hitboxes", [])[0].get("active_window", {})) == expected_active_window, "%s hitbox window shifts for insertion %s" % [move_id, label])
		_expect(_window(move.get("hurtboxes", [])[0].get("active_window", {})) == expected_hurt_window, "%s hurtbox window shifts for insertion %s" % [move_id, label])
		_expect(_event_frames(move) == expected_event_frames, "%s events shift for insertion %s" % [move_id, label])
	_expect(bool(snapshot.get("dirty", false)), "valid insertion %s marks the Draft dirty" % label)
	_expect(snapshot.get("diagnostics", []).is_empty(), "valid insertion %s remains diagnostic-free" % label)
	_expect(snapshot.get("preview_bundle", {}) == snapshot.get("bundle", {}), "valid insertion %s advances the trusted Preview" % label)


func _run_ambiguous_aliased_action_rejection_slice() -> void:
	var draft = _new_aliased_action_draft()
	var before: Dictionary = draft.snapshot()
	_expect(
		not draft.insert_frame_slot(ALIASED_JUMP_SEQUENCE, 1, INSERTED_SLOT, true),
		"shifted insertion rejects a backing Move mapped to multiple distinct sequences"
	)
	var insert_error := str(draft.last_operation_error()).to_lower()
	_expect(insert_error.contains("jump") and insert_error.contains("multiple"), "ambiguous insertion names jump and its multiple sequences")
	_expect(draft.snapshot() == before, "ambiguous shifted insertion leaves the complete Draft unchanged")

	draft = _new_aliased_action_draft()
	before = draft.snapshot()
	_expect(
		not draft.delete_frame_slot(ALIASED_JUMP_SEQUENCE, 1),
		"deletion rejects a backing Move mapped to multiple distinct sequences"
	)
	var delete_error := str(draft.last_operation_error()).to_lower()
	_expect(delete_error.contains("jump") and delete_error.contains("multiple"), "ambiguous deletion names jump and its multiple sequences")
	_expect(draft.snapshot() == before, "ambiguous deletion leaves the complete Draft unchanged")


func _run_delete_slices() -> void:
	var draft = _new_draft()
	var before: Dictionary = draft.snapshot()
	_expect(not draft.delete_frame_slot(SHARED_SEQUENCE, 3), "deletion rejects a frame referenced by timing metadata")
	_expect(str(draft.last_operation_error()).contains("references frame 3"), "rejected deletion identifies the referenced frame")
	_expect(draft.snapshot() == before, "referenced-frame deletion leaves the complete Draft unchanged")

	draft = _new_draft()
	_expect(draft.delete_frame_slot(SHARED_SEQUENCE, 1), "deletion accepts an unreferenced frame")
	var deleted: Dictionary = draft.snapshot()
	_expect(_sequence(deleted).size() == 7, "unreferenced deletion shrinks the shared sequence once")
	for move_id in MOVE_IDS:
		var move: Dictionary = _move(deleted, move_id)
		_expect(int(move.get("frame_count", -1)) == 7, "%s frame count shifts after deletion" % move_id)
		_expect(_rhythm(move) == [2, 2, 3], "%s startup rhythm shifts after deletion" % move_id)
		_expect(_window(move.get("active_window", {})) == [2, 3], "%s Move window shifts after deletion" % move_id)
		_expect(_window(move.get("hitboxes", [])[0].get("active_window", {})) == [2, 3], "%s hitbox window shifts after deletion" % move_id)
		_expect(_window(move.get("hurtboxes", [])[0].get("active_window", {})) == [1, 4], "%s hurtbox window shifts after deletion" % move_id)
		_expect(_event_frames(move) == [2, 3, 3], "%s events shift after deletion" % move_id)
	_expect(deleted.get("preview_bundle", {}) == deleted.get("bundle", {}), "valid deletion advances the trusted Preview")


func _run_replace_and_mark_slices() -> void:
	var draft = _new_draft()
	var replacement := "user://draft_sprite_test_frame.png"
	_expect(draft.replace_frame_slot(SHARED_SEQUENCE, 0, replacement), "replacement accepts a supported URI for an existing slot")
	var replaced: Dictionary = draft.snapshot()
	_expect(_sequence(replaced)[0] == replacement, "replacement stores the requested frame URI")
	_expect(replaced.get("preview_bundle", {}) == replaced.get("bundle", {}), "valid replacement advances the trusted Preview")

	for status in ["empty", "missing", "placeholder"]:
		draft = _new_draft()
		_expect(draft.mark_frame_slot(SHARED_SEQUENCE, 2, status), "marking an existing slot %s succeeds" % status)
		var marked_slot := str(_sequence(draft.snapshot())[2])
		_expect(marked_slot.begins_with("%s://" % status), "%s marking stores an explicit slot state" % status)
		_expect(draft.snapshot().get("preview_bundle", {}) == draft.snapshot().get("bundle", {}), "%s marking advances the trusted Preview" % status)

	_run_atomic_frame_rejection("replacement rejects an out-of-range index", func(candidate) -> bool:
		return candidate.replace_frame_slot(SHARED_SEQUENCE, 8, replacement)
	)
	_run_atomic_frame_rejection("replacement rejects a malformed index", func(candidate) -> bool:
		return candidate.replace_frame_slot(SHARED_SEQUENCE, "zero", replacement)
	)
	_run_atomic_frame_rejection("replacement rejects an unsupported URI", func(candidate) -> bool:
		return candidate.replace_frame_slot(SHARED_SEQUENCE, 0, "bogus://frame.png")
	)
	_run_atomic_frame_rejection("marking rejects an out-of-range index", func(candidate) -> bool:
		return candidate.mark_frame_slot(SHARED_SEQUENCE, 8, "empty")
	)
	_run_atomic_frame_rejection("marking rejects an unsupported status", func(candidate) -> bool:
		return candidate.mark_frame_slot(SHARED_SEQUENCE, 0, "texture")
	)
	_run_atomic_frame_rejection("insertion rejects a malformed index", func(candidate) -> bool:
		return candidate.insert_frame_slot(SHARED_SEQUENCE, "one", INSERTED_SLOT, true)
	)
	_run_atomic_frame_rejection("insertion rejects an unsupported URI", func(candidate) -> bool:
		return candidate.insert_frame_slot(SHARED_SEQUENCE, 1, "bogus://frame.png", true)
	)


func _run_atomic_frame_rejection(label: String, operation: Callable) -> void:
	var draft = _new_draft()
	var before: Dictionary = draft.snapshot()
	_expect(not bool(operation.call(draft)), label)
	_expect(draft.snapshot() == before, "%s without changing the complete Draft" % label)


func _run_source_copy_slice() -> void:
	var source := _source_bundle()
	var source_before := source.duplicate(true)
	var draft = DraftScript.new()
	_expect(draft.load_bundle(source).is_empty(), "synthetic shared-sequence bundle is valid")
	_expect(draft.insert_frame_slot(SHARED_SEQUENCE, 1, INSERTED_SLOT, true), "source-copy insertion succeeds")
	_expect(source == source_before, "frame editing never aliases or mutates the loaded source bundle")


func _new_draft():
	var draft = DraftScript.new()
	_expect(draft.load_bundle(_source_bundle()).is_empty(), "synthetic shared-sequence bundle loads without diagnostics")
	return draft


func _new_aliased_action_draft():
	var draft = DraftScript.new()
	_expect(draft.load_bundle(_aliased_action_bundle()).is_empty(), "catalog-known aliased action bundle loads without diagnostics")
	return draft


func _aliased_action_bundle() -> Dictionary:
	var bundle := _source_bundle()
	bundle["template"]["equipped_moves"].append("jump")
	bundle["moves"]["jump"] = _move_fixture("jump")
	bundle["sprite_set"]["animation_clips"]["jump"] = {
		"clip_id": "jump",
		"frame_sequence_ref": "jump_primary",
		"loop": false,
	}
	bundle["sprite_set"]["frame_sequences"]["jump_primary"] = _frame_sequence_for("jump_primary")
	bundle["sprite_set"]["required_moves_mapping"]["jump"] = "jump"
	for action_id in ["jump_start", "jump_air", "jump_land"]:
		bundle["sprite_set"]["animation_clips"][action_id] = {
			"clip_id": action_id,
			"frame_sequence_ref": ALIASED_JUMP_SEQUENCE,
			"loop": false,
		}
		bundle["sprite_set"]["required_moves_mapping"][action_id] = action_id
	bundle["sprite_set"]["frame_sequences"][ALIASED_JUMP_SEQUENCE] = _frame_sequence_for(ALIASED_JUMP_SEQUENCE)
	return bundle


func _source_bundle() -> Dictionary:
	var moves := {}
	for move_id in MOVE_IDS:
		moves[move_id] = _move_fixture(move_id)
	return {
		"template": {
			"schema_version": "0.3",
			"template_id": "draft_sprite_test",
			"sprite_set_ref": "draft_sprite_test",
			"hurtboxes": {"hurt_body": _rect(-12, -48, 24, 40)},
			"foot_collision": {"center": {"x": 0, "y": -4}, "radius": {"x": 16, "y": 8}},
			"hp": 100,
			"walk_speed": 95,
			"run_speed": 150,
			"equipped_moves": MOVE_IDS.duplicate(),
		},
		"sprite_set": {
			"schema_version": "0.3",
			"sprite_set_id": "draft_sprite_test",
			"animation_clips": {
				"idle": {"clip_id": "idle", "frame_sequence_ref": SHARED_SEQUENCE, "loop": true},
				"followup": {"clip_id": "followup", "frame_sequence_ref": SHARED_SEQUENCE, "loop": false},
			},
			"frame_sequences": {
				SHARED_SEQUENCE: _frame_sequence(),
				UNRELATED_SEQUENCE: _frame_sequence_for(UNRELATED_SEQUENCE),
			},
			"required_moves_mapping": {"idle": "idle", "followup": "followup"},
		},
		"moves": moves,
	}


func _move_fixture(move_id: String) -> Dictionary:
	var hitbox_id := "hit_%s" % move_id
	return {
		"schema_version": "0.3",
		"move_id": move_id,
		"move_type": "locomotion" if move_id == "idle" else "combat",
		"frame_count": 8,
		"startup_frames": 3,
		"active_frames": 2,
		"recovery_frames": 3,
		"active_window": {"start_frame": 3, "end_frame": 4},
		"damage": 4,
		"hitstop_frames": 3,
		"hitboxes": [{
			"hitbox_id": hitbox_id,
			"active_window": {"start_frame": 3, "end_frame": 4},
			"rect": _rect(8, -36, 20, 12),
		}],
		"hurtboxes": [{
			"hurtbox_id": "hurt_%s" % move_id,
			"active_window": {"start_frame": 2, "end_frame": 5},
			"rect": _rect(-12, -48, 24, 40),
		}],
		"multi_hit": false,
		"events": [
			{"frame": 3, "event_type": "enable_hitbox", "payload": {"hitbox_id": hitbox_id}},
			{"frame": 4, "event_type": "disable_hitbox", "payload": {"hitbox_id": hitbox_id}},
			{"frame": 4, "event_type": "apply_hitstop", "payload": {"frames": 3}},
		],
	}


func _frame_sequence() -> Array:
	return _frame_sequence_for(SHARED_SEQUENCE)


func _frame_sequence_for(sequence_id: String) -> Array:
	var frames: Array = []
	for frame_index in 8:
		frames.append("placeholder://draft_sprite_test/%s/frame_%03d.png" % [sequence_id, frame_index])
	return frames


func _sequence(snapshot: Dictionary) -> Array:
	return _sequence_for(snapshot, SHARED_SEQUENCE)


func _sequence_for(snapshot: Dictionary, sequence_id: String) -> Array:
	return snapshot.get("bundle", {}).get("sprite_set", {}).get("frame_sequences", {}).get(sequence_id, [])


func _move(snapshot: Dictionary, move_id: String) -> Dictionary:
	return snapshot.get("bundle", {}).get("moves", {}).get(move_id, {})


func _rhythm(move: Dictionary) -> Array:
	return [
		int(move.get("startup_frames", -1)),
		int(move.get("active_frames", -1)),
		int(move.get("recovery_frames", -1)),
	]


func _window(window: Dictionary) -> Array:
	return [int(window.get("start_frame", -1)), int(window.get("end_frame", -1))]


func _event_frames(move: Dictionary) -> Array:
	var frames: Array = []
	for event in move.get("events", []):
		frames.append(int(event.get("frame", -1)))
	return frames


func _rect(x: float, y: float, width: float, height: float) -> Dictionary:
	return {"x": x, "y": y, "w": width, "h": height}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
