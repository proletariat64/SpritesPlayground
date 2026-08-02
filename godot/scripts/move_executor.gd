extends Node
class_name MoveExecutor

signal move_finished(move_id: String)
signal move_started(move_id: String)
signal state_context_requested(state_context: String)

var move_templates: Dictionary = {}
var active_move_id: String = ""
var active_move: Dictionary = {}
var frame_index: int = 0
var animation_player: AnimationPlayer

var _hit_marks: Dictionary = {}
var _enabled_hitbox_windows: Dictionary = {}
var _authored_velocity: Vector2 = Vector2.ZERO
var _hitstop_frames_remaining: int = 0


func configure(templates: Dictionary) -> void:
	move_templates = templates.duplicate(true)
	cancel()
	_rebuild_timing_animations()


func start_attack_intent(move_id: String) -> bool:
	if not move_templates.has(move_id):
		return false
	_ensure_animation_player()
	active_move_id = move_id
	active_move = move_templates[move_id]
	frame_index = 0
	_hit_marks.clear()
	_enabled_hitbox_windows.clear()
	_authored_velocity = Vector2.ZERO
	_hitstop_frames_remaining = 0
	animation_player.play(StringName(active_move_id))
	move_started.emit(active_move_id)
	animation_player.advance(0.0)
	return true


func cancel() -> void:
	if animation_player != null and animation_player.is_playing():
		animation_player.stop()
	active_move_id = ""
	active_move = {}
	frame_index = 0
	_hit_marks.clear()
	_enabled_hitbox_windows.clear()
	_authored_velocity = Vector2.ZERO
	_hitstop_frames_remaining = 0


func tick(delta: float = -1.0) -> void:
	if not is_executing():
		return
	if _hitstop_frames_remaining > 0:
		_hitstop_frames_remaining -= 1
		return
	var fps := maxf(1.0, float(active_move.get("fps", 60.0)))
	var advance_delta := 1.0 / fps if delta < 0.0 else maxf(0.0, delta)
	animation_player.advance(advance_delta)


func is_executing() -> bool:
	return not active_move_id.is_empty()


func current_frame() -> int:
	return frame_index


func authored_velocity() -> Vector2:
	return _authored_velocity


func is_hitstopped() -> bool:
	return _hitstop_frames_remaining > 0


func hitstop_frames_remaining() -> int:
	return _hitstop_frames_remaining


func active_hitboxes_local() -> Array:
	var entries: Array = []
	if not is_executing() or is_hitstopped():
		return entries

	var windows: Array = active_move.get("hitbox_windows", [])
	for i in windows.size():
		if not _enabled_hitbox_windows.has(i):
			continue
		var window: Dictionary = windows[i]
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


func active_hurtboxes_world(owner_position: Vector2, facing: int, visual_jump_offset: float) -> Array:
	var entries: Array = []
	if not is_executing():
		return entries
	for window in active_move.get("hurtbox_windows", []):
		var first_frame := int(window.get("from_frame", 0))
		var last_frame := int(window.get("to_frame", first_frame))
		if frame_index < first_frame or frame_index > last_frame:
			continue
		var local_rect: Rect2 = window.get("rect", Rect2())
		if facing < 0:
			local_rect.position.x = -local_rect.position.x - local_rect.size.x
		local_rect.position.y += visual_jump_offset
		entries.append({
			"hurtbox_id": str(window.get("hurtbox_id", "")),
			"rect": Rect2(owner_position + local_rect.position, local_rect.size),
		})
	return entries


func can_hit_target(target_instance_id: String, window_index: int) -> bool:
	var key := "%s:%d:%s" % [active_move_id, window_index, target_instance_id]
	return not _hit_marks.has(key)


func mark_target_hit(target_instance_id: String, window_index: int) -> void:
	var key := "%s:%d:%s" % [active_move_id, window_index, target_instance_id]
	_hit_marks[key] = true


func _ensure_animation_player() -> void:
	if animation_player != null:
		return
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = NodePath("..")
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	add_child(animation_player)


func _rebuild_timing_animations() -> void:
	_ensure_animation_player()
	if animation_player.has_animation_library(&""):
		animation_player.remove_animation_library(&"")
	var library := AnimationLibrary.new()
	for move_id in move_templates.keys():
		library.add_animation(StringName(str(move_id)), _timing_animation(move_templates[move_id]))
	animation_player.add_animation_library(&"", library)


func _timing_animation(move: Dictionary) -> Animation:
	var animation := Animation.new()
	var fps := maxf(1.0, float(move.get("fps", 60.0)))
	var total_frames := maxi(1, int(move.get("total_frames", 1)))
	animation.length = float(total_frames) / fps
	animation.loop_mode = Animation.LOOP_NONE

	var frame_track := animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(frame_track, NodePath("."))
	for frame in total_frames:
		animation.track_insert_key(frame_track, float(frame) / fps, {
			"method": &"_set_timing_frame",
			"args": [frame],
		})
	for window_index in move.get("hitbox_windows", []).size():
		var window_track := animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(window_track, NodePath("."))
		var window: Dictionary = move["hitbox_windows"][window_index]
		var first_frame := clampi(int(window.get("from_frame", 0)), 0, total_frames - 1)
		var last_frame := clampi(int(window.get("to_frame", first_frame)), first_frame, total_frames - 1)
		animation.track_insert_key(window_track, float(first_frame) / fps, {
			"method": &"_enable_hitbox_window",
			"args": [window_index],
		})
		animation.track_insert_key(window_track, float(last_frame + 1) / fps, {
			"method": &"_disable_hitbox_window",
			"args": [window_index],
		})
	for event in move.get("events", []):
		var event_track := animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(event_track, NodePath("."))
		var event_frame := clampi(int(event.get("frame", 0)), 0, total_frames - 1)
		animation.track_insert_key(event_track, float(event_frame) / fps, {
			"method": &"_apply_frame_event",
			"args": [event.duplicate(true)],
		})
	var completion_track := animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(completion_track, NodePath("."))
	animation.track_insert_key(completion_track, animation.length, {
		"method": &"_complete_timed_move",
		"args": [],
	})
	return animation


func _set_timing_frame(next_frame: int) -> void:
	frame_index = next_frame


func _enable_hitbox_window(window_index: int) -> void:
	_enabled_hitbox_windows[window_index] = true


func _disable_hitbox_window(window_index: int) -> void:
	_enabled_hitbox_windows.erase(window_index)


func _apply_frame_event(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	match str(event.get("event_type", "")):
		"enable_hitbox":
			_set_hitbox_id_enabled(str(payload.get("hitbox_id", "")), true)
		"disable_hitbox":
			_set_hitbox_id_enabled(str(payload.get("hitbox_id", "")), false)
		"set_velocity":
			_authored_velocity = Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)))
		"change_state_context":
			state_context_requested.emit(str(payload.get("state", "")))
		"apply_hitstop":
			_hitstop_frames_remaining = maxi(0, int(payload.get("frames", active_move.get("hitstop_frames", 0))))


func _set_hitbox_id_enabled(hitbox_id: String, enabled: bool) -> void:
	for window_index in active_move.get("hitbox_windows", []).size():
		var window: Dictionary = active_move["hitbox_windows"][window_index]
		if str(window.get("hitbox_id", "")) != hitbox_id:
			continue
		if enabled:
			_enabled_hitbox_windows[window_index] = true
		else:
			_enabled_hitbox_windows.erase(window_index)


func _complete_timed_move() -> void:
	if not is_executing():
		return
	var finished_id := active_move_id
	cancel()
	move_finished.emit(finished_id)
