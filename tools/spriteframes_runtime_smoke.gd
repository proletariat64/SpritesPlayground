extends SceneTree

const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Generator := preload("res://godot/scripts/spriteframes_generator.gd")

const SKELETON_ID := "skeleton_default_unarmed_s64"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	var bundle := DataStore.load_runtime_bundle(SKELETON_ID)
	var generation: Dictionary = Generator.generate(bundle["sprite_set"], {"moves": bundle["moves"]})
	errors.append_array(_expect(bool(generation.get("ok", false)), "generates skeleton SpriteFrames for runtime"))

	var character: Node2D = CombatCharacterScript.new()
	character.instance_id = "spriteframes_runtime_smoke"
	character.is_test_dummy = true
	root.add_child(character)
	await process_frame
	character.apply_v0_3_runtime_bundle(bundle["template"], bundle["sprite_set"], bundle["moves"])
	await process_frame

	errors.append_array(_expect(character.has_method("has_spriteframes_playback"), "character exposes playback probe"))
	errors.append_array(_expect(bool(character.has_spriteframes_playback()), "character has SpriteFrames playback"))
	var sprite: AnimatedSprite2D = character.get_node_or_null("animated_sprite")
	errors.append_array(_expect(sprite != null, "character owns AnimatedSprite2D"))
	if sprite != null:
		errors.append_array(_expect(sprite.sprite_frames != null, "AnimatedSprite2D has sprite_frames"))
		errors.append_array(_expect(str(sprite.animation) == "idle", "AnimatedSprite2D starts idle"))
		character.state_machine.current_state = "walk"
		character.state_machine.current_move = "walk"
		character._sync_visual_animation()
		errors.append_array(_expect(str(sprite.animation) == "walk", "AnimatedSprite2D maps walk state"))
		character.move_executor.start_attack_intent("basic_punch")
		character._sync_visual_animation()
		errors.append_array(_expect(str(sprite.animation) == "basic_punch", "AnimatedSprite2D maps basic_punch"))
		errors.append_array(_expect(int(sprite.frame) == int(character.move_executor.current_frame()), "attack frame starts in parity"))
		character.tick_character(1.0 / 60.0, Vector2.ZERO, Vector2(999, 999))
		errors.append_array(_expect(str(sprite.animation) == "basic_punch", "attack animation remains basic_punch"))
		errors.append_array(_expect(int(sprite.frame) == int(character.move_executor.current_frame()), "attack frame advances in parity"))
		while character.move_executor.is_executing() and character.move_executor.current_frame() < 7:
			character.tick_character(1.0 / 60.0, Vector2.ZERO, Vector2(999, 999))
		errors.append_array(_expect(int(character.move_executor.current_frame()) == 7, "attack reaches trailing timing frame"))
		errors.append_array(_expect(int(sprite.frame) == 7, "attack trailing timing frame stays in parity"))

	var fallback: Node2D = CombatCharacterScript.new()
	fallback.instance_id = "spriteframes_fallback_smoke"
	fallback.is_test_dummy = true
	root.add_child(fallback)
	await process_frame
	errors.append_array(_expect(not bool(fallback.has_spriteframes_playback()), "missing default SpriteFrames uses fallback"))

	if errors.is_empty():
		print("spriteframes_runtime_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("spriteframes_runtime_smoke=FAIL")
		quit(1)


func _expect(condition: bool, message: String) -> Array:
	if condition:
		return []
	return [message]
