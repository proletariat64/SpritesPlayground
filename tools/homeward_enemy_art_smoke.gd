extends SceneTree
## Uses public stage spawn/attack/hit/reset seams; no mutation of authored resources.
const Stage := preload("res://godot/scenes/MiduoOnTheWayHome.tscn")
const Factory := preload("res://godot/scripts/homeward_enemy_frames.gd")
var errors: Array = []
var stage: Node

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func region(actor) -> Rect2:
	var sprite: AnimatedSprite2D = actor.animated_sprite
	var texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return texture.region if texture is AtlasTexture else Rect2()

func run() -> void:
	stage = Stage.instantiate()
	root.add_child(stage)
	await process_frame
	stage.set_physics_process(false)
	stage.start_run()
	var player = stage.player
	player.is_test_dummy = true
	var original_path: String = player.sprite_frames_path
	var original_frames: SpriteFrames = player.animated_sprite.sprite_frames
	var original_clip: StringName = original_frames.get_animation_names()[0]
	var original_pixels: PackedByteArray = original_frames.get_frame_texture(original_clip, 0).get_image().get_data()
	expect(not original_pixels.is_empty(), "player pixel comparison has real original pixels")
	expect(not original_path.is_empty(), "player still loads original shared resource")
	var resources: Array = []
	for role in Factory.IDENTITIES:
		var actor = stage.spawn_actor(role, Vector2(350, 270))
		actor.is_test_dummy = true
		var frames: SpriteFrames = actor.animated_sprite.sprite_frames
		resources.append(frames)
		expect(actor.sprite_frames_path.is_empty() and frames == Factory.for_role(role), "%s consumes cached runtime art" % role)
		var texture: AtlasTexture = frames.get_frame_texture("punch", 0)
		expect(texture.atlas.resource_path == "res://godot/assets/homeward/enemies/%s.png" % Factory.IDENTITIES[role], "%s actual generated atlas" % role)
		expect(texture.get_size() == Vector2(80, 80) and actor.animated_sprite.modulate == Color.WHITE, "%s native cell and palette" % role)
		for facing in [-1, 1]:
			actor.state_machine.facing = facing
			actor.stage_tick(0.0)
			expect(actor.animated_sprite.flip_h == (facing > 0), "%s raw left art mirrored only east" % role)
		expect(region(actor) == Rect2(0, 80, 80, 80), "%s guard deliberately holds punch[0]" % role)
		expect(frames.get_frame_count("guard") == 1, "%s no fake breathing" % role)
		var previous_mode: String = actor.control_mode
		var previous_dummy: bool = actor.is_test_dummy
		actor.control_mode = "manual"
		actor.is_test_dummy = false
		for mode in ["walk", "run"]:
			Input.action_press("move_left")
			if mode == "run":
				Input.action_press("run")
			actor.stage_tick(0.1)
			expect(actor.animated_sprite.animation == mode and actor.animated_sprite.is_playing(), "%s actual %s playback" % [role, mode])
			var pixels0: PackedByteArray = frames.get_frame_texture(mode, 0).get_image().get_data()
			var pixels2: PackedByteArray = frames.get_frame_texture(mode, 2).get_image().get_data()
			expect(pixels0 != pixels2, "%s %s has changed drawn poses" % [role, mode])
			var initial: int = actor.animated_sprite.frame
			await create_timer(0.12).timeout
			expect(actor.animated_sprite.frame != initial, "%s %s advances real animation" % [role, mode])
			Input.action_release("move_left")
			Input.action_release("run")
		actor.control_mode = previous_mode
		actor.is_test_dummy = previous_dummy
		for move in ["jab", "cross_punch", "high_kick", "roundhouse_kick"]:
			actor.reset_runtime(Vector2(342, 270))
			actor.state_machine.facing = -1
			player.reset_runtime(Vector2(302, 270))
			player.grace = 0
			expect(actor.request_attack(move), "%s %s accepted" % [role, move])
			var seen: Array = []
			var contact_seen := false
			for tick in 32:
				actor.stage_tick(1.0 / 60)
				if actor.state_machine.current_state != "attack":
					break
				var index: int = actor.move_executor.current_frame()
				seen.append(index)
				var row := 1 if move in ["jab", "cross_punch"] else 2
				var col: int = [0, 2, 3, 4, 5, 5][index] if row == 1 else index
				expect(region(actor) == Rect2(col * 80, row * 80, 80, 80), "%s %s texture follows executor frame %d" % [role, move, index])
				expect(not actor.animated_sprite.is_playing(), "attacks never independently loop")
				if not actor.active_hitboxes_world().is_empty():
					contact_seen = true
					expect(col in [2, 3], "%s %s active frame %d uses generated contact poses; windows=%s" % [role, move, index, actor.move_executor.active_move.hitbox_windows])
				stage.process_hits()
			expect(contact_seen and seen.has(2) and seen.has(3), "%s %s traverses contact frames" % [role, move])
			expect(player.current_hp < player.max_hp, "%s %s actual collision remains functional" % [role, move])
		actor.reset_runtime(Vector2(350, 270))
		actor.grace = 0
		actor.take_hit(7, "proof", "player")
		actor.stage_tick(0.01)
		expect(actor.animated_sprite.animation == "hurt" and region(actor).position.y == 240, "%s real hurt poses" % role)
		actor.reset_runtime(Vector2(350, 270))
		actor.grace = 0
		actor.take_hit(12, "proof", "player")
		var phases: Array = []
		for tick in 75:
			actor.stage_tick(1.0 / 60)
			var clip: String = actor.animated_sprite.animation
			if not phases.has(clip):
				phases.append(clip)
			if clip == "fall":
				expect(region(actor).position.y == 240 and region(actor).position.x >= 240, "fall uses core fall3")
			elif clip == "down":
				expect(region(actor) == Rect2(400, 240, 80, 80), "down holds final fallen pose")
			elif clip == "get_up":
				expect(region(actor).position.y == 560 and region(actor).position.x >= 240, "get-up uses real extended rise poses")
		expect(phases.has("fall") and phases.has("down") and phases.has("get_up"), "%s all knockdown phases present" % role)
		actor.grace = 0
		actor.take_hit(999, "proof", "player")
		for tick in 100:
			actor.stage_tick(1.0 / 60)
		expect(actor.state_machine.current_state == "dead" and actor.animated_sprite.animation == "down" and region(actor) == Rect2(400, 240, 80, 80), "%s death stays fallen" % role)
		actor.reset_runtime(Vector2(350, 270))
		expect(actor.animated_sprite.sprite_frames == frames and actor.animated_sprite.animation == "guard", "%s reset retains new art" % role)
	for i in resources.size():
		for j in range(i + 1, resources.size()):
			expect(resources[i] != resources[j], "five identities are distinct resources")
	expect(player.sprite_frames_path == original_path and player.animated_sprite.sprite_frames == original_frames, "enemy spawn/reset leaves player resource unchanged")
	expect(original_pixels == original_frames.get_frame_texture(original_clip, 0).get_image().get_data(), "player pixels unchanged")
	stage.queue_free()
	await process_frame
	if errors.is_empty():
		print("homeward_enemy_art_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		print("homeward_enemy_art_smoke=FAIL")
		quit(1)
