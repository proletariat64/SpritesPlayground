extends SceneTree

const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")
const DT := 1.0 / 60.0
const ARENA_CENTER := Vector2(320, 205)
const ARENA_RADIUS := Vector2(280, 125)

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var character := CombatCharacterScript.new()
	character.template_id = "miduo"
	character.instance_id = "presentation_smoke"
	character.is_test_dummy = true
	root.add_child(character)
	await process_frame

	_slice_jump_phases(character, "jump")
	_slice_jump_phases(character, "big_jump")
	_slice_airborne_kick_continuity(character)
	_slice_knockdown_recovery(character)
	_slice_combat_idle_and_disengagement(character)
	await _slice_legacy_without_fight_idle_remains_visible()
	_slice_honest_death(character)
	_slice_two_facing_and_missing(character)
	character.free()

	if _errors.is_empty():
		print("action_presentation_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("action_presentation_smoke=FAIL")
		quit(1)


func _slice_jump_phases(character: Node, mode: String) -> void:
	character.reset_runtime(Vector2(245, 245))
	_expect(character.state_machine.request_action(mode), "%s starts" % mode)
	_tick(character, 1)
	_expect(character.state_machine.jump_phase == "start", "%s starts with takeoff" % mode)
	_expect(str(character.animated_sprite.animation) == "eden_%s_start_e" % mode, "%s uses its start art" % mode)
	_tick(character, 18)
	_expect(character.state_machine.jump_phase == "air", "%s reaches airborne phase" % mode)
	_expect(str(character.animated_sprite.animation) == "eden_%s_air_e" % mode, "%s uses its airborne art" % mode)
	_tick(character, 22)
	_expect(character.state_machine.jump_phase == "land", "%s reaches landing phase" % mode)
	var landing_animation := "eden_land_e" if mode == "jump" else "eden_big_jump_land_e"
	_expect(str(character.animated_sprite.animation) == landing_animation, "%s uses its landing art" % mode)
	_tick(character, 24)
	_expect(character.state_machine.current_state == "idle", "%s completes to idle" % mode)


func _slice_airborne_kick_continuity(character: Node) -> void:
	character.reset_runtime(Vector2(245, 245))
	_expect(character.state_machine.request_action("jump"), "airborne kick setup starts jump")
	_tick(character, 18)
	var airborne_offset := float(character.state_machine.visual_jump_offset)
	_expect(airborne_offset < -1.0, "airborne kick setup reaches visible height")
	_expect(character.request_attack("flying_kick", true), "airborne flying_kick starts")
	_tick(character, 1)
	_expect(character.state_machine.current_state == "attack", "flying_kick enters attack state")
	_expect(character.state_machine.visual_jump_offset < -1.0, "flying_kick does not snap to ground")
	_expect(is_equal_approx(character.state_machine.visual_jump_offset, airborne_offset), "flying_kick preserves its initial airborne offset")
	_tick(character, 20)
	_expect(character.state_machine.current_state == "idle", "flying_kick completes to idle")
	_expect(is_zero_approx(character.state_machine.visual_jump_offset), "flying_kick returns smoothly to ground")


func _slice_knockdown_recovery(character: Node) -> void:
	character.reset_runtime(Vector2(245, 245))
	character.take_hit(14, "hit_roundhouse", "attacker")
	_tick(character, 1)
	_expect(character.state_machine.current_state == "hurt", "nonlethal heavy hit enters reaction state")
	_expect(character.state_machine.reaction_phase == "fall_down", "knockdown starts falling")
	_expect(str(character.animated_sprite.animation) == "eden_fall_down_e", "knockdown uses fall_down art")
	_tick(character, 32)
	_expect(character.state_machine.reaction_phase == "down", "knockdown reaches down hold")
	_expect(str(character.animated_sprite.animation) == "eden_down_e", "knockdown uses down art")
	_tick(character, 32)
	_expect(character.state_machine.reaction_phase == "get_up", "nonlethal knockdown gets up")
	_expect(str(character.animated_sprite.animation) == "eden_get_up_e", "recovery uses get_up art")
	_tick(character, 30)
	_expect(character.state_machine.current_state == "idle", "nonlethal knockdown recovers")


func _slice_combat_idle_and_disengagement(character: Node) -> void:
	character.reset_runtime(Vector2(245, 245))
	_expect(character.request_attack("jab"), "jab engages combat context")
	_tick(character, 12)
	_expect(character.state_machine.current_state == "idle", "jab returns to idle state")
	_expect(str(character.animated_sprite.animation) == "fight_idle", "engaged idle uses combat idle")
	_tick(character, 130)
	_expect(str(character.animated_sprite.animation) == "idle_e", "disengagement returns to normal idle")


func _slice_legacy_without_fight_idle_remains_visible() -> void:
	var legacy := CombatCharacterScript.new()
	legacy.template_id = "skeleton_default_unarmed_s64"
	legacy.instance_id = "legacy_combat_idle_smoke"
	legacy.is_test_dummy = true
	root.add_child(legacy)
	await process_frame
	legacy.mark_combat_engaged()
	_tick(legacy, 1)
	_expect(legacy.animated_sprite.visible, "legacy character without fight_idle remains visible")
	_expect(str(legacy.animated_sprite.animation) == "idle", "legacy character stays on its authored idle art")
	legacy.free()


func _slice_honest_death(character: Node) -> void:
	character.reset_runtime(Vector2(245, 245))
	character.take_hit(character.max_hp, "hit_lethal", "attacker")
	_tick(character, 1)
	_expect(character.state_machine.current_state == "dead", "lethal hit enters dead state")
	_expect(character.state_machine.death_phase == "fall_down", "death honestly starts with fall_down")
	_expect(str(character.animated_sprite.animation) == "eden_fall_down_e", "death uses imported fall_down art")
	_tick(character, 40)
	_expect(character.state_machine.death_phase == "down", "death reaches down hold")
	_expect(str(character.animated_sprite.animation) == "eden_down_e", "death holds imported down pose")
	_tick(character, 180)
	_expect(character.state_machine.current_state == "dead", "death remains dead")
	_expect(str(character.animated_sprite.animation) == "eden_down_e", "death remains in down pose")


func _slice_two_facing_and_missing(character: Node) -> void:
	character.reset_runtime(Vector2(245, 245))
	character.state_machine.facing = -1
	_expect(character.request_attack("jab"), "west jab starts")
	_tick(character, 1)
	_expect(str(character.animated_sprite.animation) == "jab_w", "combat presentation selects west-authored art")
	_expect(not character.animated_sprite.flip_h, "west-authored art is not flipped")
	character.reset_runtime(Vector2(245, 245))
	var resolved: Dictionary = character._resolve_visual_animation(character.animated_sprite.sprite_frames, "uppercut")
	_expect(resolved.is_empty(), "missing unequipped uppercut has no unrelated visual substitute")


func _tick(character: Node, count: int) -> void:
	for _index in count:
		character.tick_character(DT, ARENA_CENTER, ARENA_RADIUS)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
