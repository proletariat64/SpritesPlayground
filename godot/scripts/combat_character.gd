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
var _hit_hurtbox_id: String = ""
var _contact_hurtbox_ids: Dictionary = {}
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


func apply_v0_3_runtime_bundle(next_template: Dictionary, _next_sprite_set: Dictionary, next_moves: Dictionary) -> void:
	var next_max_hp := maxi(1, int(next_template.get("hp", max_hp)))
	template_id = str(next_template.get("template_id", template_id))
	sprite_set_id = str(next_template.get("sprite_set_ref", sprite_set_id))
	max_hp = next_max_hp
	current_hp = mini(current_hp, max_hp)
	hurtbox_profile = _v0_3_hurtboxes_to_runtime(next_template.get("hurtboxes", {}))
	foot_collision_profile = _v0_3_foot_to_runtime(next_template.get("foot_collision", {}))
	var move_templates := {}
	for move_id in next_moves.keys():
		move_templates[str(move_id)] = _v0_3_move_to_runtime(next_moves[move_id])
	template = {
		"template_id": template_id,
		"sprite_size_class": sprite_size_class,
		"sprite_set_id": sprite_set_id,
		"frame_size": frame_size,
		"max_hp": max_hp,
		"hurtbox_profile": hurtbox_profile,
		"foot_collision_profile": foot_collision_profile,
		"move_templates": move_templates,
	}
	if move_executor != null:
		move_executor.configure(move_templates)
	if state_machine != null:
		state_machine.reset_to_idle()
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
	if _flash_time <= 0.0:
		_hit_hurtbox_id = ""
		_contact_hurtbox_ids.clear()

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
	clamp_to_arena(arena_center, arena_radius)
	queue_redraw()


func clamp_to_arena(arena_center: Vector2, arena_radius: Vector2) -> void:
	_clamp_foot_to_arena(arena_center, arena_radius)


func take_hit(damage: int, _hitbox_id: String, _source_instance_id: String, resolved_hurtbox_id: String = "", contact_hurtbox_ids: Array = []) -> void:
	if current_hp <= 0:
		return
	current_hp = maxi(0, current_hp - damage)
	_flash_time = 0.14
	_hit_hurtbox_id = resolved_hurtbox_id
	_contact_hurtbox_ids.clear()
	for hurtbox_id in contact_hurtbox_ids:
		_contact_hurtbox_ids[str(hurtbox_id)] = true
	if not resolved_hurtbox_id.is_empty():
		_contact_hurtbox_ids[resolved_hurtbox_id] = true
	if current_hp <= 0:
		state_machine.enter_dead()
	else:
		state_machine.enter_hurt()
	queue_redraw()


func reset_runtime(new_position: Vector2) -> void:
	position = new_position
	current_hp = max_hp
	_flash_time = 0.0
	_hit_hurtbox_id = ""
	_contact_hurtbox_ids.clear()
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


func depth_sort_key() -> float:
	return foot_center_world().y


func foot_contact_ellipse() -> Dictionary:
	return {
		"center": foot_center_world(),
		"radius": foot_collision_profile.get("radius", Vector2.ZERO),
	}


static func foot_separation_delta(first, second) -> Vector2:
	if first == null or second == null:
		return Vector2.ZERO
	if not first.has_method("foot_contact_ellipse") or not second.has_method("foot_contact_ellipse"):
		return Vector2.ZERO
	var first_ellipse: Dictionary = first.foot_contact_ellipse()
	var second_ellipse: Dictionary = second.foot_contact_ellipse()
	var first_center: Vector2 = first_ellipse.get("center", Vector2.ZERO)
	var second_center: Vector2 = second_ellipse.get("center", Vector2.ZERO)
	var first_radius: Vector2 = first_ellipse.get("radius", Vector2.ZERO)
	var second_radius: Vector2 = second_ellipse.get("radius", Vector2.ZERO)
	var combined := Vector2(
		maxf(1.0, first_radius.x + second_radius.x),
		maxf(1.0, first_radius.y + second_radius.y)
	)
	var current_delta := second_center - first_center
	var normalized := Vector2(current_delta.x / combined.x, current_delta.y / combined.y)
	var normalized_distance := normalized.length()
	if normalized_distance >= 1.0:
		return Vector2.ZERO
	var direction := Vector2.RIGHT
	if normalized_distance > 0.0001:
		direction = normalized / normalized_distance
	var target_delta := Vector2(direction.x * combined.x, direction.y * combined.y)
	return target_delta - current_delta


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
		"last_hit_hurtbox": _hit_hurtbox_id,
		"contact_hurtboxes": _contact_hurtbox_ids.keys(),
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
	var foot_radius: Vector2 = foot_collision_profile.get("radius", Vector2.ZERO)
	var effective_radius := Vector2(
		maxf(1.0, arena_radius.x - foot_radius.x),
		maxf(1.0, arena_radius.y - foot_radius.y)
	)
	var normalized := Vector2(rel.x / effective_radius.x, rel.y / effective_radius.y)
	if normalized.length() <= 1.0:
		return
	normalized = normalized.normalized()
	var clamped_foot := arena_center + Vector2(normalized.x * effective_radius.x, normalized.y * effective_radius.y)
	position += clamped_foot - foot


func _v0_3_hurtboxes_to_runtime(hurtboxes: Dictionary) -> Dictionary:
	var profile := {}
	for hurtbox_id in hurtboxes.keys():
		var rect: Dictionary = hurtboxes[hurtbox_id]
		profile[str(hurtbox_id)] = Rect2(
			float(rect.get("x", 0.0)),
			float(rect.get("y", 0.0)),
			maxf(1.0, float(rect.get("w", 1.0))),
			maxf(1.0, float(rect.get("h", 1.0)))
		)
	return profile


func _v0_3_foot_to_runtime(foot: Dictionary) -> Dictionary:
	var center: Dictionary = foot.get("center", {})
	var radius: Dictionary = foot.get("radius", {})
	return {
		"center": Vector2(float(center.get("x", 0.0)), float(center.get("y", 0.0))),
		"radius": Vector2(maxf(1.0, float(radius.get("x", 1.0))), maxf(1.0, float(radius.get("y", 1.0)))),
	}


func _v0_3_move_to_runtime(move: Dictionary) -> Dictionary:
	# ponytail: live MoveExecutor currently consumes frame count, hitbox windows, rects, and damage only.
	# v0.3 hitstop_frames, multi_hit, events, and sprite-set frame data stay authoring-preview only until live combat consumes them.
	var windows: Array = []
	for hitbox in move.get("hitboxes", []):
		var window: Dictionary = hitbox.get("active_window", {})
		var rect: Dictionary = hitbox.get("rect", {})
		windows.append({
			"from_frame": int(window.get("start_frame", 0)),
			"to_frame": int(window.get("end_frame", 0)),
			"hitbox_id": str(hitbox.get("hitbox_id", "")),
			"damage": int(move.get("damage", 0)),
			"rect": Rect2(
				float(rect.get("x", 0.0)),
				float(rect.get("y", 0.0)),
				maxf(1.0, float(rect.get("w", 1.0))),
				maxf(1.0, float(rect.get("h", 1.0)))
			),
		})
	return {
		"move_id": str(move.get("move_id", "")),
		"fps": 60,
		"total_frames": maxi(1, int(move.get("frame_count", 1))),
		"hitbox_windows": windows,
	}


func _draw() -> void:
	var jump_y: float = state_machine.visual_jump_offset
	var body_color := Color(0.72, 0.72, 0.72)
	if is_test_dummy:
		body_color = Color(0.48, 0.52, 0.58)
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
		var fill_color := Color(0.1, 0.55, 1.0, 0.18)
		var line_color := Color(0.1, 0.55, 1.0)
		var line_width := 1.0
		if _flash_time > 0.0 and _contact_hurtbox_ids.has(hurtbox_id):
			fill_color = Color(1.0, 0.92, 0.35, 0.24)
			line_color = Color(1.0, 0.88, 0.35)
			line_width = 1.5
		if _flash_time > 0.0 and hurtbox_id == _hit_hurtbox_id:
			fill_color = Color(1.0, 0.34, 0.12, 0.52)
			line_color = Color(1.0, 0.18, 0.08)
			line_width = 2.0
		draw_rect(rect, fill_color, true)
		draw_rect(rect, line_color, false, line_width)

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
