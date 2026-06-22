extends SceneTree

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")
const CreatorDataStoreScript := preload("res://godot/scripts/creator_data_store.gd")


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
	if punch_ok and kick_ok and lethal_ok and non_goal_ok and ai_ok and creator_ok:
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
	for i in 45:
		await physics_frame
		if playground.player.state_machine.current_state == "attack":
			saw_attack = true
		if playground.dummy.state_machine.current_state == "hurt":
			saw_hurt = true

	var expected_hp: int = playground.dummy.max_hp - expected_damage
	return saw_attack and saw_hurt and playground.dummy.current_hp == expected_hp


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

	var original_punch := CreatorDataStoreScript.load_move_json("basic_punch").duplicate(true)
	var copy_id := "combat_gray_s64_smoke_copy"
	var copy_path := CreatorDataStoreScript.template_path(copy_id)
	if FileAccess.file_exists(copy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(copy_path))

	panel._load_template("combat_gray_s64")
	panel.create_editable_copy(copy_id)
	if str(panel.template_json["template_id"]) != copy_id:
		_restore_creator_smoke(original_punch, copy_path)
		return false

	panel.selected_hurtbox = "hurt_head"
	panel.template_json["hurtboxes"]["hurt_head"]["x"] = -11
	panel.template_json["foot_collision"]["radius"]["x"] = 19
	panel.template_json["sprite_set_id"] = "blue_dummy_s64"
	panel.sprite_set_json = CreatorDataStoreScript.load_sprite_set_json("blue_dummy_s64")
	panel.move_json["frame_count"] = 28
	panel.move_json["active_start_frame"] = 8
	panel.move_json["active_end_frame"] = 13
	panel.move_json["hitboxes"][0]["frame_start"] = 8
	panel.move_json["hitboxes"][0]["frame_end"] = 13
	panel.move_json["hitboxes"][0]["rect"]["x"] = 13
	panel._save_all()

	var reloaded_template := CreatorDataStoreScript.load_template_json(copy_id)
	var reloaded_move := CreatorDataStoreScript.load_move_json("basic_punch")
	var exact_ok := JSON.stringify(panel.template_json, "\t", true) == JSON.stringify(reloaded_template, "\t", true)
	exact_ok = exact_ok and JSON.stringify(panel.move_json, "\t", true) == JSON.stringify(reloaded_move, "\t", true)
	var wardrobe_ok: bool = panel._missing_animations().has("basic_punch")
	var apply_ok: bool = playground.player.template_id == copy_id and playground.player.sprite_set_id == "blue_dummy_s64"
	var toggle_ok: bool = _run_creator_toggle_smoke(playground)

	playground.player.reset_runtime(Vector2(245, 245))
	playground.dummy.reset_runtime(Vector2(282, 245))
	playground.player.request_attack("basic_punch")
	for i in 45:
		await physics_frame
	var runtime_ok: bool = playground.dummy.current_hp < playground.dummy.max_hp

	_restore_creator_smoke(original_punch, copy_path)
	if not (exact_ok and wardrobe_ok and apply_ok and toggle_ok and runtime_ok):
		print("creator_lab_smoke exact_ok=%s wardrobe_ok=%s apply_ok=%s toggle_ok=%s runtime_ok=%s" % [exact_ok, wardrobe_ok, apply_ok, toggle_ok, runtime_ok])
	return exact_ok and wardrobe_ok and apply_ok and toggle_ok and runtime_ok


func _run_creator_toggle_smoke(playground: Node) -> bool:
	playground.creator_lab.visible = true
	var action_bound: bool = InputMap.has_action("toggle_creator_lab")
	playground.toggle_creator_lab()
	var hidden: bool = not playground.creator_lab.visible
	playground.toggle_creator_lab()
	var visible_again: bool = playground.creator_lab.visible
	return action_bound and hidden and visible_again


func _restore_creator_smoke(original_punch: Dictionary, copy_path: String) -> void:
	CreatorDataStoreScript.save_move_json(original_punch)
	if FileAccess.file_exists(copy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(copy_path))


func _target_position_for(move_id: String) -> Vector2:
	# Places the dummy's upper/lower hurtboxes inside the named move's first active hitbox.
	if move_id == "basic_kick":
		return Vector2(282, 245)
	return Vector2(282, 245)
