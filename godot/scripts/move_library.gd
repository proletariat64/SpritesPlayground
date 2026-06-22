extends Resource
class_name MoveLibrary

const CreatorDataStoreScript := preload("res://godot/scripts/creator_data_store.gd")


static func combat_gray_s64_moves() -> Dictionary:
	return {
		"basic_punch": load_move("basic_punch"),
		"basic_kick": load_move("basic_kick"),
	}


static func load_move(move_id: String) -> Dictionary:
	return CreatorDataStoreScript.move_json_to_runtime(CreatorDataStoreScript.load_move_json(move_id))
