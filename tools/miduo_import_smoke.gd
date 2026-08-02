extends SceneTree

# Issue #32 public-seam smoke: the deterministic Eden import result is one saved
# character consumed by both Creator Lab and Playground, with Eden provenance and
# honest uppercut reporting.

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Generator := preload("res://godot/scripts/spriteframes_generator.gd")
const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")

const REPORT_PATH := "res://data/imports/miduo/import_report.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	errors.append_array(_run_report_smoke())
	errors.append_array(_run_bundle_smoke())
	errors.append_array(await _run_playground_smoke())

	if errors.is_empty():
		print("miduo_import_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("miduo_import_smoke=FAIL")
		quit(1)


func _run_report_smoke() -> Array:
	var errors: Array = []
	var report := _read_json(REPORT_PATH)
	errors.append_array(_expect(not report.is_empty(), "import report exists"))
	if report.is_empty():
		return errors
	var accounting: Dictionary = report.get("source_accounting", {})
	errors.append_array(_expect(int(accounting.get("behavior_count", 0)) == 31, "report accounts 31 behaviors"))
	errors.append_array(_expect(int(accounting.get("direction_unit_count", 0)) == 116, "report accounts 116 direction units"))
	errors.append_array(_expect(int(accounting.get("frame_count", 0)) == 476, "report accounts 476 frames"))
	errors.append_array(_expect(report.get("imported", []).size() == 31, "report imports every supplied behavior"))
	var first: Dictionary = report.get("imported", [{}])[0]
	errors.append_array(_expect(str(first.get("eden_behavior_id", "")).begins_with("bhv_"), "imported rows preserve Eden behavior ids"))
	errors.append_array(_expect(report.get("missing", []).has("uppercut"), "uppercut reported missing"))
	errors.append_array(_expect(report.get("unequipped", []).has("uppercut"), "uppercut reported unequipped"))
	errors.append_array(_expect(not report.get("equipped_moves", []).has("miduo_uppercut"), "uppercut not equipped"))
	errors.append_array(_expect(report.get("unresolved", []).is_empty(), "no unresolved items for the known package"))
	return errors


func _run_bundle_smoke() -> Array:
	var errors: Array = []
	var bundle := DataStore.load_runtime_bundle("miduo")
	errors.append_array(DataStore.validate_runtime_bundle(bundle))
	errors.append_array(_expect(not bundle.is_empty(), "miduo v0.3 bundle loads"))
	if bundle.is_empty():
		return errors
	var template: Dictionary = bundle["template"]
	errors.append_array(_expect(str(template.get("sprite_set_ref", "")) == "miduo", "template references miduo sprite set"))
	errors.append_array(_expect(template.get("equipped_moves", []).has("miduo_jab"), "template equips miduo_jab"))
	errors.append_array(_expect(not template.get("equipped_moves", []).has("miduo_uppercut"), "template leaves uppercut unequipped"))
	var validation := Generator.validate_generated(bundle["sprite_set"], "", {"moves": bundle["moves"]})
	for error in validation.get("errors", []):
		errors.append(str(error))
	errors.append_array(_expect(FileAccess.file_exists(Generator.sprite_frames_path("miduo")), "miduo SpriteFrames resource exists"))
	return errors


func _run_playground_smoke() -> Array:
	var errors: Array = []
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame

	var player: Node2D = playground.player
	errors.append_array(_expect(str(player.template_id) == "miduo", "playground player is imported miduo"))
	errors.append_array(_expect(str(player.sprite_set_id) == "miduo", "player uses miduo sprite set"))
	errors.append_array(_expect(player.has_spriteframes_playback(), "player has SpriteFrames playback"))
	errors.append_array(_expect(str(player.animated_sprite.animation) == "idle_e", "player boots onto idle_e (got %s)" % player.animated_sprite.animation))

	# Explicit runtime alias: bare move request resolves to the scoped equipped id.
	var started: bool = player.request_attack("jab")
	errors.append_array(_expect(started, "jab request starts scoped miduo_jab"))
	errors.append_array(_expect(str(player.state_machine.current_move) == "miduo_jab", "runtime move id stays scoped (got %s)" % player.state_machine.current_move))
	await physics_frame
	errors.append_array(_expect(str(player.animated_sprite.animation) == "jab", "attack plays imported jab clip (got %s)" % player.animated_sprite.animation))
	while player.move_executor.is_executing():
		await physics_frame
	errors.append_array(_expect(str(player.state_machine.current_state) == "idle", "attack finishes back to idle"))

	# Unequipped uppercut never blocks or substitutes: requesting it is a safe no-op.
	errors.append_array(_expect(not player.request_attack("uppercut"), "unequipped uppercut is a safe no-op"))
	errors.append_array(_expect(str(player.state_machine.current_state) == "idle", "unequipped uppercut does not change state"))

	# Same saved character result is consumable by Creator Lab.
	playground.select_player_character()
	var panel: Node = playground.creator_lab
	errors.append_array(_expect(str(panel.bound_template_id) == "miduo", "creator lab binds miduo"))
	var draft_snapshot: Dictionary = panel.authoring_draft_snapshot()
	var authored_bundle: Dictionary = draft_snapshot.get("bundle", {})
	var authored_template: Dictionary = authored_bundle.get("template", {})
	errors.append_array(_expect(str(authored_template.get("template_id", "")) == "miduo", "creator lab loads miduo template"))
	errors.append_array(_expect(int(authored_template.get("hp", 0)) == 100, "creator lab sees imported default hp"))

	playground.free()
	return errors


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _expect(condition: bool, message: String) -> Array:
	if condition:
		return []
	return [message]
