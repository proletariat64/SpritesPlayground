extends Node2D
class_name CombatCharacter

const MoveExecutorScript := preload("res://godot/scripts/move_executor.gd")
const StateMachineScript := preload("res://godot/scripts/combat_state_machine.gd")
const CharacterTemplateScript := preload("res://godot/scripts/character_template.gd")
const SpriteFramesGeneratorScript := preload("res://godot/scripts/spriteframes_generator.gd")
const CombatAIControllerScript := preload("res://godot/scripts/combat_ai_controller.gd")
const COMBO_BUFFER_MSEC := 650
const COMBAT_CONTEXT_SECONDS := 2.0
# Temporary #33 presentation rule until Move reaction metadata exists: heavy hits
# at or above this damage use the imported fall_down/down/get_up composition.
const KNOCKDOWN_DAMAGE_THRESHOLD := 12

var template_id: String = "combat_gray_s64"
var instance_id: String = "character"
var sprite_size_class: String = "s64"
var sprite_set_id: String = "gray_dummy_s64"
var frame_size: int = 80
var max_hp: int = 100
var current_hp: int = 100
var walk_speed: float = 95.0
var run_speed: float = 150.0
var control_mode: String = "manual"
var debug_boxes_visible: bool = true
var is_test_dummy: bool = false
var template: Dictionary = {}
var hurtbox_profile: Dictionary = {}
var foot_collision_profile: Dictionary = {}

var animated_sprite: AnimatedSprite2D
var sprite_frames_path: String = ""
var sprite_frames_valid: bool = false
var visual_fallback_enabled: bool = true

var move_executor: Node
var state_machine: Node
var ai_controller: Node
var combat_target: Node2D

var _flash_time: float = 0.0
var _hit_hurtbox_id: String = ""
var _contact_hurtbox_ids: Dictionary = {}
var _queued_combo_move: String = ""
var _combo_started_at_msec: int = 0
var _combat_context_remaining: float = 0.0


func _ready() -> void:
	_load_template()
	_ensure_animated_sprite()
	move_executor = MoveExecutorScript.new()
	move_executor.name = "move_executor"
	add_child(move_executor)
	move_executor.configure(template["move_templates"])

	state_machine = StateMachineScript.new()
	state_machine.name = "state_machine"
	add_child(state_machine)
	state_machine.configure(move_executor)
	state_machine.walk_speed = walk_speed
	state_machine.run_speed = run_speed
	move_executor.move_finished.connect(_on_move_finished_for_combo)

	ai_controller = CombatAIControllerScript.new()
	ai_controller.name = "combat_ai_controller"
	add_child(ai_controller)
	ai_controller.configure(self)
	ai_controller.set_target(combat_target)
	_load_sprite_frames_for_sprite_set()

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
	_load_sprite_frames_for_sprite_set()
	queue_redraw()


func apply_runtime_template(runtime_template: Dictionary) -> void:
	template = runtime_template.duplicate(true)
	_apply_template_data(template)
	if move_executor != null:
		move_executor.configure(template["move_templates"])
	if state_machine != null:
		state_machine.reset_to_idle()
	current_hp = max_hp
	_load_sprite_frames_for_sprite_set()
	queue_redraw()


func apply_v0_3_runtime_bundle(next_template: Dictionary, _next_sprite_set: Dictionary, next_moves: Dictionary) -> void:
	var next_max_hp := maxi(1, int(next_template.get("hp", max_hp)))
	template_id = str(next_template.get("template_id", template_id))
	sprite_set_id = str(next_template.get("sprite_set_ref", sprite_set_id))
	max_hp = next_max_hp
	current_hp = mini(current_hp, max_hp)
	walk_speed = maxf(1.0, float(next_template.get("walk_speed", 95.0)))
	run_speed = maxf(1.0, float(next_template.get("run_speed", 150.0)))
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
		"walk_speed": walk_speed,
		"run_speed": run_speed,
		"hurtbox_profile": hurtbox_profile,
		"foot_collision_profile": foot_collision_profile,
		"move_templates": move_templates,
	}
	if move_executor != null:
		move_executor.configure(move_templates)
	if state_machine != null:
		state_machine.walk_speed = walk_speed
		state_machine.run_speed = run_speed
		state_machine.reset_to_idle()
	_load_sprite_frames_for_sprite_set()
	queue_redraw()


func _apply_template_data(runtime_template: Dictionary) -> void:
	template_id = str(runtime_template["template_id"])
	sprite_size_class = str(runtime_template["sprite_size_class"])
	sprite_set_id = str(runtime_template.get("sprite_set_id", ""))
	frame_size = int(runtime_template["frame_size"])
	max_hp = int(runtime_template["max_hp"])
	current_hp = max_hp
	walk_speed = maxf(1.0, float(runtime_template.get("walk_speed", 95.0)))
	run_speed = maxf(1.0, float(runtime_template.get("run_speed", 150.0)))
	hurtbox_profile = runtime_template["hurtbox_profile"].duplicate(true)
	foot_collision_profile = runtime_template["foot_collision_profile"].duplicate(true)
	if state_machine != null:
		state_machine.walk_speed = walk_speed
		state_machine.run_speed = run_speed


func tick_character(delta: float, arena_center: Vector2, arena_radius: Vector2) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)
	_combat_context_remaining = maxf(0.0, _combat_context_remaining - delta)
	if _flash_time <= 0.0:
		_hit_hurtbox_id = ""
		_contact_hurtbox_ids.clear()

	var input_vector := Vector2.ZERO
	var run_requested := false
	if current_hp <= 0:
		if state_machine.current_state != StateMachineScript.STATE_DEAD:
			state_machine.enter_dead()
	elif is_test_dummy:
		input_vector = Vector2.ZERO
	elif control_mode == "ai":
		input_vector = _tick_ai(delta)
	else:
		input_vector = _manual_input()
		_apply_manual_actions()
		run_requested = _manual_run_requested()

	state_machine.tick(delta, input_vector, run_requested)
	_sync_visual_animation()
	position += state_machine.velocity * delta
	clamp_to_arena(arena_center, arena_radius)
	queue_redraw()


func clamp_to_arena(arena_center: Vector2, arena_radius: Vector2) -> void:
	_clamp_foot_to_arena(arena_center, arena_radius)


func take_hit(damage: int, _hitbox_id: String, _source_instance_id: String, resolved_hurtbox_id: String = "", contact_hurtbox_ids: Array = []) -> void:
	if current_hp <= 0:
		return
	mark_combat_engaged()
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
		state_machine.enter_hurt(damage >= KNOCKDOWN_DAMAGE_THRESHOLD)
	queue_redraw()


func reset_runtime(new_position: Vector2) -> void:
	position = new_position
	current_hp = max_hp
	_flash_time = 0.0
	_hit_hurtbox_id = ""
	_contact_hurtbox_ids.clear()
	_clear_combo_buffer()
	_combat_context_remaining = 0.0
	if ai_controller != null:
		ai_controller.reset()
	state_machine.reset_to_idle()
	_sync_visual_animation()
	queue_redraw()


func active_hitboxes_world() -> Array:
	return move_executor.active_hitboxes_world(global_position, state_machine.facing, state_machine.visual_jump_offset)


func hurtboxes_world() -> Array:
	# A Move may author frame-scoped defensive geometry. When one of those
	# windows is active it replaces the character's default profile for that
	# frame; outside the authored window the stable template profile applies.
	var attack_hurtboxes: Array = move_executor.active_hurtboxes_world(
		global_position,
		state_machine.facing,
		state_machine.visual_jump_offset
	)
	if not attack_hurtboxes.is_empty():
		return attack_hurtboxes
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
		"state_context": state_machine.current_state_context,
		"state_authority_backend": state_machine.state_authority_backend(),
		"state_authority_state": state_machine.state_authority_state(),
		"move": state_machine.current_move,
		"frame": state_machine.current_frame(),
		"hitstop_frames": move_executor.hitstop_frames_remaining(),
		"hp": "%d/%d" % [current_hp, max_hp],
		"active_hitboxes": move_executor.active_hitboxes_local().size(),
		"last_hit_hurtbox": _hit_hurtbox_id,
		"contact_hurtboxes": _contact_hurtbox_ids.keys(),
		"mode": control_mode,
		"ai_backend": ai_backend(),
	}


func _manual_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _manual_run_requested() -> bool:
	return Input.is_action_pressed("run")


func _apply_manual_actions() -> void:
	if Input.is_action_just_pressed("dash"):
		state_machine.request_action("dash")
	if Input.is_action_just_pressed("jump"):
		var jump_action := "big_jump" if Input.is_action_pressed("run") else "jump"
		state_machine.request_action(jump_action)
	if Input.is_action_just_pressed("basic_punch"):
		_handle_punch_input()
	if Input.is_action_just_pressed("basic_kick"):
		_handle_kick_input()


func _handle_punch_input() -> void:
	if Input.is_action_pressed("move_down"):
		_clear_combo_buffer()
		request_attack("uppercut")
		return
	if state_machine.current_state == StateMachineScript.STATE_ATTACK:
		_queue_combo("jab", "cross_punch")
		return
	_start_combo_first("jab")


func _handle_kick_input() -> void:
	if state_machine.current_state == StateMachineScript.STATE_JUMP:
		_clear_combo_buffer()
		request_attack("flying_kick", true)
		return
	if Input.is_action_pressed("move_down"):
		_clear_combo_buffer()
		request_attack("sweep")
		return
	if state_machine.current_state == StateMachineScript.STATE_ATTACK:
		_queue_combo("high_kick", "roundhouse_kick")
		return
	_start_combo_first("high_kick")


func _start_combo_first(move_id: String) -> void:
	_clear_combo_buffer()
	if request_attack(move_id):
		_combo_started_at_msec = Time.get_ticks_msec()


func _queue_combo(first_move_id: String, continuation_move_id: String) -> void:
	var elapsed := Time.get_ticks_msec() - _combo_started_at_msec
	if elapsed > COMBO_BUFFER_MSEC:
		return
	var active_move := str(state_machine.current_move)
	if active_move != _resolve_move_id(first_move_id):
		return
	var resolved := _resolve_move_id(continuation_move_id)
	if move_executor.move_templates.has(resolved):
		_queued_combo_move = continuation_move_id


func _on_move_finished_for_combo(_move_id: String) -> void:
	if _queued_combo_move.is_empty():
		return
	call_deferred("_start_queued_combo")


func _start_queued_combo() -> void:
	var next_move := _queued_combo_move
	_queued_combo_move = ""
	_combo_started_at_msec = 0
	request_attack(next_move)


func _clear_combo_buffer() -> void:
	_queued_combo_move = ""
	_combo_started_at_msec = 0


func request_attack(move_id: String, allow_airborne: bool = false) -> bool:
	if not state_machine.can_start_attack(allow_airborne):
		return false
	var started: bool = move_executor.start_attack_intent(_resolve_move_id(move_id))
	if started:
		mark_combat_engaged()
	return started


func mark_combat_engaged() -> void:
	_combat_context_remaining = COMBAT_CONTEXT_SECONDS


# Explicit runtime-facing alias rule: a bare move id (jab) resolves to the
# character-scoped id (miduo_jab) when that is what the template equipped.
func _resolve_move_id(move_id: String) -> String:
	if move_executor.move_templates.has(move_id):
		return move_id
	var prefixed := "%s_%s" % [template_id, move_id]
	if move_executor.move_templates.has(prefixed):
		return prefixed
	return move_id


func _first_available_move(candidates: Array) -> String:
	for candidate in candidates:
		var resolved := _resolve_move_id(str(candidate))
		if move_executor.move_templates.has(resolved):
			return resolved
	return str(candidates[0]) if not candidates.is_empty() else ""


func _punch_move_id() -> String:
	return _first_available_move(["jab", "basic_punch"])


func _kick_move_id() -> String:
	return _first_available_move(["high_kick", "basic_kick"])


func set_combat_target(next_target: Node2D) -> void:
	combat_target = next_target
	if ai_controller != null:
		ai_controller.set_target(next_target)


func ai_backend() -> String:
	return str(ai_controller.backend()) if ai_controller != null else "deterministic_fallback"


func _tick_ai(delta: float) -> Vector2:
	if ai_controller == null:
		return Vector2.ZERO
	return ai_controller.movement_intent(delta)


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
	return CharacterTemplateScript.v0_3_move_to_runtime(
		str(move.get("move_id", "")),
		move,
		template_id
	)


func _ensure_animated_sprite() -> void:
	if animated_sprite != null:
		return
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "animated_sprite"
	animated_sprite.centered = true
	animated_sprite.position = Vector2(0, -32)
	animated_sprite.visible = false
	add_child(animated_sprite)


func _load_sprite_frames_for_sprite_set() -> void:
	_ensure_animated_sprite()
	sprite_frames_path = SpriteFramesGeneratorScript.sprite_frames_path(sprite_set_id)
	if not FileAccess.file_exists(sprite_frames_path):
		sprite_frames_valid = false
		if animated_sprite != null:
			animated_sprite.sprite_frames = null
			animated_sprite.visible = false
		return
	var resource := ResourceLoader.load(sprite_frames_path, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is SpriteFrames:
		animated_sprite.sprite_frames = resource
		sprite_frames_valid = true
		animated_sprite.visible = true
		_sync_visual_animation()
		return
	sprite_frames_valid = false
	if animated_sprite != null:
		animated_sprite.sprite_frames = null
		animated_sprite.visible = false


func has_spriteframes_playback() -> bool:
	return sprite_frames_valid and animated_sprite != null and animated_sprite.sprite_frames != null


func _sync_visual_animation() -> void:
	if not has_spriteframes_playback() or state_machine == null:
		return
	var frames: SpriteFrames = animated_sprite.sprite_frames
	var base_name := _animation_for_runtime_state()
	var resolved := _resolve_visual_animation(frames, base_name)
	var animation_name := str(resolved.get("animation", ""))
	if animation_name.is_empty():
		animated_sprite.visible = false
		return
	animated_sprite.visible = true
	animated_sprite.flip_h = bool(resolved.get("flip_h", false))
	animated_sprite.position = Vector2(0, -32 + state_machine.visual_jump_offset)
	var previous_animation := str(animated_sprite.animation)
	var previous_frame := animated_sprite.frame
	var previous_progress := animated_sprite.frame_progress
	var switching := previous_animation != animation_name
	if switching:
		animated_sprite.animation = animation_name
	var frame_count := maxi(1, frames.get_frame_count(animation_name))
	if state_machine.current_state == StateMachineScript.STATE_ATTACK:
		animated_sprite.pause()
		animated_sprite.frame = clampi(move_executor.current_frame(), 0, frame_count - 1)
	else:
		if not animated_sprite.is_playing():
			animated_sprite.play(animation_name)
		if switching and _preserves_cycle_phase(previous_animation, animation_name):
			animated_sprite.frame = clampi(previous_frame, 0, frame_count - 1)
			animated_sprite.frame_progress = previous_progress


const LOCOMOTION_BASE_STATES := ["idle", "walk", "run"]
const LOCOMOTION_DIRECTIONS := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


func _resolve_visual_animation(frames: SpriteFrames, base_name: String) -> Dictionary:
	if _is_locomotion_animation_base(base_name):
		var direction := str(state_machine.get("locomotion_direction"))
		var directional_candidates: Array = []
		if base_name.begins_with("walk_") or base_name.begins_with("run_"):
			directional_candidates.append("eden_%s_%s" % [base_name, direction])
		directional_candidates.append("%s_%s" % [base_name, direction])
		for directional in directional_candidates:
			if _has_animation(frames, str(directional)):
				return {"animation": str(directional), "flip_h": false}
		if _has_animation(frames, base_name):
			return {"animation": base_name, "flip_h": state_machine.facing < 0}
		var mode := "run" if base_name.begins_with("run_") else "walk"
		if base_name != "idle":
			var loop_directional := "%s_%s" % [mode, direction]
			if _has_animation(frames, loop_directional):
				return {"animation": loop_directional, "flip_h": false}
			if _has_animation(frames, mode):
				return {"animation": mode, "flip_h": state_machine.facing < 0}
		var idle_directional := "idle_%s" % direction
		if _has_animation(frames, idle_directional):
			return {"animation": idle_directional, "flip_h": false}
		if _has_animation(frames, "idle"):
			return {"animation": "idle", "flip_h": state_machine.facing < 0}
		return {}
	var side_resolved := _resolve_two_facing_animation(frames, base_name)
	if not side_resolved.is_empty():
		return side_resolved
	var animation_name := _fallback_animation(frames, base_name)
	if animation_name.is_empty():
		return {}
	return {"animation": animation_name, "flip_h": false}


func _resolve_two_facing_animation(frames: SpriteFrames, base_name: String) -> Dictionary:
	var facing_value := 1 if state_machine == null else int(state_machine.facing)
	var side := "w" if facing_value < 0 else "e"
	var candidates: Array = []
	if side == "w":
		candidates = ["%s_w" % base_name]
	else:
		candidates = [base_name, "%s_e" % base_name]
	for candidate in candidates:
		if _has_animation(frames, str(candidate)):
			return {"animation": str(candidate), "flip_h": false}
	# Legacy side-only sets may contain east art without an authored west clip.
	if side == "w" and _has_animation(frames, base_name):
		return {"animation": base_name, "flip_h": true}
	return {}


func _is_locomotion_animation_base(animation_name: String) -> bool:
	return (
		animation_name in LOCOMOTION_BASE_STATES
		or animation_name.begins_with("walk_")
		or animation_name.begins_with("run_")
	)


func _locomotion_base(animation_name: String) -> String:
	for base in LOCOMOTION_BASE_STATES:
		if animation_name == base:
			return base
		for direction in LOCOMOTION_DIRECTIONS:
			if animation_name == "%s_%s" % [base, direction]:
				return base
	return ""


func _preserves_cycle_phase(previous_animation: String, next_animation: String) -> bool:
	var previous_base := _locomotion_base(previous_animation)
	var next_base := _locomotion_base(next_animation)
	if previous_base.is_empty() or next_base.is_empty():
		return false
	if previous_base == next_base:
		return true
	return previous_base in ["walk", "run"] and next_base in ["walk", "run"]


func _animation_for_runtime_state() -> String:
	match state_machine.current_state:
		StateMachineScript.STATE_ATTACK:
			# Attack clips keep their imported action id; scoped move ids (miduo_jab)
			# resolve back through the explicit animation_id alias.
			var animation_id := str(move_executor.active_move.get("animation_id", ""))
			if animation_id.is_empty():
				animation_id = str(state_machine.current_move)
			return animation_id
		StateMachineScript.STATE_DASH:
			return "dash"
		StateMachineScript.STATE_JUMP, StateMachineScript.STATE_HURT, StateMachineScript.STATE_DEAD:
			return str(state_machine.presentation_animation_base())
		StateMachineScript.STATE_WALK:
			return str(state_machine.locomotion_animation_base())
	if _combat_context_remaining > 0.0 and _has_combat_idle_animation():
		return "fight_idle"
	return "idle"


func _has_combat_idle_animation() -> bool:
	if not has_spriteframes_playback():
		return false
	var frames: SpriteFrames = animated_sprite.sprite_frames
	return (
		_has_animation(frames, "fight_idle")
		or _has_animation(frames, "fight_idle_e")
		or _has_animation(frames, "fight_idle_w")
	)


func _fallback_animation(_frames: SpriteFrames, _requested: String) -> String:
	# Missing and unequipped actions stay visibly missing. Unrelated animation
	# substitution would make the import report and live behavior disagree.
	return ""


func _has_animation(frames: SpriteFrames, animation_name: String) -> bool:
	for name in frames.get_animation_names():
		if str(name) == animation_name:
			return true
	return false


func _draw() -> void:
	var jump_y: float = state_machine.visual_jump_offset
	if visual_fallback_enabled and not has_spriteframes_playback():
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

	for hurtbox in hurtboxes_world():
		var hurtbox_id := str(hurtbox["hurtbox_id"])
		var rect: Rect2 = hurtbox["rect"]
		rect.position -= global_position
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
