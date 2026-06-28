extends SceneTree

const DemoScene := preload("res://godot/scenes/AdamCainPunchDemo.tscn")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")

const REPORT_PATH := "res://docs/adam_cain_basic_punch_validation.md"
const TICK_RATE := 60
const DELTA := 1.0 / float(TICK_RATE)

var _trace: Array = []
var _checks: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = TICK_RATE
	var demo: Node = DemoScene.instantiate()
	root.add_child(demo)
	await process_frame
	await physics_frame

	var playground: Node = demo.get_node("Playground")
	var adam: Node2D = playground.player
	var cain: Node2D = playground.dummy
	adam.instance_id = "adam"
	cain.instance_id = "cain"
	cain.is_test_dummy = true

	_checks["value_surface"] = _collect_value_surface(adam, cain)
	_checks["move_right_walk"] = await _run_move_right_walk(playground, adam, cain)
	_checks["single_punch"] = await _run_single_punch(playground, adam, cain)
	_checks["rapid_j_chain"] = await _run_rapid_j_chain(playground, adam, cain)
	_checks["recovered_three_hits"] = await _run_recovered_three_hits(playground, adam, cain)
	_checks["death_entry"] = await _run_death_entry(playground, adam, cain)

	var report := _build_report()
	_write_report(report)
	print(report)

	var pass_runtime := (
		bool(_checks["move_right_walk"]["passed"])
		and bool(_checks["single_punch"]["passed"])
		and bool(_checks["recovered_three_hits"]["passed"])
		and bool(_checks["death_entry"]["passed"])
	)
	if pass_runtime:
		print("adam_cain_punch_demo_smoke=PASS")
		quit(0)
	else:
		push_error("adam_cain_punch_demo_smoke=FAIL")
		quit(1)


func _collect_value_surface(adam: Node2D, cain: Node2D) -> Dictionary:
	var move: Dictionary = DataStore.load_move("basic_punch")
	var walk: Dictionary = DataStore.load_move("walk")
	var template: Dictionary = DataStore.load_template("combat_gray_s64")
	var cain_template: Dictionary = DataStore.load_template("skeleton_default_unarmed_s64")
	var hitbox: Dictionary = move.get("hitboxes", [{}])[0]
	var hitbox_rect: Dictionary = hitbox.get("rect", {})
	var active_window: Dictionary = hitbox.get("active_window", {})
	var runtime_move: Dictionary = adam.move_executor.move_templates.get("basic_punch", {})
	var runtime_windows: Array = runtime_move.get("hitbox_windows", [])
	var runtime_window: Dictionary = runtime_windows[0] if not runtime_windows.is_empty() else {}
	var runtime_rect: Rect2 = runtime_window.get("rect", Rect2())
	return {
		"runtime_tick_rate": TICK_RATE,
		"authoring_fps": 12,
		"move_right": "D",
		"basic_punch": "J",
		"light_punch_mapping": "light_punch -> basic_punch",
		"move_state_mapping": "move -> walk / locomotion",
		"states": ["idle", "walk", "attack", "hurt", "dead"],
		"adam_template": adam.template_id,
		"cain_template": cain.template_id,
		"adam_hp": adam.max_hp,
		"cain_hp": cain.max_hp,
		"template_hp": int(template.get("hp", 0)),
		"cain_template_hp": int(cain_template.get("hp", 0)),
		"walk_move_type": str(walk.get("move_type", "")),
		"walk_velocity_event": walk.get("events", []),
		"v03_basic_punch_frame_count": int(move.get("frame_count", 0)),
		"v03_basic_punch_active_start": int(active_window.get("start_frame", -1)),
		"v03_basic_punch_active_end": int(active_window.get("end_frame", -1)),
		"v03_basic_punch_damage": int(move.get("damage", 0)),
		"v03_basic_punch_hitstop_frames": int(move.get("hitstop_frames", 0)),
		"basic_punch_multi_hit": bool(move.get("multi_hit", false)),
		"hitbox_id": str(hitbox.get("hitbox_id", "")),
		"hitbox_rect": hitbox_rect,
		"runtime_basic_punch_frame_count": int(runtime_move.get("total_frames", 0)),
		"runtime_basic_punch_active_start": int(runtime_window.get("from_frame", -1)),
		"runtime_basic_punch_active_end": int(runtime_window.get("to_frame", -1)),
		"runtime_basic_punch_damage": int(runtime_window.get("damage", 0)),
		"runtime_hitbox_id": str(runtime_window.get("hitbox_id", "")),
		"runtime_hitbox_rect": {"x": runtime_rect.position.x, "y": runtime_rect.position.y, "w": runtime_rect.size.x, "h": runtime_rect.size.y},
		"hurtboxes": cain_template.get("hurtboxes", {}),
		"hurtbox_def_runtime": "missing",
		"hitbox_atk_runtime": "missing",
		"document_formula": "damage=max(0, hitbox_atk-hurtbox_def)",
		"runtime_formula": "damage=move.hitbox_windows[].damage",
		"design_seed_atk": 10,
		"scenario_def": 2,
		"scenario_hp": 100,
		"input_buffer_runtime": "missing",
		"cancel_window_runtime": "missing",
		"combo_string_runtime": "missing",
		"death_event_runtime": "state_machine.enter_dead()",
	}


func _run_move_right_walk(playground: Node, adam: Node2D, cain: Node2D) -> Dictionary:
	_reset_pair(playground, adam, cain, Vector2(245, 245), Vector2(405, 245))
	var start_x: float = adam.position.x
	Input.action_press("move_right")
	var frames := 0
	var saw_walk := false
	while frames < 100 and adam.position.x < 368.0:
		await physics_frame
		frames += 1
		saw_walk = saw_walk or adam.state_machine.current_state == "walk"
		if frames % 10 == 0 or adam.position.x >= 368.0:
			_record_trace("move_right", frames, adam, cain)
	Input.action_release("move_right")
	await physics_frame
	var reachable: bool = _projected_overlap(adam, cain, "basic_punch")
	return {
		"passed": saw_walk and adam.position.x > start_x and reachable,
		"frames": frames,
		"start_x": start_x,
		"end_x": adam.position.x,
		"saw_walk": saw_walk,
		"projected_hitbox_reaches_cain": reachable,
	}


func _run_single_punch(playground: Node, adam: Node2D, cain: Node2D) -> Dictionary:
	_reset_pair(playground, adam, cain, Vector2(245, 245), Vector2(282, 245))
	var hp_before: int = int(cain.current_hp)
	await _tap_action("basic_punch")
	var frames: Array = []
	var saw_attack := false
	var saw_active := false
	var saw_overlap := false
	var saw_hurt := false
	for frame in 14:
		await physics_frame
		var active_count: int = adam.active_hitboxes_world().size()
		var overlap: bool = _current_overlap(adam, cain)
		saw_attack = saw_attack or adam.state_machine.current_state == "attack"
		saw_active = saw_active or active_count > 0
		saw_overlap = saw_overlap or overlap
		saw_hurt = saw_hurt or cain.state_machine.current_state == "hurt"
		frames.append(_frame_summary(frame + 1, adam, cain, active_count, overlap))
		_record_trace("single_punch", frame + 1, adam, cain)
	var damage: int = hp_before - int(cain.current_hp)
	return {
		"passed": saw_attack and saw_active and saw_overlap and saw_hurt and damage == 8,
		"hp_before": hp_before,
		"hp_after": cain.current_hp,
		"damage": damage,
		"saw_attack": saw_attack,
		"saw_active_hitbox": saw_active,
		"saw_overlap": saw_overlap,
		"saw_hurt": saw_hurt,
		"resolved_hurtbox": str(cain.debug_summary()["last_hit_hurtbox"]),
		"contact_hurtboxes": cain.debug_summary()["contact_hurtboxes"],
		"frames": frames,
	}


func _run_rapid_j_chain(playground: Node, adam: Node2D, cain: Node2D) -> Dictionary:
	_reset_pair(playground, adam, cain, Vector2(245, 245), Vector2(282, 245))
	var hp_before: int = int(cain.current_hp)
	var start_count: int = 0
	await _tap_action("basic_punch")
	for frame in 3:
		await physics_frame
		if adam.state_machine.current_state == "attack" and adam.state_machine.current_frame() == 0:
			start_count += 1
	_record_trace("rapid_j_after_first", 3, adam, cain)
	await _tap_action("basic_punch")
	for frame in 2:
		await physics_frame
	_record_trace("rapid_j_after_second", 5, adam, cain)
	await _tap_action("basic_punch")
	for frame in 12:
		await physics_frame
	_record_trace("rapid_j_after_third", 17, adam, cain)
	var damage: int = hp_before - int(cain.current_hp)
	return {
		"passed": damage == 8,
		"hp_before": hp_before,
		"hp_after": cain.current_hp,
		"damage": damage,
		"accepted_as_combo": damage > 8,
		"buffer_cancel_supported": false,
		"state_after": adam.state_machine.current_state,
	}


func _run_recovered_three_hits(playground: Node, adam: Node2D, cain: Node2D) -> Dictionary:
	_reset_pair(playground, adam, cain, Vector2(245, 245), Vector2(282, 245))
	var hp_before: int = int(cain.current_hp)
	var hit_hps: Array = []
	for i in 3:
		await _tap_action("basic_punch")
		await _wait_until_pair_ready(adam, cain, 48)
		hit_hps.append(cain.current_hp)
		_record_trace("recovered_hit_%d" % (i + 1), i + 1, adam, cain)
	var damage: int = hp_before - int(cain.current_hp)
	return {
		"passed": damage == 24 and cain.current_hp == 76,
		"hp_before": hp_before,
		"hp_after": cain.current_hp,
		"damage": damage,
		"hit_hps": hit_hps,
		"ko": cain.state_machine.current_state == "dead",
	}


func _run_death_entry(playground: Node, adam: Node2D, cain: Node2D) -> Dictionary:
	_reset_pair(playground, adam, cain, Vector2(245, 245), Vector2(282, 245))
	var hits: int = 0
	while cain.current_hp > 0 and hits < 16:
		await _tap_action("basic_punch")
		await _wait_until_pair_ready(adam, cain, 48)
		hits += 1
	var expected_hits: int = int(ceil(float(cain.max_hp) / 8.0))
	return {
		"passed": cain.current_hp == 0 and cain.state_machine.current_state == "dead" and hits == expected_hits,
		"hits": hits,
		"expected_hits": expected_hits,
		"hp_after": cain.current_hp,
		"state_after": cain.state_machine.current_state,
	}


func _reset_pair(playground: Node, adam: Node2D, cain: Node2D, adam_position: Vector2, cain_position: Vector2) -> void:
	Input.action_release("move_right")
	Input.action_release("basic_punch")
	adam.reset_runtime(adam_position)
	cain.reset_runtime(cain_position)
	adam.control_mode = "manual"
	cain.control_mode = "manual"
	cain.is_test_dummy = true
	playground._tick_combat(DELTA)


func _tap_action(action_id: String) -> void:
	Input.action_press(action_id)
	await physics_frame
	Input.action_release(action_id)


func _wait_until_idle_or_dead(character: Node2D, max_frames: int) -> void:
	for _frame in max_frames:
		await physics_frame
		if character.state_machine.current_state in ["idle", "dead"]:
			return


func _wait_until_pair_ready(attacker: Node2D, target: Node2D, max_frames: int) -> void:
	for _frame in max_frames:
		await physics_frame
		var attacker_ready: bool = attacker.state_machine.current_state in ["idle", "dead"]
		var target_ready: bool = target.state_machine.current_state in ["idle", "dead"]
		if attacker_ready and target_ready:
			return


func _projected_overlap(attacker: Node2D, target: Node2D, move_id: String) -> bool:
	var move: Dictionary = attacker.move_executor.move_templates.get(move_id, {})
	for window in move.get("hitbox_windows", []):
		var rect: Rect2 = window.get("rect", Rect2())
		if attacker.state_machine.facing < 0:
			rect.position.x = -rect.position.x - rect.size.x
		var world_rect := Rect2(attacker.global_position + rect.position, rect.size)
		for hurtbox in target.hurtboxes_world():
			if world_rect.intersects(hurtbox["rect"]):
				return true
	return false


func _current_overlap(attacker: Node2D, target: Node2D) -> bool:
	for hitbox in attacker.active_hitboxes_world():
		for hurtbox in target.hurtboxes_world():
			if hitbox["rect"].intersects(hurtbox["rect"]):
				return true
	return false


func _frame_summary(frame: int, adam: Node2D, cain: Node2D, active_count: int, overlap: bool) -> Dictionary:
	return {
		"frame": frame,
		"adam_state": adam.state_machine.current_state,
		"adam_move": adam.state_machine.current_move,
		"adam_move_frame": adam.state_machine.current_frame(),
		"adam_x": snapped(adam.position.x, 0.01),
		"facing": adam.state_machine.facing,
		"active_hitboxes": active_count,
		"overlap": overlap,
		"cain_hp": cain.current_hp,
		"cain_state": cain.state_machine.current_state,
		"cain_hurtbox": str(cain.debug_summary()["last_hit_hurtbox"]),
	}


func _record_trace(label: String, frame: int, adam: Node2D, cain: Node2D) -> void:
	_trace.append(_frame_summary(frame, adam, cain, adam.active_hitboxes_world().size(), _current_overlap(adam, cain)).merged({"label": label}, true))


func _write_report(report: String) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write report: %s" % REPORT_PATH)
		return
	file.store_string(report)


func _build_report() -> String:
	var values: Dictionary = _checks["value_surface"]
	var single: Dictionary = _checks["single_punch"]
	var rapid: Dictionary = _checks["rapid_j_chain"]
	var recovered: Dictionary = _checks["recovered_three_hits"]
	var death: Dictionary = _checks["death_entry"]
	var move_right: Dictionary = _checks["move_right_walk"]
	var lines: Array[String] = []
	lines.append("# Adam/Cain basic_punch Scene Validation")
	lines.append("")
	lines.append("Generated by `tools/adam_cain_punch_demo_smoke.gd` against `godot/scenes/AdamCainPunchDemo.tscn`.")
	lines.append("")
	lines.append("## Verdict")
	lines.append("")
	lines.append("FAIL")
	lines.append("")
	lines.append("The runnable Godot slice proves movement, attack start, active hitbox overlap, one-hit damage, HP reduction, repeated full-recovery punches, and death entry. It does not prove the PRD/DDD design contract for ATK/DEF damage formula, input buffer, cancel window, combo string, hitstop, hitstun, or explicit death event emission because those runtime mechanisms are missing or bypassed by the current GDScript implementation.")
	lines.append("")
	lines.append("## Value List")
	lines.append("")
	lines.append("| Value | Runtime / data value | Source | Status |")
	lines.append("| --- | --- | --- | --- |")
	lines.append("| runtime_tick_rate | %s | Playground COMBAT_TICK_RATE / smoke Engine setting | present |" % values["runtime_tick_rate"])
	lines.append("| authoring_fps | %s | PRD/DDD baseline | design only in this smoke |" % values["authoring_fps"])
	lines.append("| move_right | D | InputMap in Playground | present |")
	lines.append("| basic_punch | J | InputMap in Playground | present |")
	lines.append("| light_punch mapping | light_punch -> basic_punch | scenario assumption | mapped, no new MoveData |")
	lines.append("| move state mapping | move -> walk / locomotion | scenario assumption + walk MoveData | mapped |")
	lines.append("| states | idle, walk, attack, hurt, dead | CombatStateMachine | present |")
	lines.append("| hp/current_hp | Adam %s, Cain %s | CharacterTemplate -> CombatCharacter | present |" % [values["adam_hp"], values["cain_hp"]])
	lines.append("| live hitbox rect/window | %s f%s-f%s total=%s | data/moves/basic_punch.json -> MoveExecutor | present |" % [str(values["runtime_hitbox_rect"]), values["runtime_basic_punch_active_start"], values["runtime_basic_punch_active_end"], values["runtime_basic_punch_frame_count"]])
	lines.append("| v0.3 hitbox rect/window | %s f%s-f%s total=%s | data/v0_3/moves/basic_punch.json | reference, not live Playground path |" % [str(values["hitbox_rect"]), values["v03_basic_punch_active_start"], values["v03_basic_punch_active_end"], values["v03_basic_punch_frame_count"]])
	lines.append("| hurtbox rect/priority/DEF | hurtbox rects present; priority is dictionary order; DEF missing | data/templates/*.json live path; data/v0_3/templates reference | partial |")
	lines.append("| hitbox_atk | missing; live runtime uses damage=%s | PRD/DDD vs data/moves/basic_punch.json | mismatch |" % values["runtime_basic_punch_damage"])
	lines.append("| damage formula | design says max(0, hitbox_atk-hurtbox_def); runtime applies window damage | PRD/DDD + MoveExecutor/Playground | mismatch |")
	lines.append("| hitstop/hitstun | v0.3 hitstop_frames=%s in data; live Playground path does not consume hitstop/hitstun | data + runtime | missing in live slice |" % values["v03_basic_punch_hitstop_frames"])
	lines.append("| cancel window | absent in runtime move template | runtime | missing |")
	lines.append("| input buffer | absent in Playground input path | runtime | missing |")
	lines.append("| combo string | absent in Playground input path | runtime | missing |")
	lines.append("| hit-once rule | one target per active window via MoveExecutor hit marks | runtime | present |")
	lines.append("| death event | Cain enters dead state; no explicit ev_dead signal/event observed | runtime | partial |")
	lines.append("")
	lines.append("## Step Trace Summary")
	lines.append("")
	lines.append("| Check | Result | Evidence |")
	lines.append("| --- | --- | --- |")
	lines.append("| [d] -> walk and reach | %s | frames=%s x=%s->%s projected_overlap=%s |" % [_pass_fail(move_right["passed"]), move_right["frames"], _num(move_right["start_x"]), _num(move_right["end_x"]), move_right["projected_hitbox_reaches_cain"]])
	lines.append("| [j] -> basic_punch/attack | %s | saw_attack=%s active_hitbox=%s overlap=%s Cain HP %s->%s |" % [_pass_fail(single["passed"]), single["saw_attack"], single["saw_active_hitbox"], single["saw_overlap"], single["hp_before"], single["hp_after"]])
	lines.append("| rapid [j][j][j] buffer/cancel | FAIL | Cain damage=%s; only one hit accepted, no buffer/cancel chain observed |" % rapid["damage"])
	lines.append("| full recovery [j] x3 | %s | Cain HP %s->%s, damage=%s, hit HPs=%s |" % [_pass_fail(recovered["passed"]), recovered["hp_before"], recovered["hp_after"], recovered["damage"], str(recovered["hit_hps"])])
	lines.append("| death entry | %s | hits=%s expected=%s final HP=%s state=%s |" % [_pass_fail(death["passed"]), death["hits"], death["expected_hits"], death["hp_after"], death["state_after"]])
	lines.append("")
	lines.append("## Frame Trace: Single Punch")
	lines.append("")
	lines.append("| frame | Adam state | move | move frame | active | overlap | Cain HP | Cain state | hurtbox |")
	lines.append("| --- | --- | --- | ---: | ---: | --- | ---: | --- | --- |")
	for frame in single["frames"]:
		lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			frame["frame"],
			frame["adam_state"],
			frame["adam_move"],
			frame["adam_move_frame"],
			frame["active_hitboxes"],
			frame["overlap"],
			frame["cain_hp"],
			frame["cain_state"],
			frame["cain_hurtbox"],
		])
	lines.append("")
	lines.append("## Known Conflicts Checked")
	lines.append("")
	lines.append("| Conflict | Observation |")
	lines.append("| --- | --- |")
	lines.append("| Docs use hitbox_atk/hurtbox_def; runtime data uses damage and hurtbox has no def | Confirmed. `basic_punch.damage=8`; no runtime DEF field is loaded. |")
	lines.append("| DDD recommends basic_punch ATK=10 / DEF=0; scenario asks ATK=10 / DEF=2 / HP=100 | Confirmed as unresolved value conflict. Current data has HP=100 and damage=8 only. |")
	lines.append("| basic_punch.damage=8 equals 10-2 but source path does not follow formula | Confirmed. The equality is incidental in current runtime. |")
	lines.append("| Three hits at 8 damage cannot KO 100 HP | Confirmed. Full-recovery three hits leave Cain at 76 HP; KO requires 13 hits. |")
	lines.append("")
	lines.append("## Gap List")
	lines.append("")
	lines.append("| Category | Gap | Evidence | Minimal existing-mechanism fix |")
	lines.append("| --- | --- | --- | --- |")
	lines.append("| Design Missing | Scenario-level `light_punch` is not a committed MoveData ID. | Existing data only has `basic_punch`. | Keep mapping `light_punch -> basic_punch` in scenario/test wording. |")
	lines.append("| Value Conflict | ATK/DEF/HP seeds conflict across DDD recommendation and scenario. | DDD recommends ATK 10, DEF 0; scenario says DEF 2; data stores damage 8. | Clarify numeric truth table using existing MoveData damage or existing PRD formula, without adding fields in this pass. |")
	lines.append("| Formula Mismatch | Runtime does not compute `max(0, hitbox_atk-hurtbox_def)`. | Playground passes `hitbox.damage` directly to `take_hit`. | Either document this slice as damage-field based, or retune existing data once ATK/DEF fields already exist in the schema. |")
	lines.append("| Runtime Missing | No live input buffer, cancel window, combo string, hitstop, or hitstun in Playground path. | Rapid [j][j][j] produces one hit; `hitstop_frames` is data-only here. | Validate full-recovery repeat only; mark combo/cancel as not implemented until existing runtime modules consume existing values. |")
	lines.append("| Prototype Mismatch | HTML prototype exposes buffer/combo/system params and behavior defaults not mirrored by live GDScript. | Prototype has InputSystem buffer and CombatSystem combo table; Playground input path is direct. | Treat prototype as authoring surface reference, not gameplay formula truth. |")
	lines.append("")
	lines.append("## Improvement Notes")
	lines.append("")
	lines.append("- Keep `basic_punch` as the only MoveData for this scenario; do not add `light_punch`.")
	lines.append("- Keep the current smoke as a regression boundary for movement, overlap, damage, hit-once, repeat-after-recovery, and death.")
	lines.append("- Before claiming PRD PASS, existing runtime paths must consume already-defined input buffer, cancel window, combo string, hitstop/hitstun, and ATK/DEF formula values.")
	lines.append("")
	lines.append("## PASS/FAIL")
	lines.append("")
	lines.append("FAIL")
	return "\n".join(lines) + "\n"


func _pass_fail(value: bool) -> String:
	return "PASS" if value else "FAIL"


func _num(value) -> String:
	return str(snapped(float(value), 0.01))
