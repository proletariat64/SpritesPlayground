extends Node2D

const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")
const CreatorLabV03PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const COMBAT_TICK_RATE := 60

var arena_center := Vector2(320, 205)
var arena_radius := Vector2(280, 125)

var player: Node2D
var dummy: Node2D
var selected_character: Node2D
var debug_label: RichTextLabel
var creator_lab: PanelContainer
var _ai_started_at_msec: int = 0


func _ready() -> void:
	Engine.physics_ticks_per_second = COMBAT_TICK_RATE
	_ensure_input_actions()
	player = _spawn_character("combat_gray_s64", "player_1", Vector2(245, 245), false)
	dummy = _spawn_character("combat_gray_s64", "test_dummy_1", Vector2(405, 245), true)
	_build_debug_gui()
	_build_creator_lab()
	select_player_character()
	_ai_started_at_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if creator_lab != null and selected_character != null and creator_lab.has_method("update_bound_instance_summary"):
		creator_lab.update_bound_instance_summary(selected_character)
	_update_debug_gui()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_process_input()
	_tick_combat(delta)


func _process_input() -> void:
	if _manual_gameplay_input_active():
		get_viewport().gui_release_focus()
	if Input.is_action_just_pressed("toggle_ai"):
		player.control_mode = "ai" if player.control_mode == "manual" else "manual"
		_ai_started_at_msec = Time.get_ticks_msec()
	if Input.is_action_just_pressed("toggle_boxes"):
		player.debug_boxes_visible = not player.debug_boxes_visible
		dummy.debug_boxes_visible = player.debug_boxes_visible
	if Input.is_action_just_pressed("toggle_creator_lab") and creator_lab != null:
		toggle_creator_lab()
	if Input.is_action_just_pressed("toggle_preview_window") and creator_lab != null and creator_lab.has_method("toggle_preview_window"):
		creator_lab.toggle_preview_window()
	if Input.is_action_just_pressed("reset_playground"):
		player.reset_runtime(Vector2(245, 245))
		dummy.reset_runtime(Vector2(405, 245))
		player.control_mode = "manual"
		_ai_started_at_msec = Time.get_ticks_msec()


func _manual_gameplay_input_active() -> bool:
	return (
		Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
		or Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
		or Input.is_action_just_pressed("dash")
		or Input.is_action_just_pressed("jump")
		or Input.is_action_just_pressed("basic_punch")
		or Input.is_action_just_pressed("basic_kick")
	)


func _tick_combat(delta: float) -> void:
	player.tick_character(delta, arena_center, arena_radius)
	dummy.tick_character(delta, arena_center, arena_radius)
	_resolve_foot_spacing()
	_process_hits(player, dummy)
	_process_hits(dummy, player)


func toggle_creator_lab() -> void:
	if creator_lab != null:
		creator_lab.visible = not creator_lab.visible
		if creator_lab.visible and selected_character != null and creator_lab.has_method("update_bound_instance_summary"):
			creator_lab.update_bound_instance_summary(selected_character)
		if not creator_lab.visible:
			get_viewport().gui_release_focus()


func select_character(character: Node2D) -> void:
	if character == null:
		return
	selected_character = character
	if creator_lab != null and creator_lab.has_method("bind_instance"):
		creator_lab.bind_instance(character)
	_update_debug_gui()


func select_player_character() -> void:
	select_character(player)


func select_dummy_character() -> void:
	select_character(dummy)


func selected_character_summary() -> Dictionary:
	if selected_character == null:
		return {}
	return selected_character.debug_summary()


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
		var contact_hurtboxes: Array = []
		for hurtbox in target.hurtboxes_world():
			var hurt_rect: Rect2 = hurtbox["rect"]
			if hit_rect.intersects(hurt_rect):
				contact_hurtboxes.append(str(hurtbox["hurtbox_id"]))
		if not contact_hurtboxes.is_empty():
			var resolved_hurtbox_id := str(contact_hurtboxes[0])
			target.take_hit(int(hitbox["damage"]), str(hitbox["hitbox_id"]), attacker.instance_id, resolved_hurtbox_id, contact_hurtboxes)
			attacker.move_executor.mark_target_hit(target.instance_id, window_index)


func _resolve_foot_spacing() -> void:
	var separation_delta: Vector2 = CombatCharacterScript.foot_separation_delta(player, dummy)
	if separation_delta == Vector2.ZERO:
		return
	player.position -= separation_delta * 0.5
	dummy.position += separation_delta * 0.5


func _build_debug_gui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "debug_gui"
	add_child(layer)

	debug_label = RichTextLabel.new()
	debug_label.name = "runtime_status"
	debug_label.position = Vector2(8, 8)
	debug_label.custom_minimum_size = Vector2(420, 58)
	debug_label.bbcode_enabled = true
	debug_label.focus_mode = Control.FOCUS_NONE
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.fit_content = true
	debug_label.add_theme_font_size_override("font_size", 8)
	debug_label.add_theme_font_size_override("normal_font_size", 8)
	debug_label.add_theme_color_override("default_color", Color(0.9, 0.93, 0.95))
	layer.add_child(debug_label)
	_update_debug_gui()


func _build_creator_lab() -> void:
	var layer := CanvasLayer.new()
	layer.name = "creator_lab_layer"
	layer.layer = 20
	add_child(layer)

	creator_lab = CreatorLabV03PanelScript.new()
	creator_lab.name = "creator_lab_v0_3"
	creator_lab.position = Vector2(72, 10)
	creator_lab.size = Vector2(560, 526)
	creator_lab.visible = false
	layer.add_child(creator_lab)
	creator_lab.setup()
	creator_lab.bind_player_requested.connect(select_player_character)
	creator_lab.bind_dummy_requested.connect(select_dummy_character)


func _update_debug_gui() -> void:
	var p: Dictionary = player.debug_summary()
	var d: Dictionary = dummy.debug_summary()
	var s: Dictionary = selected_character_summary()
	var ai_seconds := 0.0
	if player.control_mode == "ai":
		ai_seconds = float(Time.get_ticks_msec() - _ai_started_at_msec) / 1000.0
	var boxes_status := "on" if player.debug_boxes_visible else "off"
	debug_label.text = "\n".join([
		"[color=#86d7ff]P[/color] %s %s f:%s hit:%s" % [p["state"], p["hp"], p["frame"], p["active_hitboxes"]],
		"[color=#ff9aa2]D[/color] %s %s  [color=#ffd166]%s[/color] box:%s" % [d["state"], d["hp"], p["mode"].substr(0, 3), boxes_status],
		"[color=#86d7ff]SEL[/color] %s tpl:%s set:%s st:%s mv:%s f:%s hp:%s mode:%s" % [
			s.get("instance_id", "none"),
			s.get("template_id", ""),
			s.get("sprite_set_id", ""),
			s.get("state", ""),
			s.get("move", ""),
			s.get("frame", 0),
			s.get("hp", ""),
			s.get("mode", ""),
		],
		"[color=#c7d2fe]wasd[/color] move  j/k atk  sh dash  sp jump  tab ai  b box  c lab v0.3  v preview  r reset",
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
	_bind_key_action("toggle_creator_lab", [KEY_C])
	_bind_key_action("toggle_preview_window", [KEY_V])
	_bind_key_action("reset_playground", [KEY_R])


func _bind_key_action(action_id: String, keys: Array) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = int(keycode)
		if not InputMap.action_has_event(action_id, event):
			InputMap.action_add_event(action_id, event)
