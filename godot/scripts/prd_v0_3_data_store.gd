extends RefCounted
class_name PrdV03DataStore

const DocumentRules := preload("res://godot/scripts/prd_v0_3_document_rules.gd")
const DEFAULT_DATA_ROOT := "res://data/v0_3"
const TEMPLATE_DIR := DEFAULT_DATA_ROOT + "/templates"
const MOVE_DIR := DEFAULT_DATA_ROOT + "/moves"
const SPRITE_SET_DIR := DEFAULT_DATA_ROOT + "/sprite_sets"


static func template_path(template_id: String, data_root: String = DEFAULT_DATA_ROOT) -> String:
	return data_root.path_join("templates").path_join("%s.json" % template_id)


static func move_path(move_id: String, data_root: String = DEFAULT_DATA_ROOT) -> String:
	return data_root.path_join("moves").path_join("%s.json" % move_id)


static func sprite_set_path(sprite_set_id: String, data_root: String = DEFAULT_DATA_ROOT) -> String:
	return data_root.path_join("sprite_sets").path_join("%s.json" % sprite_set_id)


static func load_template(template_id: String, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
	return _read_json(template_path(template_id, data_root))


static func load_move(move_id: String, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
	return _read_json(move_path(move_id, data_root))


static func load_sprite_set(sprite_set_id: String, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
	return _read_json(sprite_set_path(sprite_set_id, data_root))


static func save_template(data: Dictionary, data_root: String = DEFAULT_DATA_ROOT) -> Error:
	return _write_json(template_path(str(data["template_id"]), data_root), DocumentRules.normalize_template(data))


static func save_move(data: Dictionary, data_root: String = DEFAULT_DATA_ROOT) -> Error:
	return _write_json(move_path(str(data["move_id"]), data_root), DocumentRules.normalize_move(data))


static func save_sprite_set(data: Dictionary, data_root: String = DEFAULT_DATA_ROOT) -> Error:
	return _write_json(sprite_set_path(str(data["sprite_set_id"]), data_root), data)


static func duplicate_template(source_id: String, next_id: String, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
	var data := load_template(source_id, data_root).duplicate(true)
	data["template_id"] = next_id
	save_template(data, data_root)
	return data


static func list_template_ids(data_root: String = DEFAULT_DATA_ROOT) -> Array:
	return _list_json_ids(data_root.path_join("templates"))


static func list_move_ids(data_root: String = DEFAULT_DATA_ROOT) -> Array:
	return _list_json_ids(data_root.path_join("moves"))


static func list_sprite_set_ids(data_root: String = DEFAULT_DATA_ROOT) -> Array:
	return _list_json_ids(data_root.path_join("sprite_sets"))


static func load_runtime_bundle(template_id: String, data_root: String = DEFAULT_DATA_ROOT) -> Dictionary:
	var template := load_template(template_id, data_root)
	var sprite_set := load_sprite_set(str(template["sprite_set_ref"]), data_root)
	var moves := {}
	for move_id in template["equipped_moves"]:
		moves[str(move_id)] = load_move(str(move_id), data_root)
	return {
		"template": template,
		"sprite_set": sprite_set,
		"moves": moves,
	}


static func save_runtime_bundle(bundle: Dictionary, data_root: String = DEFAULT_DATA_ROOT) -> Array:
	var errors := DocumentRules.validate_runtime_bundle(bundle)
	if not errors.is_empty():
		return errors
	var normalized := DocumentRules.normalize_runtime_bundle(bundle)
	var write_error := save_template(normalized["template"], data_root)
	if write_error != OK:
		return ["could not save template %s (error %d)" % [normalized["template"]["template_id"], write_error]]
	for move_id in normalized["moves"].keys():
		write_error = save_move(normalized["moves"][move_id], data_root)
		if write_error != OK:
			return ["could not save move %s (error %d)" % [move_id, write_error]]
	write_error = save_sprite_set(normalized["sprite_set"], data_root)
	if write_error != OK:
		return ["could not save sprite set %s (error %d)" % [normalized["sprite_set"]["sprite_set_id"], write_error]]
	return []


static func validate_runtime_bundle(bundle: Dictionary) -> Array:
	return DocumentRules.validate_runtime_bundle(bundle)


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


static func _write_json(path: String, data: Dictionary) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if directory_error != OK:
		push_error("Could not create PRD v0.3 data directory: %s" % path.get_base_dir())
		return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write PRD v0.3 JSON file: %s" % path)
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(DocumentRules.normalize_integral_numbers(data), "\t", true))
	file.store_string("\n")
	var write_error := file.get_error()
	if write_error != OK:
		push_error("Could not finish writing PRD v0.3 JSON file: %s" % path)
	return write_error


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
