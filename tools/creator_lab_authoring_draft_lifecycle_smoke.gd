extends SceneTree

const DraftScript := preload("res://godot/scripts/creator_lab_authoring_draft.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")

const SOURCE_TEMPLATE_ID := "combat_gray_s64"
const OTHER_TEMPLATE_ID := "miduo"
const MOVE_ID := "basic_punch"
const SAVED_DAMAGE := 13

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var draft = DraftScript.new()
	var required_methods := [
		"load_bundle",
		"edit_move_scalar",
		"snapshot",
		"accept_persisted_bundle",
		"discard_changes",
	]
	var missing_methods: Array = []
	for method_name in required_methods:
		if not draft.has_method(method_name):
			missing_methods.append(method_name)
			_expect(false, "Authoring Draft exposes public %s" % method_name)

	if missing_methods.is_empty():
		_run_lifecycle_slice(draft)

	if _errors.is_empty():
		print("creator_lab_authoring_draft_lifecycle_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_authoring_draft_lifecycle_smoke=FAIL")
		quit(1)


func _run_lifecycle_slice(draft) -> void:
	var source_bundle := DataStore.load_runtime_bundle(SOURCE_TEMPLATE_ID)
	var other_bundle := DataStore.load_runtime_bundle(OTHER_TEMPLATE_ID)
	_expect(not source_bundle.is_empty(), "source lifecycle fixture loads")
	_expect(not other_bundle.is_empty(), "switch-intent lifecycle fixture loads")
	if source_bundle.is_empty() or other_bundle.is_empty():
		return

	_expect(draft.load_bundle(source_bundle).is_empty(), "valid persisted bundle loads")
	var initial: Dictionary = draft.snapshot()
	_expect(not bool(initial.get("dirty", true)), "loaded persisted bundle starts clean")
	_expect(initial.get("bundle", {}) == initial.get("preview_bundle", {}), "loaded persisted bundle is the valid Preview baseline")

	_expect(draft.edit_move_scalar(MOVE_ID, "damage", SAVED_DAMAGE), "valid edit is accepted")
	var edited: Dictionary = draft.snapshot()
	_expect(bool(edited.get("dirty", false)), "successful edit marks the active Draft dirty")
	_expect(bool(edited.get("can_save", false)), "valid dirty Draft can Save")
	_expect(_damage(edited.get("bundle", {})) == SAVED_DAMAGE, "current Draft exposes the edited value")
	_expect(_damage(edited.get("preview_bundle", {})) == SAVED_DAMAGE, "valid edit advances the Preview")

	var before_rejected_load := edited.duplicate(true)
	var rejected_load_errors: Array = draft.load_bundle(other_bundle)
	_expect(not rejected_load_errors.is_empty(), "dirty Draft rejects an unmediated load intent")
	_expect(draft.snapshot() == before_rejected_load, "rejected dirty load leaves current, Preview, diagnostics, and baseline state unchanged")

	var before_rejected_accept: Dictionary = draft.snapshot().duplicate(true)
	var rejected_accept_errors: Array = draft.accept_persisted_bundle({})
	_expect(not rejected_accept_errors.is_empty(), "Draft rejects an invalid persisted-bundle acknowledgement")
	_expect(draft.snapshot() == before_rejected_accept, "rejected persisted-bundle acknowledgement is atomic")

	var saved_bundle: Dictionary = edited.get("bundle", {}).duplicate(true)
	_expect(draft.accept_persisted_bundle(saved_bundle).is_empty(), "Panel can acknowledge the exact bundle written to persistence")
	var saved: Dictionary = draft.snapshot()
	_expect(not bool(saved.get("dirty", true)), "persisted acknowledgement clears dirty state")
	_expect(not bool(saved.get("can_save", true)), "persisted clean baseline is not Save eligible")
	_expect(bool(saved.get("can_apply", false)), "persisted clean baseline remains Apply eligible")
	_expect(saved.get("bundle", {}) == saved_bundle, "persisted acknowledgement retains the saved current bundle")
	_expect(saved.get("preview_bundle", {}) == saved_bundle, "persisted acknowledgement retains the saved Preview")

	_expect(draft.edit_move_scalar(MOVE_ID, "damage", SAVED_DAMAGE + 1), "post-Save edit is accepted")
	_expect(bool(draft.snapshot().get("dirty", false)), "post-Save edit compares against the advanced baseline")
	_expect(draft.edit_move_scalar(MOVE_ID, "damage", SAVED_DAMAGE), "edit can return to the saved value")
	_expect(not bool(draft.snapshot().get("dirty", true)), "editing back to the persisted value becomes clean")

	_expect(draft.edit_move_scalar(MOVE_ID, "damage", SAVED_DAMAGE + 2), "valid discard fixture edit is accepted")
	var valid_dirty: Dictionary = draft.snapshot()
	_expect(valid_dirty.get("bundle", {}) == valid_dirty.get("preview_bundle", {}), "valid dirty edit advances Preview before Discard")
	_expect(draft.discard_changes(), "valid dirty Draft can be discarded")
	_assert_restored_saved_baseline(draft.snapshot(), saved_bundle, "valid Discard")

	var trusted_preview: Dictionary = draft.snapshot().get("preview_bundle", {}).duplicate(true)
	_expect(draft.edit_move_scalar(MOVE_ID, "frame_count", 5), "temporarily invalid edit remains in the current Draft")
	var invalid: Dictionary = draft.snapshot()
	_expect(bool(invalid.get("dirty", false)), "invalid accepted edit remains dirty")
	_expect(not invalid.get("diagnostics", []).is_empty(), "invalid accepted edit exposes diagnostics")
	_expect(not bool(invalid.get("can_save", true)), "invalid accepted edit cannot Save")
	_expect(not bool(invalid.get("can_apply", true)), "invalid accepted edit cannot Apply")
	_expect(invalid.get("preview_bundle", {}) == trusted_preview, "invalid accepted edit retains the last valid Preview")
	_expect(draft.discard_changes(), "invalid dirty Draft can be discarded")
	_assert_restored_saved_baseline(draft.snapshot(), saved_bundle, "invalid Discard")

	var before_rejected_edit: Dictionary = draft.snapshot().duplicate(true)
	_expect(not draft.edit_move_scalar(MOVE_ID, "damage", "not-an-integer"), "wrong-type edit intent is rejected")
	_expect(draft.snapshot() == before_rejected_edit, "rejected edit intent leaves the complete lifecycle state unchanged")

	_expect(draft.load_bundle(other_bundle).is_empty(), "clean Draft can load a different persisted bundle immediately")
	var switched: Dictionary = draft.snapshot()
	_expect(not bool(switched.get("dirty", true)), "clean load establishes a new clean baseline")
	_expect(
		str(switched.get("bundle", {}).get("template", {}).get("template_id", "")) == OTHER_TEMPLATE_ID,
		"clean load changes the active persisted identity"
	)
	_expect(switched.get("preview_bundle", {}) == switched.get("bundle", {}), "clean load advances the Preview to the new identity")


func _assert_restored_saved_baseline(snapshot: Dictionary, saved_bundle: Dictionary, label: String) -> void:
	_expect(snapshot.get("bundle", {}) == saved_bundle, "%s restores the saved current bundle" % label)
	_expect(snapshot.get("preview_bundle", {}) == saved_bundle, "%s restores the saved Preview bundle" % label)
	_expect(snapshot.get("diagnostics", []).is_empty(), "%s clears transient diagnostics" % label)
	_expect(not bool(snapshot.get("dirty", true)), "%s clears dirty state" % label)
	_expect(not bool(snapshot.get("can_save", true)), "%s leaves the clean Draft ineligible for Save" % label)
	_expect(bool(snapshot.get("can_apply", false)), "%s restores Apply eligibility" % label)


func _damage(bundle: Dictionary) -> int:
	return int(bundle.get("moves", {}).get(MOVE_ID, {}).get("damage", -1))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
