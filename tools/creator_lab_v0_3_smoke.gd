extends SceneTree

const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")

const DATA_ROOT := "user://creator_lab_v0_3_smoke"
const TEMPLATE_ID := "combat_gray_s64"

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	var fixture := DataStore.load_runtime_bundle(TEMPLATE_ID)
	_cleanup_fixture(fixture)
	errors.append_array(_expect(not fixture.is_empty(), "default Authoring Draft fixture loads"))
	if fixture.is_empty():
		_finish(errors)
		return
	errors.append_array(_expect(
		DataStore.save_runtime_bundle(fixture, DATA_ROOT).is_empty(),
		"isolated Authoring Draft fixture persists"
	))

	var panel: PanelContainer = PanelScript.new()
	root.add_child(panel)
	for method_name in [
		"setup",
		"draft_status",
		"authoring_draft_snapshot",
		"save_all",
		"discard_current",
		"apply_to_bound_instance",
		"request_template_switch",
		"request_bound_instance_switch",
		"resolve_pending_switch",
		"pending_switch_status",
		"preview_observation",
	]:
		errors.append_array(_expect(panel.has_method(method_name), "Panel exposes public %s" % method_name))
	for retired_method in [
		"runtime_start_selected_move",
		"runtime_advance_frame",
		"runtime_reset_idle",
		"runtime_summary",
	]:
		errors.append_array(_expect(not panel.has_method(retired_method), "Panel retires %s" % retired_method))

	panel.setup(DATA_ROOT)
	await process_frame
	var initial_status: Dictionary = panel.draft_status()
	errors.append_array(_expect(str(initial_status.get("template_id", "")) == TEMPLATE_ID, "Panel loads the Authoring Draft fixture"))
	errors.append_array(_expect(not bool(initial_status.get("dirty", true)), "loaded Authoring Draft starts clean"))
	errors.append_array(_expect(initial_status.get("diagnostics", []).is_empty(), "loaded Authoring Draft has no diagnostics"))
	var detached_snapshot: Dictionary = panel.authoring_draft_snapshot()
	detached_snapshot["bundle"]["template"]["hp"] = -1
	errors.append_array(_expect(
		int(panel.authoring_draft_snapshot().get("bundle", {}).get("template", {}).get("hp", -1)) == 100,
		"Authoring Draft snapshot is detached from external mutation"
	))

	panel.select_action("basic_punch")
	panel.preview_reset()
	var preview_before: Dictionary = panel.preview_observation()
	panel.preview_step_forward()
	var preview_after: Dictionary = panel.preview_observation()
	errors.append_array(_expect(not preview_before.is_empty(), "Preview exposes a real observation"))
	errors.append_array(_expect(int(preview_after.get("frame", -1)) >= int(preview_before.get("frame", -1)), "Preview advances through its public API"))

	panel.set_hp(111)
	errors.append_array(_expect(bool(panel.draft_status().get("dirty", false)), "public authoring edit marks Draft dirty"))
	var reload_errors: Array = panel.reload_current()
	errors.append_array(_expect(not reload_errors.is_empty(), "dirty reload requires an explicit lifecycle decision"))
	errors.append_array(_expect(bool(panel.pending_switch_status().get("pending", false)), "dirty reload publishes a pending decision"))
	var cancel_result: Dictionary = panel.resolve_pending_switch("cancel")
	errors.append_array(_expect(str(cancel_result.get("outcome", "")) == "cancelled", "Cancel resolves the pending reload"))
	errors.append_array(_expect(bool(panel.draft_status().get("dirty", false)), "Cancel preserves the dirty Draft"))
	errors.append_array(_expect(int(panel.preview_sprite().max_hp) == 111, "Cancel preserves the valid Preview"))

	errors.append_array(panel.save_all())
	errors.append_array(_expect(not bool(panel.draft_status().get("dirty", true)), "Save establishes a clean persisted baseline"))
	errors.append_array(_expect(int(DataStore.load_template(TEMPLATE_ID, DATA_ROOT).get("hp", -1)) == 111, "Save uses the isolated JSON persistence path"))

	panel.set_hp(112)
	errors.append_array(_expect(not panel.reload_current().is_empty(), "second dirty reload requires a decision"))
	var discard_result: Dictionary = panel.resolve_pending_switch("discard")
	errors.append_array(_expect(str(discard_result.get("outcome", "")) == "switched", "Discard resolves the pending reload"))
	errors.append_array(_expect(not bool(panel.draft_status().get("dirty", true)), "Discard restores the saved baseline"))
	errors.append_array(_expect(int(panel.preview_sprite().max_hp) == 111, "Discard restores the saved Preview"))

	var bound_instance: Node2D = CombatCharacterScript.new()
	bound_instance.instance_id = "creator_lab_smoke_instance"
	bound_instance.template_id = TEMPLATE_ID
	bound_instance.is_test_dummy = true
	root.add_child(bound_instance)
	await process_frame
	var bind_result: Dictionary = panel.bind_instance(bound_instance)
	errors.append_array(_expect(str(bind_result.get("outcome", "")) == "switched", "public binding path selects a live instance"))
	panel.set_hp(113)
	errors.append_array(_expect(panel.mark_frame_slot("basic_punch", 0, "empty"), "public Panel seam marks basic_punch frame 0 empty"))
	errors.append_array(_expect(panel.apply_to_bound_instance(), "Apply accepts a valid Authoring Draft"))
	errors.append_array(_expect(int(bound_instance.max_hp) == 113, "Apply sends the Draft bundle to the live instance"))
	var applied_frames: SpriteFrames = bound_instance.animated_sprite.sprite_frames
	var applied_frame_texture: Texture2D = (
		applied_frames.get_frame_texture("basic_punch", 0) if applied_frames != null else null
	)
	var applied_frame_image: Image = applied_frame_texture.get_image() if applied_frame_texture != null else null
	var applied_frame_alpha := applied_frame_image.get_pixel(0, 0).a if applied_frame_image != null else -1.0
	errors.append_array(_expect(
		is_zero_approx(applied_frame_alpha),
		"Apply installs the custom-root generated empty basic_punch frame on the live instance (alpha=%s)" % applied_frame_alpha
	))

	panel.set_hp(0)
	var invalid_status: Dictionary = panel.draft_status()
	errors.append_array(_expect(not invalid_status.get("diagnostics", []).is_empty(), "invalid edit exposes Draft diagnostics"))
	errors.append_array(_expect(not bool(invalid_status.get("can_save", true)), "invalid Draft cannot Save"))
	errors.append_array(_expect(not bool(invalid_status.get("can_apply", true)), "invalid Draft cannot Apply"))
	errors.append_array(_expect(not panel.apply_to_bound_instance(), "Apply rejects an invalid Draft"))
	errors.append_array(_expect(int(panel.preview_sprite().max_hp) == 113, "invalid Draft keeps the last valid Preview"))

	bound_instance.queue_free()
	panel.queue_free()
	await process_frame
	_cleanup_fixture(fixture)
	_finish(errors)


func _cleanup_fixture(bundle: Dictionary) -> void:
	if bundle.is_empty():
		return
	var template: Dictionary = bundle.get("template", {})
	var sprite_set: Dictionary = bundle.get("sprite_set", {})
	_remove_file(DataStore.template_path(str(template.get("template_id", TEMPLATE_ID)), DATA_ROOT))
	_remove_file(DataStore.sprite_set_path(str(sprite_set.get("sprite_set_id", "")), DATA_ROOT))
	for move_id in bundle.get("moves", {}).keys():
		_remove_file(DataStore.move_path(str(move_id), DATA_ROOT))
	_remove_file(DATA_ROOT.path_join("sprite_frames").path_join("%s.tres" % str(sprite_set.get("sprite_set_id", ""))))
	for directory in ["templates", "moves", "sprite_sets", "sprite_frames"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DATA_ROOT.path_join(directory)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DATA_ROOT))


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish(errors: Array) -> void:
	if errors.is_empty():
		print("creator_lab_v0_3_smoke=PASS")
		quit(0)
		return
	for error in errors:
		push_error(str(error))
	print("creator_lab_v0_3_smoke=FAIL")
	quit(1)


func _expect(condition: bool, message: String) -> Array:
	return [] if condition else [message]
