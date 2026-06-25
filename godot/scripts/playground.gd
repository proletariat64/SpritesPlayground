extends Node2D

const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")
const CreatorLabV03PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const COMBAT_TICK_RATE := 60
const MIN_NPC_COUNT := 1
const MAX_NPC_COUNT := 10
const DEFAULT_TEMPLATE_ID := "combat_gray_s64"

var arena_center := Vector2(320, 205)
var arena_radius := Vector2(280, 125)

var player: Node2D
var dummy: Node2D
var selected_character: Node2D
var debug_label: RichTextLabel
var creator_lab: PanelContainer
var characters: Array = []
var npcs: Array = []
var next_npc_index: int = 1
var npc_template_id: String = DEFAULT_TEMPLATE_ID
var playground_status: String = ""
var _ai_started_at_msec: int = 0


func _ready() -> void:
	Engine.physics_ticks_per_second = COMBAT_TICK_RATE
	_ensure_input_actions()
	characters.clear()
	npcs.clear()
	next_npc_index = 1
	player = _spawn_character(DEFAULT_TEMPLATE_ID, "player_1", Vector2(245, 245), false)
	characters.append(player)
	add_npc(DEFAULT_TEMPLATE_ID)
	_build_debug_gui()
	_build_creator_lab()
	select_player_character()
	_update_character_depth_order()
	_ai_started_at_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if creator_lab != null:
		if selected_character != null and creator_lab.has_method("update_bound_instance_summary"):
			creator_lab.update_bound_instance_summary(selected_character)
		if creator_lab.has_method("update_playground_summary"):
			creator_lab.update_playground_summary(playground_summary())
	_update_debug_gui()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_process_input()
	_tick_combat(delta)


func _process_input() -> void:
	if _manual_gameplay_input_active():
		get_viewport().gui_release_focus()
	if Input.is_action_just_pressed("toggle_ai") and player != null:
		player.control_mode = "ai" if player.control_mode == "manual" else "manual"
		_ai_started_at_msec = Time.get_ticks_msec()
	if Input.is_action_just_pressed("toggle_boxes") and player != null:
		var next_visible: bool = not player.debug_boxes_visible
		for character in all_characters():
			character.debug_boxes_visible = next_visible
	if Input.is_action_just_pressed("toggle_creator_lab") and creator_lab != null:
		toggle_creator_lab()
	if Input.is_action_just_pressed("toggle_preview_window") and creator_lab != null and creator_lab.has_method("toggle_preview_window"):
		creator_lab.toggle_preview_window()
	if Input.is_action_just_pressed("reset_playground"):
		reset_playground()


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
	for character in all_characters():
		character.tick_character(delta, arena_center, arena_radius)
	_resolve_all_foot_spacing()
	_clamp_all_characters_to_arena()
	_update_character_depth_order()
	_process_all_hits()


func toggle_creator_lab() -> void:
	if creator_lab != null:
		creator_lab.visible = not creator_lab.visible
		if creator_lab.visible:
			if selected_character != null and creator_lab.has_method("update_bound_instance_summary"):
				creator_lab.update_bound_instance_summary(selected_character)
			if creator_lab.has_method("update_playground_summary"):
				creator_lab.update_playground_summary(playground_summary())
		if not creator_lab.visible:
			get_viewport().gui_release_focus()


func select_character(character: Node2D) -> void:
	if character == null or not is_instance_valid(character):
		return
	selected_character = character
	if creator_lab != null and creator_lab.has_method("bind_instance"):
		creator_lab.bind_instance(character)
	_update_debug_gui()


func select_player_character() -> void:
	select_character(player)


func select_dummy_character() -> void:
	select_npc(0)


func select_npc(index: int) -> void:
	if index < 0 or index >= npcs.size():
		playground_status = "npc index %d unavailable" % index
		_update_debug_gui()
		return
	select_character(npcs[index])
	playground_status = "selected %s" % str(npcs[index].instance_id)


func selected_character_summary() -> Dictionary:
	if selected_character == null or not is_instance_valid(selected_character):
		return {}
	return selected_character.debug_summary()


func playground_summary() -> Dictionary:
	return {
		"npc_count": npc_count(),
		"npc_limit": MAX_NPC_COUNT,
		"npc_min": MIN_NPC_COUNT,
		"npc_template_id": npc_template_id,
		"npc_ids": _npc_ids(),
		"selected_npc_index": npcs.find(selected_character),
		"status": playground_status,
	}


func all_characters() -> Array:
	var active: Array = []
	for character in characters:
		if character != null and is_instance_valid(character):
			active.append(character)
	return active


func npc_count() -> int:
	return npcs.size()


func add_npc(template_id: String = "", select_new: bool = false) -> Node2D:
	if npc_count() >= MAX_NPC_COUNT:
		playground_status = "npc limit reached %d/%d" % [npc_count(), MAX_NPC_COUNT]
		_update_debug_gui()
		return null
	var resolved_template := template_id if not template_id.is_empty() else npc_template_id
	if resolved_template.is_empty():
		resolved_template = DEFAULT_TEMPLATE_ID
	npc_template_id = resolved_template
	var instance_id := _next_npc_instance_id()
	var spawn_position := _spawn_npc_position(npc_count())
	var npc: Node2D = _spawn_character(resolved_template, instance_id, spawn_position, true)
	characters.append(npc)
	npcs.append(npc)
	_sync_character_aliases()
	_update_character_depth_order()
	playground_status = "added %s %d/%d" % [instance_id, npc_count(), MAX_NPC_COUNT]
	if select_new:
		select_character(npc)
	else:
		_update_debug_gui()
	return npc


func remove_npc(character: Node2D) -> bool:
	if npc_count() <= MIN_NPC_COUNT:
		playground_status = "keep at least %d npc" % MIN_NPC_COUNT
		_update_debug_gui()
		return false
	var index := npcs.find(character)
	if index < 0:
		playground_status = "selected character is not an npc"
		_update_debug_gui()
		return false
	var removed_id := str(character.instance_id)
	var removed_foot_center: Vector2 = character.foot_center_world()
	npcs.remove_at(index)
	characters.erase(character)
	if selected_character == character:
		selected_character = null
		var nearest_npc := _nearest_npc_to_position(removed_foot_center)
		if nearest_npc != null:
			select_character(nearest_npc)
		else:
			select_player_character()
	if is_instance_valid(character):
		remove_child(character)
		character.queue_free()
	_sync_character_aliases()
	_update_character_depth_order()
	playground_status = "removed %s %d/%d" % [removed_id, npc_count(), MAX_NPC_COUNT]
	_update_debug_gui()
	return true


func remove_selected_npc() -> bool:
	if selected_character != null and npcs.has(selected_character):
		return remove_npc(selected_character)
	if not npcs.is_empty():
		return remove_npc(npcs[npcs.size() - 1])
	playground_status = "no npc to remove"
	_update_debug_gui()
	return false


func reset_playground() -> void:
	if player != null:
		player.reset_runtime(Vector2(245, 245))
		player.control_mode = "manual"
	for i in npcs.size():
		npcs[i].reset_runtime(_spawn_npc_position(i))
	_sync_character_aliases()
	_clamp_all_characters_to_arena()
	_update_character_depth_order()
	playground_status = "reset %d npc" % npc_count()
	_ai_started_at_msec = Time.get_ticks_msec()


func _spawn_character(template_id: String, instance_id: String, spawn_position: Vector2, test_dummy: bool) -> Node2D:
	var character: Node2D = CombatCharacterScript.new()
	character.template_id = template_id
	character.instance_id = instance_id
	character.is_test_dummy = test_dummy
	character.position = spawn_position
	character.control_mode = "manual"
	add_child(character)
	return character


func _process_all_hits() -> void:
	var active_characters := all_characters()
	for attacker in active_characters:
		for target in active_characters:
			_process_hits(attacker, target)


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


func _resolve_all_foot_spacing() -> void:
	var active_characters := all_characters()
	for _iteration in 3:
		var moved := false
		for i in active_characters.size():
			for j in range(i + 1, active_characters.size()):
				var first: Node2D = active_characters[i]
				var second: Node2D = active_characters[j]
				var separation_delta: Vector2 = CombatCharacterScript.foot_separation_delta(first, second)
				if separation_delta == Vector2.ZERO:
					continue
				first.position -= separation_delta * 0.5
				second.position += separation_delta * 0.5
				moved = true
		if not moved:
			return


func _resolve_foot_spacing() -> void:
	_resolve_all_foot_spacing()


func _clamp_all_characters_to_arena() -> void:
	for character in all_characters():
		if character.has_method("clamp_to_arena"):
			character.clamp_to_arena(arena_center, arena_radius)


func _clamp_characters_to_arena() -> void:
	_clamp_all_characters_to_arena()


func _update_character_depth_order() -> void:
	var sorted := all_characters()
	sorted.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_y := float(a.foot_center_world().y)
		var b_y := float(b.foot_center_world().y)
		if is_equal_approx(a_y, b_y):
			return str(a.instance_id) < str(b.instance_id)
		return a_y < b_y
	)
	for index in sorted.size():
		sorted[index].z_index = index


func _sync_character_aliases() -> void:
	dummy = npcs[0] if not npcs.is_empty() else null


func _next_npc_instance_id() -> String:
	for attempt in range(MAX_NPC_COUNT):
		var candidate_index := ((next_npc_index - 1 + attempt) % MAX_NPC_COUNT) + 1
		var candidate := "npc_%03d" % candidate_index
		if not _character_id_exists(candidate):
			next_npc_index = (candidate_index % MAX_NPC_COUNT) + 1
			return candidate
	return "npc_%03d" % MAX_NPC_COUNT


func _nearest_npc_to_position(world_position: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for npc in npcs:
		if npc == null or not is_instance_valid(npc):
			continue
		var distance := world_position.distance_squared_to(npc.foot_center_world())
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = npc
	return nearest


func _spawn_npc_position(index: int) -> Vector2:
	if index == 0:
		return Vector2(405, 245)
	var columns := 5
	var col := index % columns
	var row := index / columns
	var x := 205.0 + float(col) * 54.0
	var y := 228.0 + float(row) * 24.0
	return Vector2(x, y)


func _character_id_exists(instance_id: String) -> bool:
	for character in all_characters():
		if str(character.instance_id) == instance_id:
			return true
	return false


func _npc_ids() -> Array:
	var ids: Array = []
	for npc in npcs:
		ids.append(str(npc.instance_id))
	return ids


func _build_debug_gui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "debug_gui"
	add_child(layer)

	debug_label = RichTextLabel.new()
	debug_label.name = "runtime_status"
	debug_label.position = Vector2(8, 8)
	debug_label.custom_minimum_size = Vector2(470, 68)
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
	if creator_lab.has_signal("add_npc_requested"):
		creator_lab.add_npc_requested.connect(_on_add_npc_requested)
	if creator_lab.has_signal("remove_selected_npc_requested"):
		creator_lab.remove_selected_npc_requested.connect(_on_remove_selected_npc_requested)
	if creator_lab.has_signal("bind_npc_requested"):
		creator_lab.bind_npc_requested.connect(_on_bind_npc_requested)
	if creator_lab.has_signal("npc_template_selected"):
		creator_lab.npc_template_selected.connect(_on_npc_template_selected)
	if creator_lab.has_method("update_playground_summary"):
		creator_lab.update_playground_summary(playground_summary())


func _on_add_npc_requested(template_id: String) -> void:
	add_npc(template_id, true)
	if creator_lab != null and creator_lab.has_method("update_playground_summary"):
		creator_lab.update_playground_summary(playground_summary())


func _on_remove_selected_npc_requested() -> void:
	remove_selected_npc()
	if creator_lab != null and creator_lab.has_method("update_playground_summary"):
		creator_lab.update_playground_summary(playground_summary())


func _on_bind_npc_requested(index: int) -> void:
	select_npc(index)
	if creator_lab != null and creator_lab.has_method("update_playground_summary"):
		creator_lab.update_playground_summary(playground_summary())


func _on_npc_template_selected(template_id: String) -> void:
	if not template_id.is_empty():
		npc_template_id = template_id
		playground_status = "npc template %s" % template_id
		_update_debug_gui()


func _update_debug_gui() -> void:
	if debug_label == null or player == null:
		return
	var p: Dictionary = player.debug_summary()
	var d: Dictionary = dummy.debug_summary() if dummy != null else {}
	var s: Dictionary = selected_character_summary()
	var ai_seconds := 0.0
	if player.control_mode == "ai":
		ai_seconds = float(Time.get_ticks_msec() - _ai_started_at_msec) / 1000.0
	var boxes_status := "on" if player.debug_boxes_visible else "off"
	debug_label.text = "\n".join([
		"[color=#86d7ff]P[/color] %s %s f:%s hit:%s" % [p["state"], p["hp"], p["frame"], p["active_hitboxes"]],
		"[color=#ff9aa2]NPC[/color] %d/%d first:%s hp:%s  [color=#ffd166]%s[/color] box:%s" % [
			npc_count(),
			MAX_NPC_COUNT,
			d.get("instance_id", "none"),
			d.get("hp", ""),
			p["mode"].substr(0, 3),
			boxes_status,
		],
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
		"[color=#c7d2fe]wasd[/color] move  j/k atk  sh dash  sp jump  tab ai  b box  c lab v0.3  v preview  r reset  %s" % playground_status,
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
