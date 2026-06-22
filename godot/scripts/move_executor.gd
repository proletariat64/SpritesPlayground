extends Node
class_name MoveExecutor

signal move_finished(move_id: String)

var move_templates: Dictionary = {}
var active_move_id: String = ""
var active_move: Dictionary = {}
var elapsed: float = 0.0
var frame_index: int = 0

var _hit_marks: Dictionary = {}


func configure(templates: Dictionary) -> void:
	move_templates = templates.duplicate(true)
	cancel()


func start_move(move_id: String) -> bool:
	if not move_templates.has(move_id):
		return false
	active_move_id = move_id
	active_move = move_templates[move_id]
	elapsed = 0.0
	frame_index = 0
	_hit_marks.clear()
	return true


func cancel() -> void:
	active_move_id = ""
	active_move = {}
	elapsed = 0.0
	frame_index = 0
	_hit_marks.clear()


func tick(delta: float) -> void:
	if not is_executing():
		return

	elapsed += delta
	var fps := float(active_move.get("fps", 12.0))
	frame_index = int(floor(elapsed * fps))

	if elapsed >= float(active_move.get("duration", 0.0)):
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
		var starts_at := float(window.get("from", 0.0))
		var ends_at := float(window.get("to", 0.0))
		if elapsed < starts_at or elapsed > ends_at:
			continue
		entries.append({
			"window_index": i,
			"hitbox_id": str(window.get("hitbox_id", "")),
			"damage": int(window.get("damage", 0)),
			"rect": window.get("rect", Rect2()),
		})
	return entries


func can_hit_target(target_instance_id: String, window_index: int) -> bool:
	var key := "%s:%d:%s" % [active_move_id, window_index, target_instance_id]
	return not _hit_marks.has(key)


func mark_target_hit(target_instance_id: String, window_index: int) -> void:
	var key := "%s:%d:%s" % [active_move_id, window_index, target_instance_id]
	_hit_marks[key] = true
