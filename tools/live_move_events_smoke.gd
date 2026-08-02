extends SceneTree

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")
const FRAME_DELTA := 1.0 / 60.0

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	playground.set_physics_process(false)
	var player: Node = playground.player
	player.apply_v0_3_runtime_bundle(_event_template(player), {}, {"event_probe": _event_move()})
	player.reset_runtime(Vector2(245, 245))

	_expect(str(player.debug_summary().get("state_authority_backend", "")) == "limboai", "live state decisions use the required LimboAI authority")
	_expect(player.request_attack("event_probe"), "real Playground sprite starts the authored event Move")
	_expect(str(player.debug_summary().get("state_authority_state", "")) == "attack", "LimboHSM authorizes the live attack state")
	_expect(player.state_machine.current_frame() == 0, "event Move starts on frame 0")
	_expect(player.active_hitboxes_world().is_empty(), "authored hitbox starts disabled")

	var start_position: Vector2 = player.position
	player.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 1, "Move reaches authored event frame 1")
	_expect(player.active_hitboxes_world().size() == 1, "enable_hitbox opens the authored hitbox on frame 1")
	_expect(player.position == start_position + Vector2(1, 0), "set_velocity moves the playable sprite by its authored velocity")

	player.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 2, "Move reaches authored state-context frame 2")
	_expect(str(player.debug_summary().get("state_context", "")) == "jump", "change_state_context dispatches jump through the live state authority")
	_expect(player.state_machine.current_state == "attack", "state context does not create a competing runtime state machine")
	_expect(str(player.debug_summary().get("state_authority_state", "")) == "attack", "LimboHSM keeps the Move active until AnimationPlayer completion")

	var hitstop_position: Vector2 = player.position
	player.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 3, "Move reaches authored hitstop frame 3")
	_expect(player.active_hitboxes_world().is_empty(), "hitstop freezes authored hitbox evaluation")
	_expect(player.position == hitstop_position, "hitstop freezes authored single-sprite velocity immediately")

	var other_sprite_elapsed: float = playground.dummy.state_machine.state_elapsed
	for remaining in [1, 0]:
		player.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
		playground.dummy.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
		_expect(player.state_machine.current_frame() == 3, "hitstop freezes the Move timeline while %d frames remain" % remaining)
		_expect(player.position == hitstop_position, "hitstop freezes only the executing sprite's movement")
	_expect(playground.dummy.state_machine.state_elapsed > other_sprite_elapsed, "single-sprite hitstop does not freeze the other live sprite")

	player.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 4, "Move resumes after the authored hitstop duration")
	_expect(player.active_hitboxes_world().size() == 1, "hitbox evaluation resumes with the Move")
	_expect(player.position == hitstop_position + Vector2(1, 0), "authored velocity resumes with the Move")

	player.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 5, "Move reaches authored disable frame 5")
	_expect(player.active_hitboxes_world().is_empty(), "disable_hitbox closes the authored hitbox on frame 5")
	for _frame in 2:
		player.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
	_expect(not player.move_executor.is_executing(), "AnimationPlayer completion finishes the authored Move")
	_expect(player.state_machine.current_state == "jump", "Move completion dispatches the authored finished context through the live state path")
	_expect(str(player.debug_summary().get("state_authority_state", "")) == "jump", "LimboHSM owns the finished state decision")

	playground.free()
	if _errors.is_empty():
		print("live_move_events_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("live_move_events_smoke=FAIL")
		quit(1)


func _event_template(player: Node) -> Dictionary:
	var source: Dictionary = player.template
	return {
		"template_id": "event_probe_character",
		"sprite_set_ref": str(source.get("sprite_set_id", "")),
		"hp": int(source.get("max_hp", 100)),
		"walk_speed": float(source.get("walk_speed", 95.0)),
		"run_speed": float(source.get("run_speed", 150.0)),
		"hurtboxes": _runtime_rects_to_v0_3(source.get("hurtbox_profile", {})),
		"foot_collision": {
			"center": _vector_to_dictionary(source.get("foot_collision_profile", {}).get("center", Vector2.ZERO)),
			"radius": _vector_to_dictionary(source.get("foot_collision_profile", {}).get("radius", Vector2.ONE)),
		},
	}


func _event_move() -> Dictionary:
	return {
		"move_id": "event_probe",
		"move_type": "combat",
		"state_context_override": "idle",
		"frame_count": 7,
		"active_window": {"start_frame": 1, "end_frame": 5},
		"damage": 1,
		"hitstop_frames": 2,
		"hitboxes": [{
			"hitbox_id": "hit_event_probe",
			"active_window": {"start_frame": 1, "end_frame": 5},
			"rect": {"x": 12, "y": -48, "w": 24, "h": 14},
		}],
		"multi_hit": false,
		"events": [
			{"frame": 1, "event_type": "enable_hitbox", "payload": {"hitbox_id": "hit_event_probe"}},
			{"frame": 1, "event_type": "set_velocity", "payload": {"x": 60, "y": 0}},
			{"frame": 2, "event_type": "change_state_context", "payload": {"state": "jump"}},
			{"frame": 3, "event_type": "apply_hitstop", "payload": {"frames": 2}},
			{"frame": 5, "event_type": "disable_hitbox", "payload": {"hitbox_id": "hit_event_probe"}},
		],
	}


func _runtime_rects_to_v0_3(profile: Dictionary) -> Dictionary:
	var converted := {}
	for rect_id in profile:
		var rect: Rect2 = profile[rect_id]
		converted[str(rect_id)] = {
			"x": rect.position.x,
			"y": rect.position.y,
			"w": rect.size.x,
			"h": rect.size.y,
		}
	return converted


func _vector_to_dictionary(vector: Vector2) -> Dictionary:
	return {"x": vector.x, "y": vector.y}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
