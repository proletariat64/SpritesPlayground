extends SceneTree
const Stage := preload("res://godot/scenes/MiduoOnTheWayHome.tscn")
var stage: Node
var errors: Array = []

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func fresh() -> void:
	stage.start_run()
	stage.input_latch = false
	stage.player.input_enabled = true
	stage.player.is_test_dummy = true

func ticks(count: int) -> void:
	for i in count:
		stage.advance_gameplay(1.0 / 60)

func run() -> void:
	stage = Stage.instantiate()
	root.add_child(stage)
	await process_frame
	stage.set_physics_process(false)
	expect(stage.mode == "title", "title is initial state")
	var streets := stage.get_children().filter(func(node): return node.get_script() == stage.Street)
	expect(streets.size() == 1, "stage actually instantiates the generated panorama renderer")
	if streets.size() == 1:
		var street: Node2D = streets[0]
		expect(street.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "panoramas use nearest filtering")
		var names := ["SchoolGate", "ShoppingStreet", "HomewardAlley"]
		var files := ["school_gate", "shopping_street", "homeward_alley"]
		for index in names.size():
			var panorama := street.get_node_or_null(NodePath(names[index])) as Sprite2D
			expect(panorama != null, "%s is a rendered stage Sprite2D" % names[index])
			if panorama == null:
				continue
			expect(panorama.texture is Texture2D and panorama.texture.get_size() == Vector2(768, 432), "%s imported texture has production dimensions" % names[index])
			expect(panorama.texture.resource_path == "res://godot/assets/homeward/backgrounds/%s.png" % files[index], "%s consumes generated PNG, not procedural placeholder" % names[index])
			expect(panorama.position == Vector2(index * 768, -72) and panorama.scale == Vector2.ONE and not panorama.centered, "%s panorama geometry aligns unchanged combat lane" % names[index])
			expect(panorama.is_visible_in_tree(), "%s panorama is visible in the live scene" % names[index])
	fresh()
	var p = stage.player
	expect(p.sprite_frames_valid and p.state_machine.state_authority_backend() == "limboai", "real imported green sprites and LimboAI")
	var enemies: Array = stage.living_enemies()
	expect(enemies.size() == 2 and enemies[0].sprite_frames_valid, "two real blue grunts")
	p.position.x = 900
	ticks(1)
	expect(p.foot_center_world().x <= 492, "first encounter lock clamps foot")
	var frozen: Vector2 = p.position
	stage.show_menu("paused")
	ticks(30)
	expect(p.position == frozen, "pause freezes combat")
	expect(not p.try_super(), "menu super rejected")
	stage.resume_run()
	p.input_enabled = true
	p.position = Vector2(300, 270)
	for enemy in enemies:
		enemy.is_test_dummy = true
		enemy.position = Vector2(345, 270)
		# Survive the window: dedup must not be a side effect of target death.
		enemy.max_hp = 60
		enemy.current_hp = 60
	expect(p.try_super(), "eligible super starts")
	expect(p.move_executor.active_move.animation_id == "roundhouse_kick", "super retains animation alias")
	expect(not p.try_super(), "cooldown rejects repeated super")
	# Tick executor and settle separately: no spacing moves the second target out.
	for i in 22:
		for a in stage.actors:
			a.stage_tick(1.0 / 60)
		stage.process_hits()
	expect(enemies[0].current_hp == 36 and enemies[1].current_hp == 36, "super actual hitbox settles both enemies once")
	expect(stage.hits_landed == 2, "one super settlement per enemy/window")
	fresh()
	p = stage.player
	var e = stage.living_enemies()[0]
	var other = stage.living_enemies()[1]
	e.is_test_dummy = true
	other.is_test_dummy = true
	p.position = Vector2(300, 270)
	e.position = Vector2(342, 270)
	other.position = Vector2(380, 270)
	e.state_machine.facing = 1
	expect(e.request_attack("jab"), "enemy jab starts through state authority")
	for i in 18:
		e.stage_tick(1.0 / 60)
		stage.process_hits()
	expect(other.current_hp == other.max_hp, "enemies cannot friendly fire")
	# Simultaneous lethal contact must survive cancellation of the first executor.
	p.reset_runtime(Vector2(300, 270))
	e.reset_runtime(Vector2(340, 270))
	p.grace = 0
	e.grace = 0
	p.current_hp = 1
	e.current_hp = 1
	p.state_machine.facing = 1
	e.state_machine.facing = -1
	expect(p.request_attack("jab") and e.request_attack("jab"), "reciprocal attacks accepted")
	for i in 13:
		p.stage_tick(1.0 / 60)
		e.stage_tick(1.0 / 60)
		stage.process_hits()
	expect(p.current_hp == 0 and e.current_hp == 0, "reciprocal lethal trade uses snapshots")
	ticks(1)
	expect(stage.mode == "defeat", "lethal damage opens defeat")
	fresh()
	p = stage.player
	expect(p.current_hp == 100 and p.super_cooldown == 0 and p.grace == 0, "retry resets HP/cooldown/grace")
	expect(stage.encounter == 0 and stage.spawn_counts == [1, 0, 0, 0] and stage.actors.size() == 3, "retry reconstructs actors/waves")
	expect(p.position == Vector2(130, 270) and stage.camera.position.x == 320, "retry resets position/camera")
	p.state_machine.enter_hurt()
	expect(not p.try_super() and p.super_cooldown == 0, "hurt super fails without spending cooldown")
	p.state_machine.reset_to_idle()
	# Complete all four finite encounters through actual repeated jab collision damage.
	for wave in 4:
		expect(stage.encounter == wave and stage.spawn_counts[wave] == 1, "encounter %d spawned exactly once" % wave)
		for enemy in stage.living_enemies():
			enemy.is_test_dummy = true
			var limit := 0
			while enemy.current_hp > 0 and limit < 900:
				p.position = Vector2(enemy.position.x - 40, enemy.position.y)
				p.state_machine.facing = 1
				p.request_attack("jab")
				ticks(1)
				limit += 1
			expect(enemy.current_hp == 0, "wave %d enemy defeated by executor hitboxes" % wave)
		ticks(2)
		expect(stage.cleared, "cleared wave opens gate")
		if wave < 3:
			p.position.x = stage.TRIGGERS[wave + 1]
			ticks(1)
	p.position.x = 2015
	ticks(1)
	expect(stage.mode == "victory" and stage.spawn_counts == [1, 1, 1, 1], "home victory after four finite encounters")
	fresh()
	# Stage-only grace prevents rapid chainstun; cooldown is elapsed simulation time.
	p = stage.player
	p.take_hit(7, "test", "test")
	p.take_hit(7, "test", "test")
	expect(p.current_hp == 93, "brief grace rejects repeated hit")
	for enemy in stage.living_enemies():
		enemy.is_test_dummy = true
	ticks(45)
	expect(p.try_super(), "post-hurt recovery can super")
	ticks(335)
	expect(p.super_cooldown == 0, "5.5s cooldown expires by gameplay time")
	# Archetypes exercise their actual intent, telegraph and fixed commit facing.
	for role in ["brawler", "rusher", "kicker", "mini", "boss"]:
		var actor = stage.spawn_actor(role, Vector2(350, 270))
		actor.lane = Rect2(24, 230, 2166, 90)
		p.position = Vector2(310, 270)
		actor.brain_timer = 0
		actor.stage_tick(0.01)
		expect(actor.brain_phase == "telegraph", "%s telegraphs" % role)
		if role in ["mini", "boss"]:
			expect(actor.brain_timer >= 0.69, "%s has longer heavy warning" % role)
		var facing: int = actor.committed_facing
		p.position.x = 390
		for step in 90:
			actor.stage_tick(1.0 / 60)
			if actor.brain_phase == "committed":
				break
		expect(actor.brain_phase == "committed" and actor.state_machine.current_state == "attack", "%s commits through public gameplay ticks" % role)
		expect(actor.state_machine.locked_attack_facing == facing, "%s facing locked at commit" % role)
		if role == "rusher" or role == "boss":
			expect(not actor.move_executor.active_move.events.is_empty(), "%s has authored rush velocity" % role)
		if role == "kicker" or role == "mini":
			expect(actor.pending_move == "high_kick", "%s chooses kick" % role)
		for step in 90:
			actor.stage_tick(1.0 / 60)
			if actor.brain_phase == "recovery":
				break
		expect(actor.brain_phase == "recovery" and actor.state_machine.current_state != "attack" and not actor.move_executor.is_executing(), "%s actual attack completion enters recovery" % role)
		expect(actor.brain_timer >= 0.65, "%s punishable recovery" % role)
		if role == "boss":
			for step in 240:
				actor.stage_tick(1.0 / 60)
				if actor.brain_phase == "telegraph":
					break
			expect(actor.brain_phase == "telegraph" and actor.attack_count == 2, "boss naturally recovers and telegraphs second attack")
			expect(actor.pending_move == "roundhouse_kick", "boss alternates rush/roundhouse")
	stage.queue_free()
	await process_frame
	if errors.is_empty():
		print("homeward_stage_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		print("homeward_stage_smoke=FAIL")
		quit(1)
