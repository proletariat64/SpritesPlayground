extends "res://godot/scripts/combat_character.gd"
## Stage-only tuning. Authored resources and LimboAI authority are never replaced.
const EnemyFrames := preload("res://godot/scripts/homeward_enemy_frames.gd")
const LABELS := {"player": "米多", "brawler": "拳手", "rusher": "冲锋手", "kicker": "踢手", "mini": "小头目·铁腿", "boss": "路口头领"}
const COLORS := {"player": Color("91e6a1"), "brawler": Color("96c7ee"), "rusher": Color("ffc36d"), "kicker": Color("dbabf7"), "mini": Color("ff9670"), "boss": Color("ff657b")}
var role := "player"
var team := 0
var lane := Rect2(24, 222, 490, 96)
var grace := 0.0
var super_cooldown := 0.0
var super_flash := 0.0
var brain_phase := "approach"
var brain_timer := 0.5
var committed_facing := 1
var attack_count := 0
var pending_move := ""
var input_enabled := true
var stage_font: Font

func _ready() -> void:
	super._ready()
	debug_boxes_visible = false
	var tuned: Dictionary = template.duplicate(true)
	tuned.max_hp = {"player": 100, "brawler": 22, "rusher": 24, "kicker": 24, "mini": 60, "boss": 90}[role]
	tuned.walk_speed = {"player": 95.0, "brawler": 52.0, "rusher": 92.0, "kicker": 60.0, "mini": 55.0, "boss": 67.0}[role]
	for move in tuned.move_templates.values():
		# Imported clips contain six frames: play at their intended pixel-animation pace.
		move.fps = 12
		if team == 1:
			for box in move.hitbox_windows:
				box.damage = 7 if role not in ["mini", "boss"] else 10
	var roundhouse: Dictionary = tuned.move_templates[_resolve_move_id("roundhouse_kick")].duplicate(true)
	roundhouse.move_id = "homeward_super"
	# Explicitly retain imported roundhouse animation, not the new runtime move id.
	roundhouse.animation_id = "roundhouse_kick"
	roundhouse.events = []
	roundhouse.hitbox_windows = [{"from_frame": 2, "to_frame": 3, "hitbox_id": "super_arc", "damage": 24, "rect": Rect2(-76, -60, 152, 58)}]
	tuned.move_templates.homeward_super = roundhouse
	apply_runtime_template(tuned)
	if team == 1:
		apply_runtime_sprite_frames(EnemyFrames.for_role(role))
	move_executor.move_finished.connect(_stage_move_finished)

func _resolve_visual_animation(frames: SpriteFrames, base_name: String) -> Dictionary:
	if team != 1:
		return super._resolve_visual_animation(frames, base_name)
	var clip := ""
	if base_name in ["idle", "fight_idle"]:
		# Source idle includes stepping/lifted knees: deliberately hold a safe guard.
		clip = "guard"
	elif base_name == "walk" or base_name.begins_with("walk_"):
		clip = "walk"
	elif base_name == "run" or base_name.begins_with("run_"):
		clip = "run"
	elif base_name in ["jab", "cross_punch", "uppercut"]:
		clip = "punch"
	elif base_name in ["high_kick", "roundhouse_kick", "sweep", "flying_kick"]:
		# No dedicated boss special sheet was generated: same real kick poses.
		clip = "kick"
	elif base_name == "eden_fall_down":
		clip = "fall"
	elif base_name == "eden_down":
		clip = "down"
	elif base_name == "eden_get_up":
		clip = "get_up"
	elif base_name in ["hurt", "dash"]:
		clip = base_name
	if clip.is_empty() or not frames.has_animation(clip):
		return {}
	# Generated originals face LEFT. Enemy presentation has two facings only;
	# the inherited attack clock and jump offset remain authoritative.
	return {"animation": clip, "flip_h": state_machine.facing > 0}

func _sync_visual_animation() -> void:
	super._sync_visual_animation()
	if team != 1 or state_machine == null or not has_spriteframes_playback():
		return
	if state_machine.current_state not in [StateMachineScript.STATE_HURT, StateMachineScript.STATE_DEAD]:
		return
	# Three-pose reactions finish before the inherited reaction phase does.
	# Drive them from that phase's authoritative clock, never restart autoplay.
	var clip := str(animated_sprite.animation)
	if clip not in ["hurt", "fall", "down", "get_up"]:
		return
	var elapsed: float = state_machine.state_elapsed
	if clip == "get_up":
		elapsed -= StateMachineScript.KNOCKDOWN_FALL_SECONDS + StateMachineScript.KNOCKDOWN_DOWN_SECONDS
	elif clip == "down":
		elapsed = 0.0
	var frames: SpriteFrames = animated_sprite.sprite_frames
	var index := int(floor(maxf(0.0, elapsed) * frames.get_animation_speed(clip)))
	animated_sprite.pause()
	animated_sprite.frame = clampi(index, 0, frames.get_frame_count(clip) - 1)

func _stage_move_finished(_id: String) -> void:
	if team == 1:
		brain_phase = "recovery"
		brain_timer = 0.95 if role in ["mini", "boss"] else 0.65

func stage_tick(delta: float) -> void:
	grace = maxf(0, grace - delta)
	super_cooldown = maxf(0, super_cooldown - delta)
	super_flash = maxf(0, super_flash - delta)
	tick_character(delta, Vector2.ZERO, Vector2.ONE)
	if grace > 0 and team == 0:
		animated_sprite.modulate.a = 0.5 if int(grace * 18) % 2 else 1.0
	else:
		animated_sprite.modulate.a = 1.0

func _manual_input() -> Vector2:
	return super._manual_input() if input_enabled else Vector2.ZERO

func _apply_manual_actions() -> void:
	if not input_enabled:
		return
	super._apply_manual_actions()
	if Input.is_action_just_pressed("homeward_super"):
		try_super()

func try_super() -> bool:
	if not input_enabled or team != 0 or current_hp <= 0 or super_cooldown > 0:
		return false
	if not request_attack("homeward_super"):
		return false
	_clear_combo_buffer()
	super_cooldown = 5.5
	super_flash = 0.55
	return true

func take_hit(damage: int, box_id: String, source_id: String, hurt_id: String = "", contacts: Array = []) -> void:
	if grace > 0 or current_hp <= 0:
		return
	super.take_hit(damage, box_id, source_id, hurt_id, contacts)
	# Player gets time to recover from hitstun (including knockdown).
	grace = 1.65 if team == 0 and damage >= 12 else (0.65 if team == 0 else 0.12)
	brain_phase = "recovery"
	brain_timer = 0.55

func _clamp_foot_to_arena(_center: Vector2, _radius: Vector2) -> void:
	var foot := foot_center_world()
	var radius: Vector2 = foot_collision_profile.get("radius", Vector2.ONE)
	var clamped := Vector2(clampf(foot.x, lane.position.x + radius.x, lane.end.x - radius.x), clampf(foot.y, lane.position.y + radius.y, lane.end.y - radius.y))
	position += clamped - foot

func _tick_ai(delta: float) -> Vector2:
	if combat_target == null or combat_target.current_hp <= 0:
		return Vector2.ZERO
	if state_machine.current_state in ["hurt", "dead", "attack"]:
		return Vector2.ZERO
	brain_timer = maxf(0, brain_timer - delta)
	if brain_phase == "recovery":
		if brain_timer <= 0:
			brain_phase = "approach"
		return Vector2.ZERO
	if brain_phase == "telegraph":
		state_machine.facing = committed_facing
		if brain_timer <= 0:
			if request_attack(pending_move):
				brain_phase = "committed"
		return Vector2.ZERO
	var offset: Vector2 = combat_target.position - position
	var reach := 102.0 if role == "rusher" or (role == "boss" and attack_count % 2 == 0) else 43.0
	if absf(offset.y) > 9 or absf(offset.x) > reach:
		return Vector2(offset.x if absf(offset.x) > reach - 5 else 0.0, offset.y * 2).normalized()
	if brain_timer > 0:
		return Vector2.ZERO
	committed_facing = 1 if offset.x >= 0 else -1
	state_machine.facing = committed_facing
	pending_move = "jab" if role in ["brawler", "rusher"] else "high_kick"
	if role == "boss":
		pending_move = "jab" if attack_count % 2 == 0 else "roundhouse_kick"
	var rush := role == "rusher" or (role == "boss" and pending_move == "jab")
	# Per-instance dictionary: authored velocity is world-space, fixed at commitment.
	var move: Dictionary = move_executor.move_templates[_resolve_move_id(pending_move)]
	move.events = []
	if rush:
		move.events = [{"frame": 0, "event_type": "set_velocity", "payload": {"x": committed_facing * 160.0, "y": 0}}, {"frame": 3, "event_type": "set_velocity", "payload": {"x": 0, "y": 0}}]
	move_executor.configure(move_executor.move_templates)
	brain_phase = "telegraph"
	brain_timer = 0.7 if role in ["mini", "boss"] else (0.45 if rush else 0.3)
	attack_count += 1
	return Vector2.ZERO

func _draw() -> void:
	super._draw()
	var color: Color = COLORS[role]
	draw_rect(Rect2(-21, -79, 42, 3), Color("302d43"))
	draw_rect(Rect2(-21, -79, 42.0 * current_hp / max_hp, 3), color)
	if stage_font != null:
		draw_string(stage_font, Vector2(-24, -84), LABELS[role], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	if brain_phase == "telegraph" and current_hp > 0:
		draw_line(Vector2(0, -4), Vector2(committed_facing * 82, -4), Color("ff665e"), 3)
		draw_string(stage_font, Vector2(-4, -101), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffe39a"))
	if super_flash > 0:
		draw_arc(Vector2(0, -29), 68, -PI * 0.9, PI * 0.9, 20, Color(0.5, 1, 0.84, super_flash / 0.55), 7)
		draw_arc(Vector2(0, -29), 76, PI * 0.15, PI * 1.3, 14, Color(1, 0.9, 0.5, super_flash / 0.55), 3)
