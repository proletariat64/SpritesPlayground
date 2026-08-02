extends SceneTree

const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")
const FRAME_DELTA := 1.0 / 60.0
const PREVIEW_POSITION := Vector2.ZERO
const PREVIEW_ARENA_CENTER := Vector2.ZERO
const PREVIEW_ARENA_RADIUS := Vector2(100000.0, 100000.0)

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	playground.set_process(false)
	playground.set_physics_process(false)

	var panel: PanelContainer = PanelScript.new()
	root.add_child(panel)
	panel.setup()
	await process_frame
	panel.select_action("basic_punch")

	_expect(panel.has_method("preview_sprite"), "Creator Lab Panel exposes its isolated real preview sprite")
	_expect(panel.has_method("preview_observation"), "Creator Lab Panel exposes public real-preview observation")
	_expect(panel.has_method("authoring_draft_snapshot"), "Creator Lab Panel exposes a detached public Authoring Draft snapshot")
	if (
		not panel.has_method("preview_sprite")
		or not panel.has_method("preview_observation")
		or not panel.has_method("authoring_draft_snapshot")
	):
		_finish(playground, panel)
		return

	var preview_sprite: Node = panel.preview_sprite()
	var playable_sprite: Node = playground.player
	_configure_playable_oracle(playable_sprite, panel)
	panel.preview_reset()

	_expect(preview_sprite is CombatCharacter, "Creator Lab Preview is backed by a real CombatCharacter")
	_expect(
		_combat_character_count(panel.action_preview_control) + _combat_character_count(panel.floating_preview_control) == 1,
		"embedded and floating Preview surfaces contain exactly one CombatCharacter"
	)
	_expect(preview_sprite == panel.action_preview_control.real_sprite(), "embedded Preview observes the Panel real sprite")
	_expect(preview_sprite == panel.floating_preview_control.real_sprite(), "floating Preview observes the same real sprite")
	panel.set_preview_window_visible(true)
	_expect(panel.is_preview_window_visible(), "shared real Preview remains available in the floating window")
	_expect(panel.preview_sprite() == preview_sprite, "opening the floating window does not create another preview sprite")
	_expect(
		_combat_character_count(panel.action_preview_control) + _combat_character_count(panel.floating_preview_control) == 1,
		"opening the floating window still leaves one shared CombatCharacter"
	)

	var playground_characters: Array = playground.all_characters()
	var isolated_before := _playground_isolation_snapshot(playground_characters)
	_expect(not playground_characters.has(preview_sprite), "Preview sprite is not registered in Playground combat")
	_expect(preview_sprite.combat_target == null, "Preview sprite has no combat target")
	_expect(str(preview_sprite.control_mode) != "ai", "Preview sprite cannot run Playground AI")

	_assert_parity(panel, playable_sprite, "frame 0")
	var frame_zero: Dictionary = panel.preview_observation()
	_expect(str(frame_zero.get("state", "")) == "attack", "Preview starts through the live attack state")
	_expect(str(frame_zero.get("move", "")) == "basic_punch", "Preview starts the selected live Move")
	_expect(int(frame_zero.get("frame", -1)) == 0, "Preview begins on authored frame 0")
	_expect(str(frame_zero.get("animation", "")) == "basic_punch", "Preview uses the live basic_punch animation")
	_expect(frame_zero.get("hitboxes", []).is_empty(), "Preview startup frame 0 has no active hitbox")
	_expect(frame_zero.get("hurtboxes", []).size() == 3, "Preview startup exposes the live template hurtboxes")
	_expect(int(frame_zero.get("combat_facing", 0)) == 1, "Preview starts with east combat facing")
	_expect(not bool(frame_zero.get("completed", true)), "Preview Move is executing at frame 0")

	_advance_both(panel, playable_sprite, 2, "startup")
	var startup: Dictionary = panel.preview_observation()
	_expect(int(startup.get("frame", -1)) == 2, "public forward stepping reaches startup frame 2")
	_expect(startup.get("hitboxes", []).is_empty(), "startup frame 2 keeps the real hitbox disabled")

	_advance_both(panel, playable_sprite, 1, "active")
	var active: Dictionary = panel.preview_observation()
	_expect(int(active.get("frame", -1)) == 3, "public forward stepping reaches active frame 3")
	_expect(active.get("hitboxes", []).size() == 1, "active frame 3 exposes one real hitbox")
	if not active.get("hitboxes", []).is_empty():
		var active_hitbox: Dictionary = active["hitboxes"][0]
		_expect(str(active_hitbox.get("hitbox_id", "")) == "hit_fist_1", "active Preview exposes hit_fist_1")
		_expect(active_hitbox.get("rect", Rect2()) == Rect2(12, -48, 24, 14), "active Preview exposes the authored local hitbox rect")
	var live_active_frames := _live_active_frames(playable_sprite, panel.preview_frame_count())
	var exposed_active_frames: Array[int] = []
	for frame_index in panel.preview_frame_count():
		if panel.action_preview_control.frame_has_active_hitbox(frame_index):
			exposed_active_frames.append(frame_index)
	_expect(live_active_frames == [3, 4], "real reset/replay oracle observes active frames 3 and 4")
	_expect(
		exposed_active_frames == live_active_frames,
		"timeline exposes every live active frame while frame 3 is current (expected %s, got %s)"
			% [live_active_frames, exposed_active_frames]
	)
	_expect(panel.action_preview_control.frame_strip_active_index() == 3, "timeline keeps frame 3 marked current")
	_expect(
		panel.action_preview_control.frame_has_active_hitbox(3),
		"current-frame styling preserves frame 3's simultaneous active status"
	)
	_seek_live(playable_sprite, 3)
	_assert_parity(panel, playable_sprite, "active timeline oracle restore")

	_advance_both(panel, playable_sprite, 2, "authored frame 5")
	var hitstop_start: Dictionary = panel.preview_observation()
	_expect(int(hitstop_start.get("frame", -1)) == 5, "Preview reaches authored frame 5")
	_expect(hitstop_start.get("hitboxes", []).is_empty(), "frame 5 event disables the real hitbox before hitstop")
	_expect(int(preview_sprite.debug_summary().get("hitstop_frames", -1)) == 3, "Preview enters the authored three-frame hitstop")
	_expect(not panel.action_preview_control.frame_has_active_hitbox(5), "Preview surface has no hidden dictionary hitbox at live-disabled frame 5")

	for remaining in [2, 1, 0]:
		_advance_both(panel, playable_sprite, 1, "hitstop %d" % remaining)
		_expect(int(panel.preview_observation().get("frame", -1)) == 5, "real Preview hitstop holds frame 5 while %d frames remain" % remaining)
		_expect(int(preview_sprite.debug_summary().get("hitstop_frames", -1)) == remaining, "real Preview consumes hitstop frame %d" % remaining)

	_advance_both(panel, playable_sprite, 1, "recovery")
	var recovery: Dictionary = panel.preview_observation()
	_expect(int(recovery.get("frame", -1)) == 6, "Preview resumes on recovery frame 6")
	_expect(recovery.get("hitboxes", []).is_empty(), "recovery frame 6 keeps the hitbox disabled")

	_advance_both(panel, playable_sprite, 2, "completion")
	var completed: Dictionary = panel.preview_observation()
	_expect(bool(completed.get("completed", false)), "public forward stepping completes the real Move")
	_expect(str(completed.get("state", "")) == "idle", "completed Preview returns through the live idle state")
	_expect(str(completed.get("move", "")) == "idle", "completed Preview reports the live idle Move identity")

	panel.set_preview_frame(6)
	_seek_live(playable_sprite, 6)
	_assert_parity(panel, playable_sprite, "arbitrary seek to recovery frame 6")
	_expect(int(panel.preview_observation().get("frame", -1)) == 6, "arbitrary seek reset-replays through hitstop to frame 6")

	panel.preview_step_backward()
	_seek_live(playable_sprite, 5)
	_assert_parity(panel, playable_sprite, "backward step to frame 5")
	_expect(int(preview_sprite.debug_summary().get("hitstop_frames", -1)) == 3, "backward step rebuilds frame 5 hitstop from frame zero")

	panel.preview_first()
	_seek_live(playable_sprite, 0)
	_assert_parity(panel, playable_sprite, "First")
	_expect(int(panel.preview_observation().get("frame", -1)) == 0, "First reset-replays to frame 0")

	var last_frame: int = panel.preview_frame_count() - 1
	panel.preview_last()
	_seek_live(playable_sprite, last_frame)
	_assert_parity(panel, playable_sprite, "Last")
	_expect(int(panel.preview_observation().get("frame", -1)) == last_frame, "Last reset-replays to the final authored frame")

	panel.preview_reset()
	_seek_live(playable_sprite, 0)
	_assert_parity(panel, playable_sprite, "Reset")
	_expect(int(panel.preview_observation().get("frame", -1)) == 0, "Reset restores the real Move to frame 0")

	panel.set_preview_frame(999)
	_seek_live(playable_sprite, last_frame)
	_assert_parity(panel, playable_sprite, "high seek clamp")
	panel.set_preview_frame(-10)
	_seek_live(playable_sprite, 0)
	_assert_parity(panel, playable_sprite, "low seek clamp")
	await _assert_public_playback_controls(panel)

	_expect(
		panel.floating_preview_control.observation() == panel.preview_observation(),
		"embedded and floating surfaces expose one shared real observation"
	)
	_expect(
		_playground_isolation_snapshot(playground_characters) == isolated_before,
		"Preview play, step, back, first/last, reset, and seek do not alter Playground sprites"
	)
	_expect(preview_sprite.combat_target == null, "Preview controls never assign a Playground target")
	_expect(not playground.all_characters().has(preview_sprite), "Preview remains outside Playground combat after all controls")

	_finish(playground, panel)


func _configure_playable_oracle(playable_sprite: Node, panel: PanelContainer) -> void:
	var draft_snapshot: Dictionary = panel.authoring_draft_snapshot()
	var bundle: Dictionary = draft_snapshot.get("bundle", {})
	playable_sprite.is_test_dummy = true
	playable_sprite.apply_v0_3_runtime_bundle(
		bundle.get("template", {}),
		bundle.get("sprite_set", {}),
		bundle.get("moves", {})
	)
	playable_sprite.reset_runtime(PREVIEW_POSITION)
	playable_sprite.set_combat_target(null)
	playable_sprite.state_machine.facing = 1
	_expect(playable_sprite.request_attack("basic_punch"), "real Playground sprite starts basic_punch")
	playable_sprite.tick_character(0.0, PREVIEW_ARENA_CENTER, PREVIEW_ARENA_RADIUS)


func _advance_both(panel: PanelContainer, playable_sprite: Node, count: int, label: String) -> void:
	for index in count:
		playable_sprite.tick_character(FRAME_DELTA, PREVIEW_ARENA_CENTER, PREVIEW_ARENA_RADIUS)
		panel.preview_step_forward()
		_assert_parity(panel, playable_sprite, "%s step %d" % [label, index + 1])


func _seek_live(sprite: Node, target_frame: int) -> void:
	sprite.reset_runtime(PREVIEW_POSITION)
	sprite.set_combat_target(null)
	sprite.state_machine.facing = 1
	_expect(sprite.request_attack("basic_punch"), "live seek restarts basic_punch")
	sprite.tick_character(0.0, PREVIEW_ARENA_CENTER, PREVIEW_ARENA_RADIUS)
	var guard := 0
	while (
		sprite.move_executor.is_executing()
		and int(sprite.debug_summary().get("frame", 0)) < target_frame
		and guard < 128
	):
		sprite.tick_character(FRAME_DELTA, PREVIEW_ARENA_CENTER, PREVIEW_ARENA_RADIUS)
		guard += 1
	_expect(guard < 128, "live seek reaches requested frame %d" % target_frame)


func _live_active_frames(sprite: Node, frame_count: int) -> Array[int]:
	var active_frames: Array[int] = []
	for target_frame in frame_count:
		_seek_live(sprite, target_frame)
		if not sprite.active_hitboxes_world().is_empty():
			active_frames.append(target_frame)
	return active_frames


func _assert_public_playback_controls(panel: PanelContainer) -> void:
	var previous_max_fps := Engine.max_fps
	Engine.max_fps = 60
	await process_frame

	panel.preview_reset()
	panel.set_preview_speed(1.0)
	panel.preview_play()
	_expect(panel.preview_playing, "public Play enters the playing state at 1.0x")
	await create_timer(0.1).timeout
	panel.preview_pause()
	var one_x_observation: Dictionary = panel.preview_observation()
	var one_x_frame := int(one_x_observation.get("frame", -1))
	_expect(one_x_frame > 0, "1.0x Play advances the real Preview from frame 0 over elapsed time")
	_expect(not panel.preview_playing, "public Pause leaves the 1.0x Preview paused")

	panel.preview_reset()
	panel.set_preview_speed(0.5)
	panel.preview_play()
	_expect(panel.preview_playing, "public Play enters the playing state at 0.5x")
	await create_timer(0.1).timeout
	panel.preview_pause()
	var half_x_observation: Dictionary = panel.preview_observation()
	var half_x_frame := int(half_x_observation.get("frame", -1))
	_expect(half_x_frame > 0, "0.5x Play advances the real Preview from frame 0 over elapsed time")
	_expect(
		half_x_frame < one_x_frame,
		"0.5x advances fewer authored frames than 1.0x over equal elapsed time (1.0x=%d, 0.5x=%d)"
			% [one_x_frame, half_x_frame]
	)
	_expect(not panel.preview_playing, "public Pause leaves the 0.5x Preview paused")

	var paused_observation: Dictionary = panel.preview_observation().duplicate(true)
	await create_timer(0.05).timeout
	_expect(
		panel.preview_observation() == paused_observation,
		"Pause freezes the real Preview observation over elapsed process time"
	)
	Engine.max_fps = previous_max_fps


func _assert_parity(panel: PanelContainer, playable_sprite: Node, label: String) -> void:
	var preview_observation: Dictionary = panel.preview_observation()
	var playable_observation := _observe(playable_sprite)
	_expect(
		preview_observation == playable_observation,
		"%s parity\npreview=%s\nplayable=%s" % [label, preview_observation, playable_observation]
	)


func _observe(sprite: Node) -> Dictionary:
	var summary: Dictionary = sprite.debug_summary()
	return {
		"state": str(summary.get("state", "")),
		"move": str(summary.get("move", "")),
		"frame": int(summary.get("frame", 0)),
		"animation": str(sprite.animated_sprite.animation),
		"animation_frame": int(sprite.animated_sprite.frame),
		"hitboxes": _local_boxes(sprite.active_hitboxes_world(), sprite.global_position),
		"hurtboxes": _local_boxes(sprite.hurtboxes_world(), sprite.global_position),
		"combat_facing": int(sprite.state_machine.facing),
		"completed": not sprite.move_executor.is_executing(),
	}


func _local_boxes(boxes: Array, origin: Vector2) -> Array:
	var result: Array = []
	for entry in boxes:
		var rect: Rect2 = entry.get("rect", Rect2())
		var normalized: Dictionary = entry.duplicate(true)
		normalized["rect"] = Rect2(rect.position - origin, rect.size)
		result.append(normalized)
	return result


func _combat_character_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is CombatCharacter else 0
	for child in node.get_children():
		count += _combat_character_count(child)
	return count


func _playground_isolation_snapshot(characters: Array) -> Array:
	var snapshot: Array = []
	for character in characters:
		snapshot.append({
			"instance_id": str(character.instance_id),
			"hp": int(character.current_hp),
			"position": character.position,
			"target_id": str(character.combat_target.instance_id) if character.combat_target != null else "",
		})
	return snapshot


func _finish(playground: Node, panel: PanelContainer) -> void:
	panel.set_preview_window_visible(false)
	panel.free()
	playground.free()
	if _errors.is_empty():
		print("creator_lab_real_preview_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_real_preview_smoke=FAIL")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
