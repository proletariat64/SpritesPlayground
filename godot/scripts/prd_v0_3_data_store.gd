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
const SUPPORTED_EVENT_TYPES := {
	"enable_hitbox": true,
	"disable_hitbox": true,
	"set_velocity": true,
	"change_state_context": true,
	"apply_hitstop": true,
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
	errors.append_array(_validate_template_contract(template))
	errors.append_array(_validate_sprite_set_contract(sprite_set))
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
	for clip_id in clips.keys():
		var clip: Dictionary = clips[clip_id]
		var sequence_ref := str(clip.get("frame_sequence_ref", ""))
		if not sequences.has(sequence_ref):
			errors.append("animation clip %s missing frame sequence %s" % [clip_id, sequence_ref])
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
	errors.append_array(_validate_exact_keys(
		move,
		{
			"schema_version": true,
			"move_id": true,
			"move_type": true,
			"state_context_override": true,
			"frame_count": true,
			"active_window": true,
			"damage": true,
			"hitstop_frames": true,
			"hitboxes": true,
			"multi_hit": true,
			"events": true,
		},
		"move %s" % move_id
	))
	if str(move.get("schema_version", "")) != "0.3":
		errors.append("move %s schema_version must be 0.3" % move_id)
	if str(move.get("move_id", "")) != move_id:
		errors.append("move %s move_id must match file/reference id" % move_id)
	if not _is_snake_id(str(move.get("move_id", ""))):
		errors.append("move %s move_id must be lowercase snake_case" % move_id)
	if not ["locomotion", "combat", "reaction", "utility"].has(str(move.get("move_type", ""))):
		errors.append("move %s move_type is unsupported" % move_id)
	if move.has("state_context_override") and not ["idle", "walk", "dash", "jump", "hurt", "dead"].has(str(move["state_context_override"])):
		errors.append("move %s state_context_override is unsupported" % move_id)
	var frame_count := int(move.get("frame_count", 0))
	if frame_count < 1:
		errors.append("move %s frame_count must be >= 1" % move_id)
		return errors
	errors.append_array(_validate_frame_window(move_id, "active_window", move.get("active_window", {}), frame_count))
	for i in move.get("hitboxes", []).size():
		var hitbox: Dictionary = move["hitboxes"][i]
		errors.append_array(_validate_exact_keys(
			hitbox,
			{"hitbox_id": true, "active_window": true, "rect": true},
			"move %s hitboxes[%d]" % [move_id, i]
		))
		if not _is_hitbox_id(str(hitbox.get("hitbox_id", ""))):
			errors.append("move %s hitboxes[%d].hitbox_id must match ^hit_[a-z0-9_]+$" % [move_id, i])
		errors.append_array(_validate_frame_window(move_id, "hitboxes[%d].active_window" % i, hitbox.get("active_window", {}), frame_count))
		errors.append_array(_validate_rect(hitbox.get("rect", {}), "move %s hitboxes[%d].rect" % [move_id, i]))
	for i in move.get("events", []).size():
		var event: Dictionary = move["events"][i]
		errors.append_array(_validate_exact_keys(
			event,
			{"frame": true, "event_type": true, "payload": true},
			"move %s events[%d]" % [move_id, i]
		))
		var frame := int(event.get("frame", -1))
		if frame < 0 or frame >= frame_count:
			errors.append("move %s events[%d].frame must be within frame_count" % [move_id, i])
		errors.append_array(_validate_event_payload(move_id, i, event))
	return errors


static func _validate_template_contract(template: Dictionary) -> Array:
	var errors: Array = []
	errors.append_array(_validate_exact_keys(
		template,
		{
			"schema_version": true,
			"template_id": true,
			"sprite_set_ref": true,
			"hurtboxes": true,
			"foot_collision": true,
			"hp": true,
			"equipped_moves": true,
		},
		"template"
	))
	if str(template.get("schema_version", "")) != "0.3":
		errors.append("template schema_version must be 0.3")
	if not _is_snake_id(str(template.get("template_id", ""))):
		errors.append("template_id must be lowercase snake_case")
	if not _is_snake_id(str(template.get("sprite_set_ref", ""))):
		errors.append("sprite_set_ref must be lowercase snake_case")
	if int(template.get("hp", 0)) < 1:
		errors.append("template hp must be >= 1")
	for hurtbox_id in template.get("hurtboxes", {}).keys():
		if not str(hurtbox_id).begins_with("hurt_"):
			errors.append("hurtbox id %s must start with hurt_" % hurtbox_id)
		errors.append_array(_validate_rect(template["hurtboxes"][hurtbox_id], "hurtbox %s" % hurtbox_id))
	var foot: Dictionary = template.get("foot_collision", {})
	errors.append_array(_validate_exact_keys(foot, {"center": true, "radius": true}, "foot_collision"))
	errors.append_array(_validate_vector(foot.get("center", {}), "foot_collision.center", false))
	errors.append_array(_validate_vector(foot.get("radius", {}), "foot_collision.radius", true))
	for move_id in template.get("equipped_moves", []):
		if not _is_snake_id(str(move_id)):
			errors.append("equipped move %s must be lowercase snake_case" % move_id)
	return errors


static func _validate_sprite_set_contract(sprite_set: Dictionary) -> Array:
	var errors: Array = []
	errors.append_array(_validate_exact_keys(
		sprite_set,
		{
			"schema_version": true,
			"sprite_set_id": true,
			"animation_clips": true,
			"frame_sequences": true,
			"required_moves_mapping": true,
		},
		"sprite_set"
	))
	if str(sprite_set.get("schema_version", "")) != "0.3":
		errors.append("sprite_set schema_version must be 0.3")
	if not _is_snake_id(str(sprite_set.get("sprite_set_id", ""))):
		errors.append("sprite_set_id must be lowercase snake_case")
	var clips: Dictionary = sprite_set.get("animation_clips", {})
	for clip_id in clips.keys():
		var clip: Dictionary = clips[clip_id]
		errors.append_array(_validate_exact_keys(
			clip,
			{"clip_id": true, "frame_sequence_ref": true, "loop": true},
			"sprite_set.animation_clips.%s" % clip_id
		))
		if str(clip.get("clip_id", "")) != str(clip_id):
			errors.append("animation clip %s clip_id must match key" % clip_id)
	return errors


static func _validate_frame_window(move_id: String, label: String, window: Dictionary, frame_count: int) -> Array:
	var errors: Array = []
	errors.append_array(_validate_exact_keys(window, {"start_frame": true, "end_frame": true}, "move %s %s" % [move_id, label]))
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
	if not SUPPORTED_EVENT_TYPES.has(event_type):
		errors.append("move %s events[%d] unsupported event_type %s" % [move_id, index, event_type])
		return errors
	match event_type:
		"enable_hitbox", "disable_hitbox":
			errors.append_array(_validate_exact_keys(payload, {"hitbox_id": true}, "move %s events[%d].payload" % [move_id, index]))
			if not payload.has("hitbox_id"):
				errors.append("move %s events[%d] missing hitbox_id" % [move_id, index])
			elif not _is_hitbox_id(str(payload["hitbox_id"])):
				errors.append("move %s events[%d] hitbox_id must match ^hit_[a-z0-9_]+$" % [move_id, index])
		"set_velocity":
			errors.append_array(_validate_exact_keys(payload, {"x": true, "y": true}, "move %s events[%d].payload" % [move_id, index]))
			if not payload.has("x") or not payload.has("y"):
				errors.append("move %s events[%d] missing velocity x/y" % [move_id, index])
			else:
				errors.append_array(_validate_number(payload["x"], "move %s events[%d].payload.x" % [move_id, index]))
				errors.append_array(_validate_number(payload["y"], "move %s events[%d].payload.y" % [move_id, index]))
		"change_state_context":
			errors.append_array(_validate_exact_keys(payload, {"state": true}, "move %s events[%d].payload" % [move_id, index]))
			if not payload.has("state"):
				errors.append("move %s events[%d] missing state" % [move_id, index])
			elif not ["idle", "walk", "dash", "jump", "hurt", "dead"].has(str(payload["state"])):
				errors.append("move %s events[%d] state is unsupported" % [move_id, index])
		"apply_hitstop":
			errors.append_array(_validate_exact_keys(payload, {"frames": true}, "move %s events[%d].payload" % [move_id, index]))
			if not payload.has("frames"):
				errors.append("move %s events[%d] missing hitstop frames" % [move_id, index])
			else:
				errors.append_array(_validate_integer(payload["frames"], "move %s events[%d].payload.frames" % [move_id, index]))
				var frames := int(payload["frames"])
				if frames < 0 or frames > 60:
					errors.append("move %s events[%d].payload.frames must be 0..60" % [move_id, index])
	return errors


static func _validate_exact_keys(data: Dictionary, allowed: Dictionary, label: String) -> Array:
	var errors: Array = []
	for key in data.keys():
		if not allowed.has(str(key)):
			errors.append("%s has unsupported key %s" % [label, key])
	return errors


static func _validate_rect(data: Dictionary, label: String) -> Array:
	var errors := _validate_exact_keys(data, {"x": true, "y": true, "w": true, "h": true}, label)
	for field in ["x", "y", "w", "h"]:
		if not data.has(field):
			errors.append("%s missing %s" % [label, field])
	if data.has("w") and float(data["w"]) <= 0.0:
		errors.append("%s.w must be > 0" % label)
	if data.has("h") and float(data["h"]) <= 0.0:
		errors.append("%s.h must be > 0" % label)
	return errors


static func _validate_vector(data: Dictionary, label: String, positive: bool) -> Array:
	var errors := _validate_exact_keys(data, {"x": true, "y": true}, label)
	for field in ["x", "y"]:
		if not data.has(field):
			errors.append("%s missing %s" % [label, field])
		elif positive and float(data[field]) <= 0.0:
			errors.append("%s.%s must be > 0" % [label, field])
	return errors


static func _validate_number(value, label: String) -> Array:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return []
	return ["%s must be a number" % label]


static func _validate_integer(value, label: String) -> Array:
	if typeof(value) == TYPE_INT:
		return []
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))):
		return []
	return ["%s must be an integer" % label]


static func _is_snake_id(value: String) -> bool:
	if value.is_empty():
		return false
	var expression := RegEx.new()
	expression.compile("^[a-z][a-z0-9_]*$")
	return expression.search(value) != null


static func _is_hitbox_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^hit_[a-z0-9_]+$")
	return expression.search(value) != null


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
