extends SceneTree

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")


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
	if punch_ok and kick_ok and lethal_ok and non_goal_ok and ai_ok:
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


func _target_position_for(move_id: String) -> Vector2:
	# Places the dummy's upper/lower hurtboxes inside the named move's first active hitbox.
	if move_id == "basic_kick":
		return Vector2(282, 245)
	return Vector2(282, 245)
