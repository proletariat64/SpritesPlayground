extends SceneTree
const Stage := preload("res://godot/scenes/MiduoOnTheWayHome.tscn")
var stage: Node
var errors: Array = []

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	await physics_frame
	await physics_frame
	key(code, false)
	await physics_frame
	await physics_frame

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func reset_player() -> void:
	stage.player.reset_runtime(Vector2(140, 270))
	stage.player.grace = 0

func menu_navigation() -> void:
	# Verify focused actions rather than only the existence of menu buttons.
	await tap(KEY_ENTER)
	expect(stage.mode == "playing", "title default Enter still starts")
	var original_player: Node = stage.player
	await tap(KEY_ENTER)
	expect(stage.mode == "playing" and stage.player == original_player, "Enter during gameplay does not restart")
	await tap(KEY_ESCAPE)
	var activations := [0]
	stage.menu_buttons.get_child(0).pressed.connect(func(): activations[0] += 1)
	await tap(KEY_ENTER)
	expect(stage.mode == "playing" and stage.player == original_player and activations[0] == 1, "focused pause Resume activates once without retry")
	await tap(KEY_ESCAPE)
	await tap(KEY_DOWN)
	await tap(KEY_DOWN)
	expect(root.gui_get_focus_owner() == stage.menu_buttons.get_child(2), "pause Down Down selects Return Title")
	await tap(KEY_ENTER)
	expect(stage.mode == "title", "Enter activates focused pause Return Title")
	await tap(KEY_DOWN)
	expect(root.gui_get_focus_owner() == stage.menu_buttons.get_child(1), "title Down selects Playground")
	var launches := [0]
	stage.menu_buttons.get_child(1).pressed.connect(func(): launches[0] += 1)
	await tap(KEY_ENTER)
	await process_frame
	await process_frame
	await frames(4)
	expect(current_scene != null and current_scene.scene_file_path == "res://godot/scenes/Playground.tscn" and launches[0] == 1, "Enter loads actual focused Playground exactly once")
	# Repeat from a real current scene to retain native Space activation coverage.
	change_scene_to_packed(Stage)
	await process_frame
	await process_frame
	stage = current_scene
	await tap(KEY_DOWN)
	await tap(KEY_SPACE)
	await process_frame
	await process_frame
	await frames(4)
	expect(current_scene != null and current_scene.scene_file_path == "res://godot/scenes/Playground.tscn", "Space still loads focused Playground")
	change_scene_to_packed(Stage)
	await process_frame
	await process_frame
	stage = current_scene
	for menu_mode in ["defeat", "victory"]:
		stage.show_menu(menu_mode)
		await frames(3)
		await tap(KEY_DOWN)
		expect(root.gui_get_focus_owner() == stage.menu_buttons.get_child(1), "%s Down selects Return Title" % menu_mode)
		await tap(KEY_ENTER)
		expect(stage.mode == "title", "%s focused Return Title honors Enter" % menu_mode)
		stage.show_menu(menu_mode)
		await tap(KEY_ENTER)
		expect(stage.mode == "playing" and stage.player.current_hp == 100, "%s default Enter retries" % menu_mode)
	stage.show_menu("title")
	root.gui_release_focus()
	await frames(3)
	await tap(KEY_ENTER)
	expect(stage.mode == "playing", "unfocused title Enter falls back to Start")

func run() -> void:
	stage = Stage.instantiate()
	root.add_child(stage)
	current_scene = stage
	await process_frame
	await tap(KEY_ENTER)
	await frames(3)
	expect(stage.mode == "playing", "Enter starts from focused title button")
	for enemy in stage.living_enemies():
		enemy.is_test_dummy = true
	var p = stage.player
	var x: float = p.position.x
	key(KEY_D, true)
	key(KEY_CTRL, true)
	await frames(5)
	expect(p.position.x > x and p.state_machine.locomotion_mode == "run", "stage real Ctrl+D runs")
	key(KEY_D, false)
	key(KEY_CTRL, false)
	await frames(4)
	reset_player()
	await tap(KEY_SHIFT)
	expect(p.state_machine.current_state == "dash", "stage real Shift dashes")
	reset_player()
	key(KEY_CTRL, true)
	await tap(KEY_SPACE)
	expect(p.state_machine.jump_mode == "big_jump", "stage real Ctrl+Space big jump")
	key(KEY_CTRL, false)
	await tap(KEY_K)
	expect(p.state_machine.current_move == "miduo_flying_kick", "stage real airborne K")
	reset_player()
	await tap(KEY_J)
	await tap(KEY_J)
	var cross := false
	for i in 50:
		await physics_frame
		cross = cross or p.state_machine.current_move == "miduo_cross_punch"
	expect(cross, "stage real J-J combo at stage animation tempo")
	reset_player()
	await tap(KEY_K)
	await tap(KEY_K)
	var roundhouse := false
	for i in 50:
		await physics_frame
		roundhouse = roundhouse or p.state_machine.current_move == "miduo_roundhouse_kick"
	expect(roundhouse, "stage real K-K combo")
	reset_player()
	key(KEY_S, true)
	await tap(KEY_K)
	expect(p.state_machine.current_move == "miduo_sweep", "stage real Down+K sweep")
	key(KEY_S, false)
	reset_player()
	await tap(KEY_L)
	expect(p.super_cooldown > 5 and p.state_machine.current_move == "homeward_super", "real L starts super")
	await tap(KEY_ESCAPE)
	expect(stage.mode == "paused", "Esc opens pause")
	var cooldown: float = p.super_cooldown
	await frames(8)
	expect(p.super_cooldown == cooldown, "pause freezes cooldown")
	await tap(KEY_ESCAPE)
	await frames(3)
	expect(stage.mode == "playing", "Esc resumes")
	# UI transition latch must reject held attack until released.
	stage.show_menu("paused")
	key(KEY_J, true)
	await frames(2)
	stage.resume_run()
	await frames(4)
	expect(stage.input_latch and not p.input_enabled, "held attack does not leak through resume")
	key(KEY_J, false)
	await frames(4)
	expect(not stage.input_latch, "release rearms gameplay")
	stage.show_menu("defeat")
	await tap(KEY_ENTER)
	await frames(3)
	expect(stage.mode == "playing" and stage.player.current_hp == 100 and stage.player.super_cooldown == 0, "Enter retries fresh from defeat")
	stage.show_menu("title")
	expect(stage.menu_buttons.get_child_count() == 2, "title retains Start and Playground buttons")
	for code in [KEY_J, KEY_K, KEY_L, KEY_CTRL, KEY_D, KEY_SPACE, KEY_SHIFT, KEY_ESCAPE, KEY_ENTER, KEY_S]:
		key(code, false)
	await menu_navigation()
	current_scene.queue_free()
	await process_frame
	if errors.is_empty():
		print("homeward_input_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		print("homeward_input_smoke=FAIL")
		quit(1)
