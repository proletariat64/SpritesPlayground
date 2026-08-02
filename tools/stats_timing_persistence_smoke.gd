extends SceneTree

const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")

const TEMPLATE_ID := "miduo"
const MOVE_ID := "miduo_jab"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	var original_template := DataStore.load_template(TEMPLATE_ID).duplicate(true)
	var original_move := DataStore.load_move(MOVE_ID).duplicate(true)
	var backups := {}
	backups[DataStore.template_path(TEMPLATE_ID)] = _read_text(DataStore.template_path(TEMPLATE_ID))
	backups[DataStore.sprite_set_path(str(original_template["sprite_set_ref"]))] = _read_text(DataStore.sprite_set_path(str(original_template["sprite_set_ref"])))
	for move_id in original_template["equipped_moves"]:
		backups[DataStore.move_path(str(move_id))] = _read_text(DataStore.move_path(str(move_id)))

	var panel: PanelContainer = PanelScript.new()
	root.add_child(panel)
	panel.setup()
	await process_frame
	panel.load_template_id(TEMPLATE_ID)
	panel.set_hp(140)
	panel.set_movement_speeds(80.0, 220.0)
	panel.select_move(MOVE_ID)
	panel.set_move_scalar("damage", 17)
	panel.set_move_rhythm(2, 3, 4)
	panel.save_all()

	var saved_template := DataStore.load_template(TEMPLATE_ID)
	var saved_move := DataStore.load_move(MOVE_ID)
	errors.append_array(_expect(int(saved_template.get("hp", 0)) == 140, "HP persists exactly"))
	errors.append_array(_expect(float(saved_template.get("walk_speed", 0.0)) == 80.0, "walk speed persists exactly"))
	errors.append_array(_expect(float(saved_template.get("run_speed", 0.0)) == 220.0, "run speed persists exactly"))
	errors.append_array(_expect(int(saved_move.get("damage", 0)) == 17, "move power persists exactly"))
	errors.append_array(_expect(int(saved_move.get("startup_frames", -1)) == 2, "startup persists exactly"))
	errors.append_array(_expect(int(saved_move.get("active_frames", -1)) == 3, "active persists exactly"))
	errors.append_array(_expect(int(saved_move.get("recovery_frames", -1)) == 4, "recovery persists exactly"))
	errors.append_array(_expect(int(saved_move.get("frame_count", 0)) == int(original_move.get("frame_count", 0)), "explicit rhythm preserves authored frame_count"))

	var loaded_bundle := DataStore.load_runtime_bundle(TEMPLATE_ID)
	var tuned: Node = await _spawn_character("tuned")
	tuned.apply_v0_3_runtime_bundle(loaded_bundle["template"], loaded_bundle["sprite_set"], loaded_bundle["moves"])
	tuned.reset_runtime(Vector2.ZERO)
	errors.append_array(_expect(tuned.max_hp == 140 and tuned.current_hp == 140, "next attempt applies persisted HP"))
	tuned.take_hit(120, "probe", "test")
	errors.append_array(_expect(tuned.current_hp == 20, "HP edit measurably changes survival"))

	var slow_bundle: Dictionary = loaded_bundle.duplicate(true)
	slow_bundle["template"]["run_speed"] = 80.0
	var slow: Node = await _spawn_character("slow")
	slow.apply_v0_3_runtime_bundle(slow_bundle["template"], slow_bundle["sprite_set"], slow_bundle["moves"])
	slow.reset_runtime(Vector2.ZERO)
	tuned.reset_runtime(Vector2.ZERO)
	for _frame in 30:
		slow.state_machine.tick(1.0 / 60.0, Vector2.RIGHT, true)
		tuned.state_machine.tick(1.0 / 60.0, Vector2.RIGHT, true)
		slow.position += slow.state_machine.velocity * (1.0 / 60.0)
		tuned.position += tuned.state_machine.velocity * (1.0 / 60.0)
	errors.append_array(_expect(tuned.position.x > slow.position.x + 50.0, "identical input duration yields tuned run displacement"))

	var target: Node = await _spawn_character("target")
	target.reset_runtime(Vector2.ZERO)
	var hp_before: int = target.current_hp

	tuned.reset_runtime(Vector2.ZERO)
	errors.append_array(_expect(tuned.request_attack("jab"), "tuned move starts"))
	errors.append_array(_expect(tuned.move_executor.active_hitboxes_local().is_empty(), "startup frame 0 is inactive"))
	tuned.move_executor.tick()
	var active_hitboxes: Array = tuned.move_executor.active_hitboxes_local()
	errors.append_array(_expect(active_hitboxes.size() == 1, "authored enable event opens the hitbox on frame 1"))
	if not active_hitboxes.is_empty():
		target.take_hit(int(active_hitboxes[0]["damage"]), str(active_hitboxes[0]["hitbox_id"]), "tuned")
	errors.append_array(_expect(hp_before - target.current_hp == 17, "persisted move power changes runtime HP delta"))
	tuned.move_executor.tick()
	errors.append_array(_expect(tuned.move_executor.current_frame() == 2, "authored disable and hitstop events execute on frame 2"))
	errors.append_array(_expect(tuned.move_executor.active_hitboxes_local().is_empty(), "hitstop freezes hitbox evaluation"))
	for remaining in [2, 1, 0]:
		tuned.move_executor.tick()
		errors.append_array(_expect(tuned.move_executor.current_frame() == 2, "persisted three-frame hitstop freezes timing while %d remain" % remaining))
	for _frame in 6:
		tuned.move_executor.tick()
	errors.append_array(_expect(tuned.move_executor.is_executing(), "move remains locked through authored recovery"))
	tuned.move_executor.tick()
	errors.append_array(_expect(not tuned.move_executor.is_executing(), "move finishes after timing resumes from hitstop"))

	for path in backups.keys():
		_write_text(str(path), str(backups[path]))
	panel.queue_free()
	slow.queue_free()
	tuned.queue_free()
	target.queue_free()

	if errors.is_empty():
		print("stats_timing_persistence_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("stats_timing_persistence_smoke=FAIL")
		quit(1)


func _spawn_character(id: String):
	var character = CombatCharacterScript.new()
	character.instance_id = id
	character.template_id = "miduo"
	root.add_child(character)
	await process_frame
	return character


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text()


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)


func _expect(condition: bool, label: String) -> Array:
	return [] if condition else [label]
