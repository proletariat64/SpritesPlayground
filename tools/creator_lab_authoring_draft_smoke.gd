extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")

const DRAFT_SCRIPT_PATH := "res://godot/scripts/creator_lab_authoring_draft.gd"
const TEMPLATE_ID := "combat_gray_s64"
const MOVE_ID := "basic_punch"
const ORIGINAL_DAMAGE := 8
const EDITED_DAMAGE := 13

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var move_path := DataStore.move_path(MOVE_ID)
	var persisted_move_before := FileAccess.get_file_as_string(move_path)
	_expect(not persisted_move_before.is_empty(), "fixture loads persisted basic_punch JSON")
	_run_headless_draft_slice(persisted_move_before)

	if _errors.is_empty():
		print("creator_lab_authoring_draft_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_authoring_draft_smoke=FAIL")
		quit(1)


func _run_headless_draft_slice(persisted_move_before: String) -> void:
	if not ResourceLoader.exists(DRAFT_SCRIPT_PATH):
		_expect(false, "Authoring Draft module exists at %s" % DRAFT_SCRIPT_PATH)
		return

	var draft_script = load(DRAFT_SCRIPT_PATH)
	if draft_script == null:
		_expect(false, "Authoring Draft script loads")
		return
	var draft = draft_script.new()
	for method_name in ["load_bundle", "edit_move_scalar", "snapshot"]:
		if not draft.has_method(method_name):
			_expect(false, "Authoring Draft exposes public %s" % method_name)
			return

	var source_bundle := DataStore.load_runtime_bundle(TEMPLATE_ID)
	var source_before := source_bundle.duplicate(true)
	_expect(draft.load_bundle(source_bundle).is_empty(), "Authoring Draft accepts the persisted source bundle")
	var initial: Dictionary = draft.snapshot()
	_expect(_snapshot_is_coherent(initial), "Authoring Draft loads one coherent Template, SpriteSet, and Moves bundle")
	_expect(not bool(initial.get("dirty", true)), "fresh Authoring Draft is clean")

	var detached_snapshot: Dictionary = draft.snapshot()
	detached_snapshot["bundle"]["moves"][MOVE_ID]["damage"] = 91
	detached_snapshot["preview_bundle"]["moves"][MOVE_ID]["damage"] = 92
	var after_detached_snapshot_attempt: Dictionary = draft.snapshot()
	_expect(
		_bundle_move_damage(after_detached_snapshot_attempt.get("bundle", {})) == ORIGINAL_DAMAGE
		and _bundle_move_damage(after_detached_snapshot_attempt.get("preview_bundle", {})) == ORIGINAL_DAMAGE
		and not bool(after_detached_snapshot_attempt.get("dirty", true)),
		"mutating a detached snapshot cannot bypass Draft ownership, dirty state, or valid Preview snapshot"
	)

	_expect(draft.edit_move_scalar(MOVE_ID, "damage", EDITED_DAMAGE), "representative public Draft edit succeeds")
	var edited: Dictionary = draft.snapshot()
	var current_bundle: Dictionary = edited.get("bundle", {})
	var preview_bundle: Dictionary = edited.get("preview_bundle", {})
	_expect(_bundle_move_damage(current_bundle) == EDITED_DAMAGE, "Draft owns the edited basic_punch damage")
	_expect(_bundle_move_damage(preview_bundle) == EDITED_DAMAGE, "valid edit advances the latest valid Preview snapshot")
	_expect(bool(edited.get("dirty", false)), "successful edit marks the Draft dirty")
	_expect(edited.get("diagnostics", []).is_empty(), "representative Draft edit remains valid")
	_expect(bool(edited.get("can_save", false)), "valid dirty Draft is save eligible")
	_expect(bool(edited.get("can_apply", false)), "valid dirty Draft is apply eligible")
	_expect(source_bundle == source_before, "Draft deep-copies its input instead of mutating the loaded bundle")
	_expect(_bundle_move_damage(source_bundle) == ORIGINAL_DAMAGE, "source bundle retains persisted damage 8")
	_expect(
		FileAccess.get_file_as_string(DataStore.move_path(MOVE_ID)) == persisted_move_before,
		"headless Draft edit does not persist basic_punch"
	)


func _snapshot_is_coherent(snapshot: Dictionary) -> bool:
	var bundle: Dictionary = snapshot.get("bundle", {})
	var template: Dictionary = bundle.get("template", {})
	var sprite_set: Dictionary = bundle.get("sprite_set", {})
	var moves: Dictionary = bundle.get("moves", {})
	if str(template.get("template_id", "")) != TEMPLATE_ID:
		return false
	if str(template.get("sprite_set_ref", "")) != str(sprite_set.get("sprite_set_id", "")):
		return false
	var equipped_moves: Array = template.get("equipped_moves", [])
	if equipped_moves.size() != moves.size():
		return false
	for move_id in equipped_moves:
		if not moves.has(str(move_id)):
			return false
	return true


func _bundle_move_damage(bundle: Dictionary) -> int:
	var moves: Dictionary = bundle.get("moves", {})
	var move: Dictionary = moves.get(MOVE_ID, {})
	return int(move.get("damage", -1))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
