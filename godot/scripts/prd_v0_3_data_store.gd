extends RefCounted
class_name PrdV03DataStore

const TEMPLATE_DIR := "res://data/v0_3/templates"
const MOVE_DIR := "res://data/v0_3/moves"
const SPRITE_SET_DIR := "res://data/v0_3/sprite_sets"
const FORBIDDEN_KEYS := {
	"action": true,
	"actions": true,
	"attack": true,
	"base_action_set": true,
	"base_actions": true,
	"base_attack_moves": true,
	"cooldown_seconds": true,
	"duration_seconds": true,
	"seconds": true,
}


static func template_path(template_id: String) -> String:
	return TEMPLATE_DIR.path_join("%s.json" % template_id)


static func move_path(move_id: String) -> String:
	return MOVE_DIR.path_join("%s.json" % move_id)


static func sprite_set_path(sprite_set_id: String) -> String:
	return SPRITE_SET_DIR.path_join("%s.json" % sprite_set_id)


static func load_template(template_id: String) -> Dictionary:
	return _read_json(template_path(template_id))


static func load_move(move_id: String) -> Dictionary:
	return _read_json(move_path(move_id))


static func load_sprite_set(sprite_set_id: String) -> Dictionary:
	return _read_json(sprite_set_path(sprite_set_id))


static func save_template(data: Dictionary) -> void:
	_write_json(template_path(str(data["template_id"])), _normalize_template(data))


static func save_move(data: Dictionary) -> void:
	_write_json(move_path(str(data["move_id"])), _normalize_move(data))


static func save_sprite_set(data: Dictionary) -> void:
	_write_json(sprite_set_path(str(data["sprite_set_id"])), data)


static func duplicate_template(source_id: String, next_id: String) -> Dictionary:
	var data := load_template(source_id).duplicate(true)
	data["template_id"] = next_id
	save_template(data)
	return data


static func list_template_ids() -> Array:
	return _list_json_ids(TEMPLATE_DIR)


static func list_move_ids() -> Array:
	return _list_json_ids(MOVE_DIR)


static func list_sprite_set_ids() -> Array:
	return _list_json_ids(SPRITE_SET_DIR)


static func load_runtime_bundle(template_id: String) -> Dictionary:
	var template := load_template(template_id)
	var sprite_set := load_sprite_set(str(template["sprite_set_ref"]))
	var moves := {}
	for move_id in template["equipped_moves"]:
		moves[str(move_id)] = load_move(str(move_id))
	return {
		"template": template,
		"sprite_set": sprite_set,
		"moves": moves,
	}


static func validate_runtime_bundle(bundle: Dictionary) -> Array:
	var errors: Array = []
	var template: Dictionary = bundle.get("template", {})
	var sprite_set: Dictionary = bundle.get("sprite_set", {})
	var moves: Dictionary = bundle.get("moves", {})
	var mapping: Dictionary = sprite_set.get("required_moves_mapping", {})
	var clips: Dictionary = sprite_set.get("animation_clips", {})
	var sequences: Dictionary = sprite_set.get("frame_sequences", {})

	errors.append_array(_scan_forbidden_keys(template, "template"))
	errors.append_array(_scan_forbidden_keys(sprite_set, "sprite_set"))
	errors.append_array(_scan_forbidden_keys(moves, "moves"))
	if not template.get("equipped_moves", []).has("idle"):
		errors.append("template must equip idle move")
	for move_id in moves.keys():
		errors.append_array(_validate_move(str(move_id), moves[move_id]))
	for move_id in template.get("equipped_moves", []):
		var id := str(move_id)
		if not moves.has(id):
			errors.append("missing move %s" % id)
		if not mapping.has(id):
			errors.append("missing sprite mapping for %s" % id)
			continue
		var clip_id := str(mapping[id])
		if not clips.has(clip_id):
			errors.append("missing animation clip %s" % clip_id)
			continue
		var sequence_id := str(clips[clip_id].get("frame_sequence_ref", ""))
		if not sequences.has(sequence_id):
			errors.append("missing frame sequence %s" % sequence_id)
	return errors


static func _scan_forbidden_keys(value, path: String) -> Array:
	var errors: Array = []
	match typeof(value):
		TYPE_DICTIONARY:
			for key in value.keys():
				var key_text := str(key)
				var child_path := "%s.%s" % [path, key_text]
				if FORBIDDEN_KEYS.has(key_text):
					errors.append("%s is a forbidden legacy key" % child_path)
				errors.append_array(_scan_forbidden_keys(value[key], child_path))
		TYPE_ARRAY:
			for i in value.size():
				errors.append_array(_scan_forbidden_keys(value[i], "%s[%d]" % [path, i]))
	return errors


static func _validate_move(move_id: String, move: Dictionary) -> Array:
	var errors: Array = []
	var frame_count := int(move.get("frame_count", 0))
	if frame_count < 1:
		errors.append("move %s frame_count must be >= 1" % move_id)
		return errors
	errors.append_array(_validate_frame_window(move_id, "active_window", move.get("active_window", {}), frame_count))
	for i in move.get("hitboxes", []).size():
		var hitbox: Dictionary = move["hitboxes"][i]
		errors.append_array(_validate_frame_window(move_id, "hitboxes[%d].active_window" % i, hitbox.get("active_window", {}), frame_count))
	for i in move.get("events", []).size():
		var event: Dictionary = move["events"][i]
		var frame := int(event.get("frame", -1))
		if frame < 0 or frame >= frame_count:
			errors.append("move %s events[%d].frame must be within frame_count" % [move_id, i])
		errors.append_array(_validate_event_payload(move_id, i, event))
	return errors


static func _validate_frame_window(move_id: String, label: String, window: Dictionary, frame_count: int) -> Array:
	var errors: Array = []
	if not window.has("start_frame") or not window.has("end_frame"):
		errors.append("move %s %s must include start_frame and end_frame" % [move_id, label])
		return errors
	var start_frame := int(window["start_frame"])
	var end_frame := int(window["end_frame"])
	if start_frame > end_frame:
		errors.append("move %s %s start_frame must be <= end_frame" % [move_id, label])
	if end_frame >= frame_count:
		errors.append("move %s %s end_frame must be < frame_count" % [move_id, label])
	return errors


static func _validate_event_payload(move_id: String, index: int, event: Dictionary) -> Array:
	var errors: Array = []
	var event_type := str(event.get("event_type", ""))
	var payload: Dictionary = event.get("payload", {})
	match event_type:
		"enable_hitbox", "disable_hitbox":
			if not payload.has("hitbox_id"):
				errors.append("move %s events[%d] missing hitbox_id" % [move_id, index])
		"set_velocity":
			if not payload.has("x") or not payload.has("y"):
				errors.append("move %s events[%d] missing velocity x/y" % [move_id, index])
		"change_state_context":
			if not payload.has("state"):
				errors.append("move %s events[%d] missing state" % [move_id, index])
		"apply_hitstop":
			if not payload.has("frames"):
				errors.append("move %s events[%d] missing hitstop frames" % [move_id, index])
	return errors


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing PRD v0.3 JSON file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open PRD v0.3 JSON file: %s" % path)
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("JSON parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("JSON root must be a dictionary: %s" % path)
		return {}
	return json.data


static func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write PRD v0.3 JSON file: %s" % path)
		return
	file.store_string(JSON.stringify(_normalize_integral_numbers(data), "\t", true))
	file.store_string("\n")


static func _normalize_template(data: Dictionary) -> Dictionary:
	var normalized := data.duplicate(true)
	if normalized.has("hp"):
		normalized["hp"] = int(normalized["hp"])
	return normalized


static func _normalize_move(data: Dictionary) -> Dictionary:
	var normalized := data.duplicate(true)
	for field in ["frame_count", "damage", "hitstop_frames"]:
		if normalized.has(field):
			normalized[field] = int(normalized[field])
	if normalized.has("active_window"):
		_normalize_window(normalized["active_window"])
	for hitbox in normalized.get("hitboxes", []):
		_normalize_window(hitbox["active_window"])
	for event in normalized.get("events", []):
		if event.has("frame"):
			event["frame"] = int(event["frame"])
		var payload: Dictionary = event.get("payload", {})
		if payload.has("frames"):
			payload["frames"] = int(payload["frames"])
	return normalized


static func _normalize_window(window: Dictionary) -> void:
	window["start_frame"] = int(window["start_frame"])
	window["end_frame"] = int(window["end_frame"])


static func _normalize_integral_numbers(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in value.keys():
				result[key] = _normalize_integral_numbers(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_normalize_integral_numbers(item))
			return result
		TYPE_FLOAT:
			var number := float(value)
			if is_equal_approx(number, roundf(number)):
				return int(roundf(number))
			return number
	return value


static func _list_json_ids(dir_path: String) -> Array:
	var ids: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ids
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			ids.append(file_name.get_basename())
	dir.list_dir_end()
	ids.sort()
	return ids
