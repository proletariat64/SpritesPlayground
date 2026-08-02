extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const CharacterTemplate := preload("res://godot/scripts/character_template.gd")


func _initialize() -> void:
	var errors: Array = []
	_expect(
		DataStore.template_path("combat_gray_s64") == "res://data/v0_6/templates/combat_gray_s64.json",
		"default authored-data path uses the v0.6 root",
		errors
	)
	var bundle := DataStore.load_runtime_bundle("combat_gray_s64")
	_expect(not bundle.get("template", {}).is_empty(), "default root loads the live template", errors)
	_expect(DataStore.validate_runtime_bundle(bundle).is_empty(), "default root loads a valid live bundle", errors)
	var runtime_template := CharacterTemplate.load_template("combat_gray_s64")
	for move_id in bundle.get("template", {}).get("equipped_moves", []):
		_expect(
			runtime_template.get("move_templates", {}).has(move_id),
			"live template exposes v0.6 move %s" % move_id,
			errors
		)
	if errors.is_empty():
		print("v0_6_data_root_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		print("v0_6_data_root_smoke=FAIL")
		quit(1)


func _expect(condition: bool, message: String, errors: Array) -> void:
	if not condition:
		errors.append(message)
