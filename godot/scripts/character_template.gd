extends Resource
class_name CharacterTemplate

const CreatorDataStoreScript := preload("res://godot/scripts/creator_data_store.gd")


static func combat_gray_s64() -> Dictionary:
	return load_template("combat_gray_s64")


static func load_template(template_id: String) -> Dictionary:
	var template_json := CreatorDataStoreScript.load_template_json(template_id)
	return CreatorDataStoreScript.template_json_to_runtime(template_json)
