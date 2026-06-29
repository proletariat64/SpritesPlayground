extends SceneTree

const RebuildData = preload("res://godot/scripts/rebuild_data.gd")
const RebuildValidator = preload("res://godot/scripts/rebuild_validator.gd")
const RebuildInput = preload("res://godot/scripts/rebuild_input.gd")


func _init() -> void:
	RebuildInput.ensure_actions()
	var failures: Array[String] = []
	var source_report = RebuildValidator.validate_all_sources()
	if not bool(source_report.get("ok", false)):
		failures.append("source validation failed:\n%s" % RebuildValidator.report_to_text(source_report))

	var round_trip = _check_round_trip("adam")
	if round_trip != "":
		failures.append(round_trip)

	var playground_scene = load("res://godot/scenes/Playground.tscn")
	if playground_scene == null:
		failures.append("Playground.tscn failed to load")
	else:
		var playground = playground_scene.instantiate()
		root.add_child(playground)
		await process_frame
		await physics_frame
		var result = playground.smoke_attack_sequence()
		if int(result.get("cain_hp", 999)) >= 30:
			failures.append("Cain HP did not decrease in smoke attack: %s" % str(result))
		if str(result.get("cain_state", "")) != "dead":
			failures.append("Cain did not reach dead after smoke attack: %s" % str(result))
		if playground.adam.blackboard.limbo_status.begins_with("missing"):
			failures.append("LimboAI missing: %s" % playground.adam.blackboard.limbo_status)
		playground.queue_free()

	if failures.is_empty():
		print("M1_SMOKE_PASS")
		quit(0)
	else:
		print("M1_SMOKE_FAIL")
		for failure in failures:
			print(failure)
		quit(1)


func _check_round_trip(character_id: String) -> String:
	var path = RebuildData.character_path(character_id)
	var loaded = RebuildData.load_json(path)
	if loaded.has("_error"):
		return loaded["_error"]
	var text = RebuildData.pretty_json(loaded)
	var parsed = RebuildData.parse_json_text(text)
	if parsed.has("_error"):
		return "round-trip parse failed: %s" % parsed["_error"]
	if RebuildData.pretty_json(parsed) != text:
		return "round-trip JSON drift for %s" % character_id
	return ""
