extends SceneTree

# Best-effort visual UAT for issue #32 without MCP: boots the real Playground,
# captures viewport screenshots of imported Miduo idle, walk, run, and jab.

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")
const OUT_DIR := "user://miduo_visual_uat"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame
	for i in 12:
		await process_frame
	await _shot("01_idle_e.png")
	print("uat template=%s animation=%s playback=%s" % [
		playground.player.template_id,
		playground.player.animated_sprite.animation,
		playground.player.has_spriteframes_playback(),
	])

	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	await _shot("02_walk_e.png")

	Input.action_press("run")
	for i in 20:
		await physics_frame
	await _shot("03_run_e.png")
	Input.action_release("run")
	Input.action_release("move_right")
	for i in 20:
		await physics_frame

	playground.player.request_attack("jab")
	for i in 2:
		await physics_frame
	await _shot("04_jab.png")
	print("uat attack_move=%s animation=%s" % [
		playground.player.state_machine.current_move,
		playground.player.animated_sprite.animation,
	])
	for i in 20:
		await physics_frame

	playground.toggle_creator_lab()
	for i in 6:
		await process_frame
	await _shot("05_creator_lab_miduo.png")

	print("miduo_visual_uat=DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUT_DIR, file_name]
	var error := image.save_png(path)
	print("shot %s error=%d" % [path, error])
