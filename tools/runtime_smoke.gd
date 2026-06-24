extends SceneTree

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")
const V03DataStoreScript := preload("res://godot/scripts/prd_v0_3_data_store.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame

	var punch_ok: bool = await _run_move_hit_smoke(playground, "basic_punch", 8)
	var kick_ok: bool = await _run_move_hit_smoke(playground, "basic_kick", 10)
	var lethal_ok: bool = await _run_lethal_smoke(playground)
	var non_goal_ok: bool = await _run_non_goal_attack_lockout_smoke(playground)
	var ai_ok: bool = await _run_ai_stress_smoke(playground)
	var creator_ok: bool = await _run_creator_lab_smoke(playground)
	var focus_ok: bool = await _run_input_focus_smoke(playground)
	if punch_ok and kick_ok and lethal_ok and non_goal_ok and ai_ok and creator_ok and focus_ok:
		print("runtime_smoke=PASS")
		quit(0)
	else:
		push_error("runtime_smoke=FAIL")
		quit(1)


func _run_move_hit_smoke(playground: Node, move_id: String, expected_damage: int) -> bool:
	playground.player.reset_runtime(Vector2(245, 245))
	playground.dummy.reset_runtime(_target_position_for(move_id))
	playground.player.request_attack(move_id)

	var saw_attack := false
	var saw_hurt := false
	var resolved_hurtbox := ""
	var contact_hurtboxes: Array = []
	for i in 45:
		await physics_frame
		if playground.player.state_machine.current_state == "attack":
			saw_attack = true
		if playground.dummy.state_machine.current_state == "hurt":
			saw_hurt = true
		if resolved_hurtbox.is_empty():
			var summary: Dictionary = playground.dummy.debug_summary()
			resolved_hurtbox = str(summary["last_hit_hurtbox"])
			contact_hurtboxes = summary["contact_hurtboxes"]

	var expected_hp: int = playground.dummy.max_hp - expected_damage
	return (
		saw_attack
		and saw_hurt
		and playground.dummy.current_hp == expected_hp
		and resolved_hurtbox.begins_with("hurt_")
		and contact_hurtboxes.has(resolved_hurtbox)
	)


func _run_lethal_smoke(playground: Node) -> bool:
	playground.player.reset_runtime(Vector2(245, 245))
	playground.dummy.reset_runtime(_target_position_for("basic_kick"))
	playground.dummy.current_hp = 10
	playground.player.request_attack("basic_kick")
	for i in 45:
		await physics_frame
	return playground.dummy.current_hp == 0 and playground.dummy.state_machine.current_state == "dead"


func _run_non_goal_attack_lockout_smoke(playground: Node) -> bool:
	playground.player.reset_runtime(Vector2(245, 245))
	playground.dummy.reset_runtime(_target_position_for("basic_punch"))
	playground.player.state_machine.request_action("dash")
	var dash_blocked: bool = not playground.player.request_attack("basic_punch")
	for i in 20:
		await physics_frame

	playground.player.reset_runtime(Vector2(245, 245))
	playground.dummy.reset_runtime(_target_position_for("basic_kick"))
	playground.player.state_machine.request_action("jump")
	var jump_blocked: bool = not playground.player.request_attack("basic_kick")
	for i in 30:
		await physics_frame
	return dash_blocked and jump_blocked


func _run_ai_stress_smoke(playground: Node) -> bool:
	playground.player.reset_runtime(Vector2(245, 245))
	playground.dummy.reset_runtime(Vector2(405, 245))
	playground.player.control_mode = "ai"
	var valid_states := {
		"idle": true,
		"walk": true,
		"dash": true,
		"jump": true,
		"attack": true,
		"hurt": true,
		"dead": true,
	}
	for i in 10800:
		playground._tick_combat(1.0 / 60.0)
		if not valid_states.has(playground.player.state_machine.current_state):
			return false
		if playground.player.state_machine.current_state == "attack" and not playground.player.move_executor.is_executing():
			return false
		if playground.player.position.distance_to(playground.arena_center) > 700.0:
			return false
	playground.player.control_mode = "manual"
	return true


func _run_creator_lab_smoke(playground: Node) -> bool:
	var panel: Node = playground.creator_lab
	if panel == null:
		return false
	if panel.name != "creator_lab_v0_3":
		print("creator_lab_smoke wrong panel=%s" % panel.name)
		return false

	var original_punch := V03DataStoreScript.load_move("basic_punch").duplicate(true)
	var copy_id := "combat_gray_s64_runtime_smoke_copy"
	var copy_path := V03DataStoreScript.template_path(copy_id)
	if FileAccess.file_exists(copy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(copy_path))

	panel.load_template_id("combat_gray_s64")
	panel.copy_template(copy_id)
	if str(panel.template_json["template_id"]) != copy_id:
		_restore_creator_smoke(original_punch, copy_path)
		return false

	panel.set_hp(101)
	panel.set_hurtbox_rect("hurt_head", {"x": -11, "y": -63, "w": 25, "h": 19})
	panel.set_foot_collision({"x": 1, "y": -5}, {"x": 19, "y": 9})
	panel.select_move("basic_punch")
	panel.set_move_scalar("frame_count", 9)
	panel.set_move_active_window(2, 6)
	panel.set_move_scalar("damage", 9)
	panel.set_move_scalar("hitstop_frames", 4)
	panel.set_first_hitbox("hit_fist_1", 2, 6, {"x": 13, "y": -47, "w": 25, "h": 15})
	panel.set_move_events([
		{"frame": 2, "event_type": "enable_hitbox", "payload": {"hitbox_id": "hit_fist_1"}},
		{"frame": 6, "event_type": "disable_hitbox", "payload": {"hitbox_id": "hit_fist_1"}},
	])

	var exact_ok: bool = panel.save_reload_exact()
	var coverage: Dictionary = panel.wardrobe_coverage()
	var wardrobe_ok: bool = (
		coverage["missing_mapping"].is_empty()
		and coverage["missing_clips"].is_empty()
		and coverage["missing_sequences"].is_empty()
	)
	var toggle_ok: bool = _run_creator_toggle_smoke(playground)

	panel.select_move("basic_punch")
	var start_errors: Array = panel.runtime_start_selected_move()
	panel.runtime_advance_frame(2)
	var runtime_summary: Dictionary = panel.runtime_summary()
	var runtime_ok: bool = start_errors.is_empty() and int(runtime_summary["active_hitbox_count"]) == 1

	_restore_creator_smoke(original_punch, copy_path)
	if not (exact_ok and wardrobe_ok and toggle_ok and runtime_ok):
		print("creator_lab_smoke exact_ok=%s wardrobe_ok=%s toggle_ok=%s runtime_ok=%s" % [exact_ok, wardrobe_ok, toggle_ok, runtime_ok])
	return exact_ok and wardrobe_ok and toggle_ok and runtime_ok


func _run_creator_toggle_smoke(playground: Node) -> bool:
	playground.creator_lab.visible = true
	var action_bound: bool = InputMap.has_action("toggle_creator_lab")
	playground.toggle_creator_lab()
	var hidden: bool = not playground.creator_lab.visible
	var focus_released: bool = playground.get_viewport().gui_get_focus_owner() == null
	playground.toggle_creator_lab()
	var visible_again: bool = playground.creator_lab.visible
	return action_bound and hidden and focus_released and visible_again


func _run_input_focus_smoke(playground: Node) -> bool:
	playground.creator_lab.visible = true
	playground.creator_lab.current_nav = "character_template"
	playground.creator_lab._refresh_fields()
	await process_frame
	var focus_target: Control = playground.creator_lab.sprite_ref_input
	if focus_target == null:
		print("input_focus_smoke missing sprite_ref_input")
		return false
	focus_target.grab_focus()
	await process_frame
	var focused_before: bool = playground.get_viewport().gui_get_focus_owner() == focus_target
	playground.toggle_creator_lab()
	await process_frame
	var closed_focus_released: bool = not playground.creator_lab.visible and playground.get_viewport().gui_get_focus_owner() == null
	if not (focused_before and closed_focus_released):
		print("input_focus_smoke focused_before=%s closed_focus_released=%s" % [
			focused_before,
			closed_focus_released,
		])
	return focused_before and closed_focus_released


func _restore_creator_smoke(original_punch: Dictionary, copy_path: String) -> void:
	V03DataStoreScript.save_move(original_punch)
	if FileAccess.file_exists(copy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(copy_path))


func _target_position_for(move_id: String) -> Vector2:
	# Places the dummy's upper/lower hurtboxes inside the named move's first active hitbox.
	if move_id == "basic_kick":
		return Vector2(282, 245)
	return Vector2(282, 245)
