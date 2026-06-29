extends Node
class_name MoveRuntime

const AUTHORING_FPS = 12.0

var actor: Node = null
var blackboard: Node = null
var moves = {}
var active_move = {}
var active_segment_index = 0
var frame_accumulator = 0.0
var queued_attack_light = false
var attack_serial = 0
var segment_attack_instance_id = ""


func setup(owner_actor: Node, owner_blackboard: Node, loaded_moves: Dictionary) -> void:
	actor = owner_actor
	blackboard = owner_blackboard
	moves = loaded_moves


func request_light_attack() -> bool:
	if blackboard == null:
		return false
	if blackboard.state == "attack":
		queued_attack_light = true
		return true
	if not moves.has("basic_punch_3hit"):
		return false
	if not actor.state_driver.request_event("ev_attack"):
		return false
	active_move = moves["basic_punch_3hit"]
	active_segment_index = 0
	frame_accumulator = 0.0
	queued_attack_light = false
	attack_serial += 1
	_begin_segment()
	blackboard.current_move = "basic_punch"
	return true


func tick(delta: float) -> void:
	if blackboard == null or active_move.is_empty():
		return
	if blackboard.state != "attack":
		active_move = {}
		return

	frame_accumulator += delta * AUTHORING_FPS
	var frame = int(floor(frame_accumulator)) + 1
	blackboard.authored_frame = frame
	blackboard.runtime_frame += 1
	var segment = _current_segment()
	blackboard.current_segment = str(segment.get("segment_id", ""))

	if queued_attack_light and _can_continue(segment, frame):
		queued_attack_light = false
		active_segment_index += 1
		if active_segment_index < _segments().size():
			blackboard.current_move = "basic_punch_3hit"
			_begin_segment()
			return

	if frame > _segment_total_frames(segment):
		if _has_next_segment(segment) and queued_attack_light:
			queued_attack_light = false
			active_segment_index += 1
			blackboard.current_move = "basic_punch_3hit"
			_begin_segment()
			return
		active_move = {}
		actor.state_driver.request_event("ev_finished")


func get_active_hitboxes() -> Array:
	var result = []
	if active_move.is_empty() or blackboard == null or blackboard.state != "attack":
		return result
	var segment = _current_segment()
	var authored_frame = blackboard.authored_frame
	for profile in segment.get("hitbox_profiles", []):
		var start_frame = int(profile.get("active_start_frame", int(segment.get("startup_frames", 0)) + 1))
		var end_frame = int(profile.get("active_end_frame", start_frame + int(segment.get("active_frames", 1)) - 1))
		if authored_frame < start_frame or authored_frame > end_frame:
			continue
		var rect = actor.local_rect_to_global(profile.get("rect", {}))
		result.append({
			"attacker": actor,
			"attacker_id": blackboard.actor_id,
			"attack_instance_id": segment_attack_instance_id,
			"hitbox_id": str(profile.get("id", "hitbox")),
			"rect": rect,
			"atk": int(profile.get("atk", 0)),
			"hitstop_frames": int(profile.get("hitstop_frames", 0)),
			"hitstun_frames": int(profile.get("hitstun_frames", 0)),
			"reaction_tag": str(profile.get("reaction_tag", "hurt_light")),
			"knockback": profile.get("knockback", {"x": 0, "y": 0})
		})
	return result


func _begin_segment() -> void:
	frame_accumulator = 0.0
	blackboard.authored_frame = 1
	var segment = _current_segment()
	blackboard.current_segment = str(segment.get("segment_id", "s1"))
	segment_attack_instance_id = "%s:%s:%s:%s" % [
		blackboard.actor_id,
		str(active_move.get("id", "move")),
		blackboard.current_segment,
		attack_serial
	]


func _current_segment() -> Dictionary:
	var segments = _segments()
	if active_segment_index < 0 or active_segment_index >= segments.size():
		return {}
	var segment = segments[active_segment_index]
	if typeof(segment) == TYPE_DICTIONARY:
		return segment
	return {}


func _segments() -> Array:
	var segments = active_move.get("segments", [])
	if typeof(segments) != TYPE_ARRAY:
		return []
	return segments


func _segment_total_frames(segment: Dictionary) -> int:
	return int(segment.get("startup_frames", 0)) + int(segment.get("active_frames", 0)) + int(segment.get("recovery_frames", 0))


func _can_continue(segment: Dictionary, frame: int) -> bool:
	if not segment.has("continue_gate"):
		return false
	var gate = segment["continue_gate"]
	if typeof(gate) != TYPE_DICTIONARY:
		return false
	if frame < int(gate.get("start_frame", 0)):
		return false
	if frame > int(gate.get("end_frame", 0)):
		return false
	return _has_next_segment(segment)


func _has_next_segment(_segment: Dictionary) -> bool:
	return active_segment_index + 1 < _segments().size()
