extends SceneTree

const Runtime := preload("res://godot/scripts/prd_v0_3_runtime.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	var bundle := DataStore.load_runtime_bundle("combat_gray_s64")
	errors.append_array(DataStore.validate_runtime_bundle(bundle))

	var runtime := Runtime.new()
	errors.append_array(runtime.load_template("combat_gray_s64"))
	errors.append_array(_expect(runtime.current_state == "idle", "template starts in idle"))
	errors.append_array(_expect(runtime.current_move == "idle", "template starts with idle move"))
	errors.append_array(_expect(runtime.hurtboxes().has("hurt_head"), "hurtboxes exposed"))
	errors.append_array(_expect(runtime.foot_collision().has("center"), "foot collision exposed"))

	errors.append_array(_run_walk(runtime))
	errors.append_array(_run_dash(runtime))
	errors.append_array(_run_jump(runtime))
	errors.append_array(_run_basic_punch(runtime))
	errors.append_array(_run_hurt(runtime))
	errors.append_array(_run_debug_summary(runtime))

	if errors.is_empty():
		print("prd_v0_3_runtime_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("prd_v0_3_runtime_smoke=FAIL")
		quit(1)


func _run_walk(runtime: RefCounted) -> Array:
	var errors: Array = []
	errors.append_array(runtime.start_move("walk"))
	errors.append_array(_expect(runtime.current_state == "walk", "walk state context"))
	errors.append_array(_expect(runtime.velocity == Vector2(55, 0), "walk frame event sets velocity"))
	runtime.tick_frame()
	errors.append_array(_expect(runtime.current_frame == 1, "walk advances by frame"))
	return errors


func _run_dash(runtime: RefCounted) -> Array:
	var errors: Array = []
	errors.append_array(runtime.start_move("dash"))
	errors.append_array(_expect(runtime.current_state == "dash", "dash state context"))
	errors.append_array(_expect(runtime.velocity == Vector2(160, 0), "dash start velocity"))
	for i in 3:
		runtime.tick_frame()
	errors.append_array(_expect(runtime.current_frame == 3, "dash reaches final frame"))
	errors.append_array(_expect(runtime.velocity == Vector2.ZERO, "dash end velocity clears"))
	return errors


func _run_jump(runtime: RefCounted) -> Array:
	var errors: Array = []
	errors.append_array(runtime.start_move("jump"))
	errors.append_array(_expect(runtime.current_state == "jump", "jump state context"))
	errors.append_array(_expect(runtime.velocity == Vector2(0, -180), "jump velocity event"))
	for i in 5:
		runtime.tick_frame()
	errors.append_array(_expect(runtime.current_frame == 5, "jump reaches final frame"))
	errors.append_array(_expect(runtime.current_state == "idle", "jump returns to idle context"))
	return errors


func _run_basic_punch(runtime: RefCounted) -> Array:
	var errors: Array = []
	errors.append_array(runtime.start_move("basic_punch"))
	errors.append_array(_expect(runtime.current_move == "basic_punch", "combat move starts"))
	errors.append_array(_expect(runtime.current_frame == 0, "combat move starts at frame zero"))
	errors.append_array(_expect(runtime.active_hitboxes().is_empty(), "no hitbox before active frame"))
	for i in 3:
		runtime.tick_frame()
	errors.append_array(_expect(runtime.current_frame == 3, "combat move reaches active frame"))
	errors.append_array(_expect(runtime.active_hitboxes().size() == 1, "hitbox enabled on active frame"))
	var hitbox: Dictionary = runtime.active_hitboxes()[0]
	errors.append_array(_expect(str(hitbox["hitbox_id"]) == "hit_fist_1", "expected hitbox id"))
	errors.append_array(_expect(int(hitbox["damage"]) == 8, "expected damage"))
	for i in 2:
		runtime.tick_frame()
	errors.append_array(_expect(runtime.current_frame == 5, "combat move reaches hitstop frame"))
	errors.append_array(_expect(runtime.hitstop_frames == 3, "hitstop applied in frames"))
	runtime.tick_frame()
	errors.append_array(_expect(runtime.current_frame == 5, "hitstop freezes frame advance"))
	errors.append_array(_expect(runtime.hitstop_frames == 2, "hitstop counts down by frame"))
	errors.append_array(_expect(runtime.active_hitboxes().is_empty(), "hitstop freezes hitbox evaluation"))
	return errors


func _run_hurt(runtime: RefCounted) -> Array:
	var errors: Array = []
	errors.append_array(runtime.start_move("hurt"))
	errors.append_array(_expect(runtime.current_state == "hurt", "hurt reaction state context"))
	for i in 3:
		runtime.tick_frame()
	errors.append_array(_expect(runtime.current_frame == 3, "hurt reaches final frame"))
	errors.append_array(_expect(runtime.current_state == "idle", "hurt returns to idle context"))
	return errors


func _run_debug_summary(runtime: RefCounted) -> Array:
	var summary: Dictionary = runtime.debug_summary()
	var errors: Array = []
	for key in ["current_state", "current_move", "current_frame", "hitstop_frames", "active_hitboxes", "hurtboxes", "foot_collision", "sprite_set_ref"]:
		errors.append_array(_expect(summary.has(key), "debug summary exposes %s" % key))
	errors.append_array(_expect(typeof(summary["active_hitboxes"]) == TYPE_ARRAY, "debug summary exposes active_hitboxes array"))
	errors.append_array(_expect(typeof(summary["hurtboxes"]) == TYPE_DICTIONARY, "debug summary exposes hurtboxes dictionary"))
	return errors


func _expect(condition: bool, message: String) -> Array:
	if condition:
		return []
	return [message]
