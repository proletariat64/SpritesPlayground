extends Control
class_name CreatorLabActionPreview

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

var row: Dictionary = {}
var template: Dictionary = {}
var sprite_set: Dictionary = {}
var moves: Dictionary = {}
var frame_index: int = 0
var show_hurtboxes: bool = true
var show_hitboxes: bool = true
var show_foot: bool = true


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(204, 132)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_preview_data(next_row: Dictionary, next_template: Dictionary, next_sprite_set: Dictionary, next_moves: Dictionary) -> void:
	row = next_row.duplicate(true)
	template = next_template.duplicate(true)
	sprite_set = next_sprite_set.duplicate(true)
	moves = next_moves.duplicate(true)
	set_frame(frame_index)


func set_frame(next_frame_index: int) -> void:
	frame_index = clampi(next_frame_index, 0, maxi(0, frame_count() - 1))
	queue_redraw()


func set_overlay_visibility(next_show_hurtboxes: bool, next_show_hitboxes: bool, next_show_foot: bool) -> void:
	show_hurtboxes = next_show_hurtboxes
	show_hitboxes = next_show_hitboxes
	show_foot = next_show_foot
	queue_redraw()


func frame_count() -> int:
	var sequence := _resolved_sequence()
	if not sequence.is_empty():
		return sequence.size()
	var move := _resolved_move()
	if not move.is_empty():
		return int(move.get("frame_count", 1))
	return 1


func current_status() -> String:
	var warnings: Array = row.get("warnings", [])
	if warnings.has("INVALID_SPRITE_MAPPING"):
		return "INVALID"
	if warnings.has("MISSING_ANIMATION") or warnings.has("MISSING_FRAME_SEQUENCE"):
		return "MISSING"
	if warnings.has("PLACEHOLDER_ANIMATION"):
		return "PLACEHOLDER"
	return str(row.get("status", "OK"))


func current_frame_path() -> String:
	var sequence := _resolved_sequence()
	if frame_index >= 0 and frame_index < sequence.size():
		return str(sequence[frame_index])
	return ""


func current_render_state() -> String:
	var path := current_frame_path()
	if path.is_empty():
		if row.get("warnings", []).has("INVALID_SPRITE_MAPPING"):
			return "INVALID"
		return "MISSING"
	if path.begins_with("placeholder://"):
		return "PLACEHOLDER"
	if _texture_for_path(path) != null:
		return "TEXTURE"
	if path.begins_with("res://") or path.begins_with("user://"):
		return "MISSING"
	return "INVALID"


func current_frame_active() -> bool:
	var move := _resolved_move()
	if move.is_empty():
		return false
	var window: Dictionary = move.get("active_window", {})
	return frame_index >= int(window.get("start_frame", 0)) and frame_index <= int(window.get("end_frame", maxi(0, frame_count() - 1)))


func frame_strip_segment_count() -> int:
	return frame_count()


func frame_strip_active_index() -> int:
	return frame_index


func frame_has_active_hitbox(target_frame: int) -> bool:
	return _frame_has_active_hitbox(target_frame)


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
	var status := current_render_state()
	var body_rect := _sprite_body_rect(origin)
	if status == "TEXTURE":
		var texture := _texture_for_path(current_frame_path())
		if texture != null:
			var texture_rect := _texture_rect(texture, origin)
			draw_texture_rect(texture, texture_rect, false)
			draw_rect(texture_rect, Color(0.86, 0.9, 0.94), false, 1.0)
			return
	if status == "MISSING" or status == "INVALID":
		draw_rect(body_rect, COLOR_MISSING, true)
		draw_rect(body_rect, Color(1.0, 0.25, 0.18), false, 1.0)
		draw_string(font, body_rect.position + Vector2(2, -5), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.68, 0.62))
		return
	if status == "PLACEHOLDER":
		draw_rect(body_rect, COLOR_PLACEHOLDER, true)
		draw_rect(body_rect, Color(1.0, 0.74, 0.22), false, 1.0)
		draw_string(font, body_rect.position + Vector2(2, -5), "placeholder", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.8, 0.35))
		return
	draw_rect(body_rect, Color(0.62, 0.66, 0.7, 0.72), true)
	draw_rect(body_rect, Color(0.86, 0.9, 0.94), false, 1.0)


func _sprite_body_rect(origin: Vector2) -> Rect2:
	var body_height := clampf(size.y * 0.54, 64.0, 128.0)
	var body_width := clampf(body_height * 0.46, 32.0, 62.0)
	return Rect2(origin + Vector2(-body_width * 0.5, -body_height), Vector2(body_width, body_height))


func _draw_hurtboxes(origin: Vector2) -> void:
	for hurtbox_id in template.get("hurtboxes", {}).keys():
		var rect := _rect_from_dict(template["hurtboxes"][hurtbox_id])
		rect.position += origin
		draw_rect(rect, COLOR_HURT, true)
		draw_rect(rect, Color(0.2, 0.66, 1.0), false, 1.0)


func _draw_hitboxes(origin: Vector2) -> void:
	var move := _resolved_move()
	if move.is_empty():
		return
	var move_window: Dictionary = move.get("active_window", {"start_frame": 0, "end_frame": frame_count() - 1})
	if frame_index < int(move_window.get("start_frame", 0)) or frame_index > int(move_window.get("end_frame", 0)):
		return
	for hitbox in move.get("hitboxes", []):
		var window: Dictionary = hitbox.get("active_window", {})
		if frame_index < int(window.get("start_frame", 0)) or frame_index > int(window.get("end_frame", 0)):
			continue
		var rect := _rect_from_dict(hitbox.get("rect", {}))
		rect.position += origin
		draw_rect(rect, COLOR_HIT, true)
		draw_rect(rect, Color(1.0, 0.28, 0.12), false, 1.0)


func _draw_foot(origin: Vector2) -> void:
	var foot: Dictionary = template.get("foot_collision", {})
	if foot.is_empty():
		return
	var center := _vector_from_dict(foot.get("center", {}))
	var radius := _vector_from_dict(foot.get("radius", {}))
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
	for i in count:
		var x0 := strip.position.x + strip.size.x * float(i) / float(count)
		var x1 := strip.position.x + strip.size.x * float(i + 1) / float(count)
		var segment := Rect2(Vector2(x0, strip.position.y), Vector2(maxf(1.0, x1 - x0 - 1.0), strip.size.y))
		var color := COLOR_STRIP_INACTIVE
		if _frame_has_active_hitbox(i):
			color = COLOR_STRIP_HIT
		if i == frame_index:
			color = COLOR_STRIP_CURRENT
		draw_rect(segment, color, true)
		if i == frame_index:
			draw_rect(segment.grow(1.0), Color(1.0, 0.96, 0.72, 1.0), false, 1.0)


func _frame_has_active_hitbox(target_frame: int) -> bool:
	var move := _resolved_move()
	if move.is_empty():
		return false
	for hitbox in move.get("hitboxes", []):
		var window: Dictionary = hitbox.get("active_window", {})
		if target_frame >= int(window.get("start_frame", 0)) and target_frame <= int(window.get("end_frame", 0)):
			return true
	var move_window: Dictionary = move.get("active_window", {})
	return target_frame >= int(move_window.get("start_frame", 0)) and target_frame <= int(move_window.get("end_frame", -1))


func _resolved_sequence() -> Array:
	var sequences: Dictionary = sprite_set.get("frame_sequences", {})
	var sequence_ref := str(row.get("frame_sequence_ref", ""))
	if sequences.has(sequence_ref):
		return sequences[sequence_ref]
	return []


func _resolved_move() -> Dictionary:
	var move_id := str(row.get("backing_move_id", ""))
	return moves.get(move_id, {})


func _rect_from_dict(data: Dictionary) -> Rect2:
	return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("w", 1.0)), float(data.get("h", 1.0)))


func _vector_from_dict(data: Dictionary) -> Vector2:
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))


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


func _texture_rect(texture: Texture2D, origin: Vector2) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return _sprite_body_rect(origin)
	var max_size := Vector2(maxf(82.0, size.x * 0.42), maxf(96.0, size.y * 0.66))
	var scale := minf(max_size.x / texture_size.x, max_size.y / texture_size.y)
	var draw_size := texture_size * scale
	return Rect2(origin + Vector2(-draw_size.x * 0.5, -draw_size.y), draw_size)
