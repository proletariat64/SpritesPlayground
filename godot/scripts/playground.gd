extends Node2D

const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")
const COMBAT_TICK_RATE := 60

var arena_center := Vector2(320, 205)
var arena_radius := Vector2(280, 125)

var player: Node2D
var dummy: Node2D
var debug_label: Label
var _ai_started_at_msec: int = 0


func _ready() -> void:
	Engine.physics_ticks_per_second = COMBAT_TICK_RATE
	_ensure_input_actions()
	player = _spawn_character("combat_gray_s64", "player_1", Vector2(245, 245), false)
	dummy = _spawn_character("combat_gray_s64", "test_dummy_1", Vector2(405, 245), true)
	_build_debug_gui()
	_ai_started_at_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	_update_debug_gui()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_process_input()
	_tick_combat(delta)


func _process_input() -> void:
	if Input.is_action_just_pressed("toggle_ai"):
		player.control_mode = "ai" if player.control_mode == "manual" else "manual"
		_ai_started_at_msec = Time.get_ticks_msec()
	if Input.is_action_just_pressed("toggle_boxes"):
		player.debug_boxes_visible = not player.debug_boxes_visible
		dummy.debug_boxes_visible = player.debug_boxes_visible
	if Input.is_action_just_pressed("reset_playground"):
		player.reset_runtime(Vector2(245, 245))
		dummy.reset_runtime(Vector2(405, 245))
		player.control_mode = "manual"
		_ai_started_at_msec = Time.get_ticks_msec()


func _tick_combat(delta: float) -> void:
	player.tick_character(delta, arena_center, arena_radius)
	dummy.tick_character(delta, arena_center, arena_radius)
	_process_hits(player, dummy)
	_process_hits(dummy, player)


func _spawn_character(template_id: String, instance_id: String, spawn_position: Vector2, test_dummy: bool) -> Node2D:
	var character: Node2D = CombatCharacterScript.new()
	character.template_id = template_id
	character.instance_id = instance_id
	character.is_test_dummy = test_dummy
	character.position = spawn_position
	character.control_mode = "manual"
	add_child(character)
	return character


func _process_hits(attacker: Node2D, target: Node2D) -> void:
	if attacker == target:
		return
	if attacker.current_hp <= 0 or target.current_hp <= 0:
		return

	for hitbox in attacker.active_hitboxes_world():
		var window_index := int(hitbox["window_index"])
		if not attacker.move_executor.can_hit_target(target.instance_id, window_index):
			continue
		var hit_rect: Rect2 = hitbox["rect"]
		for hurtbox in target.hurtboxes_world():
			var hurt_rect: Rect2 = hurtbox["rect"]
			if hit_rect.intersects(hurt_rect):
				target.take_hit(int(hitbox["damage"]), str(hitbox["hitbox_id"]), attacker.instance_id)
				attacker.move_executor.mark_target_hit(target.instance_id, window_index)
				break


func _build_debug_gui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "debug_gui"
	add_child(layer)

	debug_label = Label.new()
	debug_label.name = "runtime_status"
	debug_label.position = Vector2(8, 8)
	debug_label.add_theme_font_size_override("font_size", 8)
	debug_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	debug_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0))
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(debug_label)
	_update_debug_gui()


func _update_debug_gui() -> void:
	var p: Dictionary = player.debug_summary()
	var d: Dictionary = dummy.debug_summary()
	var ai_seconds := 0.0
	if player.control_mode == "ai":
		ai_seconds = float(Time.get_ticks_msec() - _ai_started_at_msec) / 1000.0
	var boxes_status := "on" if player.debug_boxes_visible else "off"
	debug_label.text = "\n".join([
		"template=%s  instance=%s  mode=%s  ai_time=%.1fs" % [p["template_id"], p["instance_id"], p["mode"], ai_seconds],
		"state=%s  move=%s  frame=%s  hp=%s  active_hitboxes=%s" % [p["state"], p["move"], p["frame"], p["hp"], p["active_hitboxes"]],
		"dummy_state=%s  dummy_hp=%s" % [d["state"], d["hp"]],
		"boxes=%s  controls=wasd/arrows move, j punch, k kick, shift dash, space jump, tab ai, b boxes, r reset" % boxes_status,
	])


func _draw() -> void:
	_draw_arena()


func _draw_arena() -> void:
	var points := PackedVector2Array()
	for i in 65:
		var angle := TAU * float(i) / 64.0
		points.append(arena_center + Vector2(cos(angle) * arena_radius.x, sin(angle) * arena_radius.y))
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(0.08, 0.09, 0.1), true)
	draw_polyline(points, Color(0.32, 0.42, 0.5), 2.0)
	draw_line(Vector2(0, arena_center.y), Vector2(640, arena_center.y), Color(0.18, 0.22, 0.25), 1.0)


func _ensure_input_actions() -> void:
	_bind_key_action("move_left", [KEY_A, KEY_LEFT])
	_bind_key_action("move_right", [KEY_D, KEY_RIGHT])
	_bind_key_action("move_up", [KEY_W, KEY_UP])
	_bind_key_action("move_down", [KEY_S, KEY_DOWN])
	_bind_key_action("dash", [KEY_SHIFT])
	_bind_key_action("jump", [KEY_SPACE])
	_bind_key_action("basic_punch", [KEY_J])
	_bind_key_action("basic_kick", [KEY_K])
	_bind_key_action("toggle_ai", [KEY_TAB])
	_bind_key_action("toggle_boxes", [KEY_B])
	_bind_key_action("reset_playground", [KEY_R])


func _bind_key_action(action_id: String, keys: Array) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = int(keycode)
		if not InputMap.action_has_event(action_id, event):
			InputMap.action_add_event(action_id, event)
