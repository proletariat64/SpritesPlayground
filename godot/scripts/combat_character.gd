extends Node2D
class_name CombatCharacter

const MoveExecutorScript := preload("res://godot/scripts/move_executor.gd")
const StateMachineScript := preload("res://godot/scripts/combat_state_machine.gd")
const CharacterTemplateScript := preload("res://godot/scripts/character_template.gd")

var template_id: String = "combat_gray_s64"
var instance_id: String = "character"
var sprite_size_class: String = "s64"
var sprite_set_id: String = "gray_dummy_s64"
var frame_size: int = 80
var max_hp: int = 100
var current_hp: int = 100
var control_mode: String = "manual"
var debug_boxes_visible: bool = true
var is_test_dummy: bool = false
var template: Dictionary = {}
var hurtbox_profile: Dictionary = {}
var foot_collision_profile: Dictionary = {}

var move_executor: Node
var state_machine: Node

var _flash_time: float = 0.0
var _ai_elapsed: float = 0.0
var _ai_decision_in: float = 0.0
var _ai_vector: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(instance_id)
	_load_template()
	move_executor = MoveExecutorScript.new()
	move_executor.name = "move_executor"
	add_child(move_executor)
	move_executor.configure(template["move_templates"])

	state_machine = StateMachineScript.new()
	state_machine.name = "state_machine"
	add_child(state_machine)
	state_machine.configure(move_executor)

	queue_redraw()


func _load_template() -> void:
	template = CharacterTemplateScript.load_template(template_id)
	_apply_template_data(template)


func apply_template_id(next_template_id: String) -> void:
	template_id = next_template_id
	_load_template()
	if move_executor != null:
		move_executor.configure(template["move_templates"])
	if state_machine != null:
		state_machine.reset_to_idle()
	current_hp = max_hp
	queue_redraw()


func apply_runtime_template(runtime_template: Dictionary) -> void:
	template = runtime_template.duplicate(true)
	_apply_template_data(template)
	if move_executor != null:
		move_executor.configure(template["move_templates"])
	if state_machine != null:
		state_machine.reset_to_idle()
	current_hp = max_hp
	queue_redraw()


func _apply_template_data(runtime_template: Dictionary) -> void:
	template_id = str(runtime_template["template_id"])
	sprite_size_class = str(runtime_template["sprite_size_class"])
	sprite_set_id = str(runtime_template.get("sprite_set_id", ""))
	frame_size = int(runtime_template["frame_size"])
	max_hp = int(runtime_template["max_hp"])
	current_hp = max_hp
	hurtbox_profile = runtime_template["hurtbox_profile"].duplicate(true)
	foot_collision_profile = runtime_template["foot_collision_profile"].duplicate(true)


func tick_character(delta: float, arena_center: Vector2, arena_radius: Vector2) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)

	var input_vector := Vector2.ZERO
	if current_hp <= 0:
		state_machine.enter_dead()
	elif is_test_dummy:
		input_vector = Vector2.ZERO
	elif control_mode == "ai":
		input_vector = _tick_ai(delta)
	else:
		input_vector = _manual_input()
		_apply_manual_actions()

	state_machine.tick(delta, input_vector)
	position += state_machine.velocity * delta
	_clamp_foot_to_arena(arena_center, arena_radius)
	queue_redraw()


func take_hit(damage: int, _hitbox_id: String, _source_instance_id: String) -> void:
	if current_hp <= 0:
		return
	current_hp = maxi(0, current_hp - damage)
	_flash_time = 0.14
	if current_hp <= 0:
		state_machine.enter_dead()
	else:
		state_machine.enter_hurt()
	queue_redraw()


func reset_runtime(new_position: Vector2) -> void:
	position = new_position
	current_hp = max_hp
	_flash_time = 0.0
	state_machine.reset_to_idle()
	queue_redraw()


func active_hitboxes_world() -> Array:
	return move_executor.active_hitboxes_world(global_position, state_machine.facing, state_machine.visual_jump_offset)


func hurtboxes_world() -> Array:
	var entries: Array = []
	for hurtbox_id in hurtbox_profile.keys():
		var local_rect: Rect2 = hurtbox_profile[hurtbox_id]
		local_rect.position.y += state_machine.visual_jump_offset
		entries.append({
			"hurtbox_id": hurtbox_id,
			"rect": Rect2(global_position + local_rect.position, local_rect.size),
		})
	return entries


func foot_center_world() -> Vector2:
	return global_position + foot_collision_profile["center"]


func debug_summary() -> Dictionary:
	return {
		"template_id": template_id,
		"instance_id": instance_id,
		"sprite_set_id": sprite_set_id,
		"state": state_machine.current_state,
		"move": state_machine.current_move,
		"frame": state_machine.current_frame(),
		"hp": "%d/%d" % [current_hp, max_hp],
		"active_hitboxes": move_executor.active_hitboxes_local().size(),
		"mode": control_mode,
	}


func _manual_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _apply_manual_actions() -> void:
	if Input.is_action_just_pressed("dash"):
		state_machine.request_action("dash")
	if Input.is_action_just_pressed("jump"):
		state_machine.request_action("jump")
	if Input.is_action_just_pressed("basic_punch"):
		request_attack("basic_punch")
	if Input.is_action_just_pressed("basic_kick"):
		request_attack("basic_kick")


func request_attack(move_id: String) -> bool:
	if not state_machine.can_start_attack():
		return false
	return move_executor.start_attack_intent(move_id)


func _tick_ai(delta: float) -> Vector2:
	_ai_elapsed += delta
	_ai_decision_in -= delta
	if _ai_decision_in > 0.0:
		return _ai_vector

	_ai_decision_in = _rng.randf_range(0.25, 0.75)
	var choice := _rng.randi_range(0, 5)
	match choice:
		0:
			_ai_vector = Vector2.ZERO
		1:
			_ai_vector = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.6)).normalized()
		2:
			state_machine.request_action("dash")
		3:
			state_machine.request_action("jump")
		4:
			request_attack("basic_punch")
		5:
			request_attack("basic_kick")
	return _ai_vector


func _clamp_foot_to_arena(arena_center: Vector2, arena_radius: Vector2) -> void:
	var foot := foot_center_world()
	var rel := foot - arena_center
	var normalized := Vector2(rel.x / arena_radius.x, rel.y / arena_radius.y)
	if normalized.length() <= 1.0:
		return
	normalized = normalized.normalized()
	var clamped_foot := arena_center + Vector2(normalized.x * arena_radius.x, normalized.y * arena_radius.y)
	position += clamped_foot - foot


func _draw() -> void:
	var jump_y: float = state_machine.visual_jump_offset
	var body_color := Color(0.72, 0.72, 0.72)
	if is_test_dummy:
		body_color = Color(0.48, 0.52, 0.58)
	if _flash_time > 0.0:
		body_color = Color(1.0, 0.92, 0.86)
	if current_hp <= 0:
		body_color = Color(0.24, 0.24, 0.24)

	draw_rect(Rect2(Vector2(-16, -64 + jump_y), Vector2(32, 64)), body_color, true)
	draw_rect(Rect2(Vector2(-16, -64 + jump_y), Vector2(32, 64)), Color(0.08, 0.08, 0.08), false, 1.0)
	draw_line(Vector2(0, -46 + jump_y), Vector2(10 * state_machine.facing, -46 + jump_y), Color.BLACK, 2.0)

	if not debug_boxes_visible:
		return

	for hurtbox_id in hurtbox_profile.keys():
		var rect: Rect2 = hurtbox_profile[hurtbox_id]
		rect.position.y += jump_y
		draw_rect(rect, Color(0.1, 0.55, 1.0, 0.18), true)
		draw_rect(rect, Color(0.1, 0.55, 1.0), false, 1.0)

	for hitbox in active_hitboxes_world():
		var hit_rect: Rect2 = hitbox["rect"]
		hit_rect.position -= global_position
		draw_rect(hit_rect, Color(1.0, 0.18, 0.08, 0.26), true)
		draw_rect(hit_rect, Color(1.0, 0.18, 0.08), false, 1.0)

	_draw_ellipse(foot_collision_profile["center"], foot_collision_profile["radius"], Color(0.1, 1.0, 0.35))


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, 1.5)
