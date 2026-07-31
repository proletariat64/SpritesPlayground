extends SceneTree

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")

var _errors: Array = []
var _playground: Node
var _player: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_playground = PlaygroundScene.instantiate()
	root.add_child(_playground)
	await process_frame
	await physics_frame
	_player = _playground.player

	await _movement_and_run_controls()
	await _jump_precedence_controls()
	await _punch_controls()
	await _kick_controls()
	_release_all_keys()

	if _errors.is_empty():
		print("input_event_controls_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("input_event_controls_smoke=FAIL")
		quit(1)


func _movement_and_run_controls() -> void:
	_expect(_action_has_key("move_left", KEY_A) and _action_has_key("move_left", KEY_LEFT), "A/Left map to move_left")
	_expect(_action_has_key("move_right", KEY_D) and _action_has_key("move_right", KEY_RIGHT), "D/Right map to move_right")
	_expect(_action_has_key("move_up", KEY_W) and _action_has_key("move_up", KEY_UP), "W/Up map to move_up")
	_expect(_action_has_key("move_down", KEY_S) and _action_has_key("move_down", KEY_DOWN), "S/Down map to move_down")

	_reset_player()
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	_expect(_player.state_machine.current_state == "walk", "D/right movement event enters locomotion")
	_expect(_player.state_machine.locomotion_direction == "e", "D/right movement event resolves east")
	Input.action_release("move_right")
	await physics_frame

	_reset_player()
	Input.action_press("run")
	Input.action_press("move_up")
	await physics_frame
	await physics_frame
	_expect(_player.state_machine.current_state == "walk", "Ctrl+arrow events stay in locomotion state")
	_expect(_player.state_machine.locomotion_mode == "run", "Ctrl+arrow events resolve run mode")
	_expect(_player.state_machine.locomotion_direction == "n", "Up movement event resolves north")
	Input.action_release("move_up")
	Input.action_release("run")
	await physics_frame

	_reset_player()
	await _tap(KEY_SHIFT)
	_expect(_player.state_machine.current_state == "dash", "Shift resolves dash")


func _jump_precedence_controls() -> void:
	_reset_player()
	await _tap(KEY_SPACE)
	_expect(_player.state_machine.current_state == "jump", "Space resolves normal jump")
	_expect(_player.state_machine.jump_mode == "jump", "Space selects normal jump mode")

	_reset_player()
	_key_down(KEY_CTRL)
	await _tap(KEY_SPACE)
	_expect(_player.state_machine.current_state == "jump", "Ctrl+Space resolves jump state")
	_expect(_player.state_machine.jump_mode == "big_jump", "Ctrl+Space selects big jump before normal jump")
	_key_up(KEY_CTRL)
	await physics_frame


func _punch_controls() -> void:
	_reset_player()
	await _tap(KEY_J)
	_expect(_player.state_machine.current_state == "attack", "J starts an attack immediately")
	_expect(str(_player.state_machine.current_move) == "miduo_jab", "J resolves jab")
	await _tap(KEY_J)
	var saw_cross := await _wait_for_move("miduo_cross_punch", 40)
	_expect(saw_cross, "J then J continues to cross_punch")

	_reset_player()
	await _tap(KEY_J)
	await create_timer(0.7).timeout
	await _tap(KEY_J)
	var late_cross := await _wait_for_move("miduo_cross_punch", 40)
	_expect(not late_cross, "J after the combo window starts a new jab instead of cross_punch")

	_reset_player()
	_key_down(KEY_S)
	await _tap(KEY_J)
	_expect(_player.state_machine.current_state != "attack", "Down+J missing uppercut safely no-ops")
	_expect(not _player.move_executor.is_executing(), "Down+J never substitutes another Move")
	_key_up(KEY_S)
	await physics_frame


func _kick_controls() -> void:
	_reset_player()
	await _tap(KEY_K)
	_expect(_player.state_machine.current_state == "attack", "K starts an attack immediately")
	_expect(str(_player.state_machine.current_move) == "miduo_high_kick", "K resolves high_kick")
	await _tap(KEY_K)
	var saw_roundhouse := await _wait_for_move("miduo_roundhouse_kick", 50)
	_expect(saw_roundhouse, "K then K continues to roundhouse_kick")

	_reset_player()
	_key_down(KEY_DOWN)
	await _tap(KEY_K)
	_expect(_player.state_machine.current_state == "attack", "Down+K starts an attack")
	_expect(str(_player.state_machine.current_move) == "miduo_sweep", "Down+K resolves sweep before high_kick")
	_key_up(KEY_DOWN)
	await physics_frame

	_reset_player()
	await _tap(KEY_SPACE)
	_expect(_player.state_machine.current_state == "jump", "airborne setup enters jump")
	await _tap(KEY_K)
	_expect(_player.state_machine.current_state == "attack", "airborne K starts an attack")
	_expect(str(_player.state_machine.current_move) == "miduo_flying_kick", "airborne K resolves flying_kick before ground kick")


func _reset_player() -> void:
	_release_all_keys()
	_player.reset_runtime(Vector2(245, 245))


func _tap(keycode: Key) -> void:
	_key_down(keycode)
	await physics_frame
	await physics_frame
	_key_up(keycode)
	await physics_frame


func _key_down(keycode: Key) -> void:
	_send_key(keycode, true)


func _key_up(keycode: Key) -> void:
	_send_key(keycode, false)


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_all_keys() -> void:
	for keycode in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_CTRL, KEY_SHIFT, KEY_SPACE, KEY_J, KEY_K]:
		_key_up(keycode)
	for action_id in ["move_left", "move_right", "move_up", "move_down", "run"]:
		Input.action_release(action_id)


func _action_has_key(action_id: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_id):
		if event is InputEventKey and int(event.physical_keycode) == int(keycode):
			return true
	return false


func _wait_for_move(move_id: String, max_ticks: int) -> bool:
	for _tick in max_ticks:
		await physics_frame
		if str(_player.state_machine.current_move) == move_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
