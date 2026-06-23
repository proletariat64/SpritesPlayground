extends RefCounted
class_name PrdV03Runtime

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const DEFAULT_HITSTOP_FRAMES := 3

var template: Dictionary = {}
var sprite_set: Dictionary = {}
var moves: Dictionary = {}
var current_state: String = "idle"
var current_move: String = "idle"
var current_frame: int = 0
var hitstop_frames: int = 0
var velocity: Vector2 = Vector2.ZERO

var _enabled_hitboxes := {}
var _hit_windows := {}


func load_template(template_id: String) -> Array:
	var bundle := DataStore.load_runtime_bundle(template_id)
	return load_bundle(bundle)


func load_bundle(bundle: Dictionary) -> Array:
	var errors := DataStore.validate_runtime_bundle(bundle)
	if errors.size() > 0:
		return errors
	template = bundle["template"]
	sprite_set = bundle["sprite_set"]
	moves = bundle["moves"]
	return start_move("idle")


func start_move(move_id: String) -> Array:
	if not moves.has(move_id):
		return ["missing move %s" % move_id]
	var move: Dictionary = moves[move_id]
	current_move = move_id
	current_frame = 0
	hitstop_frames = 0
	velocity = Vector2.ZERO
	_enabled_hitboxes.clear()
	_hit_windows.clear()
	if move.has("state_context_override"):
		current_state = str(move["state_context_override"])
	else:
		current_state = _state_for_move(move)
	_apply_events_at_current_frame()
	return []


func tick_frame() -> void:
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return

	var move := current_move_data()
	var last_frame := int(move.get("frame_count", 1)) - 1
	if current_frame < last_frame:
		current_frame += 1
		_apply_events_at_current_frame()


func current_move_data() -> Dictionary:
	return moves.get(current_move, {})


func active_hitboxes() -> Array:
	var entries: Array = []
	if hitstop_frames > 0:
		return entries

	var move := current_move_data()
	var move_window: Dictionary = move.get("active_window", {"start_frame": 0, "end_frame": int(move.get("frame_count", 1)) - 1})
	if current_frame < int(move_window["start_frame"]) or current_frame > int(move_window["end_frame"]):
		return entries
	for hitbox in move.get("hitboxes", []):
		var hitbox_id := str(hitbox["hitbox_id"])
		if not _enabled_hitboxes.has(hitbox_id):
			continue
		var window: Dictionary = hitbox["active_window"]
		if current_frame < int(window["start_frame"]) or current_frame > int(window["end_frame"]):
			continue
		entries.append({
			"hitbox_id": hitbox_id,
			"rect": hitbox["rect"],
			"damage": int(move["damage"]),
			"multi_hit": bool(move["multi_hit"]),
		})
	return entries


func hurtboxes() -> Dictionary:
	return template.get("hurtboxes", {})


func foot_collision() -> Dictionary:
	return template.get("foot_collision", {})


func debug_summary() -> Dictionary:
	var hitboxes := active_hitboxes()
	return {
		"current_state": current_state,
		"current_move": current_move,
		"current_frame": current_frame,
		"hitstop_frames": hitstop_frames,
		"velocity": velocity,
		"active_hitboxes": hitboxes,
		"active_hitbox_count": hitboxes.size(),
		"hurtboxes": hurtboxes(),
		"foot_collision": foot_collision(),
		"sprite_set_ref": template.get("sprite_set_ref", ""),
	}


func _apply_events_at_current_frame() -> void:
	for event in current_move_data().get("events", []):
		if int(event["frame"]) == current_frame:
			_apply_event(event)


func _apply_event(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	match str(event["event_type"]):
		"enable_hitbox":
			if payload.has("hitbox_id"):
				_enabled_hitboxes[str(payload["hitbox_id"])] = true
		"disable_hitbox":
			if payload.has("hitbox_id"):
				_enabled_hitboxes.erase(str(payload["hitbox_id"]))
		"set_velocity":
			velocity = Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)))
		"change_state_context":
			current_state = str(payload.get("state", current_state))
		"apply_hitstop":
			hitstop_frames = int(payload.get("frames", current_move_data().get("hitstop_frames", DEFAULT_HITSTOP_FRAMES)))
		"play_sound":
			pass
		"spawn_visual":
			pass


func _state_for_move(move: Dictionary) -> String:
	match str(move.get("move_type", "utility")):
		"locomotion":
			return current_move
		"reaction":
			return current_move
		_:
			return current_state
