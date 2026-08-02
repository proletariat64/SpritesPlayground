extends Control
class_name CreatorLabActionPreview

const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")
const SpriteFramesGeneratorScript := preload("res://godot/scripts/spriteframes_generator.gd")
const LIVE_FRAME_SECONDS := 1.0 / 60.0
const MAX_REPLAY_TICKS := 4096
const PREVIEW_ARENA_RADIUS := Vector2(100000.0, 100000.0)

const COLOR_BG := Color(0.035, 0.04, 0.048, 1.0)
const COLOR_GRID := Color(0.2, 0.24, 0.28, 1.0)
const COLOR_TEXT := Color(0.82, 0.88, 0.95, 1.0)
const COLOR_PLACEHOLDER := Color(0.9, 0.68, 0.22, 0.82)
const COLOR_MISSING := Color(1.0, 0.24, 0.18, 0.74)
const COLOR_HURT := Color(0.16, 0.58, 1.0, 0.28)
const COLOR_HIT := Color(1.0, 0.26, 0.10, 0.32)
const COLOR_FOOT := Color(0.2, 1.0, 0.46, 1.0)
const COLOR_ORIGIN := Color(0.95, 0.96, 0.98, 1.0)
const COLOR_ACTIVE := Color(1.0, 0.66, 0.16, 1.0)
const COLOR_INACTIVE := Color(0.34, 0.42, 0.5, 1.0)
const COLOR_STRIP_BG := Color(0.08, 0.1, 0.12, 1.0)
const COLOR_STRIP_INACTIVE := Color(0.22, 0.28, 0.34, 1.0)
const COLOR_STRIP_HIT := Color(1.0, 0.36, 0.14, 0.9)
const COLOR_STRIP_CURRENT := Color(1.0, 0.84, 0.22, 1.0)
const FRAME_STRIP_DETAILED_LIMIT := 24

var row: Dictionary = {}
var template: Dictionary = {}
var sprite_set: Dictionary = {}
var moves: Dictionary = {}
var frame_index: int = 0
var show_hurtboxes: bool = true
var show_hitboxes: bool = true
var show_foot: bool = true
var _real_sprite: Node
var _shared_source: Control
var _advance_accumulator: float = 0.0
var _active_frame_observations: Array[bool] = []


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(204, 132)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_real_sprite()


func set_preview_data(next_row: Dictionary, next_template: Dictionary, next_sprite_set: Dictionary, next_moves: Dictionary) -> void:
	if _shared_source != null:
		row = next_row.duplicate(true)
		template = next_template.duplicate(true)
		sprite_set = next_sprite_set.duplicate(true)
		moves = next_moves.duplicate(true)
		_sync_from_source()
		queue_redraw()
		return
	var previous_move_id := str(row.get("backing_move_id", ""))
	var requested_frame := frame_index
	var runtime_changed := not _runtime_data_equals(next_template, next_sprite_set, next_moves)
	row = next_row.duplicate(true)
	if runtime_changed:
		template = next_template.duplicate(true)
		sprite_set = next_sprite_set.duplicate(true)
		moves = next_moves.duplicate(true)
	_ensure_real_sprite()
	if _real_sprite == null:
		queue_redraw()
		return
	if runtime_changed:
		_real_sprite.apply_v0_3_runtime_bundle(template, sprite_set, moves)
		var built := SpriteFramesGeneratorScript.build_in_memory(sprite_set, {"moves": moves})
		_real_sprite.apply_runtime_sprite_frames(built.get("sprite_frames", null))
	if runtime_changed or previous_move_id != str(row.get("backing_move_id", "")):
		_rebuild_active_frame_observations(requested_frame)
	else:
		_sync_from_source()
	queue_redraw()


func real_sprite() -> Node:
	_ensure_real_sprite()
	return _real_sprite


func bind_preview_source(source: Control) -> void:
	if source == null or source == self:
		return
	_shared_source = source
	if _real_sprite != null and is_instance_valid(_real_sprite) and _real_sprite.get_parent() == self:
		remove_child(_real_sprite)
		_real_sprite.free()
	_real_sprite = null
	_active_frame_observations.clear()
	_sync_from_source()
	queue_redraw()


func step_forward() -> void:
	if _shared_source != null:
		if is_instance_valid(_shared_source):
			_shared_source.step_forward()
		_sync_from_source()
		queue_redraw()
		return
	_ensure_real_sprite()
	if _real_sprite == null or not _real_sprite.move_executor.is_executing():
		return
	_advance_accumulator = 0.0
	_tick_real_sprite(LIVE_FRAME_SECONDS)
	_sync_from_source()
	queue_redraw()


func seek_frame(target_frame: int) -> void:
	if _shared_source != null:
		if is_instance_valid(_shared_source):
			_shared_source.seek_frame(target_frame)
		_sync_from_source()
		queue_redraw()
		return
	_ensure_real_sprite()
	if _real_sprite == null:
		return
	var clamped_target := clampi(target_frame, 0, maxi(0, frame_count() - 1))
	_replay_real_move_to_frame(clamped_target)
	queue_redraw()


func _replay_real_move_to_frame(target_frame: int) -> void:
	_restart_real_move()
	var guard := 0
	while (
		_real_sprite.move_executor.is_executing()
		and int(observation().get("frame", 0)) < target_frame
		and guard < MAX_REPLAY_TICKS
	):
		_tick_real_sprite(LIVE_FRAME_SECONDS)
		guard += 1
	_sync_from_source()


func _rebuild_active_frame_observations(restore_frame: int) -> void:
	var count := frame_count()
	_active_frame_observations.resize(count)
	_active_frame_observations.fill(false)
	if _real_sprite == null or count <= 0:
		return
	_restart_real_move()
	var last_observed_frame := -1
	var guard := 0
	while guard < MAX_REPLAY_TICKS:
		var observed := observation()
		var observed_frame := int(observed.get("frame", -1))
		if observed_frame >= 0 and observed_frame < count and observed_frame != last_observed_frame:
			_active_frame_observations[observed_frame] = not observed.get("hitboxes", []).is_empty()
			last_observed_frame = observed_frame
		if not _real_sprite.move_executor.is_executing():
			break
		_tick_real_sprite(LIVE_FRAME_SECONDS)
		guard += 1
		if not _real_sprite.move_executor.is_executing():
			break
	_replay_real_move_to_frame(clampi(restore_frame, 0, maxi(0, count - 1)))


func advance_time(delta: float) -> void:
	if _shared_source != null:
		if is_instance_valid(_shared_source):
			_shared_source.advance_time(delta)
		_sync_from_source()
		queue_redraw()
		return
	_ensure_real_sprite()
	if _real_sprite == null or delta <= 0.0 or is_completed():
		return
	_advance_accumulator += delta
	var guard := 0
	while _advance_accumulator + 0.000001 >= LIVE_FRAME_SECONDS and guard < MAX_REPLAY_TICKS:
		_advance_accumulator -= LIVE_FRAME_SECONDS
		_tick_real_sprite(LIVE_FRAME_SECONDS)
		guard += 1
		if is_completed():
			_advance_accumulator = 0.0
			break
	_sync_from_source()
	queue_redraw()


func is_completed() -> bool:
	if _shared_source != null:
		return not is_instance_valid(_shared_source) or bool(_shared_source.is_completed())
	_ensure_real_sprite()
	return _real_sprite == null or not _real_sprite.move_executor.is_executing()


func observation() -> Dictionary:
	if _shared_source != null:
		return _shared_source.observation() if is_instance_valid(_shared_source) else {}
	_ensure_real_sprite()
	if _real_sprite == null:
		return {}
	var summary: Dictionary = _real_sprite.debug_summary()
	var animation := ""
	var animation_frame := 0
	if _real_sprite.animated_sprite != null:
		animation = str(_real_sprite.animated_sprite.animation)
		animation_frame = int(_real_sprite.animated_sprite.frame)
	return {
		"state": str(summary.get("state", "")),
		"move": str(summary.get("move", "")),
		"frame": int(summary.get("frame", 0)),
		"animation": animation,
		"animation_frame": animation_frame,
		"hitboxes": _boxes_relative_to_sprite(_real_sprite.active_hitboxes_world()),
		"hurtboxes": _boxes_relative_to_sprite(_real_sprite.hurtboxes_world()),
		"combat_facing": int(_real_sprite.state_machine.facing),
		"completed": is_completed(),
	}


func _boxes_relative_to_sprite(boxes: Array) -> Array:
	var result: Array = []
	for entry in boxes:
		var rect: Rect2 = entry.get("rect", Rect2())
		var normalized: Dictionary = entry.duplicate(true)
		normalized["rect"] = Rect2(rect.position - _real_sprite.global_position, rect.size)
		result.append(normalized)
	return result


func _ensure_real_sprite() -> void:
	if _shared_source != null:
		if is_instance_valid(_shared_source):
			_real_sprite = _shared_source.real_sprite()
		else:
			_real_sprite = null
		return
	if _real_sprite != null and is_instance_valid(_real_sprite):
		return
	_real_sprite = CombatCharacterScript.new()
	_real_sprite.name = "isolated_preview_sprite"
	_real_sprite.instance_id = "creator_lab_preview"
	_real_sprite.is_test_dummy = true
	_real_sprite.visible = false
	add_child(_real_sprite)
	_real_sprite.set_combat_target(null)


func _restart_real_move() -> void:
	if _shared_source != null:
		if is_instance_valid(_shared_source):
			_shared_source.seek_frame(0)
		_sync_from_source()
		return
	if _real_sprite == null:
		return
	_advance_accumulator = 0.0
	var anchor := _preview_anchor()
	_real_sprite.reset_runtime(anchor)
	_real_sprite.set_combat_target(null)
	_real_sprite.state_machine.facing = 1
	_real_sprite.request_attack(str(row.get("backing_move_id", "")))
	_tick_real_sprite(0.0)
	_sync_from_source()


func _preview_anchor() -> Vector2:
	return Vector2(size.x * 0.5, size.y - 32.0)


func _preview_arena_center() -> Vector2:
	return get_global_transform() * _preview_anchor()


func _tick_real_sprite(delta: float) -> void:
	_real_sprite.tick_character(delta, _preview_arena_center(), PREVIEW_ARENA_RADIUS)


func _sync_from_source() -> void:
	var observed := observation()
	if not observed.is_empty():
		frame_index = int(observed.get("frame", frame_index))


func _runtime_data_equals(next_template: Dictionary, next_sprite_set: Dictionary, next_moves: Dictionary) -> bool:
	return template == next_template and sprite_set == next_sprite_set and moves == next_moves


func set_frame(next_frame_index: int) -> void:
	var target := clampi(next_frame_index, 0, maxi(0, frame_count() - 1))
	if _shared_source != null:
		_sync_from_source()
		queue_redraw()
		return
	if target != frame_index:
		seek_frame(target)
	else:
		_sync_from_source()
		queue_redraw()


func set_overlay_visibility(next_show_hurtboxes: bool, next_show_hitboxes: bool, next_show_foot: bool) -> void:
	show_hurtboxes = next_show_hurtboxes
	show_hitboxes = next_show_hitboxes
	show_foot = next_show_foot
	queue_redraw()


func frame_count() -> int:
	if _shared_source != null:
		return int(_shared_source.frame_count()) if is_instance_valid(_shared_source) else 1
	_ensure_real_sprite()
	if _real_sprite == null or _real_sprite.move_executor == null:
		return 1
	var move_id := str(row.get("backing_move_id", ""))
	var runtime_move: Dictionary = _real_sprite.move_executor.move_templates.get(move_id, {})
	return maxi(1, int(runtime_move.get("total_frames", 1)))


func current_status() -> String:
	if _shared_source != null and is_instance_valid(_shared_source) and row.is_empty():
		return str(_shared_source.current_status())
	var warnings: Array = row.get("warnings", [])
	if warnings.has("INVALID_SPRITE_MAPPING"):
		return "INVALID"
	if warnings.has("MISSING_ANIMATION") or warnings.has("MISSING_FRAME_SEQUENCE"):
		return "MISSING"
	if warnings.has("PLACEHOLDER_ANIMATION"):
		return "PLACEHOLDER"
	return str(row.get("status", "OK"))


func current_frame_path() -> String:
	if _shared_source != null and is_instance_valid(_shared_source) and (row.is_empty() or sprite_set.is_empty()):
		return str(_shared_source.current_frame_path())
	var sequence := _resolved_sequence()
	if frame_index >= 0 and frame_index < sequence.size():
		return str(sequence[frame_index])
	return ""


func current_render_state() -> String:
	if _shared_source != null and is_instance_valid(_shared_source) and (row.is_empty() or sprite_set.is_empty()):
		return str(_shared_source.current_render_state())
	var path := current_frame_path()
	if path.is_empty():
		if row.get("warnings", []).has("INVALID_SPRITE_MAPPING"):
			return "INVALID"
		return "MISSING"
	if path.begins_with("empty://"):
		return "EMPTY"
	if path.begins_with("missing://"):
		return "MISSING"
	if path.begins_with("placeholder://"):
		return "PLACEHOLDER"
	if _texture_for_path(path) != null:
		return "TEXTURE"
	if path.begins_with("res://") or path.begins_with("user://"):
		return "MISSING"
	return "INVALID"


func current_frame_active() -> bool:
	return not observation().get("hitboxes", []).is_empty()


func frame_strip_segment_count() -> int:
	return frame_count()


func frame_strip_active_index() -> int:
	return int(observation().get("frame", frame_index))


func frame_has_active_hitbox(target_frame: int) -> bool:
	if _shared_source != null:
		return (
			is_instance_valid(_shared_source)
			and bool(_shared_source.frame_has_active_hitbox(target_frame))
		)
	return (
		target_frame >= 0
		and target_frame < _active_frame_observations.size()
		and _active_frame_observations[target_frame]
	)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, COLOR_BG, true)
	draw_rect(rect, COLOR_ACTIVE if current_frame_active() else COLOR_INACTIVE, false, 2.0 if current_frame_active() else 1.0)
	var origin := Vector2(size.x * 0.5, size.y - 32.0)
	draw_line(Vector2(8, origin.y), Vector2(size.x - 8, origin.y), COLOR_GRID, 1.0)
	_draw_sprite_state(origin)
	_draw_origin_marker(origin)
	if show_hurtboxes:
		_draw_hurtboxes(origin)
	if show_hitboxes:
		_draw_hitboxes(origin)
	if show_foot:
		_draw_foot(origin)
	_draw_frame_strip()
	_draw_header()


func _draw_header() -> void:
	var font := get_theme_default_font()
	var action_id := str(row.get("action_id", "none"))
	var status := "%s/%s" % [current_render_state(), current_status()]
	draw_string(font, Vector2(7, 13), "%s  %s" % [action_id, status], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_TEXT)
	draw_string(font, Vector2(7, size.y - 8), "Frame %d / %d" % [frame_index + 1, frame_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_TEXT)


func _draw_sprite_state(origin: Vector2) -> void:
	var font := get_theme_default_font()
	var texture := _runtime_frame_texture()
	if texture != null:
		var texture_rect := _runtime_texture_rect(texture, origin)
		_draw_runtime_texture(texture, texture_rect)
		return
	var status := current_render_state()
	var diagnostic_rect := Rect2(origin + Vector2(-54.0, -48.0), Vector2(108.0, 24.0))
	var diagnostic_color := COLOR_PLACEHOLDER if status in ["PLACEHOLDER", "EMPTY"] else COLOR_MISSING
	draw_rect(diagnostic_rect, Color(diagnostic_color, 0.18), true)
	draw_rect(diagnostic_rect, diagnostic_color, false, 1.0)
	draw_string(
		font,
		diagnostic_rect.position + Vector2(4.0, 15.0),
		"runtime %s" % status.to_lower(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8,
		diagnostic_color
	)


func _sprite_body_rect(origin: Vector2) -> Rect2:
	var body_height := clampf(size.y * 0.54, 64.0, 128.0)
	var body_width := clampf(body_height * 0.46, 32.0, 62.0)
	return Rect2(origin + Vector2(-body_width * 0.5, -body_height), Vector2(body_width, body_height))


func _draw_hurtboxes(origin: Vector2) -> void:
	for hurtbox in observation().get("hurtboxes", []):
		var rect: Rect2 = hurtbox.get("rect", Rect2())
		rect.position += origin
		draw_rect(rect, COLOR_HURT, true)
		draw_rect(rect, Color(0.2, 0.66, 1.0), false, 1.0)


func _draw_hitboxes(origin: Vector2) -> void:
	for hitbox in observation().get("hitboxes", []):
		var rect: Rect2 = hitbox.get("rect", Rect2())
		rect.position += origin
		draw_rect(rect, COLOR_HIT, true)
		draw_rect(rect, Color(1.0, 0.28, 0.12), false, 1.0)


func _draw_foot(origin: Vector2) -> void:
	var sprite := real_sprite()
	if sprite == null:
		return
	var foot: Dictionary = sprite.foot_contact_ellipse()
	var center: Vector2 = foot.get("center", sprite.global_position) - sprite.global_position
	var radius: Vector2 = foot.get("radius", Vector2.ZERO)
	var foot_center := origin + center
	var points := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		points.append(foot_center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, COLOR_FOOT, 1.4)
	draw_circle(foot_center, 2.4, COLOR_FOOT)
	draw_line(foot_center + Vector2(-5, 0), foot_center + Vector2(5, 0), COLOR_FOOT, 1.0)
	draw_line(foot_center + Vector2(0, -5), foot_center + Vector2(0, 5), COLOR_FOOT, 1.0)


func _draw_origin_marker(origin: Vector2) -> void:
	draw_circle(origin, 2.2, COLOR_ORIGIN)
	draw_line(origin + Vector2(-6, 0), origin + Vector2(6, 0), COLOR_ORIGIN, 1.0)
	draw_line(origin + Vector2(0, -6), origin + Vector2(0, 6), COLOR_ORIGIN, 1.0)


func _draw_frame_strip() -> void:
	var count := frame_count()
	var strip := Rect2(Vector2(7, size.y - 24.0), Vector2(maxf(12.0, size.x - 14.0), 8.0))
	draw_rect(strip, COLOR_STRIP_BG, true)
	if count <= 0:
		return
	if count > FRAME_STRIP_DETAILED_LIMIT:
		_draw_compressed_frame_strip(strip, count)
		return
	for i in count:
		var x0 := strip.position.x + strip.size.x * float(i) / float(count)
		var x1 := strip.position.x + strip.size.x * float(i + 1) / float(count)
		var segment := Rect2(Vector2(x0, strip.position.y), Vector2(maxf(1.0, x1 - x0 - 1.0), strip.size.y))
		var color := COLOR_STRIP_INACTIVE
		if frame_has_active_hitbox(i):
			color = COLOR_STRIP_HIT
		draw_rect(segment, color, true)
		if i == frame_strip_active_index():
			draw_rect(segment.grow(1.0), COLOR_STRIP_CURRENT, false, 1.0)


func _draw_compressed_frame_strip(strip: Rect2, count: int) -> void:
	_draw_active_frame_runs(strip, count)
	var tick_count := mini(FRAME_STRIP_DETAILED_LIMIT, count)
	for tick in range(tick_count + 1):
		var frame := int(round(float(tick) * float(count - 1) / float(tick_count)))
		var x := _frame_center_x(strip, count, frame)
		draw_line(Vector2(x, strip.position.y), Vector2(x, strip.position.y + strip.size.y), COLOR_STRIP_INACTIVE, 1.0)
	var current_x := _frame_center_x(strip, count, frame_strip_active_index())
	draw_line(Vector2(current_x, strip.position.y - 3.0), Vector2(current_x, strip.position.y - 1.0), COLOR_STRIP_CURRENT, 2.0)
	draw_line(
		Vector2(current_x, strip.position.y + strip.size.y + 1.0),
		Vector2(current_x, strip.position.y + strip.size.y + 3.0),
		COLOR_STRIP_CURRENT,
		2.0
	)


func _draw_active_frame_runs(strip: Rect2, count: int) -> void:
	var run_start := -1
	for frame in range(count + 1):
		var active := frame < count and frame_has_active_hitbox(frame)
		if active and run_start < 0:
			run_start = frame
		elif not active and run_start >= 0:
			var x0 := strip.position.x + strip.size.x * float(run_start) / float(count)
			var x1 := strip.position.x + strip.size.x * float(frame) / float(count)
			draw_rect(
				Rect2(
					Vector2(x0, strip.position.y),
					Vector2(maxf(1.0, x1 - x0), strip.size.y)
				),
				COLOR_STRIP_HIT,
				true
			)
			run_start = -1


func _frame_center_x(strip: Rect2, count: int, target_frame: int) -> float:
	var frame := clampi(target_frame, 0, count - 1)
	return strip.position.x + strip.size.x * (float(frame) + 0.5) / float(count)


func _resolved_sequence() -> Array:
	var sequences: Dictionary = sprite_set.get("frame_sequences", {})
	var sequence_ref := str(row.get("frame_sequence_ref", ""))
	if sequences.has(sequence_ref):
		return sequences[sequence_ref]
	return []


func _texture_for_path(path: String) -> Texture2D:
	if path.is_empty() or not (path.begins_with("res://") or path.begins_with("user://")):
		return null
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path)
		if resource is Texture2D:
			return resource
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return null


func _runtime_frame_texture() -> Texture2D:
	var sprite := real_sprite()
	if sprite == null or sprite.animated_sprite == null or not sprite.animated_sprite.visible:
		return null
	var frames: SpriteFrames = sprite.animated_sprite.sprite_frames
	var animation: StringName = sprite.animated_sprite.animation
	if frames == null or not frames.has_animation(animation):
		return null
	var count := frames.get_frame_count(animation)
	if count <= 0:
		return null
	var runtime_frame := clampi(int(sprite.animated_sprite.frame), 0, count - 1)
	return frames.get_frame_texture(animation, runtime_frame)


func _runtime_texture_rect(texture: Texture2D, origin: Vector2) -> Rect2:
	var sprite := real_sprite()
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return _sprite_body_rect(origin)
	var sprite_offset := Vector2(0.0, -texture_size.y * 0.5)
	if sprite != null and sprite.animated_sprite != null:
		sprite_offset = sprite.animated_sprite.position
	var center := origin + sprite_offset
	return Rect2(center - texture_size * 0.5, texture_size)


func _draw_runtime_texture(texture: Texture2D, texture_rect: Rect2) -> void:
	var sprite := real_sprite()
	var flip_h: bool = sprite != null and sprite.animated_sprite != null and bool(sprite.animated_sprite.flip_h)
	if flip_h:
		draw_set_transform(Vector2(texture_rect.end.x, texture_rect.position.y), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(texture, Rect2(Vector2.ZERO, texture_rect.size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(texture, texture_rect, false)
	draw_rect(texture_rect, Color(0.86, 0.9, 0.94), false, 1.0)
