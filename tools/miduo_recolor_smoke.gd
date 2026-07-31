extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Generator := preload("res://godot/scripts/spriteframes_generator.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	var source := DataStore.load_runtime_bundle("miduo")
	var variant := DataStore.load_runtime_bundle("miduo_blue")
	_expect(DataStore.list_template_ids().has("miduo_blue"), "variant selectable in Creator Lab", errors)
	errors.append_array(DataStore.validate_runtime_bundle(source))
	errors.append_array(DataStore.validate_runtime_bundle(variant))
	_expect(str(source["template"]["template_id"]) == "miduo", "source identity", errors)
	_expect(str(variant["template"]["template_id"]) == "miduo_blue", "variant identity", errors)
	_expect(str(variant["template"]["sprite_set_ref"]) == "miduo_blue", "variant sprite set", errors)
	_expect(source["template"]["equipped_moves"].size() == variant["template"]["equipped_moves"].size(), "same action count", errors)
	for move_id in variant["template"]["equipped_moves"]:
		_expect(str(move_id).begins_with("miduo_blue_"), "variant-scoped move %s" % move_id, errors)
	var source_hp := int(source["template"]["hp"])
	var source_damage := int(source["moves"]["miduo_jab"]["damage"])
	variant["template"]["hp"] = 333
	variant["moves"]["miduo_blue_jab"]["damage"] = 77
	_expect(int(source["template"]["hp"]) == source_hp, "template edit isolation", errors)
	_expect(int(source["moves"]["miduo_jab"]["damage"]) == source_damage, "move edit isolation", errors)
	var generated := Generator.validate_generated(variant["sprite_set"])
	errors.append_array(generated["errors"])
	if errors.is_empty():
		print("miduo_recolor_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("miduo_recolor_smoke=FAIL")
		quit(1)


func _expect(condition: bool, message: String, errors: Array) -> void:
	if not condition:
		errors.append(message)
