extends RefCounted
class_name CreatorDataStore

const TEMPLATE_DIR := "res://data/templates"
const MOVE_DIR := "res://data/moves"
const SPRITE_SET_DIR := "res://data/sprite_sets"


static func template_path(template_id: String) -> String:
	return TEMPLATE_DIR.path_join("%s.json" % template_id)


static func move_path(move_id: String) -> String:
	return MOVE_DIR.path_join("%s.json" % move_id)


static func sprite_set_path(sprite_set_id: String) -> String:
	return SPRITE_SET_DIR.path_join("%s.json" % sprite_set_id)


static func load_template_json(template_id: String) -> Dictionary:
	return _read_json(template_path(template_id))


static func load_move_json(move_id: String) -> Dictionary:
	return _read_json(move_path(move_id))


static func load_sprite_set_json(sprite_set_id: String) -> Dictionary:
	return _read_json(sprite_set_path(sprite_set_id))


static func save_template_json(data: Dictionary) -> void:
	_write_json(template_path(str(data["template_id"])), data)


static func save_move_json(data: Dictionary) -> void:
	_write_json(move_path(str(data["move_id"])), data)


static func duplicate_template(source_id: String, new_id: String) -> Dictionary:
	var data := load_template_json(source_id).duplicate(true)
	data["template_id"] = new_id
	data["lock_state"] = "editable"
	data["validation_status"] = "draft"
	save_template_json(data)
	return data


static func template_json_to_runtime(template_json: Dictionary) -> Dictionary:
	var move_templates := {}
	for move_id in template_json.get("base_attack_moves", []):
		move_templates[str(move_id)] = move_json_to_runtime(load_move_json(str(move_id)))
	for move_id in template_json.get("equipped_moves", []):
		move_templates[str(move_id)] = move_json_to_runtime(load_move_json(str(move_id)))
	return {
		"template_id": str(template_json["template_id"]),
		"sprite_size_class": str(template_json["sprite_size_class"]),
		"frame_size": int(template_json["frame_size"]),
		"sprite_set_id": str(template_json.get("sprite_set_id", "")),
		"max_hp": int(template_json["max_hp"]),
		"hurtbox_profile": _hurtboxes_json_to_runtime(template_json["hurtboxes"]),
		"foot_collision_profile": _foot_json_to_runtime(template_json["foot_collision"]),
		"move_templates": move_templates,
	}


static func move_json_to_runtime(move_json: Dictionary) -> Dictionary:
	var windows: Array = []
	for hitbox in move_json.get("hitboxes", []):
		windows.append({
			"from_frame": int(hitbox["frame_start"]),
			"to_frame": int(hitbox["frame_end"]),
			"hitbox_id": str(hitbox["name"]),
			"damage": int(move_json["damage"]),
			"rect": rect_json_to_runtime(hitbox["rect"]),
		})
	return {
		"move_id": str(move_json["move_id"]),
		"fps": 60,
		"total_frames": int(move_json["frame_count"]),
		"hitbox_windows": windows,
	}


static func list_template_ids() -> Array:
	return _list_json_ids(TEMPLATE_DIR)


static func list_sprite_set_ids() -> Array:
	return _list_json_ids(SPRITE_SET_DIR)


static func rect_json_to_runtime(data: Dictionary) -> Rect2:
	return Rect2(float(data["x"]), float(data["y"]), float(data["w"]), float(data["h"]))


static func rect_runtime_to_json(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


static func vector_json_to_runtime(data: Dictionary) -> Vector2:
	return Vector2(float(data["x"]), float(data["y"]))


static func vector_runtime_to_json(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func _hurtboxes_json_to_runtime(data: Dictionary) -> Dictionary:
	var result := {}
	for key in data.keys():
		result[key] = rect_json_to_runtime(data[key])
	return result


static func _foot_json_to_runtime(data: Dictionary) -> Dictionary:
	return {
		"center": vector_json_to_runtime(data["center"]),
		"radius": vector_json_to_runtime(data["radius"]),
	}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing JSON file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("JSON root must be a dictionary: %s" % path)
		return {}
	return json.data


static func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true))
	file.store_string("\n")


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
