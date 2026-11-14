extends Node2D
## One finite route. Menus freeze the manual combat tick, never the UI tree.
const Actor := preload("res://godot/scripts/homeward_actor.gd")
const Street := preload("res://godot/scripts/homeward_street.gd")
const FONT := preload("res://godot/assets/homeward/DroidSansFallbackFull.ttf")
const ENCOUNTERS := [["brawler", "brawler"], ["rusher", "kicker"], ["mini"], ["boss"]]
const LOCKS := [510.0, 1080.0, 1510.0, 1900.0]
const TRIGGERS := [0.0, 650.0, 1200.0, 1580.0]
const PLACES := ["校门口", "放学商店街", "回家小巷", "最后的路口"]
var actors: Array = []
var player: Node2D
var camera: Camera2D
var encounter := -1
var spawn_counts := [0, 0, 0, 0]
var cleared := false
var mode := "title"
var world: Node2D
var hud: Label
var overlay: Panel
var menu_title: Label
var menu_buttons: VBoxContainer
var input_latch := true
var hits_landed := 0

func _ready() -> void:
	ensure_inputs()
	var street := Street.new()
	street.font = FONT
	street.z_index = -20
	add_child(street)
	world = Node2D.new()
	add_child(world)
	camera = Camera2D.new()
	camera.position = Vector2(320, 180)
	add_child(camera)
	build_ui()
	show_menu("title")

func ensure_inputs() -> void:
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "run": [KEY_CTRL], "dash": [KEY_SHIFT], "jump": [KEY_SPACE], "basic_punch": [KEY_J], "basic_kick": [KEY_K], "homeward_super": [KEY_L]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

func start_run() -> void:
	for actor in actors:
		world.remove_child(actor)
		actor.queue_free()
	actors.clear()
	encounter = -1
	spawn_counts = [0, 0, 0, 0]
	cleared = false
	hits_landed = 0
	camera.position = Vector2(320, 180)
	player = spawn_actor("player", Vector2(130, 270))
	mode = "playing"
	overlay.hide()
	get_viewport().gui_release_focus()
	input_latch = true
	begin_encounter()
	update_hud()

func spawn_actor(role: String, at: Vector2) -> Node2D:
	var actor := Actor.new()
	actor.role = role
	actor.team = 0 if role == "player" else 1
	actor.template_id = "miduo" if actor.team == 0 else "miduo_blue"
	actor.instance_id = "homeward_%s_%d" % [role, actors.size()]
	actor.position = at
	actor.stage_font = FONT
	actor.control_mode = "manual" if actor.team == 0 else "ai"
	world.add_child(actor)
	if actor.team == 1:
		actor.set_combat_target(player)
	actors.append(actor)
	return actor

func begin_encounter() -> void:
	encounter += 1
	cleared = false
	spawn_counts[encounter] += 1
	for i in ENCOUNTERS[encounter].size():
		spawn_actor(ENCOUNTERS[encounter][i], Vector2(LOCKS[encounter] - 120 + i * 60, 264 + i * 25))
	update_lanes()

func living_enemies() -> Array:
	return actors.filter(func(a): return a.team == 1 and a.current_hp > 0)

func update_lanes() -> void:
	var left: float = 24.0 if encounter == 0 else LOCKS[encounter - 1] - 90
	var right: float = 2190.0 if cleared else LOCKS[encounter]
	for actor in actors:
		actor.lane = Rect2(left, 230, right - left, 90)

func _physics_process(delta: float) -> void:
	if mode != "playing":
		return
	if input_latch:
		player.input_enabled = false
		var held := false
		for action in ["move_left", "move_right", "move_up", "move_down", "run", "dash", "jump", "basic_punch", "basic_kick", "homeward_super"]:
			held = held or Input.is_action_pressed(action)
		if not held:
			input_latch = false
		return
	player.input_enabled = true
	advance_gameplay(delta)

func advance_gameplay(delta: float) -> void:
	if mode != "playing":
		return
	for actor in actors:
		actor.stage_tick(delta)
	for i in actors.size():
		for j in range(i + 1, actors.size()):
			if actors[i].current_hp <= 0 or actors[j].current_hp <= 0:
				continue
			var separation: Vector2 = Actor.foot_separation_delta(actors[i], actors[j])
			actors[i].position -= separation * 0.5
			actors[j].position += separation * 0.5
	for actor in actors:
		actor.clamp_to_arena(Vector2.ZERO, Vector2.ONE)
		actor.z_index = int(actor.depth_sort_key())
	process_hits()
	if player.current_hp <= 0:
		show_menu("defeat")
	elif living_enemies().is_empty():
		cleared = true
		update_lanes()
		if encounter < 3 and player.position.x >= TRIGGERS[encounter + 1]:
			begin_encounter()
		elif encounter == 3 and player.position.x >= 2010:
			show_menu("victory")
	camera.position.x = clampf(player.position.x + 100, 320, 1920)
	update_hud()
	queue_redraw()

func process_hits() -> void:
	# Snapshot all contacts before any cancellation/death, then mark, then settle.
	var snapshots: Array = []
	var accepted := {}
	for attacker in actors:
		for target in actors:
			if attacker.team == target.team or attacker.current_hp <= 0 or target.current_hp <= 0 or target.grace > 0:
				continue
			for box in attacker.active_hitboxes_world():
				var window := int(box.window_index)
				var key := "%s:%s:%d" % [attacker.instance_id, target.instance_id, window]
				if accepted.has(key) or not attacker.move_executor.can_hit_target(target.instance_id, window):
					continue
				var contacts: Array = []
				for hurt in target.hurtboxes_world():
					if box.rect.intersects(hurt.rect):
						contacts.append(hurt.hurtbox_id)
				if not contacts.is_empty():
					accepted[key] = true
					snapshots.append({"attacker": attacker, "target": target, "box": box, "contacts": contacts})
	for hit in snapshots:
		hit.attacker.move_executor.mark_target_hit(hit.target.instance_id, hit.box.window_index)
	for hit in snapshots:
		hit.target.take_hit(hit.box.damage, hit.box.hitbox_id, hit.attacker.instance_id, hit.contacts[0], hit.contacts)
		hits_landed += 1

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if mode == "playing":
			show_menu("paused")
		elif mode == "paused":
			resume_run()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER and overlay.visible and mode in ["title", "paused", "defeat", "victory"]:
		var focused := get_viewport().gui_get_focus_owner()
		# Only unhandled Enter reaches here; GUI-handled Space/accept stays native.
		# Consume before activation, which may replace the menu or change scenes.
		get_viewport().set_input_as_handled()
		if focused is Button and menu_buttons.is_ancestor_of(focused) and focused.is_visible_in_tree() and not focused.disabled:
			focused.pressed.emit()
		elif mode in ["title", "defeat", "victory"]:
			start_run()

func resume_run() -> void:
	mode = "playing"
	overlay.hide()
	input_latch = true
	get_viewport().gui_release_focus()

func show_menu(next_mode: String) -> void:
	mode = next_mode
	if player != null:
		player.input_enabled = false
	input_latch = true
	for child in menu_buttons.get_children():
		menu_buttons.remove_child(child)
		child.queue_free()
	menu_title.text = {"title": "米多放学路\n从校门口，平安回家", "paused": "休息一下", "defeat": "今天有点难…\n再试一次！", "victory": "到家了！\n饭菜还热着，明天见。"}[mode]
	if mode == "paused":
		add_menu_button("继续", resume_run)
	add_menu_button("开始回家  [Enter]" if mode == "title" else "重新挑战", start_run)
	if mode == "title":
		add_menu_button("精灵实验室 / Playground", launch_playground)
	else:
		add_menu_button("返回标题", func(): show_menu("title"))
	overlay.show()
	menu_buttons.get_child(0).grab_focus()

func launch_playground() -> void:
	get_tree().change_scene_to_file("res://godot/scenes/Playground.tscn")

func add_menu_button(title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(272, 29)
	button.pressed.connect(action)
	menu_buttons.add_child(button)

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 13
	hud = Label.new()
	hud.theme = theme
	hud.position = Vector2(12, 6)
	hud.add_theme_color_override("font_shadow_color", Color("222039"))
	hud.add_theme_constant_override("shadow_offset_x", 1)
	hud.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(hud)
	var controls := Label.new()
	controls.theme = theme
	controls.position = Vector2(8, 323)
	controls.add_theme_font_size_override("font_size", 10)
	controls.text = "WASD/方向 移动 · Ctrl 跑 · Shift 冲刺 · 空格 跳 / Ctrl+空格 大跳\nJ-J 连拳 · K-K 连踢 · ↓+K 扫腿 · 空中K 飞踢 · L 必杀 · Esc 暂停"
	layer.add_child(controls)
	overlay = Panel.new()
	overlay.theme = theme
	overlay.position = Vector2(143, 55)
	overlay.size = Vector2(354, 250)
	layer.add_child(overlay)
	menu_title = Label.new()
	menu_title.position = Vector2(12, 18)
	menu_title.size = Vector2(330, 67)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 22)
	overlay.add_child(menu_title)
	menu_buttons = VBoxContainer.new()
	menu_buttons.position = Vector2(40, 99)
	menu_buttons.add_theme_constant_override("separation", 10)
	overlay.add_child(menu_buttons)

func update_hud() -> void:
	if player == null:
		return
	var super_status := "就绪" if player.super_cooldown <= 0 else "%.1fs" % player.super_cooldown
	hud.text = "米多  HP %d / 100     必杀 L：%s\n%s  ·  遭遇 %d / 4   %s" % [player.current_hp, super_status, PLACES[encounter], encounter + 1, "GO → 向右回家" if cleared else "击败敌人解除路障"]
	for enemy in living_enemies():
		if enemy.role in ["mini", "boss"]:
			hud.text += "\n%s  %d / %d  红线预警 → 闪避 → 反击" % [Actor.LABELS[enemy.role], enemy.current_hp, enemy.max_hp]

func _draw() -> void:
	if mode != "playing" or player == null:
		return
	if not cleared:
		var x: float = LOCKS[encounter]
		draw_line(Vector2(x, 230), Vector2(x, 320), Color("efbc82"), 3)
		for y in range(238, 320, 16):
			draw_line(Vector2(x - 6, y), Vector2(x + 6, y + 8), Color("eb766e"), 4)
	else:
		draw_string(FONT, Vector2(camera.position.x + 220, 160), "GO →", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffe5a0"))
