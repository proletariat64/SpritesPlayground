extends Node
class_name RebuildData

const CHARACTER_IDS = ["adam", "cain"]
const MOVE_IDS = ["basic_punch", "basic_punch_3hit"]


static func character_path(character_id: String) -> String:
	return "res://data/rebuild/characters/%s.json" % character_id


static func move_path(move_id: String) -> String:
	return "res://data/rebuild/moves/%s.json" % move_id


static func sprite_set_path(sprite_set_id: String) -> String:
	return "res://data/rebuild/sprite_sets/%s.json" % sprite_set_id


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"_error": "Missing JSON file: %s" % path}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"_error": "Cannot open %s, error %s" % [path, FileAccess.get_open_error()]}

	var text = file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"_error": "Invalid JSON object: %s" % path}
	return parsed


static func parse_json_text(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"_error": "Text is not a JSON object"}
	return parsed


static func save_json(path: String, data: Dictionary) -> Dictionary:
	var dir = path.get_base_dir()
	var absolute_dir = ProjectSettings.globalize_path(dir)
	var dir_error = DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		return {"ok": false, "error": "Cannot create %s, error %s" % [dir, dir_error]}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot write %s, error %s" % [path, FileAccess.get_open_error()]}

	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	return {"ok": true, "path": path}


static func load_character(character_id: String) -> Dictionary:
	return load_json(character_path(character_id))


static func load_move(move_id: String) -> Dictionary:
	return load_json(move_path(move_id))


static func load_sprite_set(sprite_set_id: String) -> Dictionary:
	return load_json(sprite_set_path(sprite_set_id))


static func load_actor_bundle(definition_path: String) -> Dictionary:
	var definition = load_json(definition_path)
	if definition.has("_error"):
		return {"_error": definition["_error"]}

	var template = definition.get("character_template", {})
	var sprite_set_id = str(template.get("sprite_set_id", definition.get("id", "")))
	var sprite_set = load_json(str(template.get("sprite_set_path", sprite_set_path(sprite_set_id))))
	if sprite_set.has("_error"):
		return {"_error": sprite_set["_error"]}

	var moves = {}
	for move_id in template.get("equipped_moves", []):
		var move = load_move(str(move_id))
		if move.has("_error"):
			return {"_error": move["_error"]}
		moves[str(move_id)] = move

	return {
		"definition": definition,
		"sprite_set": sprite_set,
		"moves": moves
	}


static func clone_dictionary(data: Dictionary) -> Dictionary:
	var text = JSON.stringify(data)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func pretty_json(data: Dictionary) -> String:
	return JSON.stringify(data, "\t", false)
