extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const DraftScript := preload("res://godot/scripts/creator_lab_authoring_draft.gd")

const TEMPLATE_ID := "combat_gray_s64"
const MOVE_ID := "basic_punch"

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_expanded_scalar_slice()

	var draft = _new_draft()
	var missing_methods: Array = []
	for method_name in [
		"edit_move_rhythm",
		"edit_move_active_window",
		"edit_first_hitbox",
		"edit_first_attack_hurtbox",
		"edit_move_events",
	]:
		if not draft.has_method(method_name):
			missing_methods.append(method_name)
			_expect(false, "Authoring Draft exposes public %s" % method_name)

	if missing_methods.is_empty():
		_run_complete_move_edit_slice()
		_run_atomic_rejection_slice()
		_run_invalid_retention_and_repair_slice()
		_run_rhythm_atomicity_slice()
		_run_invalid_numeric_diagnostics_slice()

	if _errors.is_empty():
		print("creator_lab_move_authoring_draft_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_move_authoring_draft_smoke=FAIL")
		quit(1)


func _run_expanded_scalar_slice() -> void:
	var draft = _new_draft()
	var initial: Dictionary = draft.snapshot()
	_expect(
		draft.edit_move_scalar(MOVE_ID, "frame_count", 9),
		"Draft accepts frame_count as a Move scalar intention"
	)
	var frame_count_edit: Dictionary = draft.snapshot()
	_expect(
		_move(frame_count_edit).get("frame_count", -1) == 9,
		"frame_count edit is visible in the current Draft"
	)
	_expect(
		_move(frame_count_edit, true).get("frame_count", -1) == 9,
		"valid frame_count edit advances the Preview snapshot"
	)
	_expect(bool(frame_count_edit.get("dirty", false)), "frame_count edit marks the Draft dirty")

	draft = _new_draft()
	_expect(
		draft.edit_move_scalar(MOVE_ID, "move_type", "utility"),
		"Draft accepts move_type as a Move scalar intention"
	)
	_expect(
		draft.edit_move_scalar(MOVE_ID, "state_context_override", "jump"),
		"Draft accepts state_context_override as a Move scalar intention"
	)
	_expect(
		draft.edit_move_scalar(MOVE_ID, "hitstop_frames", 4),
		"Draft accepts hitstop_frames as a Move scalar intention"
	)
	_expect(
		draft.edit_move_scalar(MOVE_ID, "multi_hit", true),
		"Draft accepts multi_hit as a Move scalar intention"
	)
	var scalar_edit: Dictionary = draft.snapshot()
	var move := _move(scalar_edit)
	_expect(str(move.get("move_type", "")) == "utility", "current Draft owns move_type")
	_expect(str(move.get("state_context_override", "")) == "jump", "current Draft owns state context")
	_expect(int(move.get("hitstop_frames", -1)) == 4, "current Draft owns hitstop")
	_expect(bool(move.get("multi_hit", false)), "current Draft owns multi-hit")
	_expect(scalar_edit.get("diagnostics", []).is_empty(), "valid scalar edits remain diagnostic-free")
	_expect(initial.get("bundle", {}) != scalar_edit.get("bundle", {}), "scalar edits change the Draft")


func _run_complete_move_edit_slice() -> void:
	var draft = _new_draft()
	_expect(draft.edit_move_scalar(MOVE_ID, "frame_count", 9), "Draft edits Move frame count")
	_expect(draft.edit_move_scalar(MOVE_ID, "move_type", "utility"), "Draft edits Move type")
	_expect(draft.edit_move_scalar(MOVE_ID, "state_context_override", "jump"), "Draft edits Move state context")
	_expect(draft.edit_move_scalar(MOVE_ID, "damage", 12), "Draft edits Move damage")
	_expect(draft.edit_move_scalar(MOVE_ID, "hitstop_frames", 4), "Draft edits Move hitstop")
	_expect(draft.edit_move_scalar(MOVE_ID, "multi_hit", true), "Draft edits Move multi-hit")
	_expect(draft.edit_move_rhythm(MOVE_ID, 2, 3, 4), "Draft edits complete Move rhythm")
	_expect(draft.edit_move_active_window(MOVE_ID, 2, 4), "Draft edits Move active window")
	_expect(
		draft.edit_first_hitbox(MOVE_ID, "hit_draft_fist", 2, 4, _rect(13, -47, 25, 15)),
		"Draft edits the first Move hitbox"
	)
	_expect(
		draft.edit_first_attack_hurtbox(MOVE_ID, "hurt_draft_body", 1, 7, _rect(-15, -55, 30, 46)),
		"Draft edits the first attack hurtbox"
	)
	_expect(draft.edit_move_events(MOVE_ID, _events("hit_draft_fist", 2, 4)), "Draft edits Move events")

	var snapshot: Dictionary = draft.snapshot()
	var current := _move(snapshot)
	var preview := _move(snapshot, true)
	_expect(str(current.get("move_type", "")) == "utility", "complete edit retains Move type")
	_expect(str(current.get("state_context_override", "")) == "jump", "complete edit retains state context")
	_expect(int(current.get("frame_count", -1)) == 9, "complete edit retains frame count")
	_expect(
		[int(current.get("startup_frames", -1)), int(current.get("active_frames", -1)), int(current.get("recovery_frames", -1))] == [2, 3, 4],
		"complete edit retains startup, active, and recovery together"
	)
	_expect(current.get("active_window", {}) == {"start_frame": 2, "end_frame": 4}, "complete edit retains active window")
	_expect(int(current.get("damage", -1)) == 12, "complete edit retains damage")
	_expect(int(current.get("hitstop_frames", -1)) == 4, "complete edit retains hitstop")
	_expect(bool(current.get("multi_hit", false)), "complete edit retains multi-hit")
	_expect(str(current.get("hitboxes", [])[0].get("hitbox_id", "")) == "hit_draft_fist", "complete edit retains hitbox")
	_expect(str(current.get("hurtboxes", [])[0].get("hurtbox_id", "")) == "hurt_draft_body", "complete edit retains attack hurtbox")
	_expect(current.get("events", []) == _events("hit_draft_fist", 2, 4), "complete edit retains frame events")
	_expect(snapshot.get("diagnostics", []).is_empty(), "complete valid Move edit has no diagnostics")
	_expect(bool(snapshot.get("dirty", false)), "complete Move edit marks Draft dirty")
	_expect(bool(snapshot.get("can_save", false)), "complete valid Move edit can Save")
	_expect(bool(snapshot.get("can_apply", false)), "complete valid Move edit can Apply")
	_expect(preview == current, "complete valid Move edit advances the latest valid Preview")


func _run_atomic_rejection_slice() -> void:
	var draft = _new_draft()
	var before: Dictionary = draft.snapshot()
	_expect(not draft.edit_move_scalar(MOVE_ID, "damage", "not-a-number"), "malformed scalar edit is rejected")
	_expect(draft.snapshot() == before, "rejected scalar edit leaves the complete Draft unchanged")

	_expect(
		not draft.edit_first_hitbox(MOVE_ID, "bad_hitbox_id", 3, 5, _rect(12, -48, 24, 14)),
		"malformed hitbox edit is rejected"
	)
	_expect(draft.snapshot() == before, "rejected hitbox edit leaves the complete Draft unchanged")

	_expect(
		not draft.edit_first_attack_hurtbox(MOVE_ID, "bad_hurtbox_id", 3, 5, _rect(-14, -52, 28, 44)),
		"malformed attack hurtbox edit is rejected"
	)
	_expect(draft.snapshot() == before, "rejected attack hurtbox edit leaves the complete Draft unchanged")

	_expect(
		not draft.edit_move_events("missing_move", _events("hit_fist_1", 3, 5)),
		"edit against a missing Move is rejected"
	)
	_expect(draft.snapshot() == before, "rejected events edit leaves the complete Draft unchanged")


func _run_invalid_retention_and_repair_slice() -> void:
	var draft = _new_draft()
	_expect(
		draft.edit_first_attack_hurtbox(MOVE_ID, "hurt_attack_body", 3, 5, _rect(-14, -52, 28, 44)),
		"valid attack hurtbox establishes the latest trusted Preview"
	)
	var trusted_preview: Dictionary = draft.snapshot().get("preview_bundle", {}).duplicate(true)

	_expect(draft.edit_move_scalar(MOVE_ID, "frame_count", 5), "locally valid frame count edit enters the Draft")
	var invalid: Dictionary = draft.snapshot()
	_expect(int(_move(invalid).get("frame_count", -1)) == 5, "temporarily invalid frame count remains visible in current Draft")
	_expect(not invalid.get("diagnostics", []).is_empty(), "temporarily invalid timing exposes diagnostics")
	_expect(not bool(invalid.get("can_save", true)), "temporarily invalid Draft cannot Save")
	_expect(not bool(invalid.get("can_apply", true)), "temporarily invalid Draft cannot Apply")
	_expect(invalid.get("preview_bundle", {}) == trusted_preview, "invalid frame count retains the latest valid Preview")

	_expect(draft.edit_move_active_window(MOVE_ID, 3, 4), "invalid Draft accepts an active-window repair")
	_expect(not draft.snapshot().get("diagnostics", []).is_empty(), "other invalid timing references still diagnose after window repair")
	_expect(draft.snapshot().get("preview_bundle", {}) == trusted_preview, "partial repair does not advance Preview")

	_expect(
		draft.edit_first_hitbox(MOVE_ID, "hit_fist_1", 3, 4, _rect(12, -48, 24, 14)),
		"invalid Draft accepts a hitbox-window repair"
	)
	_expect(not draft.snapshot().get("diagnostics", []).is_empty(), "hurtbox/events remain diagnostic after hitbox repair")
	_expect(draft.snapshot().get("preview_bundle", {}) == trusted_preview, "Preview remains trusted after hitbox-only repair")

	_expect(
		draft.edit_first_attack_hurtbox(MOVE_ID, "hurt_attack_body", 3, 4, _rect(-14, -52, 28, 44)),
		"invalid Draft accepts an attack-hurtbox repair"
	)
	_expect(not draft.snapshot().get("diagnostics", []).is_empty(), "events remain diagnostic after box repairs")
	_expect(draft.snapshot().get("preview_bundle", {}) == trusted_preview, "Preview remains trusted until all references are repaired")

	_expect(draft.edit_move_events(MOVE_ID, _events("hit_fist_1", 3, 4)), "invalid Draft accepts the final event repair")
	var repaired: Dictionary = draft.snapshot()
	_expect(repaired.get("diagnostics", []).is_empty(), "complete timing repair makes the Draft valid")
	_expect(bool(repaired.get("can_save", false)), "repaired Draft can Save")
	_expect(bool(repaired.get("can_apply", false)), "repaired Draft can Apply")
	_expect(int(_move(repaired, true).get("frame_count", -1)) == 5, "repaired valid frame count advances Preview")
	_expect(repaired.get("preview_bundle", {}) == repaired.get("bundle", {}), "repaired valid Draft becomes the trusted Preview")


func _run_rhythm_atomicity_slice() -> void:
	var draft = _new_draft()
	_expect(draft.edit_move_rhythm(MOVE_ID, 2, 2, 4), "valid rhythm edit succeeds")
	var valid: Dictionary = draft.snapshot()
	_expect(
		_rhythm(_move(valid)) == [2, 2, 4] and _rhythm(_move(valid, true)) == [2, 2, 4],
		"one rhythm intention commits startup, active, and recovery together"
	)

	var trusted_preview: Dictionary = valid.get("preview_bundle", {}).duplicate(true)
	_expect(draft.edit_move_rhythm(MOVE_ID, 1, 0, 7), "semantic-invalid rhythm remains editable")
	var invalid: Dictionary = draft.snapshot()
	_expect(_rhythm(_move(invalid)) == [1, 0, 7], "invalid rhythm still commits all three fields atomically")
	_expect(_diagnostics_contain(invalid, "active_frames"), "invalid rhythm explains the active-frame error")
	_expect(invalid.get("preview_bundle", {}) == trusted_preview, "invalid rhythm retains the previous valid Preview")


func _run_invalid_numeric_diagnostics_slice() -> void:
	var draft = _new_draft()
	var trusted_preview: Dictionary = draft.snapshot().get("preview_bundle", {}).duplicate(true)
	_expect(draft.edit_move_active_window(MOVE_ID, -1, 5), "negative active-window start remains editable")
	var invalid: Dictionary = draft.snapshot()
	_expect(int(_move(invalid).get("active_window", {}).get("start_frame", 0)) == -1, "negative active start is visible in current Draft")
	_expect(_diagnostics_contain(invalid, "active_window"), "negative active start exposes an active-window diagnostic")
	_expect(invalid.get("preview_bundle", {}) == trusted_preview, "negative active start does not update Preview")

	draft = _new_draft()
	trusted_preview = draft.snapshot().get("preview_bundle", {}).duplicate(true)
	_expect(draft.edit_move_scalar(MOVE_ID, "damage", -1), "negative damage remains editable")
	invalid = draft.snapshot()
	_expect(int(_move(invalid).get("damage", 0)) == -1, "negative damage is visible in current Draft")
	_expect(_diagnostics_contain(invalid, "damage"), "negative damage exposes a useful diagnostic")
	_expect(invalid.get("preview_bundle", {}) == trusted_preview, "negative damage does not update Preview")

	draft = _new_draft()
	trusted_preview = draft.snapshot().get("preview_bundle", {}).duplicate(true)
	_expect(draft.edit_move_scalar(MOVE_ID, "hitstop_frames", 61), "out-of-range hitstop remains editable")
	invalid = draft.snapshot()
	_expect(int(_move(invalid).get("hitstop_frames", 0)) == 61, "out-of-range hitstop is visible in current Draft")
	_expect(_diagnostics_contain(invalid, "hitstop_frames"), "out-of-range hitstop exposes a useful diagnostic")
	_expect(invalid.get("preview_bundle", {}) == trusted_preview, "out-of-range hitstop does not update Preview")


func _new_draft():
	var draft = DraftScript.new()
	draft.load_bundle(DataStore.load_runtime_bundle(TEMPLATE_ID))
	return draft


func _move(snapshot: Dictionary, preview: bool = false) -> Dictionary:
	var bundle_key := "preview_bundle" if preview else "bundle"
	var bundle: Dictionary = snapshot.get(bundle_key, {})
	var moves: Dictionary = bundle.get("moves", {})
	return moves.get(MOVE_ID, {})


func _rhythm(move: Dictionary) -> Array:
	return [
		int(move.get("startup_frames", -1)),
		int(move.get("active_frames", -1)),
		int(move.get("recovery_frames", -1)),
	]


func _events(hitbox_id: String, start_frame: int, end_frame: int) -> Array:
	return [
		{"frame": start_frame, "event_type": "enable_hitbox", "payload": {"hitbox_id": hitbox_id}},
		{"frame": end_frame, "event_type": "disable_hitbox", "payload": {"hitbox_id": hitbox_id}},
		{"frame": end_frame, "event_type": "apply_hitstop", "payload": {"frames": 3}},
	]


func _rect(x: float, y: float, width: float, height: float) -> Dictionary:
	return {"x": x, "y": y, "w": width, "h": height}


func _diagnostics_contain(snapshot: Dictionary, fragment: String) -> bool:
	for diagnostic in snapshot.get("diagnostics", []):
		if str(diagnostic).contains(fragment):
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
