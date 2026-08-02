extends Resource
class_name MoveLibrary

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const CharacterTemplateScript := preload("res://godot/scripts/character_template.gd")


static func combat_gray_s64_moves() -> Dictionary:
	return {
		"basic_punch": load_move("basic_punch"),
		"basic_kick": load_move("basic_kick"),
	}


static func load_move(move_id: String) -> Dictionary:
	return CharacterTemplateScript.v0_3_move_to_runtime(move_id, DataStore.load_move(move_id))
