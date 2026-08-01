extends SceneTree

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")
const HALF_FRAME := 1.0 / 120.0
const FULL_FRAME := 1.0 / 60.0

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	playground.set_physics_process(false)
	var player: Node = playground.player
	player.reset_runtime(Vector2(245, 245))

	Input.action_press("basic_punch")
	player.tick_character(0.0, playground.arena_center, playground.arena_radius)
	Input.action_release("basic_punch")

	_expect(str(player.state_machine.current_move) == "miduo_jab", "real Playground punch input starts miduo_jab")
	_expect(player.move_executor.has_node("AnimationPlayer"), "live Move execution owns an AnimationPlayer timing source")
	_expect(player.state_machine.current_frame() == 0, "attack begins on authored startup frame 0")
	_expect(player.active_hitboxes_world().is_empty(), "startup frame 0 keeps the hitbox disabled")

	player.tick_character(HALF_FRAME, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 0, "half a frame does not skip authored startup")
	_expect(player.active_hitboxes_world().is_empty(), "hitbox stays disabled before the active callback")

	player.tick_character(HALF_FRAME, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 1, "authored active timing begins on frame 1 (got %d)" % player.state_machine.current_frame())
	_expect(player.active_hitboxes_world().size() == 1, "AnimationPlayer callback enables the hitbox on frame 1")

	player.tick_character(FULL_FRAME, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 2, "authored active timing includes frame 2")
	_expect(player.active_hitboxes_world().size() == 1, "hitbox remains enabled through the second active frame")

	player.tick_character(FULL_FRAME, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_frame() == 3, "authored recovery begins on frame 3 (got %d)" % player.state_machine.current_frame())
	_expect(player.active_hitboxes_world().is_empty(), "AnimationPlayer callback disables the hitbox for recovery")
	_expect(player.state_machine.current_state == "attack", "recovery keeps the character attack-locked")

	player.tick_character(FULL_FRAME, playground.arena_center, playground.arena_radius)
	_expect(player.state_machine.current_state == "idle", "AnimationPlayer completion returns the live sprite to idle")
	_expect(not player.move_executor.is_executing(), "completed Move no longer executes")

	playground.free()
	if _errors.is_empty():
		print("live_animationplayer_timing_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("live_animationplayer_timing_smoke=FAIL")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
