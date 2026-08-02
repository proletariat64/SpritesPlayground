extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const DocumentRules := preload("res://godot/scripts/prd_v0_3_document_rules.gd")

const TEMPLATE_ID := "combat_gray_s64"
const TEMP_ROOT := "user://authored_data_persistence_smoke"
const INVALID_ROOT := "user://authored_data_persistence_smoke_invalid"
const BLOCKED_ROOT := "user://authored_data_persistence_smoke_blocked"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	_remove_tree(TEMP_ROOT)
	_remove_tree(INVALID_ROOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BLOCKED_ROOT))

	var live_bundle := DataStore.load_runtime_bundle(TEMPLATE_ID)
	var live_snapshot := _live_file_snapshot(live_bundle)
	errors.append_array(_expect(DocumentRules.validate_runtime_bundle(live_bundle).is_empty(), "document rules validate without Creator Lab Panel"))

	var authored_bundle: Dictionary = live_bundle.duplicate(true)
	authored_bundle["template"]["hp"] = 111.0
	for move_id in authored_bundle["moves"].keys():
		authored_bundle["moves"][move_id]["damage"] = float(authored_bundle["moves"][move_id].get("damage", 0))
	var normalized := DocumentRules.normalize_runtime_bundle(authored_bundle)
	errors.append_array(_expect(typeof(normalized["template"]["hp"]) == TYPE_INT, "document rules normalize template integers"))
	for move_id in normalized["moves"].keys():
		errors.append_array(_expect(typeof(normalized["moves"][move_id]["damage"]) == TYPE_INT, "document rules normalize move integers"))

	var save_errors := DataStore.save_runtime_bundle(authored_bundle, TEMP_ROOT)
	errors.append_array(_expect(save_errors.is_empty(), "complete bundle saves through the production file store"))
	var reloaded := DataStore.load_runtime_bundle(TEMPLATE_ID, TEMP_ROOT)
	errors.append_array(_expect(DocumentRules.validate_runtime_bundle(reloaded).is_empty(), "reloaded temporary bundle validates"))
	var normalized_reloaded := DocumentRules.normalize_runtime_bundle(reloaded)
	var round_trip_difference := _first_difference(normalized, normalized_reloaded)
	errors.append_array(_expect(round_trip_difference.is_empty(), "complete bundle reloads exactly after normalization: %s" % round_trip_difference))

	var invalid_bundle: Dictionary = live_bundle.duplicate(true)
	invalid_bundle["template"]["hp"] = 0
	var invalid_errors := DataStore.save_runtime_bundle(invalid_bundle, INVALID_ROOT)
	errors.append_array(_expect(not invalid_errors.is_empty(), "invalid bundle save reports document diagnostics"))
	errors.append_array(_expect(not FileAccess.file_exists(DataStore.template_path(TEMPLATE_ID, INVALID_ROOT)), "invalid bundle writes no template"))
	var blocker := FileAccess.open(BLOCKED_ROOT, FileAccess.WRITE)
	if blocker != null:
		blocker.store_string("blocks creation of child data directories")
		blocker = null
	var write_errors := DataStore.save_runtime_bundle(live_bundle, BLOCKED_ROOT)
	errors.append_array(_expect(not write_errors.is_empty(), "filesystem write failure is reported to the caller"))
	errors.append_array(_expect(_live_file_snapshot(live_bundle) == live_snapshot, "successful and failing saves leave live data unchanged"))

	_remove_tree(TEMP_ROOT)
	_remove_tree(INVALID_ROOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BLOCKED_ROOT))
	errors.append_array(_expect(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEMP_ROOT)), "successful fixture cleans up"))
	errors.append_array(_expect(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(INVALID_ROOT)), "failing fixture cleans up independently"))
	errors.append_array(_expect(not FileAccess.file_exists(BLOCKED_ROOT), "write-failure fixture cleans up independently"))

	if errors.is_empty():
		print("authored_data_persistence_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("authored_data_persistence_smoke=FAIL")
		quit(1)


func _live_file_snapshot(bundle: Dictionary) -> Dictionary:
	var snapshot := {}
	var template: Dictionary = bundle["template"]
	var template_path := DataStore.template_path(str(template["template_id"]))
	var sprite_set_path := DataStore.sprite_set_path(str(template["sprite_set_ref"]))
	snapshot[template_path] = FileAccess.get_file_as_string(template_path)
	snapshot[sprite_set_path] = FileAccess.get_file_as_string(sprite_set_path)
	for move_id in template["equipped_moves"]:
		var move_path := DataStore.move_path(str(move_id))
		snapshot[move_path] = FileAccess.get_file_as_string(move_path)
	return snapshot


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		if dir.current_is_dir():
			_remove_tree(path.path_join(entry))
		else:
			dir.remove(entry)
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, label: String) -> Array:
	return [] if condition else [label]


func _first_difference(expected, actual, path: String = "bundle") -> String:
	if typeof(expected) != typeof(actual):
		return "%s type %d != %d (%s != %s)" % [path, typeof(expected), typeof(actual), expected, actual]
	if typeof(expected) == TYPE_DICTIONARY:
		if expected.keys().size() != actual.keys().size():
			return "%s keys %s != %s" % [path, expected.keys(), actual.keys()]
		for key in expected.keys():
			if not actual.has(key):
				return "%s missing key %s" % [path, key]
			var difference := _first_difference(expected[key], actual[key], "%s.%s" % [path, key])
			if not difference.is_empty():
				return difference
	elif typeof(expected) == TYPE_ARRAY:
		if expected.size() != actual.size():
			return "%s size %d != %d" % [path, expected.size(), actual.size()]
		for index in expected.size():
			var difference := _first_difference(expected[index], actual[index], "%s[%d]" % [path, index])
			if not difference.is_empty():
				return difference
	elif expected != actual:
		return "%s %s != %s" % [path, expected, actual]
	return ""
