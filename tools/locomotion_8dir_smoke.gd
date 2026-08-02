extends SceneTree

const StateMachineScript := preload("res://godot/scripts/combat_state_machine.gd")
const MoveExecutorScript := preload("res://godot/scripts/move_executor.gd")
const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")
const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")

const DT := 1.0 / 60.0

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_slice_direction_from_intent()
	_slice_hysteresis()
	_slice_run_mode()
	_slice_locomotion_phase_matrix()
	_slice_facing_split()
	_slice_attack_from_run()
	_slice_dash_exit_to_run()
	await _slice_directional_animation_and_flip()
	await _slice_cycle_phase()
	await _slice_resource_and_scene()
	await _slice_reset_to_idle_direction()
	_finish()


func _finish() -> void:
	if _errors.is_empty():
		print("locomotion_8dir_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("locomotion_8dir_smoke=FAIL")
		quit(1)


func _make_sm() -> Array:
	var executor: Node = MoveExecutorScript.new()
	var state_machine: Node = StateMachineScript.new()
	root.add_child(executor)
	root.add_child(state_machine)
	state_machine.configure(executor)
	return [state_machine, executor]


func _free_sm(parts: Array) -> void:
	for part in parts:
		part.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _dir(state_machine: Node) -> String:
	return str(state_machine.get("locomotion_direction"))


func _mode(state_machine: Node) -> String:
	return str(state_machine.get("locomotion_mode"))


func _phase(state_machine: Node) -> String:
	return str(state_machine.get("locomotion_phase"))


func _slice_direction_from_intent() -> void:
	var parts := _make_sm()
	var sm: Node = parts[0]
	_expect(_dir(sm) == "e", "initial locomotion_direction is e (got %s)" % _dir(sm))
	sm.tick(DT, Vector2(1, -1).normalized())
	_expect(_dir(sm) == "ne", "NE input selects ne (got %s)" % _dir(sm))
	sm.tick(DT, Vector2.ZERO)
	_expect(_dir(sm) == "ne", "stop preserves ne (got %s)" % _dir(sm))
	var sectors: Array = [
		[Vector2(1, 0), "e"],
		[Vector2(1, 1).normalized(), "se"],
		[Vector2(0, 1), "s"],
		[Vector2(-1, 1).normalized(), "sw"],
		[Vector2(-1, 0), "w"],
		[Vector2(-1, -1).normalized(), "nw"],
		[Vector2(0, -1), "n"],
		[Vector2(1, -1).normalized(), "ne"],
	]
	for sector in sectors:
		sm.tick(DT, sector[0])
		_expect(_dir(sm) == sector[1], "input %s selects %s (got %s)" % [sector[0], sector[1], _dir(sm)])
	_free_sm(parts)


func _slice_hysteresis() -> void:
	var parts := _make_sm()
	var sm: Node = parts[0]
	sm.tick(DT, Vector2(1, 0))
	# 25 degrees is past the raw 22.5 sector edge but inside the hysteresis margin.
	sm.tick(DT, Vector2(cos(deg_to_rad(25.0)), sin(deg_to_rad(25.0))))
	_expect(_dir(sm) == "e", "25deg inside hysteresis keeps e (got %s)" % _dir(sm))
	# 35 degrees is past the edge plus margin, so the sector flips.
	sm.tick(DT, Vector2(cos(deg_to_rad(35.0)), sin(deg_to_rad(35.0))))
	_expect(_dir(sm) == "se", "35deg past hysteresis selects se (got %s)" % _dir(sm))
	# Returning to 25 degrees stays se (hysteresis is stable, not flickering).
	sm.tick(DT, Vector2(cos(deg_to_rad(25.0)), sin(deg_to_rad(25.0))))
	_expect(_dir(sm) == "se", "25deg back inside margin keeps se (got %s)" % _dir(sm))
	_free_sm(parts)


func _slice_run_mode() -> void:
	var parts := _make_sm()
	var sm: Node = parts[0]
	sm.tick(DT, Vector2(1, 0), true)
	_expect(sm.current_state == "walk", "run remains in locomotion state walk (got %s)" % sm.current_state)
	_expect(_mode(sm) == "run", "run_requested selects run mode (got %s)" % _mode(sm))
	_expect(is_equal_approx(sm.velocity.length(), 150.0), "run velocity is 150 (got %s)" % sm.velocity.length())
	sm.tick(DT, Vector2(1, 0), false)
	_expect(sm.current_state == "walk", "releasing run remains in walk state (got %s)" % sm.current_state)
	_expect(_mode(sm) == "walk", "releasing run selects walk mode (got %s)" % _mode(sm))
	_expect(is_equal_approx(sm.velocity.length(), 95.0), "walk velocity is 95 (got %s)" % sm.velocity.length())
	_free_sm(parts)


func _slice_locomotion_phase_matrix() -> void:
	var sectors: Array = [
		[Vector2(1, 0), "e"],
		[Vector2(1, 1).normalized(), "se"],
		[Vector2(0, 1), "s"],
		[Vector2(-1, 1).normalized(), "sw"],
		[Vector2(-1, 0), "w"],
		[Vector2(-1, -1).normalized(), "nw"],
		[Vector2(0, -1), "n"],
		[Vector2(1, -1).normalized(), "ne"],
	]
	for run_requested in [false, true]:
		var expected_mode := "run" if run_requested else "walk"
		for sector in sectors:
			var parts := _make_sm()
			var sm: Node = parts[0]
			var direction: Vector2 = sector[0]
			sm.tick(DT, direction, run_requested)
			_expect(sm.current_state == "walk", "%s %s start uses walk state" % [expected_mode, sector[1]])
			_expect(_mode(sm) == expected_mode, "%s %s selects mode" % [expected_mode, sector[1]])
			_expect(_phase(sm) == "start", "%s %s presents start (got %s)" % [expected_mode, sector[1], _phase(sm)])
			for i in 12:
				sm.tick(DT, direction, run_requested)
			_expect(_phase(sm) == "loop", "%s %s presents loop (got %s)" % [expected_mode, sector[1], _phase(sm)])
			sm.tick(DT, -direction, run_requested)
			_expect(_phase(sm) == "turn", "%s %s presents turn (got %s)" % [expected_mode, sector[1], _phase(sm)])
			for i in 26:
				sm.tick(DT, -direction, run_requested)
			_expect(_phase(sm) == "loop", "%s %s returns to loop after turn" % [expected_mode, sector[1]])
			sm.tick(DT, Vector2.ZERO, run_requested)
			_expect(_phase(sm) == "stop", "%s %s presents stop (got %s)" % [expected_mode, sector[1], _phase(sm)])
			for i in 12:
				sm.tick(DT, Vector2.ZERO, run_requested)
			_expect(sm.current_state == "idle", "%s %s stop completes to idle" % [expected_mode, sector[1]])
			_free_sm(parts)


func _slice_facing_split() -> void:
	var parts := _make_sm()
	var sm: Node = parts[0]
	var executor: Node = parts[1]
	executor.configure({"test_move": {"total_frames": 2}})
	_expect(sm.facing == 1, "initial combat facing is 1 (got %s)" % sm.facing)
	sm.tick(DT, Vector2(0, -1))
	_expect(sm.facing == 1, "pure N preserves combat facing (got %s)" % sm.facing)
	_expect(_dir(sm) == "n", "pure N sets locomotion direction n (got %s)" % _dir(sm))
	sm.tick(DT, Vector2(0, 1))
	_expect(sm.facing == 1, "pure S preserves combat facing (got %s)" % sm.facing)
	sm.tick(DT, Vector2(-1, -1).normalized())
	_expect(sm.facing == -1, "diagonal W updates combat facing (got %s)" % sm.facing)
	_expect(_dir(sm) == "nw", "diagonal sets locomotion direction nw (got %s)" % _dir(sm))
	_expect(sm.can_start_attack(), "can start attack from walk")
	executor.start_attack_intent("test_move")
	_expect(sm.current_state == "attack", "attack intent enters attack (got %s)" % sm.current_state)
	_expect(sm.locked_attack_facing == -1, "attack locks combat facing -1 (got %s)" % sm.locked_attack_facing)
	sm.tick(DT, Vector2(1, 0))
	_expect(sm.facing == -1, "input during attack cannot change combat facing (got %s)" % sm.facing)
	_expect(_dir(sm) == "nw", "attack does not change locomotion direction (got %s)" % _dir(sm))
	sm.tick(DT, Vector2.ZERO)
	_expect(sm.current_state == "idle", "attack completes back to idle (got %s)" % sm.current_state)
	sm.tick(DT, Vector2(1, 0))
	_expect(sm.current_state == "walk", "post-attack movement resumes walk (got %s)" % sm.current_state)
	_expect(_dir(sm) == "e", "post-attack locomotion direction resumes with new intent e (got %s)" % _dir(sm))
	_free_sm(parts)


func _slice_attack_from_run() -> void:
	var parts := _make_sm()
	var sm: Node = parts[0]
	sm.tick(DT, Vector2(1, 0), true)
	_expect(sm.current_state == "walk", "setup: run mode uses walk state (got %s)" % sm.current_state)
	_expect(_mode(sm) == "run", "setup: running mode selected")
	_expect(sm.can_start_attack(), "can start attack while running")
	_free_sm(parts)


func _slice_dash_exit_to_run() -> void:
	var parts := _make_sm()
	var sm: Node = parts[0]
	_expect(sm.request_action("dash"), "setup: dash starts")
	for i in 30:
		sm.tick(DT, Vector2(1, 0), true)
	_expect(sm.current_state == "walk", "dash exit with run held returns to locomotion walk state (got %s)" % sm.current_state)
	_expect(_mode(sm) == "run", "dash exit with run held restores run mode")
	_expect(is_equal_approx(sm.velocity.length(), 150.0), "post-dash run velocity is 150 (got %s)" % sm.velocity.length())
	_free_sm(parts)


func _slice_directional_animation_and_flip() -> void:
	var miduo := CombatCharacterScript.new()
	miduo.template_id = "miduo"
	miduo.instance_id = "loco_miduo"
	root.add_child(miduo)
	await process_frame
	var sectors: Array = [
		[Vector2(1, 0), "e"],
		[Vector2(1, 1).normalized(), "se"],
		[Vector2(0, 1), "s"],
		[Vector2(-1, 1).normalized(), "sw"],
		[Vector2(-1, 0), "w"],
		[Vector2(-1, -1).normalized(), "nw"],
		[Vector2(0, -1), "n"],
		[Vector2(1, -1).normalized(), "ne"],
	]
	for sector in sectors:
		miduo.reset_runtime(Vector2.ZERO)
		miduo.state_machine.tick(DT, sector[0])
		_refresh_visual(miduo)
		_expect(str(miduo.animated_sprite.animation) == "eden_walk_start_%s" % sector[1], "miduo %s walk resolves imported start art (got %s)" % [sector[1], miduo.animated_sprite.animation])
		for i in 12:
			miduo.state_machine.tick(DT, sector[0])
		_refresh_visual(miduo)
		_expect(str(miduo.animated_sprite.animation) == "eden_walk_loop_%s" % sector[1], "miduo %s walk resolves imported loop art (got %s)" % [sector[1], miduo.animated_sprite.animation])
		_expect(not miduo.animated_sprite.flip_h, "miduo %s authored directional art is not flipped" % sector[1])
	var skeleton := CombatCharacterScript.new()
	skeleton.template_id = "skeleton_default_unarmed_s64"
	skeleton.instance_id = "loco_skeleton"
	root.add_child(skeleton)
	await process_frame
	skeleton.state_machine.tick(DT, Vector2(-1, 0))
	_refresh_visual(skeleton)
	_expect(str(skeleton.animated_sprite.animation) == "walk", "skeleton W walk falls back to unsuffixed walk (got %s)" % skeleton.animated_sprite.animation)
	_expect(skeleton.animated_sprite.flip_h, "skeleton legacy W walk mirrors with flip_h")
	skeleton.state_machine.tick(DT, Vector2(1, 0))
	_refresh_visual(skeleton)
	_expect(not skeleton.animated_sprite.flip_h, "skeleton legacy E walk is not flipped")
	miduo.free()
	skeleton.free()


func _slice_cycle_phase() -> void:
	var miduo := CombatCharacterScript.new()
	miduo.template_id = "miduo"
	miduo.instance_id = "loco_phase"
	root.add_child(miduo)
	await process_frame
	miduo.state_machine.tick(DT, Vector2(1, 0))
	for i in 12:
		miduo.state_machine.tick(DT, Vector2(1, 0))
	_refresh_visual(miduo)
	_expect(str(miduo.animated_sprite.animation) == "eden_walk_loop_e", "walk reaches imported loop phase (got %s)" % miduo.animated_sprite.animation)
	miduo.state_machine.tick(DT, Vector2(-1, 0))
	_refresh_visual(miduo)
	_expect(str(miduo.animated_sprite.animation) == "eden_walk_turn_w", "direction change presents imported turn phase (got %s)" % miduo.animated_sprite.animation)
	miduo.state_machine.tick(DT, Vector2(-1, 0), true)
	_refresh_visual(miduo)
	_expect(str(miduo.animated_sprite.animation) == "eden_run_start_w", "walk to run presents imported run start (got %s)" % miduo.animated_sprite.animation)
	for i in 12:
		miduo.state_machine.tick(DT, Vector2(-1, 0), true)
	_refresh_visual(miduo)
	_expect(str(miduo.animated_sprite.animation) == "eden_run_loop_w", "run reaches imported loop phase (got %s)" % miduo.animated_sprite.animation)
	miduo.state_machine.tick(DT, Vector2.ZERO, true)
	_refresh_visual(miduo)
	_expect(str(miduo.animated_sprite.animation) == "eden_run_stop_w", "run stop presents imported stop phase (got %s)" % miduo.animated_sprite.animation)
	miduo.free()


func _slice_resource_and_scene() -> void:
	var frames: SpriteFrames = ResourceLoader.load("res://godot/resources/sprite_frames/miduo.tres", "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(frames != null, "miduo.tres loads as SpriteFrames")
	if frames != null:
		var names: Array = []
		for animation_name in frames.get_animation_names():
			names.append(str(animation_name))
		var required: Array = []
		for base in ["idle", "walk", "run"]:
			for direction in ["s", "se", "e", "ne", "n", "nw", "w", "sw"]:
				required.append("%s_%s" % [base, direction])
		for mode in ["walk", "run"]:
			for phase in ["start", "loop", "stop", "turn"]:
				for direction in ["s", "se", "e", "ne", "n", "nw", "w", "sw"]:
					required.append("eden_%s_%s_%s" % [mode, phase, direction])
		required.append_array(["dash", "jump", "hurt", "dead", "jab", "high_kick"])
		for animation_name in required:
			_expect(names.has(animation_name), "miduo has animation %s" % animation_name)
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame
	_expect(str(playground.player.template_id) == "miduo", "playground player defaults to imported miduo")
	_expect(str(playground.player.animated_sprite.animation) == "idle_e", "player boots onto idle_e (got %s)" % playground.player.animated_sprite.animation)
	var animation_before_missing_attack := str(playground.player.animated_sprite.animation)
	_expect(not playground.player.request_attack("uppercut"), "missing uppercut request is rejected")
	await physics_frame
	_expect(str(playground.player.animated_sprite.animation) == animation_before_missing_attack, "missing uppercut never substitutes unrelated animation art")
	Input.action_press("run")
	Input.action_press("move_right")
	for i in 10:
		await physics_frame
	_expect(playground.player.state_machine.current_state == "walk", "Ctrl + move stays in walk state (got %s)" % playground.player.state_machine.current_state)
	_expect(_mode(playground.player.state_machine) == "run", "Ctrl + move selects run mode")
	_expect(is_equal_approx(playground.player.state_machine.velocity.length(), 150.0), "scene run velocity is 150 (got %s)" % playground.player.state_machine.velocity.length())
	Input.action_release("run")
	Input.action_release("move_right")
	for i in 12:
		await physics_frame
	_expect(playground.player.state_machine.current_state == "idle", "releasing input returns to idle (got %s)" % playground.player.state_machine.current_state)
	playground.free()


func _refresh_visual(character: Node) -> void:
	character.apply_runtime_sprite_frames(character.animated_sprite.sprite_frames)


func _slice_reset_to_idle_direction() -> void:
	var parts := _make_sm()
	var sm: Node = parts[0]
	sm.tick(DT, Vector2(0, -1))
	_expect(_dir(sm) == "n", "setup: direction n (got %s)" % _dir(sm))
	sm.reset_to_idle()
	_expect(_dir(sm) == "e", "reset_to_idle restores direction e (got %s)" % _dir(sm))
	_free_sm(parts)
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame
	Input.action_press("move_up")
	for i in 10:
		await physics_frame
	Input.action_release("move_up")
	for i in 3:
		await physics_frame
	_expect(_dir(playground.player.state_machine) == "n", "player walked north (got %s)" % _dir(playground.player.state_machine))
	playground.reset_playground()
	await process_frame
	_expect(_dir(playground.player.state_machine) == "e", "reset_playground restores direction e (got %s)" % _dir(playground.player.state_machine))
	_expect(str(playground.player.animated_sprite.animation) == "idle_e", "reset_playground returns player to idle_e (got %s)" % playground.player.animated_sprite.animation)
	playground.free()
