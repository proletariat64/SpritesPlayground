extends SceneTree

const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const DocumentRules := preload("res://godot/scripts/prd_v0_3_document_rules.gd")
const SpriteFramesGenerator := preload("res://godot/scripts/spriteframes_generator.gd")
const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")

const DATA_ROOT := "user://creator_lab_issue_47_switching_smoke"
const SOURCE_TEMPLATE_ID := "combat_gray_s64"
const TARGET_TEMPLATE_ID := "miduo"
const SOURCE_SPRITE_SET_ID := "issue47_source_sprite"
const TARGET_SPRITE_SET_ID := "issue47_target_sprite"
const MOVE_ID := "basic_punch"
const TARGET_MOVE_ID := "miduo_jab"
const EDITED_SOURCE_HP := 111
const EDITED_TARGET_HP := 122
const EDITED_TARGET_DAMAGE := 9

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_fixture()

	var panel: PanelContainer = PanelScript.new()
	root.add_child(panel)
	var required_methods := [
		"setup",
		"save_all",
		"discard_current",
		"request_template_switch",
		"request_bound_instance_switch",
		"resolve_pending_switch",
	]
	var missing_methods: Array = []
	for method_name in required_methods:
		if not panel.has_method(method_name):
			missing_methods.append(method_name)
			_expect(false, "Creator Lab Panel exposes public %s" % method_name)
	if _method_argument_count(panel, "setup") < 1:
		missing_methods.append("setup(data_root)")
		_expect(false, "Creator Lab Panel setup accepts an explicit data root")

	if missing_methods.is_empty():
		await _run_switching_slice(panel)

	panel.queue_free()
	await process_frame
	_cleanup_fixture()

	if _errors.is_empty():
		print("creator_lab_dirty_switching_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_dirty_switching_smoke=FAIL")
		quit(1)


func _run_switching_slice(panel: PanelContainer) -> void:
	var source_bundle := _fixture_bundle(SOURCE_TEMPLATE_ID, SOURCE_SPRITE_SET_ID)
	var target_bundle := _fixture_bundle(TARGET_TEMPLATE_ID, TARGET_SPRITE_SET_ID)
	_expect(not source_bundle.is_empty(), "source switching fixture loads")
	_expect(not target_bundle.is_empty(), "target switching fixture loads")
	if source_bundle.is_empty() or target_bundle.is_empty():
		return

	_expect(DataStore.save_runtime_bundle(source_bundle, DATA_ROOT).is_empty(), "source fixture persists through the real DataStore")
	_expect(DataStore.save_runtime_bundle(target_bundle, DATA_ROOT).is_empty(), "target fixture persists through the real DataStore")
	var fixture_paths := _fixture_paths(source_bundle, target_bundle)
	var initial_bytes := _read_bytes(fixture_paths)
	_expect(not initial_bytes.is_empty(), "switching fixture captures persisted JSON bytes")

	panel.setup(DATA_ROOT)
	await process_frame
	_expect(_active_template_id(panel) == SOURCE_TEMPLATE_ID, "explicit-root setup loads the source template")
	_expect(not bool(panel.draft_status().get("dirty", true)), "explicit-root setup starts with a clean Draft")

	var clean_target_result: Dictionary = panel.request_template_switch(TARGET_TEMPLATE_ID)
	_expect(_outcome(clean_target_result) == "switched", "clean template request switches immediately")
	_expect(_active_template_id(panel) == TARGET_TEMPLATE_ID, "clean switch selects the target template")
	_expect(not bool(panel.draft_status().get("dirty", true)), "clean switch loads a clean target Draft")
	var clean_source_result: Dictionary = panel.request_template_switch(SOURCE_TEMPLATE_ID)
	_expect(_outcome(clean_source_result) == "switched", "second clean template request switches immediately")
	_expect(_active_template_id(panel) == SOURCE_TEMPLATE_ID, "second clean switch restores the source template")

	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	playground.set_process(false)
	playground.set_physics_process(false)
	var player: Node = playground.player
	var second_instance: Node = playground.dummy
	await _run_playground_selection_slice(playground, player, second_instance)
	player.apply_template_id(SOURCE_TEMPLATE_ID)
	second_instance.apply_template_id(SOURCE_TEMPLATE_ID)
	var player_live_before := _live_state(player)
	var second_live_before := _live_state(second_instance)

	var clean_bind_result: Dictionary = panel.request_bound_instance_switch(player)
	_expect(_outcome(clean_bind_result) == "switched", "clean bound-instance request binds immediately")
	_expect(_bound_instance_id(panel) == str(player.instance_id), "clean bind selects the requested Playground instance")
	panel.select_action(MOVE_ID)
	panel.set_preview_frame(3)

	panel.set_hp(EDITED_SOURCE_HP)
	var valid_dirty_before_cancel := _authored_state(panel)
	var bytes_before_cancel := _read_bytes(fixture_paths)
	_expect(bool(panel.draft_status().get("dirty", false)), "valid Panel edit marks the Draft dirty")
	_expect(int(panel.preview_sprite().max_hp) == EDITED_SOURCE_HP, "valid dirty edit advances the real Preview")
	_expect(_live_state(player) == player_live_before, "valid dirty edit does not Apply to the bound Playground instance")

	var dirty_request: Dictionary = panel.request_template_switch(TARGET_TEMPLATE_ID)
	_expect(_outcome(dirty_request) == "decision_required", "dirty template request requires an explicit decision")
	_expect(_authored_state(panel) == valid_dirty_before_cancel, "pending dirty template request does not mutate Draft, Preview, template, selection, or binding")
	_expect(_read_bytes(fixture_paths) == bytes_before_cancel, "pending dirty template request does not write JSON")
	var cancel_result: Dictionary = panel.resolve_pending_switch("cancel")
	_expect(_outcome(cancel_result) == "cancelled", "Cancel resolves the pending template request")
	_expect(_authored_state(panel) == valid_dirty_before_cancel, "Cancel preserves the exact Draft, Preview, template, selection, and binding")
	_expect(_read_bytes(fixture_paths) == bytes_before_cancel, "Cancel leaves persisted JSON bytes unchanged")

	var before_bound_cancel := _authored_state(panel)
	var dirty_bind_request: Dictionary = panel.request_bound_instance_switch(second_instance)
	_expect(_outcome(dirty_bind_request) == "decision_required", "dirty same-template second-instance bind requires a decision")
	_expect(_authored_state(panel) == before_bound_cancel, "pending bound-instance request does not change selection or authored state")
	var bind_cancel_result: Dictionary = panel.resolve_pending_switch("cancel")
	_expect(_outcome(bind_cancel_result) == "cancelled", "Cancel resolves the pending bound-instance request")
	_expect(_authored_state(panel) == before_bound_cancel, "bound-instance Cancel preserves Draft, Preview, template, and player binding")
	_expect(_bound_instance_id(panel) == str(player.instance_id), "bound-instance Cancel keeps the original Playground selection")

	_run_reload_lifecycle_slice(panel)
	panel.set_hp(EDITED_SOURCE_HP)
	_run_legacy_load_lifecycle_slice(panel)

	var trusted_valid_preview_hp := int(panel.preview_sprite().max_hp)
	panel.set_hp(0)
	var invalid_before_save := _authored_state(panel)
	_expect(not panel.draft_status().get("diagnostics", []).is_empty(), "invalid Draft exposes diagnostics before switching")
	_expect(not bool(panel.draft_status().get("can_save", true)), "invalid Draft cannot Save")
	_expect(int(panel.preview_sprite().max_hp) == trusted_valid_preview_hp, "invalid Draft retains the last valid Preview")
	var invalid_request: Dictionary = panel.request_template_switch(TARGET_TEMPLATE_ID)
	_expect(_outcome(invalid_request) == "decision_required", "invalid dirty Draft still offers a switch decision")
	var invalid_save_result: Dictionary = panel.resolve_pending_switch("save")
	_expect(_outcome(invalid_save_result) == "save_failed", "Save decision reports failure for an invalid Draft")
	_expect(_authored_state(panel) == invalid_before_save, "failed invalid Save retains current Draft, last-valid Preview, template, selection, and binding")
	_expect(_read_bytes(fixture_paths) == initial_bytes, "failed invalid Save leaves every fixture JSON byte unchanged")
	_expect(_active_template_id(panel) == SOURCE_TEMPLATE_ID, "failed invalid Save does not switch templates")
	_expect(_outcome(panel.resolve_pending_switch("cancel")) == "cancelled", "failed Save keeps the pending request cancellable")

	panel.set_hp(EDITED_SOURCE_HP)
	_expect(panel.draft_status().get("diagnostics", []).is_empty(), "invalid Draft can be repaired before another decision")
	var valid_before_io_failure := _authored_state(panel)
	var bytes_before_io_failure := _read_bytes(fixture_paths)
	_expect(_block_templates_directory(), "hard-failure fixture replaces the templates directory with a file")
	var io_save_errors: Array = panel.save_all()
	_restore_templates_directory()
	_expect(not io_save_errors.is_empty(), "real local text persistence reports a hard write failure")
	_expect(_authored_state(panel) == valid_before_io_failure, "failed valid Save retains the complete dirty Draft and Preview")
	_expect(_read_bytes(fixture_paths) == bytes_before_io_failure, "failed valid Save leaves all persisted JSON bytes unchanged")

	var discard_request: Dictionary = panel.request_template_switch(TARGET_TEMPLATE_ID)
	_expect(_outcome(discard_request) == "decision_required", "repaired dirty Draft still requires a switch decision")
	var discard_result: Dictionary = panel.resolve_pending_switch("discard")
	_expect(_outcome(discard_result) == "switched", "Discard resolves the request and switches templates")
	_expect(_active_template_id(panel) == TARGET_TEMPLATE_ID, "Discard loads the requested target template")
	_expect(not bool(panel.draft_status().get("dirty", true)), "Discard switch establishes the target clean baseline")
	_expect(int(DataStore.load_template(SOURCE_TEMPLATE_ID, DATA_ROOT).get("hp", -1)) == 100, "Discard leaves the source template persisted value unchanged")
	_expect(_read_bytes(fixture_paths) == initial_bytes, "Discard switch performs no persistence writes")

	panel.select_move(TARGET_MOVE_ID)
	panel.set_hp(EDITED_TARGET_HP)
	panel.set_move_scalar("damage", EDITED_TARGET_DAMAGE)
	var sequence_ref := _sequence_ref_for_bundle(target_bundle, TARGET_MOVE_ID)
	_expect(not sequence_ref.is_empty(), "target fixture exposes the mapped Move frame sequence")
	if not sequence_ref.is_empty():
		_expect(panel.mark_frame_slot(sequence_ref, 0, "empty"), "target SpriteSet edit uses the public frame-slot seam")
	var target_dirty: Dictionary = panel.draft_status()
	_expect(bool(target_dirty.get("dirty", false)), "complete target bundle edit is dirty")
	_expect(target_dirty.get("diagnostics", []).is_empty(), "complete target bundle edit remains valid")
	_expect(int(panel.preview_sprite().max_hp) == EDITED_TARGET_HP, "complete target edit advances Preview without Apply")
	var expected_saved_target := target_bundle.duplicate(true)
	expected_saved_target["template"]["hp"] = EDITED_TARGET_HP
	expected_saved_target["moves"][TARGET_MOVE_ID]["damage"] = EDITED_TARGET_DAMAGE
	if not sequence_ref.is_empty():
		expected_saved_target["sprite_set"]["frame_sequences"][sequence_ref][0] = (
			"empty://%s/%s/frame_000.png" % [TARGET_SPRITE_SET_ID, sequence_ref]
		)
	expected_saved_target = DocumentRules.normalize_runtime_bundle(expected_saved_target)
	var target_template_path := DataStore.template_path(TARGET_TEMPLATE_ID, DATA_ROOT)
	var target_move_path := DataStore.move_path(TARGET_MOVE_ID, DATA_ROOT)
	var target_sprite_path := DataStore.sprite_set_path(TARGET_SPRITE_SET_ID, DATA_ROOT)
	var target_bytes_before := {
		target_template_path: FileAccess.get_file_as_string(target_template_path),
		target_move_path: FileAccess.get_file_as_string(target_move_path),
		target_sprite_path: FileAccess.get_file_as_string(target_sprite_path),
	}

	var save_switch_request: Dictionary = panel.request_template_switch(SOURCE_TEMPLATE_ID)
	_expect(_outcome(save_switch_request) == "decision_required", "valid dirty target requires a switch decision")
	var save_switch_result: Dictionary = panel.resolve_pending_switch("save")
	_expect(_outcome(save_switch_result) == "switched", "successful Save writes the bundle before switching")
	_expect(_active_template_id(panel) == SOURCE_TEMPLATE_ID, "successful Save continues to the requested source template")
	_expect(not bool(panel.draft_status().get("dirty", true)), "successful Save-then-switch leaves the loaded source clean")
	var persisted_target := DataStore.load_runtime_bundle(TARGET_TEMPLATE_ID, DATA_ROOT)
	var normalized_persisted_target := DocumentRules.normalize_runtime_bundle(persisted_target)
	var persisted_difference := _first_difference(expected_saved_target, normalized_persisted_target)
	_expect(persisted_difference.is_empty(), "Save-then-switch persists the complete Template, SpriteSet, and Moves bundle: %s" % persisted_difference)
	_expect(FileAccess.get_file_as_string(target_template_path) != target_bytes_before[target_template_path], "Save changes target CharacterTemplate JSON bytes")
	_expect(FileAccess.get_file_as_string(target_move_path) != target_bytes_before[target_move_path], "Save changes target Move JSON bytes")
	_expect(FileAccess.get_file_as_string(target_sprite_path) != target_bytes_before[target_sprite_path], "Save changes target SpriteSet JSON bytes")

	var reload_target_result: Dictionary = panel.request_template_switch(TARGET_TEMPLATE_ID)
	_expect(_outcome(reload_target_result) == "switched", "clean request reloads the saved target immediately")
	panel.select_move(TARGET_MOVE_ID)
	_expect(_normalized_move(panel.selected_move_json()) == expected_saved_target["moves"][TARGET_MOVE_ID], "public Move seam reloads the saved target Move exactly")
	_expect(not bool(panel.draft_status().get("dirty", true)), "reloaded saved target uses the advanced clean baseline")
	_expect(int(panel.preview_sprite().max_hp) == EDITED_TARGET_HP, "reloaded saved target restores its valid Preview")

	panel.set_hp(EDITED_TARGET_HP + 1)
	_expect(bool(panel.draft_status().get("dirty", false)), "post-Save target edit compares against the advanced baseline")
	_expect(panel.discard_current(), "public Discard restores the active saved target without switching")
	_expect(_normalized_move(panel.selected_move_json()) == expected_saved_target["moves"][TARGET_MOVE_ID], "public Discard restores the saved target Move")
	_expect(not bool(panel.draft_status().get("dirty", true)), "public Discard clears dirty state")
	_expect(int(panel.preview_sprite().max_hp) == EDITED_TARGET_HP, "public Discard restores the saved Preview")
	_expect(DocumentRules.normalize_runtime_bundle(DataStore.load_runtime_bundle(TARGET_TEMPLATE_ID, DATA_ROOT)) == expected_saved_target, "public Discard leaves the complete saved target bundle unchanged on disk")

	_expect(_live_state(player) == player_live_before, "Save, Discard, Cancel, and template switching never implicitly Apply to the bound player")
	_expect(_live_state(second_instance) == second_live_before, "lifecycle decisions never mutate the unselected Playground instance")

	playground.queue_free()
	await process_frame


func _run_playground_selection_slice(playground: Node, player: Node, second_instance: Node) -> void:
	var integrated_panel: PanelContainer = playground.creator_lab
	_expect(integrated_panel != null, "Playground exposes its real Creator Lab Panel")
	if integrated_panel == null:
		return
	_expect(playground.selected_character == player, "Playground integration fixture starts with the player selected")
	var preview_sprite: Node = integrated_panel.preview_sprite()
	_expect(preview_sprite != null, "Playground Creator Lab exposes its real Preview sprite")
	if preview_sprite == null:
		return

	integrated_panel.set_hp(int(preview_sprite.max_hp) + 1)
	_expect(bool(integrated_panel.draft_status().get("dirty", false)), "Playground Creator Lab becomes dirty through its public edit seam")
	playground.select_dummy_character()
	await process_frame
	_expect(
		playground.selected_character == player,
		"dirty public dummy selection keeps the global player selection while the binding decision is pending"
	)
	var cancel_result: Dictionary = integrated_panel.resolve_pending_switch("cancel")
	await process_frame
	_expect(_outcome(cancel_result) == "cancelled", "Playground binding decision can be cancelled publicly")
	_expect(playground.selected_character == player, "Cancel preserves the global player selection")

	playground.select_character(second_instance)
	await process_frame
	var discard_result: Dictionary = integrated_panel.resolve_pending_switch("discard")
	await process_frame
	_expect(_outcome(discard_result) == "switched", "Playground binding decision can discard the Draft publicly")
	_expect(
		playground.selected_character == second_instance,
		"Discard commits the requested dummy as the global selected character"
	)
	_expect(not bool(integrated_panel.draft_status().get("dirty", true)), "Discarded Playground binding establishes a clean Draft")

	playground.select_character(player)
	await process_frame
	_expect(playground.selected_character == player, "clean public selection commits the player immediately")

	await _run_dirty_selected_npc_removal_slice(playground, integrated_panel)


func _run_reload_lifecycle_slice(panel: PanelContainer) -> void:
	var before_reload_cancel := _authored_state(panel)
	var reload_cancel_errors: Array = panel.reload_current()
	_expect(not reload_cancel_errors.is_empty(), "dirty public Reload reports that a lifecycle decision is required")
	_expect(bool(panel.pending_switch_status().get("pending", false)), "dirty public Reload establishes a pending lifecycle decision")
	_expect(_authored_state(panel) == before_reload_cancel, "pending dirty Reload does not discard or reload the active Draft")
	var reload_cancel_result: Dictionary = panel.resolve_pending_switch("cancel")
	_expect(_outcome(reload_cancel_result) == "cancelled", "dirty public Reload can be cancelled")
	_expect(_authored_state(panel) == before_reload_cancel, "Reload Cancel preserves the exact Draft, Preview, template, selection, and binding")

	if not bool(panel.draft_status().get("dirty", false)):
		panel.set_hp(EDITED_SOURCE_HP)
	var reload_discard_errors: Array = panel.reload_current()
	_expect(not reload_discard_errors.is_empty(), "second dirty public Reload reports that a lifecycle decision is required")
	_expect(bool(panel.pending_switch_status().get("pending", false)), "second dirty public Reload remains publicly resolvable")
	var reload_discard_result: Dictionary = panel.resolve_pending_switch("discard")
	_expect(_outcome(reload_discard_result) == "switched", "Reload Discard restores the saved document and completes the reload")
	_expect(_active_template_id(panel) == SOURCE_TEMPLATE_ID, "Reload Discard keeps the active template identity")
	_expect(not bool(panel.draft_status().get("dirty", true)), "Reload Discard establishes the saved clean baseline")
	_expect(int(panel.preview_sprite().max_hp) == 100, "Reload Discard restores the saved valid Preview")


func _run_legacy_load_lifecycle_slice(panel: PanelContainer) -> void:
	var before_legacy_load := _authored_state(panel)
	var legacy_errors: Array = panel.load_template_id(TARGET_TEMPLATE_ID)
	_expect(not legacy_errors.is_empty(), "legacy load_template_id reports dirty lifecycle interception instead of an empty success")
	_expect(bool(panel.pending_switch_status().get("pending", false)), "legacy load_template_id keeps its dirty switch pending for public resolution")
	_expect(_authored_state(panel) == before_legacy_load, "legacy load_template_id leaves the dirty Draft and Preview unchanged")
	var cancel_result: Dictionary = panel.resolve_pending_switch("cancel")
	_expect(_outcome(cancel_result) == "cancelled", "legacy load_template_id pending switch can be cancelled")
	_expect(_authored_state(panel) == before_legacy_load, "legacy load_template_id Cancel preserves the exact authored state")


func _run_dirty_selected_npc_removal_slice(playground: Node, integrated_panel: PanelContainer) -> void:
	var removable: Node = playground.add_npc("miduo_blue", true)
	await process_frame
	_expect(removable != null, "dirty-removal fixture adds a second public NPC")
	if removable == null:
		return
	_expect(playground.selected_character == removable, "dirty-removal fixture selects the removable NPC")
	_expect(_bound_instance_id(integrated_panel) == str(removable.instance_id), "dirty-removal fixture binds Creator Lab to the removable NPC")
	integrated_panel.set_hp(int(integrated_panel.preview_sprite().max_hp) + 1)
	_expect(bool(integrated_panel.draft_status().get("dirty", false)), "selected-NPC removal fixture has a dirty Draft")
	var npc_count_before: int = int(playground.npc_count())
	var removable_id := str(removable.instance_id)

	playground.remove_selected_npc()
	_expect(bool(integrated_panel.pending_switch_status().get("pending", false)), "dirty selected-NPC removal establishes a visible lifecycle decision")
	_expect(playground.npc_count() == npc_count_before, "dirty selected-NPC removal does not remove the NPC before a decision")
	_expect(playground.npcs.has(removable), "dirty selected-NPC removal retains the NPC in the public collection")
	_expect(not removable.is_queued_for_deletion(), "dirty selected-NPC removal does not queue_free the NPC before a decision")
	_expect(playground.selected_character == removable, "dirty selected-NPC removal retains the global selection before a decision")
	_expect(_bound_instance_id(integrated_panel) == removable_id, "dirty selected-NPC removal retains the Creator Lab binding before a decision")

	var cancel_result: Dictionary = integrated_panel.resolve_pending_switch("cancel")
	await process_frame
	_expect(_outcome(cancel_result) == "cancelled", "dirty selected-NPC removal can be cancelled publicly")
	_expect(is_instance_valid(removable), "selected-NPC removal Cancel keeps the original NPC alive")
	_expect(playground.npc_count() == npc_count_before and playground.npcs.has(removable), "selected-NPC removal Cancel retains the original NPC collection")
	_expect(playground.selected_character == removable, "selected-NPC removal Cancel retains the original global selection")
	_expect(_bound_instance_id(integrated_panel) == removable_id, "selected-NPC removal Cancel retains the original Creator Lab binding")

	_expect(integrated_panel.discard_current(), "user can explicitly Discard before retrying selected-NPC removal")
	_expect(playground.remove_selected_npc(), "clean retry completes selected-NPC removal")
	await process_frame
	_expect(playground.npc_count() == npc_count_before - 1, "clean retry removes exactly one NPC")
	_expect(not playground.npcs.has(removable), "clean retry removes the intended NPC from the public collection")
	_expect(playground.selected_character != null and playground.selected_character != removable, "clean retry selects a surviving replacement")
	var replacement_id := (
		str(playground.selected_character.instance_id) if playground.selected_character != null else ""
	)
	_expect(not replacement_id.is_empty() and _bound_instance_id(integrated_panel) == replacement_id, "clean retry binds Creator Lab to the replacement selection")


func _fixture_bundle(template_id: String, sprite_set_id: String) -> Dictionary:
	var bundle := DataStore.load_runtime_bundle(template_id).duplicate(true)
	if bundle.is_empty():
		return {}
	bundle["template"]["sprite_set_ref"] = sprite_set_id
	bundle["sprite_set"]["sprite_set_id"] = sprite_set_id
	return bundle


func _fixture_paths(source_bundle: Dictionary, target_bundle: Dictionary) -> Array:
	var paths := [
		DataStore.template_path(SOURCE_TEMPLATE_ID, DATA_ROOT),
		DataStore.template_path(TARGET_TEMPLATE_ID, DATA_ROOT),
		DataStore.sprite_set_path(SOURCE_SPRITE_SET_ID, DATA_ROOT),
		DataStore.sprite_set_path(TARGET_SPRITE_SET_ID, DATA_ROOT),
	]
	var move_ids := {}
	for bundle in [source_bundle, target_bundle]:
		for move_id in bundle.get("moves", {}).keys():
			move_ids[str(move_id)] = true
	var sorted_move_ids: Array = move_ids.keys()
	sorted_move_ids.sort()
	for move_id in sorted_move_ids:
		paths.append(DataStore.move_path(str(move_id), DATA_ROOT))
	return paths


func _read_bytes(paths: Array) -> Dictionary:
	var bytes := {}
	for path in paths:
		bytes[str(path)] = FileAccess.get_file_as_string(str(path))
	return bytes


func _authored_state(panel: PanelContainer) -> Dictionary:
	var status: Dictionary = panel.draft_status()
	var preview: Dictionary = panel.preview_observation().duplicate(true)
	return {
		"template_id": str(status.get("template_id", "")),
		"bound_instance_id": str(status.get("bound_instance_id", "")),
		"dirty": bool(status.get("dirty", false)),
		"diagnostics": status.get("diagnostics", []).duplicate(true),
		"can_save": bool(status.get("can_save", false)),
		"can_apply": bool(status.get("can_apply", false)),
		"preview": preview,
		"preview_hp": int(panel.preview_sprite().max_hp) if panel.preview_sprite() != null else -1,
		"preview_frame": int(preview.get("frame", -1)),
		"selected_move": panel.selected_move_json().duplicate(true),
	}


func _active_template_id(panel: PanelContainer) -> String:
	var status: Dictionary = panel.draft_status()
	return str(status.get("template_id", ""))


func _bound_instance_id(panel: PanelContainer) -> String:
	var status: Dictionary = panel.draft_status()
	return str(status.get("bound_instance_id", ""))


func _sequence_ref_for_bundle(bundle: Dictionary, move_id: String) -> String:
	var sprite_set: Dictionary = bundle.get("sprite_set", {})
	var mapping: Dictionary = sprite_set.get("required_moves_mapping", {})
	var clips: Dictionary = sprite_set.get("animation_clips", {})
	var clip_id := str(mapping.get(move_id, ""))
	return str(clips.get(clip_id, {}).get("frame_sequence_ref", ""))


func _live_state(instance: Node) -> Dictionary:
	return {
		"instance_id": str(instance.instance_id),
		"template_id": str(instance.template_id),
		"sprite_set_id": str(instance.sprite_set_id),
		"max_hp": int(instance.max_hp),
		"walk_speed": float(instance.walk_speed),
		"run_speed": float(instance.run_speed),
	}


func _outcome(result: Dictionary) -> String:
	return str(result.get("outcome", ""))


func _method_argument_count(instance: Object, method_name: String) -> int:
	for method in instance.get_method_list():
		if str(method.get("name", "")) == method_name:
			return method.get("args", []).size()
	return -1


func _block_templates_directory() -> bool:
	var templates_path := DATA_ROOT.path_join("templates")
	var backup_path := DATA_ROOT.path_join("templates_backup")
	var templates_absolute := ProjectSettings.globalize_path(templates_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if DirAccess.rename_absolute(templates_absolute, backup_absolute) != OK:
		return false
	var blocker := FileAccess.open(templates_path, FileAccess.WRITE)
	if blocker == null:
		DirAccess.rename_absolute(backup_absolute, templates_absolute)
		return false
	blocker.store_string("intentional issue 47 write blocker\n")
	return true


func _restore_templates_directory() -> void:
	var templates_path := DATA_ROOT.path_join("templates")
	var backup_path := DATA_ROOT.path_join("templates_backup")
	var templates_absolute := ProjectSettings.globalize_path(templates_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(templates_path):
		DirAccess.remove_absolute(templates_absolute)
	if DirAccess.dir_exists_absolute(backup_absolute):
		DirAccess.rename_absolute(backup_absolute, templates_absolute)


func _cleanup_fixture() -> void:
	_remove_tree_absolute(ProjectSettings.globalize_path(DATA_ROOT))
	for sprite_set_id in [SOURCE_SPRITE_SET_ID, TARGET_SPRITE_SET_ID]:
		var generated_path := SpriteFramesGenerator.sprite_frames_path(sprite_set_id)
		if FileAccess.file_exists(generated_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(generated_path))


func _remove_tree_absolute(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree_absolute(child)
			else:
				DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _first_difference(expected, actual, path: String = "bundle") -> String:
	if typeof(expected) != typeof(actual):
		return "%s type %d != %d (%s != %s)" % [path, typeof(expected), typeof(actual), expected, actual]
	if typeof(expected) == TYPE_DICTIONARY:
		if expected.keys().size() != actual.keys().size():
			return "%s keys %s != %s" % [path, expected.keys(), actual.keys()]
		for key in expected.keys():
			if not actual.has(key):
				return "%s missing key %s" % [path, key]
			var difference := _first_difference(expected[key], actual[key], "%s.%s" % [path, key])
			if not difference.is_empty():
				return difference
	elif typeof(expected) == TYPE_ARRAY:
		if expected.size() != actual.size():
			return "%s size %d != %d" % [path, expected.size(), actual.size()]
		for index in expected.size():
			var difference := _first_difference(expected[index], actual[index], "%s[%d]" % [path, index])
			if not difference.is_empty():
				return difference
	elif expected != actual:
		return "%s %s != %s" % [path, expected, actual]
	return ""


func _normalized_move(move: Dictionary) -> Dictionary:
	return DocumentRules.normalize_integral_numbers(DocumentRules.normalize_move(move))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
