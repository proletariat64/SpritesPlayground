extends SceneTree
## Real elapsed process waits expose autonomous SpriteFrames restarts that fast
## manual ticks cannot. State/move data and player presentation remain untouched.
const Stage := preload("res://godot/scenes/MiduoOnTheWayHome.tscn")
const Factory := preload("res://godot/scripts/homeward_enemy_frames.gd")
const BaseActor := preload("res://godot/scripts/combat_character.gd")
var errors: Array = []

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value and not errors.has(message):
		errors.append(message)

func observe(actor, ticks: int, label: String) -> Dictionary:
	var previous_clip := ""
	var previous_frame := -1
	var reached_last := false
	var samples := {}
	for tick in ticks:
		actor.stage_tick(1.0 / 60)
		# AnimatedSprite2D gets actual process time between authoritative ticks.
		await create_timer(1.0 / 60).timeout
		var clip: String = actor.animated_sprite.animation
		if clip not in ["hurt", "fall", "down", "get_up"]:
			previous_clip = ""
			continue
		var frame: int = actor.animated_sprite.frame
		var last: int = actor.animated_sprite.sprite_frames.get_frame_count(clip) - 1
		if clip == previous_clip:
			expect(frame >= previous_frame, "%s %s never rewinds within phase" % [label, clip])
			if reached_last:
				expect(frame == last, "%s %s holds final frame until phase changes" % [label, clip])
		else:
			reached_last = false
		if frame == last:
			reached_last = true
		if not samples.has(clip):
			samples[clip] = []
		samples[clip].append(frame)
		previous_clip = clip
		previous_frame = frame
	return samples

func run() -> void:
	var stage = Stage.instantiate()
	root.add_child(stage)
	await process_frame
	stage.set_physics_process(false)
	stage.start_run()
	for actor in stage.actors:
		actor.is_test_dummy = true
	for role in Factory.IDENTITIES:
		var actor = stage.spawn_actor(role, Vector2(350, 270))
		actor.is_test_dummy = true
		actor.take_hit(7, "reaction_proof", "player")
		var ordinary: Dictionary = await observe(actor, 18, role + " ordinary")
		expect(ordinary.has("hurt") and ordinary.hurt.has(2), "%s ordinary hurt reaches final pose" % role)
		# New hits may legitimately reset the same clip; begin a new observation.
		actor.grace = 0
		actor.take_hit(7, "reaction_proof", "player")
		actor.stage_tick(0.0)
		expect(actor.animated_sprite.frame == 0, "%s new ordinary hit resets presentation" % role)
		await observe(actor, 18, role + " repeated ordinary")
		actor.reset_runtime(Vector2(350, 270))
		actor.grace = 0
		actor.take_hit(12, "reaction_proof", "player")
		var knockdown: Dictionary = await observe(actor, 90, role + " knockdown")
		for clip in ["fall", "down", "get_up"]:
			expect(knockdown.has(clip), "%s knockdown traverses %s" % [role, clip])
			if knockdown.has(clip):
				expect(knockdown[clip].has(0) and knockdown[clip].has(actor.animated_sprite.sprite_frames.get_frame_count(clip) - 1), "%s %s samples full reaction range" % [role, clip])
		actor.reset_runtime(Vector2(350, 270))
		actor.grace = 0
		actor.take_hit(999, "reaction_proof", "player")
		var death: Dictionary = await observe(actor, 45, role + " death")
		expect(death.has("fall") and death.has("down"), "%s death falls once then holds down" % role)
		expect(actor.animated_sprite.animation == "down" and actor.state_machine.current_state == "dead", "%s death never enters get-up" % role)
		# Freeze early in a reaction, not only once already down. No stage ticks
		# means paused gameplay even though the UI/process tree continues running.
		actor.reset_runtime(Vector2(350, 270))
		actor.grace = 0
		actor.take_hit(12, "reaction_proof", "player")
		actor.stage_tick(1.0 / 60)
		stage.show_menu("paused")
		var frozen_frame: int = actor.animated_sprite.frame
		var frozen_time: float = actor.state_machine.state_elapsed
		await create_timer(0.3).timeout
		expect(actor.animated_sprite.frame == frozen_frame and actor.state_machine.state_elapsed == frozen_time, "%s paused reaction stays frozen" % role)
		stage.resume_run()
		actor.reset_runtime(Vector2(350, 270))
		expect(actor.animated_sprite.animation == "guard" and actor.animated_sprite.is_playing(), "%s reset leaves reaction clock and resumes guard playback" % role)
	# A base-character peer proves the player still follows inherited playback,
	# rather than merely testing an enemy condition against its own implementation.
	var peer := BaseActor.new()
	peer.template_id = "miduo"
	root.add_child(peer)
	var player = stage.player
	player.input_enabled = false
	player.grace = 0
	player.take_hit(7, "reaction_proof", "enemy")
	peer.take_hit(7, "reaction_proof", "enemy")
	player.stage_tick(0.01)
	peer.tick_character(0.01, Vector2.ZERO, Vector2(10000, 10000))
	expect(player.animated_sprite.animation == peer.animated_sprite.animation and player.animated_sprite.is_playing() == peer.animated_sprite.is_playing(), "player retains base reaction playback")
	await create_timer(0.12).timeout
	expect(player.animated_sprite.frame == peer.animated_sprite.frame, "player real-time reaction frames remain identical to base")
	peer.queue_free()
	stage.queue_free()
	await process_frame
	if errors.is_empty():
		print("homeward_enemy_reaction_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		print("homeward_enemy_reaction_smoke=FAIL")
		quit(1)
