extends SceneTree

# Direct-window visual acceptance for #42's isolated real Creator Lab Preview.
# Run with a display server; screenshots are written under OUT_DIR.

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")
const OUT_DIR := "user://creator_lab_real_preview_visual_uat"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_clear_old_shots()
	if DisplayServer.get_name() == "headless":
		errors.append("visual UAT requires a real display server")

	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await _frames(12)
	playground.set_physics_process(false)
	playground.toggle_creator_lab()
	await _frames(6)

	var panel: PanelContainer = playground.creator_lab
	if panel == null:
		errors.append("Playground did not create Creator Lab")
		await _finish(playground, errors)
		return
	# The debug panel is taller than the 640x360 logical viewport. Lift it for
	# this capture so the persistent embedded Preview is visibly on-screen.
	panel.position = Vector2(72, -150)
	panel.load_template_id("skeleton_default_unarmed_s64")
	panel.current_nav = "action_preview"
	panel.select_action("basic_punch")
	panel.preview_reset()
	await _frames(6)

	var embedded_start: Dictionary = panel.preview_observation()
	if panel.current_action_id != "basic_punch" or panel.selected_move != "basic_punch":
		errors.append("Panel public selection did not resolve basic_punch")
	if str(embedded_start.get("move", "")) != "basic_punch":
		errors.append("embedded Preview did not start basic_punch")
	if str(embedded_start.get("animation", "")) != "basic_punch":
		errors.append("embedded Preview did not present basic_punch art")
	if int(embedded_start.get("frame", -1)) != 0:
		errors.append("embedded Preview did not start on frame 0")
	if panel.preview_frame_count() != panel.action_preview_control.frame_count():
		errors.append("Panel and embedded Preview disagree on basic_punch frame count")
	if not str(panel.preview_frame_label.text).contains("basic_punch"):
		errors.append("embedded Preview chrome does not name basic_punch")
	if not str(panel.preview_frame_label.text).contains("f:1/%d" % panel.preview_frame_count()):
		errors.append("embedded Preview chrome does not show frame 1/%d" % panel.preview_frame_count())
	print("embedded_preview_rect=%s" % panel.action_preview_control.get_global_rect())
	await _record_shot("01_embedded_basic_punch.png", errors)

	panel.set_preview_window_visible(true)
	panel.preview_reset()
	for _frame in 3:
		panel.preview_step_forward()
	await _frames(6)

	var active: Dictionary = panel.preview_observation()
	if int(active.get("frame", -1)) != 3:
		errors.append("basic_punch Preview did not reach active frame 3")
	if active.get("hitboxes", []).is_empty():
		errors.append("basic_punch active capture has no real hitbox")
	if active.get("hurtboxes", []).is_empty():
		errors.append("basic_punch active capture has no real hurtboxes")
	if not panel.preview_show_hurtboxes or not panel.preview_show_hitboxes or not panel.preview_show_foot:
		errors.append("Panel Preview box overlays are not publicly enabled")
	if panel.preview_sprite() != panel.action_preview_control.real_sprite():
		errors.append("Panel and embedded Preview do not share one real sprite")
	if panel.preview_sprite() != panel.floating_preview_control.real_sprite():
		errors.append("embedded and floating Preview do not share one real sprite")
	if panel.preview_observation() != panel.floating_preview_control.observation():
		errors.append("embedded and floating Preview do not share one observation")
	if playground.all_characters().has(panel.preview_sprite()):
		errors.append("Creator Lab Preview sprite joined Playground combat")
	if panel.preview_frame_count() != panel.action_preview_control.frame_count():
		errors.append("Panel and Preview frame counts diverged at the active frame")
	if not str(panel.preview_frame_label.text).contains("basic_punch"):
		errors.append("active embedded chrome does not name basic_punch")
	if not str(panel.preview_frame_label.text).contains("f:4/%d" % panel.preview_frame_count()):
		errors.append("active embedded chrome does not show frame 4/%d" % panel.preview_frame_count())
	if panel.floating_preview_frame_label.text != panel.preview_frame_label.text:
		errors.append("embedded and floating chrome do not match")
	await _record_shot("02_embedded_and_floating_active_boxes.png", errors)

	await _finish(playground, errors)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


func _clear_old_shots() -> void:
	var directory := DirAccess.open(OUT_DIR)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.ends_with(".png"):
			directory.remove(file_name)


func _record_shot(file_name: String, errors: Array[String]) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUT_DIR, file_name]
	var error := image.save_png(path)
	print("shot %s error=%d" % [path, error])
	if error != OK:
		errors.append("Screenshot failed: %s (error %d)" % [file_name, error])


func _finish(playground: Node, errors: Array[String]) -> void:
	var output_dir := ProjectSettings.globalize_path(OUT_DIR)
	playground.queue_free()
	await _frames(2)
	if errors.is_empty():
		print("creator_lab_real_preview_visual_uat=PASS dir=%s" % output_dir)
		print("creator_lab_real_preview_visual_uat=DONE dir=%s" % output_dir)
		quit(0)
	else:
		for message in errors:
			push_error(message)
		print("creator_lab_real_preview_visual_uat=FAIL dir=%s" % output_dir)
		quit(1)
