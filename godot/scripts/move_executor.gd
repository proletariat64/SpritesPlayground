extends Node
class_name MoveExecutor

signal move_finished(move_id: String)
signal move_started(move_id: String)

var move_templates: Dictionary = {}
var active_move_id: String = ""
var active_move: Dictionary = {}
var frame_index: int = 0

var _hit_marks: Dictionary = {}


func configure(templates: Dictionary) -> void:
	move_templates = templates.duplicate(true)
	cancel()


func start_attack_intent(move_id: String) -> bool:
	if not move_templates.has(move_id):
		return false
	active_move_id = move_id
	active_move = move_templates[move_id]
	frame_index = 0
	_hit_marks.clear()
	move_started.emit(active_move_id)
	return true


func cancel() -> void:
	active_move_id = ""
	active_move = {}
	frame_index = 0
	_hit_marks.clear()


func tick() -> void:
	if not is_executing():
		return

	frame_index += 1
	if frame_index >= int(active_move.get("total_frames", 1)):
		var finished_id := active_move_id
		cancel()
		move_finished.emit(finished_id)


func is_executing() -> bool:
	return not active_move_id.is_empty()


func current_frame() -> int:
	return frame_index


func active_hitboxes_local() -> Array:
	var entries: Array = []
	if not is_executing():
		return entries

	var windows: Array = active_move.get("hitbox_windows", [])
	for i in windows.size():
		var window: Dictionary = windows[i]
		var first_frame := int(window.get("from_frame", 0))
		var last_frame := int(window.get("to_frame", first_frame))
		if frame_index < first_frame or frame_index > last_frame:
			continue
		entries.append({
			"window_index": i,
			"hitbox_id": str(window.get("hitbox_id", "")),
			"damage": int(window.get("damage", 0)),
			"rect": window.get("rect", Rect2()),
		})
	return entries


func active_hitboxes_world(owner_position: Vector2, facing: int, visual_jump_offset: float) -> Array:
	var entries: Array = []
	for local_entry in active_hitboxes_local():
		var local_rect: Rect2 = local_entry["rect"]
		if facing < 0:
			local_rect.position.x = -local_rect.position.x - local_rect.size.x
		local_rect.position.y += visual_jump_offset
		entries.append({
			"window_index": int(local_entry["window_index"]),
			"hitbox_id": str(local_entry["hitbox_id"]),
			"damage": int(local_entry["damage"]),
			"rect": Rect2(owner_position + local_rect.position, local_rect.size),
		})
	return entries


func can_hit_target(target_instance_id: String, window_index: int) -> bool:
	var key := "%s:%d:%s" % [active_move_id, window_index, target_instance_id]
	return not _hit_marks.has(key)


func mark_target_hit(target_instance_id: String, window_index: int) -> void:
	var key := "%s:%d:%s" % [active_move_id, window_index, target_instance_id]
	_hit_marks[key] = true
