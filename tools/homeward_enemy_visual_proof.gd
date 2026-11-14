extends SceneTree
## Staged visual evidence, NOT normal-AI route proof. Own temporary headed process;
## captures its viewport without OS keyboard input or touching other Godot windows.
const Stage := preload("res://godot/scenes/MiduoOnTheWayHome.tscn")
const ROLES := ["brawler", "rusher", "kicker", "mini", "boss"]
const OUT := "res://docs/06_testing/evidence/homeward-enemies/"

func _init() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + label + ".png")
	assert(result == OK, "screenshot write failed")
	print("visual_proof=%s pid=%d" % [label, OS.get_process_id()])

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use an isolated headed process")
	DisplayServer.window_set_title("Homeward generated enemy art — staged evidence")
	var stage = Stage.instantiate()
	root.add_child(stage)
	await process_frame
	stage.set_physics_process(false)
	stage.start_run()
	for actor in stage.actors:
		if actor != stage.player:
			stage.world.remove_child(actor)
			actor.queue_free()
	stage.actors = [stage.player]
	var enemies: Array = []
	for i in ROLES.size():
		enemies.append(stage.spawn_actor(ROLES[i], Vector2(165 + 88 * i, 280)))
	for actor in stage.actors:
		actor.is_test_dummy = true
		# Staged panorama lineup spans the route, outside the first encounter lock.
		actor.lane = Rect2(24, 230, 2166, 90)
	stage.player.input_enabled = false
	var places := ["school_gate", "shopping_street", "homeward_alley"]
	for place in 3:
		var offset := place * 768
		stage.camera.position.x = offset + 320
		stage.player.reset_runtime(Vector2(offset + 65, 280))
		for i in enemies.size():
			var actor = enemies[i]
			actor.reset_runtime(Vector2(offset + 165 + 88 * i, 280))
			actor.state_machine.facing = -1 if i % 2 == 0 else 1
			actor.stage_tick(0.0)
		await capture("%s_guard_lineup" % places[place])
		for i in enemies.size():
			var actor = enemies[i]
			assert(actor.request_attack("jab" if i < 2 else "high_kick"))
			# Snapshot contact through executor's real clock, not manually set sprite frame.
			for tick in (7 if i < 2 else 12):
				actor.stage_tick(1.0 / 60)
		await capture("%s_contact_lineup" % places[place])
		for actor in enemies:
			actor.grace = 0
			actor.take_hit(999, "visual_proof", "player")
			for tick in 40:
				actor.stage_tick(1.0 / 60)
		await capture("%s_fallen_lineup" % places[place])
	stage.queue_free()
	await process_frame
	quit(0)
