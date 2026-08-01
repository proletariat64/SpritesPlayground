extends SceneTree

# Direct-window visual acceptance for Miduo Blue's LimboAI combat lifecycle.
# Run with a display server; screenshots are written under user://miduo_blue_visual_uat.

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")
const OUT_DIR := "user://miduo_blue_visual_uat"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await _frames(12)
	var player: Node2D = playground.player
	var npc: Node2D = playground.dummy
	if npc.template_id != "miduo_blue" or npc.ai_backend() != "limboai":
		errors.append("Miduo Blue must start with the LimboAI backend")

	player.reset_runtime(Vector2(205, 245))
	npc.reset_runtime(Vector2(435, 245))
	await _frames(4)
	await _record_shot("01_miduo_blue_ready.png", errors)

	var saw_approach := false
	var saw_attack := false
	var player_hp_before: int = int(player.current_hp)
	for _frame in 360:
		await physics_frame
		var distance := npc.position.distance_to(player.position)
		saw_approach = saw_approach or distance < 190.0
		if npc.state_machine.current_state == "attack":
			saw_attack = true
			await _record_shot("02_limboai_attack.png", errors)
			break
	if not saw_approach:
		errors.append("LimboAI NPC did not approach the player")
	if not saw_attack:
		errors.append("LimboAI NPC did not present an attack")

	for _frame in 240:
		await physics_frame
		if int(player.current_hp) < player_hp_before:
			break
	if int(player.current_hp) >= player_hp_before:
		errors.append("LimboAI NPC did not damage the player")
	await _record_shot("03_player_hit.png", errors)

	# Freeze AI so the remaining captures isolate shared reaction and lifecycle rules.
	npc.control_mode = "manual"
	npc.is_test_dummy = true
	player.control_mode = "manual"
	player.is_test_dummy = true
	player.reset_runtime(Vector2(245, 245))
	npc.reset_runtime(Vector2(282, 245))
	if not player.request_attack("roundhouse_kick"):
		errors.append("Player roundhouse request was rejected")
	var saw_knockdown := false
	for _frame in 150:
		await physics_frame
		if npc.state_machine.current_state == "hurt" and npc.state_machine.reaction_mode == "knockdown":
			saw_knockdown = true
			await _record_shot("04_miduo_blue_knockdown.png", errors)
			break
	if not saw_knockdown:
		errors.append("Miduo Blue did not present knockdown")

	var saw_recovery := false
	for _frame in 180:
		await physics_frame
		if npc.state_machine.current_state == "idle":
			saw_recovery = true
			break
	if not saw_recovery:
		errors.append("Miduo Blue did not recover from knockdown")
	await _record_shot("05_miduo_blue_recovered.png", errors)

	npc.current_hp = 1
	npc.take_hit(99, "visual_uat", player.instance_id, "hurt_upper_body", ["hurt_upper_body"])
	for _frame in 180:
		await physics_frame
		if npc.state_machine.current_state == "dead":
			break
	if npc.state_machine.current_state != "dead" or int(npc.current_hp) != 0:
		errors.append("Miduo Blue did not remain dead at zero HP")
	await _record_shot("06_miduo_blue_dead.png", errors)

	playground.reset_playground()
	await _frames(12)
	if npc.state_machine.current_state != "idle" or int(npc.current_hp) != int(npc.max_hp):
		errors.append("Playground reset did not revive Miduo Blue")
	if npc.control_mode != "ai" or npc.ai_backend() != "limboai":
		errors.append("Playground reset did not restore LimboAI control")
	await _record_shot("07_miduo_blue_reset.png", errors)

	playground.queue_free()
	await _frames(2)
	if errors.is_empty():
		print("miduo_blue_visual_uat=PASS dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
		quit(0)
	else:
		for message in errors:
			push_error(message)
		print("miduo_blue_visual_uat=FAIL")
		quit(1)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


func _record_shot(file_name: String, errors: Array[String]) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUT_DIR, file_name]
	var error := image.save_png(path)
	print("shot %s error=%d" % [path, error])
	if error != OK:
		errors.append("Screenshot failed: %s (error %d)" % [file_name, error])
