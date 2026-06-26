extends PanelContainer
class_name CreatorLabV03Panel

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Runtime := preload("res://godot/scripts/prd_v0_3_runtime.gd")
const Catalog := preload("res://godot/scripts/creator_lab_action_catalog.gd")
const Coverage := preload("res://godot/scripts/creator_lab_action_coverage.gd")
const ActionPreview := preload("res://godot/scripts/creator_lab_action_preview.gd")
const SpriteFramesGeneratorScript := preload("res://godot/scripts/spriteframes_generator.gd")
const COLOR_TITLE := Color(0.72, 0.86, 1.0)
const COLOR_LABEL := Color(0.82, 0.88, 0.95)
const COLOR_HINT := Color(0.56, 0.64, 0.72)
const COLOR_INSTANCE := Color(0.46, 0.74, 1.0)
const COLOR_ACTION := Color(0.98, 0.82, 0.36)
const COLOR_CHARACTER := Color(0.56, 0.82, 1.0)
const COLOR_MOVE := Color(1.0, 0.78, 0.42)
const COLOR_WARDROBE := Color(0.62, 0.88, 0.58)
const COLOR_RUNTIME := Color(0.84, 0.72, 1.0)
const COLOR_PASS := Color(0.42, 0.88, 0.56)
const COLOR_WARN := Color(1.0, 0.78, 0.28)
const COLOR_FAIL := Color(1.0, 0.42, 0.36)
const COLOR_STATUS := Color(0.72, 0.78, 0.84)
const PREVIEW_FRAME_SECONDS := 1.0 / 12.0

signal bind_player_requested
signal bind_dummy_requested
signal add_npc_requested(template_id: String)
signal remove_selected_npc_requested
signal bind_npc_requested(index: int)
signal npc_template_selected(template_id: String)

var template_json: Dictionary = {}
var sprite_set_json: Dictionary = {}
var moves_json: Dictionary = {}
var selected_move: String = "idle"
var runtime: RefCounted = Runtime.new()
var bound_instance_ref = null
var bound_instance_id: String = ""
var bound_template_id: String = ""
var bound_sprite_set_id: String = ""
var bound_state: String = ""
var bound_move: String = ""
var bound_frame: int = 0
var bound_hp: String = ""
var bound_control_mode: String = ""
var coverage: Dictionary = {}
var current_action_id: String = "idle"
var preview_playing: bool = false
var preview_speed: float = 1.0
var preview_frame: int = 0
var preview_show_hurtboxes: bool = true
var preview_show_hitboxes: bool = true
var preview_show_foot: bool = true
var _preview_elapsed: float = 0.0
var npc_template_id: String = "combat_gray_s64"
var npc_count_current: int = 1
var npc_limit: int = 10
var selected_npc_index: int = 0
var npc_status: String = ""

var template_select: OptionButton
var npc_template_select: OptionButton
var npc_count_label: Label
var npc_status_label: Label
var move_select: OptionButton
var sprite_set_select: OptionButton
var coverage_list: ItemList
var status_label: Label
var runtime_label: Label
var preview_frame_label: Label
var preview_frame_slider: HSlider
var frame_slot_path_input: LineEdit
var action_preview_control: Control
var floating_preview_window: PanelContainer
var floating_preview_control: Control
var floating_preview_frame_label: Label
var navigation_list: ItemList
var values_panel: VBoxContainer
var detail_panel: VBoxContainer
var hp_input: LineEdit
var sprite_ref_input: LineEdit
var move_type_input: OptionButton
var state_context_input: OptionButton
var frame_count_input: LineEdit
var active_start_input: LineEdit
var active_end_input: LineEdit
var damage_input: LineEdit
var hitstop_input: LineEdit
var multi_hit_input: CheckBox
var hurtbox_select: OptionButton
var hurt_inputs := {}
var foot_inputs := {}
var hitbox_id_input: LineEdit
var hitbox_inputs := {}
var events_text: TextEdit
var current_nav: String = "character_template"
var current_hurtbox_id: String = "hurt_head"
var current_move_section: String = "summary"
var nav_keys: Array = []
var move_section_list: ItemList


func setup() -> void:
	set_process(true)
	_build_ui()
	_ensure_floating_preview_window()
	load_template_id("combat_gray_s64")


func _process(delta: float) -> void:
	if not preview_playing:
		return
	_preview_elapsed += delta * preview_speed
	if _preview_elapsed < PREVIEW_FRAME_SECONDS:
		return
	_preview_elapsed = 0.0
	var last_frame: int = maxi(0, _preview_frame_count() - 1)
	if preview_frame >= last_frame:
		preview_playing = false
		_refresh_action_preview()
		return
	preview_frame = mini(preview_frame + 1, last_frame)
	_refresh_action_preview()


func load_template_id(template_id: String) -> Array:
	template_json = DataStore.load_template(template_id)
	if template_json.is_empty():
		return _set_errors(["missing template %s" % template_id])
	sprite_set_json = DataStore.load_sprite_set(str(template_json["sprite_set_ref"]))
	moves_json.clear()
	for move_id in template_json["equipped_moves"]:
		moves_json[str(move_id)] = DataStore.load_move(str(move_id))
	if not template_json["equipped_moves"].is_empty():
		selected_move = str(template_json["equipped_moves"][0])
	_refresh_options()
	_refresh_fields()
	return validate_current()


func bind_instance(instance: Node) -> void:
	if instance == null:
		_set_status("bind failed: missing instance")
		return
	bound_instance_ref = weakref(instance)
	update_bound_instance_summary(instance)
	if bound_template_id.is_empty():
		_set_status("bound %s without template id" % bound_instance_id)
		_refresh_fields()
		return
	if not DataStore.list_template_ids().has(bound_template_id):
		_set_status("bound %s; missing v0.3 template %s" % [bound_instance_id, bound_template_id])
		_refresh_fields()
		return
	load_template_id(bound_template_id)
	_set_status("bound %s" % bound_instance_id)


func update_bound_instance_summary(instance: Node) -> void:
	if instance == null:
		return
	var summary: Dictionary = {}
	if instance.has_method("debug_summary"):
		summary = instance.debug_summary()
	bound_instance_id = str(summary.get("instance_id", _node_property(instance, "instance_id")))
	bound_template_id = str(summary.get("template_id", _node_property(instance, "template_id")))
	bound_sprite_set_id = str(summary.get("sprite_set_id", _node_property(instance, "sprite_set_id")))
	bound_state = str(summary.get("state", ""))
	bound_move = str(summary.get("move", ""))
	bound_frame = int(summary.get("frame", 0))
	bound_hp = str(summary.get("hp", ""))
	bound_control_mode = str(summary.get("mode", summary.get("control_mode", "")))
	if current_nav == "instance_binding":
		_refresh_three_panel()


func refresh_action_coverage() -> Dictionary:
	coverage = Coverage.analyze(template_json, sprite_set_json, moves_json)
	return coverage


func select_action(action_id: String) -> void:
	if Catalog.action_for(action_id).is_empty():
		return
	current_action_id = action_id
	var row := _coverage_row_for(action_id)
	var move_id := str(row.get("backing_move_id", ""))
	if moves_json.has(move_id):
		selected_move = move_id
	preview_frame = clampi(preview_frame, 0, maxi(0, _preview_frame_count() - 1))
	_refresh_fields()


func set_npc_summary(count: int, limit: int = 10, selected_index: int = 0, status: String = "") -> void:
	npc_limit = maxi(1, limit)
	npc_count_current = clampi(count, 1, npc_limit)
	selected_npc_index = clampi(selected_index, 0, maxi(0, npc_count_current - 1))
	npc_status = status
	_refresh_npc_controls()
	if current_nav == "instance_binding":
		_refresh_three_panel()


func update_npc_summary(summary: Dictionary) -> void:
	var template_id := str(summary.get("npc_template_id", npc_template_id))
	if not template_id.is_empty():
		npc_template_id = template_id
	var summary_status := str(summary.get("npc_status", summary.get("status", npc_status)))
	set_npc_summary(
		int(summary.get("npc_count", npc_count_current)),
		int(summary.get("npc_limit", npc_limit)),
		int(summary.get("selected_npc_index", selected_npc_index)),
		summary_status
	)
	_refresh_npc_controls()


func update_playground_summary(summary: Dictionary) -> void:
	update_npc_summary(summary)


func selected_npc_template_id() -> String:
	return npc_template_id


func selected_npc_bind_index() -> int:
	return selected_npc_index


func preview_play() -> void:
	if preview_frame >= maxi(0, _preview_frame_count() - 1):
		preview_frame = 0
	_preview_elapsed = 0.0
	preview_playing = true
	_refresh_action_preview()


func preview_pause() -> void:
	preview_playing = false
	_refresh_action_preview()


func preview_step_forward() -> void:
	preview_playing = false
	preview_frame = mini(preview_frame + 1, maxi(0, _preview_frame_count() - 1))
	_refresh_action_preview()


func preview_step_backward() -> void:
	preview_playing = false
	preview_frame = maxi(0, preview_frame - 1)
	_refresh_action_preview()


func preview_first() -> void:
	preview_playing = false
	preview_frame = 0
	_refresh_action_preview()


func preview_last() -> void:
	preview_playing = false
	preview_frame = maxi(0, _preview_frame_count() - 1)
	_refresh_action_preview()


func set_preview_frame(frame_index: int) -> void:
	preview_playing = false
	preview_frame = clampi(frame_index, 0, maxi(0, _preview_frame_count() - 1))
	_refresh_action_preview()


func preview_frame_count() -> int:
	return _preview_frame_count()


func preview_reset() -> void:
	preview_first()


func set_preview_speed(value: float) -> void:
	preview_speed = 0.5 if value < 0.75 else 1.0
	_refresh_action_preview()


func toggle_preview_window() -> void:
	set_preview_window_visible(not is_preview_window_visible())


func set_preview_window_visible(next_visible: bool) -> void:
	_ensure_floating_preview_window()
	if floating_preview_window == null:
		return
	floating_preview_window.visible = next_visible
	if next_visible:
		floating_preview_window.move_to_front()
		_refresh_action_preview()
	_set_status("preview window %s" % ("on" if next_visible else "off"))


func is_preview_window_visible() -> bool:
	return floating_preview_window != null and floating_preview_window.visible


func copy_template(copy_id: String = "") -> String:
	var source_id := str(template_json["template_id"])
	var next_id := copy_id if not copy_id.is_empty() else _next_copy_id(source_id)
	template_json = DataStore.duplicate_template(source_id, next_id)
	_refresh_options()
	_refresh_fields()
	_set_status("copied %s" % next_id)
	return next_id


func save_all() -> void:
	var errors := validate_current()
	if not errors.is_empty():
		return
	DataStore.save_template(template_json)
	for move_id in moves_json.keys():
		DataStore.save_move(moves_json[move_id])
	DataStore.save_sprite_set(sprite_set_json)
	var generation := SpriteFramesGeneratorScript.generate(sprite_set_json, {"moves": moves_json})
	if bool(generation.get("ok", false)):
		_set_status("saved %s + SpriteFrames generated" % str(template_json["template_id"]))
	else:
		_set_status("saved JSON; SpriteFrames generation FAIL: %s" % _diagnostic_codes(generation.get("errors", [])))


func apply_to_bound_instance() -> bool:
	var errors := validate_current()
	if not errors.is_empty():
		return false
	var instance := _bound_instance()
	if instance == null:
		_set_status("apply failed: no bound instance")
		return false

	var generation := SpriteFramesGeneratorScript.generate(sprite_set_json, {"moves": moves_json})
	if not bool(generation.get("ok", false)):
		_set_status("apply blocked: SpriteFrames generation FAIL: %s" % _diagnostic_codes(generation.get("errors", [])))
		return false

	if instance.has_method("apply_v0_3_runtime_bundle"):
		instance.apply_v0_3_runtime_bundle(template_json, sprite_set_json, moves_json)
	else:
		var max_hp := maxi(1, int(template_json.get("hp", 1)))
		instance.set("template_id", str(template_json.get("template_id", "")))
		instance.set("sprite_set_id", str(template_json.get("sprite_set_ref", "")))
		instance.set("max_hp", max_hp)
		instance.set("current_hp", mini(int(_node_property(instance, "current_hp")), max_hp))
		instance.set("hurtbox_profile", _runtime_hurtbox_profile())
		instance.set("foot_collision_profile", _runtime_foot_collision_profile())
		if instance.has_method("queue_redraw"):
			instance.queue_redraw()
	update_bound_instance_summary(instance)
	_set_status("applied v0.3 bundle to %s" % bound_instance_id)
	return true


func reload_current() -> Array:
	return load_template_id(str(template_json["template_id"]))


func save_reload_exact() -> bool:
	if not validate_current().is_empty():
		return false
	var before := _normalized_json_text(_current_state())
	save_all()
	var template_id := str(template_json["template_id"])
	var loaded_template := DataStore.load_template(template_id)
	var loaded_sprite_set := DataStore.load_sprite_set(str(loaded_template["sprite_set_ref"]))
	var loaded_moves := {}
	for move_id in loaded_template["equipped_moves"]:
		loaded_moves[str(move_id)] = DataStore.load_move(str(move_id))
	var after := _normalized_json_text({
		"template": loaded_template,
		"sprite_set": loaded_sprite_set,
		"moves": loaded_moves,
	})
	var ok := before == after
	if ok:
		template_json = loaded_template
		sprite_set_json = loaded_sprite_set
		moves_json = loaded_moves
		_set_status("roundtrip PASS")
	else:
		_set_status("roundtrip FAIL")
	_refresh_options()
	_refresh_fields()
	return ok


func validate_current() -> Array:
	var errors := DataStore.validate_runtime_bundle(_runtime_bundle())
	if errors.is_empty():
		_set_status("validation PASS")
	else:
		_set_errors(errors)
	_refresh_runtime()
	return errors


func set_hp(value: int) -> void:
	template_json["hp"] = maxi(1, value)
	_refresh_fields()


func set_sprite_set_ref(sprite_set_id: String) -> void:
	template_json["sprite_set_ref"] = sprite_set_id
	sprite_set_json = DataStore.load_sprite_set(sprite_set_id)
	_refresh_options()
	_refresh_fields()


func set_equipped_moves(move_ids: Array) -> void:
	template_json["equipped_moves"] = move_ids.duplicate()
	moves_json.clear()
	for move_id in template_json["equipped_moves"]:
		moves_json[str(move_id)] = DataStore.load_move(str(move_id))
	if not template_json["equipped_moves"].is_empty():
		selected_move = str(template_json["equipped_moves"][0])
	_refresh_options()
	_refresh_fields()


func set_hurtbox_rect(hurtbox_id: String, rect: Dictionary) -> void:
	template_json["hurtboxes"][hurtbox_id] = _rect_json(rect)
	_refresh_fields()


func set_foot_collision(center: Dictionary, radius: Dictionary) -> void:
	template_json["foot_collision"] = {
		"center": {"x": float(center["x"]), "y": float(center["y"])},
		"radius": {"x": maxf(1.0, float(radius["x"])), "y": maxf(1.0, float(radius["y"]))},
	}
	_refresh_fields()


func select_move(move_id: String) -> void:
	if moves_json.has(move_id):
		if selected_move != move_id:
			current_move_section = "summary"
		selected_move = move_id
		current_nav = "move:%s" % move_id
	_refresh_options()
	_refresh_fields()


func selected_move_json() -> Dictionary:
	return moves_json[selected_move]


func set_move_scalar(field: String, value) -> void:
	var move := selected_move_json()
	match field:
		"move_type":
			move["move_type"] = str(value)
		"state_context_override":
			if str(value).is_empty():
				move.erase("state_context_override")
			else:
				move["state_context_override"] = str(value)
		"frame_count", "damage", "hitstop_frames":
			move[field] = int(value)
		"multi_hit":
			move["multi_hit"] = bool(value)
	_refresh_fields()


func set_move_active_window(start_frame: int, end_frame: int) -> void:
	var move := selected_move_json()
	move["active_window"] = {"start_frame": start_frame, "end_frame": end_frame}
	_refresh_fields()


func set_first_hitbox(hitbox_id: String, start_frame: int, end_frame: int, rect: Dictionary) -> void:
	var move := selected_move_json()
	if move["hitboxes"].is_empty():
		move["hitboxes"].append({})
	move["hitboxes"][0] = {
		"hitbox_id": hitbox_id,
		"active_window": {"start_frame": start_frame, "end_frame": end_frame},
		"rect": _rect_json(rect),
	}
	_refresh_fields()


func set_move_events(events: Array) -> void:
	selected_move_json()["events"] = events.duplicate(true)
	_refresh_fields()


func insert_empty_frame_slot(sequence_id: String, frame_index: int, shift_timing: bool = false) -> bool:
	if not shift_timing:
		_set_status("frame insert blocked: choose shift timing")
		return false
	if not sprite_set_json.get("frame_sequences", {}).has(sequence_id):
		_set_status("frame insert failed: missing sequence %s" % sequence_id)
		return false
	var sequence: Array = sprite_set_json["frame_sequences"][sequence_id]
	var insert_index := clampi(frame_index, 0, sequence.size())
	sequence.insert(insert_index, _slot_uri("empty", sequence_id, insert_index))
	_shift_timing_after_insert(_move_id_for_sequence(sequence_id), insert_index)
	_refresh_after_slot_edit("inserted empty frame")
	return true


func remove_frame_slot(sequence_id: String, frame_index: int) -> bool:
	if not sprite_set_json.get("frame_sequences", {}).has(sequence_id):
		_set_status("frame remove failed: missing sequence %s" % sequence_id)
		return false
	var sequence: Array = sprite_set_json["frame_sequences"][sequence_id]
	if frame_index < 0 or frame_index >= sequence.size():
		_set_status("frame remove failed: frame out of range")
		return false
	var move_id := _move_id_for_sequence(sequence_id)
	if _frame_has_timing_reference(move_id, frame_index):
		_set_status("frame remove blocked: timing metadata references frame %d" % frame_index)
		return false
	sequence.remove_at(frame_index)
	_shift_timing_after_delete(move_id, frame_index)
	_refresh_after_slot_edit("removed frame")
	return true


func replace_frame_slot(sequence_id: String, frame_index: int, frame_path: String) -> bool:
	return _set_frame_slot(sequence_id, frame_index, frame_path, "replaced frame")


func mark_frame_slot(sequence_id: String, frame_index: int, slot_state: String) -> bool:
	if not ["empty", "missing", "placeholder"].has(slot_state):
		_set_status("frame mark failed: invalid slot state %s" % slot_state)
		return false
	return _set_frame_slot(sequence_id, frame_index, _slot_uri(slot_state, sequence_id, frame_index), "marked frame %s" % slot_state)


func wardrobe_coverage() -> Dictionary:
	var result := refresh_action_coverage()
	var missing_mapping: Array = []
	var missing_clips: Array = []
	var missing_sequences: Array = []
	for row in result.get("rows", []):
		var action_id := str(row.get("action_id", ""))
		if row.get("warnings", []).has(Coverage.INVALID_SPRITE_MAPPING):
			missing_mapping.append(action_id)
		if not bool(row.get("clip_exists", false)) and not str(row.get("clip_id", "")).is_empty():
			missing_clips.append(str(row.get("clip_id", "")))
		if row.get("warnings", []).has(Coverage.MISSING_FRAME_SEQUENCE):
			missing_sequences.append(str(row.get("frame_sequence_ref", "")))
	return {
		"missing_mapping": missing_mapping,
		"missing_clips": missing_clips,
		"missing_sequences": missing_sequences,
		"rows": result.get("rows", []),
		"summary": result.get("summary", {}),
	}


func runtime_start_selected_move() -> Array:
	_refresh_runtime()
	return runtime.start_move(selected_move)


func runtime_advance_frame(count: int = 1) -> void:
	for i in count:
		runtime.tick_frame()
	_refresh_runtime_label()


func runtime_reset_idle() -> Array:
	_refresh_runtime()
	return runtime.start_move("idle")


func runtime_summary() -> Dictionary:
	return runtime.debug_summary()


func _build_ui() -> void:
	custom_minimum_size = Vector2(560, 526)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.065, 0.075, 0.96)
	panel_style.border_color = Color(0.26, 0.34, 0.42, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", panel_style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 3)
	add_child(root)

	var title := Label.new()
	title.text = "Creator Lab v0.3 Action Lab"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	root.add_child(title)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 3)
	root.add_child(top)
	template_select = OptionButton.new()
	_style_control(template_select, 130, 18)
	template_select.item_selected.connect(_on_template_selected)
	top.add_child(template_select)
	top.add_child(_button("Bind P", _on_bind_player_pressed, 48))
	top.add_child(_button("Bind D", _on_bind_dummy_pressed, 48))
	top.add_child(_button("Save", _on_save_pressed))
	top.add_child(_button("Check", _on_check_pressed))

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 3)
	root.add_child(tools)
	tools.add_child(_button("Reload", _on_reload_pressed))
	tools.add_child(_button("Roundtrip", _on_exact_pressed))

	var main := HBoxContainer.new()
	main.custom_minimum_size = Vector2(546, 288)
	main.add_theme_constant_override("separation", 4)
	root.add_child(main)

	var nav_box := VBoxContainer.new()
	nav_box.custom_minimum_size = Vector2(114, 284)
	nav_box.add_theme_constant_override("separation", 2)
	main.add_child(nav_box)
	nav_box.add_child(_label("1 Choose", COLOR_CHARACTER))
	navigation_list = ItemList.new()
	navigation_list.custom_minimum_size = Vector2(114, 262)
	navigation_list.add_theme_font_size_override("font_size", 8)
	navigation_list.item_selected.connect(_on_navigation_selected)
	nav_box.add_child(navigation_list)

	var values_scroll := ScrollContainer.new()
	values_scroll.custom_minimum_size = Vector2(160, 284)
	values_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(values_scroll)
	values_panel = VBoxContainer.new()
	values_panel.custom_minimum_size = Vector2(120, 0)
	values_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values_panel.add_theme_constant_override("separation", 2)
	values_scroll.add_child(values_panel)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(264, 284)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(detail_scroll)
	detail_panel = VBoxContainer.new()
	detail_panel.custom_minimum_size = Vector2(252, 0)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_constant_override("separation", 2)
	detail_scroll.add_child(detail_panel)

	_build_persistent_preview_surface(root)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 8)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)


func _refresh_navigation() -> void:
	if navigation_list == null:
		return
	navigation_list.clear()
	nav_keys.clear()
	_add_nav_item("Instance", "instance_binding")
	_add_nav_item("Action Coverage", "action_coverage")
	_add_nav_item("Action Preview", "action_preview")
	_add_nav_item("Template", "character_template")
	_add_nav_item("Hurtboxes", "character_hurtboxes")
	_add_nav_item("Foot Collision", "character_foot")
	_add_nav_item("Moves", "character_moves")
	for move_id in template_json.get("equipped_moves", []):
		_add_nav_item("Move / %s" % str(move_id), "move:%s" % str(move_id))
	_add_nav_item("Wardrobe Map", "wardrobe_mapping")
	_add_nav_item("Wardrobe Clips", "wardrobe_clips")
	_add_nav_item("Wardrobe Frames", "wardrobe_sequences")
	_add_nav_item("Runtime", "runtime_preview")
	var selected_index := nav_keys.find(current_nav)
	if selected_index < 0:
		current_nav = "character_template"
		selected_index = 0
	if selected_index >= 0:
		navigation_list.select(selected_index)
		navigation_list.ensure_current_is_visible()


func _add_nav_item(text: String, key: String) -> void:
	navigation_list.add_item(text)
	navigation_list.set_item_custom_fg_color(navigation_list.item_count - 1, _nav_color(key))
	nav_keys.append(key)


func _refresh_three_panel() -> void:
	if values_panel == null or detail_panel == null:
		return
	_reset_editor_refs()
	_clear_children(values_panel)
	_clear_children(detail_panel)
	if current_nav.begins_with("move:"):
		var move_id := current_nav.substr(5)
		if moves_json.has(move_id):
			selected_move = move_id
		else:
			current_nav = "character_template"
	_refresh_navigation()
	_build_values_panel()
	_build_detail_panel()
	_refresh_runtime_label()


func _reset_editor_refs() -> void:
	npc_template_select = null
	npc_count_label = null
	npc_status_label = null
	move_select = null
	sprite_set_select = null
	coverage_list = null
	hp_input = null
	sprite_ref_input = null
	move_type_input = null
	state_context_input = null
	frame_count_input = null
	active_start_input = null
	active_end_input = null
	damage_input = null
	hitstop_input = null
	multi_hit_input = null
	hurtbox_select = null
	hurt_inputs = {}
	foot_inputs = {}
	hitbox_id_input = null
	hitbox_inputs = {}
	events_text = null
	runtime_label = null
	preview_frame_slider = null
	move_section_list = null


func _build_values_panel() -> void:
	values_panel.add_child(_label("2 Overview", _current_nav_color()))
	match current_nav:
		"instance_binding":
			_add_value("instance", _bound_or_none(bound_instance_id))
			_add_value("template", _bound_or_none(bound_template_id))
			_add_value("sprite set", _bound_or_none(bound_sprite_set_id))
			_add_value("state", _bound_or_none(bound_state))
			_add_value("move", _bound_or_none(bound_move))
			_add_value("frame", str(bound_frame))
			_add_value("hp", _bound_or_none(bound_hp))
			_add_value("mode", _bound_or_none(bound_control_mode))
			_add_value("npcs", "%d/%d" % [npc_count_current, npc_limit])
			_add_value("npc selected", str(selected_npc_index + 1))
			_add_value("npc template", npc_template_id)
			if not npc_status.is_empty():
				_add_value("npc status", npc_status)
		"action_coverage":
			var summary: Dictionary = coverage.get("summary", {})
			_add_value("required", str(coverage.get("rows", []).size()))
			_add_value("ok", str(summary.get("ok", 0)))
			_add_value("warning", str(summary.get("warning", 0)))
			_add_value("fail", str(summary.get("fail", 0)))
			_build_coverage_list(values_panel)
		"action_preview":
			var preview_row := _coverage_row_for(current_action_id)
			_add_value("action", str(preview_row.get("action_id", current_action_id)))
			_add_value("status", str(preview_row.get("status", "")))
			_add_value("clip", str(preview_row.get("clip_id", "")))
			_add_value("frames", "%s/%s" % [preview_row.get("sequence_frame_count", 0), preview_row.get("move_frame_count", 0)])
			_add_value("preview", "%d/%d" % [preview_frame + 1, _preview_frame_count()])
		"character_template":
			_add_value("id", str(template_json.get("template_id", "")))
			_add_value("sprite set", str(template_json.get("sprite_set_ref", "")))
			_add_value("hp", str(template_json.get("hp", "")))
			_add_value("moves", str(template_json.get("equipped_moves", []).size()))
		"character_hurtboxes":
			for hurtbox_id in template_json.get("hurtboxes", {}).keys():
				var rect: Dictionary = template_json["hurtboxes"][hurtbox_id]
				_add_value(str(hurtbox_id), _rect_summary(rect))
		"character_foot":
			var foot: Dictionary = template_json.get("foot_collision", {})
			if not foot.is_empty():
				_add_value("center", _xy_summary(foot.get("center", {})))
				_add_value("radius", _xy_summary(foot.get("radius", {})))
		"character_moves":
			for move_id in template_json.get("equipped_moves", []):
				_add_value(str(move_id), str(moves_json.get(str(move_id), {}).get("move_type", "")))
		"wardrobe_mapping":
			for coverage_row in coverage.get("rows", []):
				_add_value(str(coverage_row.get("action_id", "")), str(coverage_row.get("clip_id", "")))
		"wardrobe_clips":
			for coverage_row in coverage.get("rows", []):
				_add_value(str(coverage_row.get("clip_id", "")), "seq:%s" % str(coverage_row.get("frame_sequence_ref", "")))
		"wardrobe_sequences":
			for coverage_row in coverage.get("rows", []):
				_add_value(str(coverage_row.get("frame_sequence_ref", "")), "%s frames" % str(coverage_row.get("sequence_frame_count", 0)))
		"runtime_preview":
			var summary: Dictionary = runtime.debug_summary()
			_add_value("state", str(summary.get("current_state", "")))
			_add_value("move", str(summary.get("current_move", "")))
			_add_value("frame", str(summary.get("current_frame", 0)))
			_add_value("active boxes", str(summary.get("active_hitbox_count", 0)))
		_:
			if current_nav.begins_with("move:") and moves_json.has(selected_move):
				_build_move_values_panel()


func _build_detail_panel() -> void:
	detail_panel.add_child(_label("3 Edit + Preview", _current_nav_color()))
	match current_nav:
		"instance_binding":
			_build_instance_detail(detail_panel)
		"action_coverage":
			_build_action_coverage_detail(detail_panel)
		"action_preview":
			_build_action_preview_detail(detail_panel)
		"character_template":
			_build_template_detail(detail_panel)
		"character_hurtboxes":
			_build_hurtbox_detail(detail_panel)
		"character_foot":
			_build_foot_detail(detail_panel)
		"character_moves":
			_build_equipped_moves_detail(detail_panel)
		"wardrobe_mapping", "wardrobe_clips", "wardrobe_sequences":
			_build_wardrobe_detail(detail_panel)
		"runtime_preview":
			_build_runtime_detail(detail_panel)
		_:
			if current_nav.begins_with("move:") and moves_json.has(selected_move):
				_build_move_detail(detail_panel)


func _build_instance_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Selected runtime instance", COLOR_INSTANCE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	row.add_child(_button("Bind P", _on_bind_player_pressed, 48))
	row.add_child(_button("Bind D", _on_bind_dummy_pressed, 48))
	row.add_child(_button("Apply Bound", _on_apply_bound_pressed, 74))
	_build_npc_controls(parent)
	_add_detail_value(parent, "instance", _bound_or_none(bound_instance_id), COLOR_INSTANCE)
	_add_detail_value(parent, "template", _bound_or_none(bound_template_id), COLOR_INSTANCE)
	_add_detail_value(parent, "sprite set", _bound_or_none(bound_sprite_set_id), COLOR_INSTANCE)
	_add_detail_value(parent, "state", _bound_or_none(bound_state), COLOR_INSTANCE)
	_add_detail_value(parent, "move", _bound_or_none(bound_move), COLOR_INSTANCE)
	_add_detail_value(parent, "frame", str(bound_frame), COLOR_INSTANCE)
	_add_detail_value(parent, "hp", _bound_or_none(bound_hp), COLOR_INSTANCE)
	_add_detail_value(parent, "mode", _bound_or_none(bound_control_mode), COLOR_INSTANCE)


func _build_npc_controls(parent: VBoxContainer) -> void:
	parent.add_child(_label("NPC controls", COLOR_RUNTIME))
	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override("separation", 3)
	parent.add_child(spawn_row)
	npc_template_select = OptionButton.new()
	_style_control(npc_template_select, 128, 18)
	_populate_npc_template_select()
	npc_template_select.item_selected.connect(_on_npc_template_selected)
	spawn_row.add_child(npc_template_select)
	spawn_row.add_child(_button("Add NPC", _on_add_npc_pressed, 58))
	spawn_row.add_child(_button("Remove", _on_remove_selected_npc_pressed, 58))

	var bind_row := HBoxContainer.new()
	bind_row.add_theme_constant_override("separation", 3)
	parent.add_child(bind_row)
	bind_row.add_child(_button("Prev NPC", _on_npc_previous_pressed, 58))
	bind_row.add_child(_button("Bind NPC", _on_bind_npc_pressed, 58))
	bind_row.add_child(_button("Next NPC", _on_npc_next_pressed, 58))

	npc_count_label = _label("", COLOR_RUNTIME)
	parent.add_child(npc_count_label)
	npc_status_label = _label("", COLOR_HINT)
	npc_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(npc_status_label)
	_refresh_npc_controls()


func _build_action_coverage_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Action completeness", COLOR_ACTION))
	var row := _coverage_row_for(current_action_id)
	if row.is_empty():
		parent.add_child(_label("No catalog row selected.", COLOR_FAIL))
		return
	_add_detail_value(parent, "action", str(row.get("action_id", "")), _coverage_row_color(row))
	_add_detail_value(parent, "category", str(row.get("category", "")), COLOR_ACTION)
	_add_detail_value(parent, "state", str(row.get("state_context", "")), COLOR_ACTION)
	_add_detail_value(parent, "backing", str(row.get("backing", "")), COLOR_ACTION)
	_add_detail_value(parent, "clip", str(row.get("clip_id", "")), _coverage_row_color(row))
	_add_detail_value(parent, "sequence", str(row.get("frame_sequence_ref", "")), _coverage_row_color(row))
	_add_detail_value(parent, "frames", "%s sequence / %s move" % [row.get("sequence_frame_count", 0), row.get("move_frame_count", 0)], _coverage_row_color(row))
	_add_detail_value(parent, "visual", str(row.get("visual_role", "")), COLOR_ACTION)
	var warnings: Array = row.get("warnings", [])
	if warnings.is_empty():
		parent.add_child(_label("warnings: none", COLOR_PASS))
	else:
		parent.add_child(_label("warnings", COLOR_WARN if str(row.get("status", "")) == "WARNING" else COLOR_FAIL))
		for warning in warnings:
			parent.add_child(_label(str(warning), _coverage_row_color(row)))
	parent.add_child(_button("Preview", _on_preview_selected_action_pressed, 64))


func _build_action_preview_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Action preview", COLOR_ACTION))
	var action_select := OptionButton.new()
	_style_control(action_select, 132, 18)
	var selected_index := 0
	for row_index in coverage.get("rows", []).size():
		var row: Dictionary = coverage["rows"][row_index]
		action_select.add_item(str(row.get("action_id", "")))
		if str(row.get("action_id", "")) == current_action_id:
			selected_index = row_index
	if action_select.item_count > 0:
		action_select.select(selected_index)
	action_select.item_selected.connect(_on_preview_action_selected)
	_add_option_grid(parent, [["action", action_select]], 1)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 3)
	parent.add_child(controls)
	controls.add_child(_button("First", _on_preview_first_pressed, 44))
	controls.add_child(_button("Prev", _on_preview_step_back_pressed, 38))
	controls.add_child(_button("Play", _on_preview_play_pressed, 42))
	controls.add_child(_button("Pause", _on_preview_pause_pressed, 44))
	controls.add_child(_button("Next", _on_preview_step_pressed, 40))
	controls.add_child(_button("Last", _on_preview_last_pressed, 38))

	var scrub_row := HBoxContainer.new()
	scrub_row.add_theme_constant_override("separation", 4)
	parent.add_child(scrub_row)
	scrub_row.add_child(_compact_label("frame", COLOR_ACTION))
	preview_frame_slider = HSlider.new()
	preview_frame_slider.custom_minimum_size = Vector2(184, 18)
	preview_frame_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame_slider.min_value = 0
	preview_frame_slider.max_value = maxi(0, _preview_frame_count() - 1)
	preview_frame_slider.step = 1
	preview_frame_slider.value = preview_frame
	preview_frame_slider.focus_mode = Control.FOCUS_NONE
	preview_frame_slider.value_changed.connect(_on_preview_frame_slider_changed)
	scrub_row.add_child(preview_frame_slider)
	scrub_row.add_child(_button("Reset", _on_preview_reset_pressed, 42))

	var slot_path_row := HBoxContainer.new()
	slot_path_row.add_theme_constant_override("separation", 4)
	parent.add_child(slot_path_row)
	slot_path_row.add_child(_compact_label("slot", COLOR_ACTION))
	frame_slot_path_input = LineEdit.new()
	_style_control(frame_slot_path_input, 232, 16)
	frame_slot_path_input.text = _current_frame_slot_text()
	slot_path_row.add_child(frame_slot_path_input)
	slot_path_row.add_child(_button("Replace", _on_frame_slot_replace_pressed, 54))

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 3)
	parent.add_child(slot_row)
	slot_row.add_child(_button("Ins<+Shift", _on_frame_slot_insert_before_shift_pressed, 70))
	slot_row.add_child(_button("Ins>+Shift", _on_frame_slot_insert_after_shift_pressed, 70))
	slot_row.add_child(_button("Remove", _on_frame_slot_remove_pressed, 52))
	slot_row.add_child(_button("Empty", _on_frame_slot_mark_empty_pressed, 44))
	slot_row.add_child(_button("Missing", _on_frame_slot_mark_missing_pressed, 54))
	slot_row.add_child(_button("Hold", _on_frame_slot_mark_placeholder_pressed, 38))

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 3)
	parent.add_child(speed_row)
	speed_row.add_child(_button("0.5x", _on_preview_half_speed_pressed, 42))
	speed_row.add_child(_button("1x", _on_preview_normal_speed_pressed, 34))

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 3)
	parent.add_child(toggles)
	toggles.add_child(_preview_toggle("hurt", preview_show_hurtboxes, _on_preview_hurt_toggled))
	toggles.add_child(_preview_toggle("hit", preview_show_hitboxes, _on_preview_hit_toggled))
	toggles.add_child(_preview_toggle("foot", preview_show_foot, _on_preview_foot_toggled))

	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 3)
	parent.add_child(edit_row)
	edit_row.add_child(_button("Edit Move", _on_preview_edit_move_pressed, 62))
	edit_row.add_child(_button("Hitbox", _on_preview_edit_hitbox_pressed, 50))
	edit_row.add_child(_button("Hurt", _on_preview_edit_hurt_pressed, 42))
	edit_row.add_child(_button("Foot", _on_preview_edit_foot_pressed, 42))

	parent.add_child(_hint_label("Preview surface stays visible under this editor."))


func _build_template_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Character data", COLOR_CHARACTER))
	var stat_inputs := _add_bound_input_grid(parent, [
		["sprite", "sprite_ref_input", _on_sprite_ref_submitted, str(template_json.get("sprite_set_ref", "")), 88],
		["hp", "hp_input", _on_hp_submitted, int(template_json.get("hp", 0))],
	], 2)
	sprite_ref_input = stat_inputs["sprite_ref_input"]
	hp_input = stat_inputs["hp_input"]
	move_select = OptionButton.new()
	_style_control(move_select, 118, 18)
	for move_id in template_json.get("equipped_moves", []):
		move_select.add_item(str(move_id))
		if str(move_id) == selected_move:
			move_select.select(move_select.item_count - 1)
	move_select.item_selected.connect(_on_move_selected)
	_add_option_grid(parent, [["move", move_select]], 1)
	parent.add_child(_button("Duplicate", _on_copy_pressed, 70))


func _build_hurtbox_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Hurtbox - where this character can be hit", COLOR_CHARACTER))
	hurtbox_select = OptionButton.new()
	for id in template_json.get("hurtboxes", {}).keys():
		hurtbox_select.add_item(str(id))
		if str(id) == current_hurtbox_id:
			hurtbox_select.select(hurtbox_select.item_count - 1)
	hurtbox_select.item_selected.connect(_on_hurtbox_selected)
	_style_control(hurtbox_select, 118, 18)
	_add_option_grid(parent, [["box", hurtbox_select]], 1)
	parent.add_child(_label("selected hurtbox rectangle"))
	hurt_inputs = _add_input_grid(parent, ["x", "y", "w", "h"], _on_box_fields_submitted)
	if hurtbox_select.item_count > 0:
		var hurtbox_id := hurtbox_select.get_item_text(hurtbox_select.selected)
		_set_inputs(hurt_inputs, template_json.get("hurtboxes", {}).get(hurtbox_id, {}))
	parent.add_child(_hint_label("Save/Reload refreshes runtime preview."))


func _build_foot_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Foot collision - movement ground ellipse", COLOR_CHARACTER))
	parent.add_child(_label("ellipse center and radius"))
	foot_inputs = _add_input_grid(parent, ["center_x", "center_y", "radius_x", "radius_y"], _on_box_fields_submitted)
	var foot: Dictionary = template_json.get("foot_collision", {})
	if not foot.is_empty():
		_set_inputs(foot_inputs, {
			"center_x": foot["center"]["x"],
			"center_y": foot["center"]["y"],
			"radius_x": foot["radius"]["x"],
			"radius_y": foot["radius"]["y"],
		})
	parent.add_child(_hint_label("Movement contact shape, not damage."))


func _build_equipped_moves_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Equipped moves", COLOR_CHARACTER))
	move_select = OptionButton.new()
	_style_control(move_select, 118, 18)
	for move_id in template_json.get("equipped_moves", []):
		move_select.add_item(str(move_id))
		if str(move_id) == selected_move:
			move_select.select(move_select.item_count - 1)
	move_select.item_selected.connect(_on_move_selected)
	_add_option_grid(parent, [["move", move_select]], 1)
	parent.add_child(_hint_label("Choose a move to edit gameplay data."))


func _build_move_detail(parent: VBoxContainer) -> void:
	var move := selected_move_json()
	match current_move_section:
		"timing":
			_build_move_timing_detail(parent, move)
		"damage":
			_build_move_damage_detail(parent, move)
		"hitbox":
			_build_move_hitbox_detail(parent, move)
		"events":
			_build_move_events_detail(parent, move)
		_:
			_build_move_summary_detail(parent, move)


func _build_move_values_panel() -> void:
	var move := selected_move_json()
	_add_value("id", str(move.get("move_id", selected_move)))
	_add_value("type", str(move.get("move_type", "")))
	_add_value("frames", str(move.get("frame_count", 0)))
	_add_value("hitboxes", str(move.get("hitboxes", []).size()))
	_add_value("events", str(move.get("events", []).size()))
	values_panel.add_child(_label("Component", COLOR_MOVE))
	move_section_list = ItemList.new()
	move_section_list.custom_minimum_size = Vector2(120, 104)
	move_section_list.add_theme_font_size_override("font_size", 8)
	move_section_list.item_selected.connect(_on_move_section_selected)
	for row in [
		["Summary", "summary"],
		["Timing", "timing"],
		["Damage", "damage"],
		["Hitbox", "hitbox"],
		["Events", "events"],
	]:
		move_section_list.add_item(str(row[0]))
		move_section_list.set_item_metadata(move_section_list.item_count - 1, str(row[1]))
		move_section_list.set_item_custom_fg_color(move_section_list.item_count - 1, COLOR_MOVE)
	var index := _move_section_index(current_move_section)
	if index < 0:
		current_move_section = "summary"
		index = 0
	move_section_list.select(index)
	move_section_list.ensure_current_is_visible()
	values_panel.add_child(move_section_list)


func _build_move_summary_detail(parent: VBoxContainer, move: Dictionary) -> void:
	parent.add_child(_label("Move summary", COLOR_MOVE))
	move_type_input = OptionButton.new()
	for id in ["utility", "locomotion", "combat", "reaction"]:
		move_type_input.add_item(id)
	move_type_input.item_selected.connect(_on_move_type_selected)
	_style_control(move_type_input, 82, 18)
	_select_option(move_type_input, str(move.get("move_type", "")))
	state_context_input = OptionButton.new()
	for id in ["", "idle", "walk", "dash", "jump", "hurt", "dead"]:
		state_context_input.add_item(id)
	state_context_input.item_selected.connect(_on_state_context_selected)
	_style_control(state_context_input, 82, 18)
	_select_option(state_context_input, str(move.get("state_context_override", "")))
	_add_option_grid(parent, [
		["type", move_type_input],
		["state", state_context_input],
	], 2)
	multi_hit_input = CheckBox.new()
	multi_hit_input.text = "multi_hit"
	multi_hit_input.button_pressed = bool(move.get("multi_hit", false))
	multi_hit_input.toggled.connect(_on_multi_hit_toggled)
	multi_hit_input.add_theme_font_size_override("font_size", 8)
	parent.add_child(multi_hit_input)
	parent.add_child(_hint_label("Use middle panel for Timing, Hitbox, Events."))


func _build_move_timing_detail(parent: VBoxContainer, move: Dictionary) -> void:
	parent.add_child(_label("Timing", COLOR_MOVE))
	var inputs := _add_bound_input_grid(parent, [
		["frames", "frame_count_input", _on_frame_count_submitted, int(move.get("frame_count", 0))],
		["start", "active_start_input", _on_active_start_submitted, int(move.get("active_window", {}).get("start_frame", 0))],
		["end", "active_end_input", _on_active_end_submitted, int(move.get("active_window", {}).get("end_frame", 0))],
	], 3)
	frame_count_input = inputs["frame_count_input"]
	active_start_input = inputs["active_start_input"]
	active_end_input = inputs["active_end_input"]


func _build_move_damage_detail(parent: VBoxContainer, move: Dictionary) -> void:
	parent.add_child(_label("Damage", COLOR_MOVE))
	var inputs := _add_bound_input_grid(parent, [
		["damage", "damage_input", _on_damage_submitted, int(move.get("damage", 0))],
		["hitstop", "hitstop_input", _on_hitstop_submitted, int(move.get("hitstop_frames", 0))],
	], 2)
	damage_input = inputs["damage_input"]
	hitstop_input = inputs["hitstop_input"]
	parent.add_child(_hint_label("Hitstop freezes movement, animation, and hitboxes."))


func _build_move_hitbox_detail(parent: VBoxContainer, move: Dictionary) -> void:
	parent.add_child(_label("Hitbox", COLOR_MOVE))
	hitbox_id_input = _line_edit(_on_box_fields_submitted)
	parent.add_child(hitbox_id_input)
	hitbox_inputs = _add_input_grid(parent, ["start_frame", "end_frame", "x", "y", "w", "h"], _on_box_fields_submitted)
	var hitboxes: Array = move.get("hitboxes", [])
	if hitboxes.size() > 1:
		parent.add_child(_hint_label("Editing first hitbox only; %d additional hitbox(es) remain unchanged." % (hitboxes.size() - 1)))
	if not hitboxes.is_empty():
		var hitbox: Dictionary = hitboxes[0]
		hitbox_id_input.text = str(hitbox["hitbox_id"])
		var window: Dictionary = hitbox["active_window"]
		var rect: Dictionary = hitbox["rect"]
		_set_inputs(hitbox_inputs, {
			"start_frame": window["start_frame"],
			"end_frame": window["end_frame"],
			"x": rect["x"],
			"y": rect["y"],
			"w": rect["w"],
			"h": rect["h"],
		})
	else:
		hitbox_id_input.text = "hit_fist_1"
		_set_inputs(hitbox_inputs, {"start_frame": 0, "end_frame": 0, "x": 0, "y": 0, "w": 1, "h": 1})


func _build_move_events_detail(parent: VBoxContainer, move: Dictionary) -> void:
	parent.add_child(_label("Frame events JSON", COLOR_MOVE))
	events_text = TextEdit.new()
	events_text.custom_minimum_size = Vector2(188, 102)
	events_text.add_theme_font_size_override("font_size", 8)
	events_text.text = JSON.stringify(move.get("events", []), "\t", true)
	parent.add_child(events_text)
	parent.add_child(_button("Apply", _on_events_apply_pressed, 58))


func _build_wardrobe_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Wardrobe coverage - sprite-set view", COLOR_WARDROBE))
	sprite_set_select = OptionButton.new()
	_style_control(sprite_set_select, 118, 18)
	for id in DataStore.list_sprite_set_ids():
		sprite_set_select.add_item(id)
		if id == str(template_json.get("sprite_set_ref", "")):
			sprite_set_select.select(sprite_set_select.item_count - 1)
	sprite_set_select.item_selected.connect(_on_sprite_set_selected)
	_add_option_grid(parent, [["set", sprite_set_select]], 1)
	var coverage := wardrobe_coverage()
	var summary: Dictionary = coverage.get("summary", {})
	parent.add_child(_label("ok:%s warn:%s fail:%s" % [summary.get("ok", 0), summary.get("warning", 0), summary.get("fail", 0)], COLOR_WARDROBE))
	for row in coverage.get("rows", []):
		parent.add_child(_label("%s -> %s  %s" % [
			str(row.get("action_id", "")),
			str(row.get("clip_id", "")),
			str(row.get("status", "")),
		], _coverage_row_color(row)))
	parent.add_child(_button("Validate", _on_check_pressed, 64))
	parent.add_child(_button("Generate Stub", _on_wardrobe_generate_stub_pressed, 88))


func _build_runtime_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Runtime preview - frame stepper", COLOR_RUNTIME))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	row.add_child(_button("Start", _on_runtime_start_pressed))
	row.add_child(_button("+1", _on_runtime_one_pressed))
	row.add_child(_button("+4", _on_runtime_four_pressed))
	row.add_child(_button("Idle", _on_runtime_idle_pressed))
	runtime_label = Label.new()
	runtime_label.add_theme_font_size_override("font_size", 8)
	runtime_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(runtime_label)


func _build_persistent_preview_surface(parent: VBoxContainer) -> void:
	var shell := HBoxContainer.new()
	shell.custom_minimum_size = Vector2(546, 136)
	shell.add_theme_constant_override("separation", 4)
	parent.add_child(shell)

	var meta := VBoxContainer.new()
	meta.custom_minimum_size = Vector2(112, 132)
	meta.add_theme_constant_override("separation", 2)
	shell.add_child(meta)
	meta.add_child(_label("4 Preview", COLOR_ACTION))
	preview_frame_label = _label("", COLOR_ACTION)
	preview_frame_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_child(preview_frame_label)

	action_preview_control = ActionPreview.new()
	action_preview_control.custom_minimum_size = Vector2(430, 132)
	action_preview_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(action_preview_control)


func _ensure_floating_preview_window() -> void:
	if floating_preview_window != null:
		return
	var host := get_parent()
	if host == null:
		call_deferred("_ensure_floating_preview_window")
		return

	floating_preview_window = PanelContainer.new()
	floating_preview_window.name = "selected_sprite_preview_window"
	floating_preview_window.position = Vector2(8, 92)
	floating_preview_window.custom_minimum_size = Vector2(292, 252)
	floating_preview_window.size = Vector2(292, 252)
	floating_preview_window.visible = false
	floating_preview_window.mouse_filter = Control.MOUSE_FILTER_STOP
	floating_preview_window.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.048, 0.99)
	style.border_color = COLOR_ACTION
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	floating_preview_window.add_theme_stylebox_override("panel", style)
	host.add_child(floating_preview_window)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	floating_preview_window.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)
	var title := _label("Selected Sprite Preview", COLOR_ACTION)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("V", _on_preview_window_toggle_pressed, 26))

	floating_preview_frame_label = _label("", COLOR_HINT)
	root.add_child(floating_preview_frame_label)

	floating_preview_control = ActionPreview.new()
	floating_preview_control.custom_minimum_size = Vector2(276, 202)
	floating_preview_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floating_preview_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(floating_preview_control)


func _build_coverage_list(parent: VBoxContainer) -> void:
	coverage_list = ItemList.new()
	coverage_list.custom_minimum_size = Vector2(144, 156)
	coverage_list.add_theme_font_size_override("font_size", 8)
	coverage_list.item_selected.connect(_on_action_coverage_selected)
	var selected_index := 0
	for i in coverage.get("rows", []).size():
		var row: Dictionary = coverage["rows"][i]
		var text := "%s  %s" % [str(row.get("action_id", "")), str(row.get("status", ""))]
		coverage_list.add_item(text)
		coverage_list.set_item_metadata(coverage_list.item_count - 1, str(row.get("action_id", "")))
		coverage_list.set_item_custom_fg_color(coverage_list.item_count - 1, _coverage_row_color(row))
		if str(row.get("action_id", "")) == current_action_id:
			selected_index = i
	if coverage_list.item_count > 0:
		coverage_list.select(selected_index)
	parent.add_child(coverage_list)


func _add_value(label_text: String, value_text: String) -> void:
	values_panel.add_child(_label("%s: %s" % [label_text, value_text], COLOR_HINT))


func _add_detail_value(parent: VBoxContainer, label_text: String, value_text: String, color: Color = COLOR_HINT) -> void:
	parent.add_child(_label("%s: %s" % [label_text, value_text], color))


func _preview_toggle(text: String, pressed: bool, callback: Callable) -> CheckBox:
	var toggle := CheckBox.new()
	toggle.text = text
	toggle.button_pressed = pressed
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_font_size_override("font_size", 8)
	toggle.toggled.connect(callback)
	return toggle


func _populate_npc_template_select() -> void:
	if npc_template_select == null:
		return
	npc_template_select.clear()
	var ids := DataStore.list_template_ids()
	if ids.is_empty():
		return
	if npc_template_id.is_empty() or not ids.has(npc_template_id):
		npc_template_id = str(ids[0])
	for id in ids:
		npc_template_select.add_item(str(id))
		if str(id) == npc_template_id:
			npc_template_select.select(npc_template_select.item_count - 1)


func _refresh_npc_controls() -> void:
	if npc_template_select != null:
		_populate_npc_template_select()
	if npc_count_label != null:
		npc_count_label.text = "NPCs: %d / %d  selected: %d" % [npc_count_current, npc_limit, selected_npc_index + 1]
	if npc_status_label != null:
		npc_status_label.text = "status: %s" % (npc_status if not npc_status.is_empty() else "ready")
		npc_status_label.add_theme_color_override("font_color", _status_color(npc_status))


func _set_npc_status(text: String) -> void:
	npc_status = text
	_refresh_npc_controls()
	_set_status(text)


func _rect_summary(rect: Dictionary) -> String:
	return "x:%s y:%s w:%s h:%s" % [rect.get("x", 0), rect.get("y", 0), rect.get("w", 0), rect.get("h", 0)]


func _xy_summary(value: Dictionary) -> String:
	return "x:%s y:%s" % [value.get("x", 0), value.get("y", 0)]


func _bound_or_none(value: String) -> String:
	return value if not value.is_empty() else "none"


func _coverage_row_for(action_id: String) -> Dictionary:
	if coverage.is_empty():
		refresh_action_coverage()
	for row in coverage.get("rows", []):
		if str(row.get("action_id", "")) == action_id:
			return row
	return {}


func _current_sequence_ref() -> String:
	return str(_coverage_row_for(current_action_id).get("frame_sequence_ref", ""))


func _current_frame_slot_text() -> String:
	var sequence_ref := _current_sequence_ref()
	var sequences: Dictionary = sprite_set_json.get("frame_sequences", {})
	if not sequences.has(sequence_ref):
		return ""
	var sequence: Array = sequences[sequence_ref]
	if preview_frame >= 0 and preview_frame < sequence.size():
		return str(sequence[preview_frame])
	return ""


func _set_frame_slot(sequence_id: String, frame_index: int, frame_path: String, status_text: String) -> bool:
	if not sprite_set_json.get("frame_sequences", {}).has(sequence_id):
		_set_status("frame edit failed: missing sequence %s" % sequence_id)
		return false
	_ensure_sequence_frame(sequence_id, frame_index)
	sprite_set_json["frame_sequences"][sequence_id][frame_index] = frame_path
	_refresh_after_slot_edit(status_text)
	return true


func _ensure_sequence_frame(sequence_id: String, frame_index: int) -> void:
	var sequence: Array = sprite_set_json["frame_sequences"][sequence_id]
	while sequence.size() <= frame_index:
		sequence.append(_slot_uri("empty", sequence_id, sequence.size()))


func _slot_uri(slot_state: String, sequence_id: String, frame_index: int) -> String:
	return "%s://%s/%s/frame_%03d.png" % [slot_state, str(sprite_set_json.get("sprite_set_id", "sprite_set")), sequence_id, frame_index]


func _move_id_for_sequence(sequence_id: String) -> String:
	if coverage.is_empty():
		refresh_action_coverage()
	for row in coverage.get("rows", []):
		if str(row.get("frame_sequence_ref", "")) == sequence_id:
			return str(row.get("backing_move_id", ""))
	if moves_json.has(sequence_id):
		return sequence_id
	return ""


func _frame_has_timing_reference(move_id: String, frame_index: int) -> bool:
	if move_id.is_empty() or not moves_json.has(move_id):
		return false
	var move: Dictionary = moves_json[move_id]
	if _window_contains(move.get("active_window", {}), frame_index):
		return true
	for hitbox in move.get("hitboxes", []):
		if _window_contains(hitbox.get("active_window", {}), frame_index):
			return true
	for event in move.get("events", []):
		if int(event.get("frame", -1)) == frame_index:
			return true
	return false


func _window_contains(window: Dictionary, frame_index: int) -> bool:
	return frame_index >= int(window.get("start_frame", 0)) and frame_index <= int(window.get("end_frame", -1))


func _shift_timing_after_insert(move_id: String, frame_index: int) -> void:
	if move_id.is_empty() or not moves_json.has(move_id):
		return
	var move: Dictionary = moves_json[move_id]
	move["frame_count"] = maxi(1, int(move.get("frame_count", 1)) + 1)
	_shift_window_after_insert(move.get("active_window", {}), frame_index)
	for hitbox in move.get("hitboxes", []):
		_shift_window_after_insert(hitbox.get("active_window", {}), frame_index)
	for event in move.get("events", []):
		if int(event.get("frame", -1)) >= frame_index:
			event["frame"] = int(event["frame"]) + 1


func _shift_timing_after_delete(move_id: String, frame_index: int) -> void:
	if move_id.is_empty() or not moves_json.has(move_id):
		return
	var move: Dictionary = moves_json[move_id]
	move["frame_count"] = maxi(1, int(move.get("frame_count", 1)) - 1)
	_shift_window_after_delete(move.get("active_window", {}), frame_index)
	for hitbox in move.get("hitboxes", []):
		_shift_window_after_delete(hitbox.get("active_window", {}), frame_index)
	for event in move.get("events", []):
		if int(event.get("frame", -1)) > frame_index:
			event["frame"] = int(event["frame"]) - 1


func _shift_window_after_insert(window: Dictionary, frame_index: int) -> void:
	if window.is_empty():
		return
	if int(window.get("start_frame", 0)) >= frame_index:
		window["start_frame"] = int(window["start_frame"]) + 1
	if int(window.get("end_frame", 0)) >= frame_index:
		window["end_frame"] = int(window["end_frame"]) + 1


func _shift_window_after_delete(window: Dictionary, frame_index: int) -> void:
	if window.is_empty():
		return
	if int(window.get("start_frame", 0)) > frame_index:
		window["start_frame"] = int(window["start_frame"]) - 1
	if int(window.get("end_frame", 0)) > frame_index:
		window["end_frame"] = int(window["end_frame"]) - 1


func _refresh_after_slot_edit(status_text: String) -> void:
	refresh_action_coverage()
	_refresh_fields()
	_set_status(status_text)


func _coverage_row_color(row: Dictionary) -> Color:
	match str(row.get("status", "")):
		"OK":
			return COLOR_PASS
		"WARNING":
			return COLOR_WARN
	return COLOR_FAIL


func _preview_frame_count() -> int:
	var row := _coverage_row_for(current_action_id)
	if row.is_empty():
		return 1
	var sequence_count := 0
	var sequence_ref := str(row.get("frame_sequence_ref", ""))
	var sequences: Dictionary = sprite_set_json.get("frame_sequences", {})
	if sequences.has(sequence_ref):
		sequence_count = sequences[sequence_ref].size()
	var move_count := 0
	var move_id := str(row.get("backing_move_id", ""))
	if moves_json.has(move_id):
		move_count = int(moves_json[move_id].get("frame_count", 1))
	return maxi(1, maxi(sequence_count, move_count))


func _clamp_preview_frame() -> void:
	preview_frame = clampi(preview_frame, 0, maxi(0, _preview_frame_count() - 1))


func _refresh_action_preview() -> void:
	_clamp_preview_frame()
	var status_text := _preview_status_text()
	if preview_frame_label != null:
		preview_frame_label.text = status_text
	if floating_preview_frame_label != null:
		floating_preview_frame_label.text = status_text
	if preview_frame_slider != null:
		preview_frame_slider.max_value = maxi(0, _preview_frame_count() - 1)
		preview_frame_slider.set_value_no_signal(preview_frame)
	if frame_slot_path_input != null and not frame_slot_path_input.has_focus():
		frame_slot_path_input.text = _current_frame_slot_text()
	_apply_preview_to_control(action_preview_control)
	_apply_preview_to_control(floating_preview_control)


func _preview_status_text() -> String:
	return "%s %s  f:%d/%d  %.1fx" % [
		"play" if preview_playing else "pause",
		current_action_id,
		preview_frame + 1,
		_preview_frame_count(),
		preview_speed,
	]


func _apply_preview_to_control(control: Control) -> void:
	if control == null or not control.has_method("set_preview_data"):
		return
	control.set_preview_data(_coverage_row_for(current_action_id), template_json, sprite_set_json, moves_json)
	control.set_overlay_visibility(preview_show_hurtboxes, preview_show_hitboxes, preview_show_foot)
	control.set_frame(preview_frame)


func _node_property(instance: Node, property_name: String):
	if instance == null:
		return ""
	var value = instance.get(property_name)
	return value if value != null else ""


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _refresh_options() -> void:
	if template_select != null:
		template_select.clear()
		for id in DataStore.list_template_ids():
			template_select.add_item(id)
			if id == str(template_json.get("template_id", "")):
				template_select.select(template_select.item_count - 1)
	if move_select != null:
		move_select.clear()
		for id in template_json.get("equipped_moves", []):
			move_select.add_item(str(id))
			if str(id) == selected_move:
				move_select.select(move_select.item_count - 1)
	if sprite_set_select != null:
		sprite_set_select.clear()
		for id in DataStore.list_sprite_set_ids():
			sprite_set_select.add_item(id)
			if id == str(template_json.get("sprite_set_ref", "")):
				sprite_set_select.select(sprite_set_select.item_count - 1)
	if npc_template_select != null:
		_populate_npc_template_select()
	_refresh_navigation()


func _refresh_fields() -> void:
	refresh_action_coverage()
	_clamp_preview_frame()
	_refresh_three_panel()
	_refresh_action_preview()
	_refresh_runtime()


func _refresh_runtime() -> Array:
	var errors: Array = runtime.load_bundle(_runtime_bundle())
	_refresh_runtime_label()
	return errors


func _refresh_runtime_label() -> void:
	if runtime_label == null:
		return
	var summary: Dictionary = runtime.debug_summary()
	runtime_label.text = "state:%s move:%s frame:%s hitstop:%s boxes:%s set:%s" % [
		summary.get("current_state", ""),
		summary.get("current_move", ""),
		summary.get("current_frame", 0),
		summary.get("hitstop_frames", 0),
		summary.get("active_hitbox_count", 0),
		summary.get("sprite_set_ref", ""),
	]


func _runtime_bundle() -> Dictionary:
	return {
		"template": template_json,
		"sprite_set": sprite_set_json,
		"moves": moves_json,
	}


func _current_state() -> Dictionary:
	return {
		"template": template_json,
		"sprite_set": sprite_set_json,
		"moves": moves_json,
	}


func _normalized_json_text(data: Dictionary) -> String:
	var json_text := JSON.stringify(data, "\t", true)
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return json_text
	return JSON.stringify(json.data, "\t", true)


func _next_copy_id(source_id: String) -> String:
	var base_id := "%s_copy" % source_id
	var ids := DataStore.list_template_ids()
	if not ids.has(base_id):
		return base_id
	var index := 2
	while ids.has("%s_%d" % [base_id, index]):
		index += 1
	return "%s_%d" % [base_id, index]


func _rect_json(rect: Dictionary) -> Dictionary:
	return {
		"x": float(rect["x"]),
		"y": float(rect["y"]),
		"w": maxf(1.0, float(rect["w"])),
		"h": maxf(1.0, float(rect["h"])),
	}


func _rect_from_json(rect: Dictionary) -> Rect2:
	return Rect2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)), maxf(1.0, float(rect.get("w", 1.0))), maxf(1.0, float(rect.get("h", 1.0))))


func _vector_from_json(value: Dictionary) -> Vector2:
	return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))


func _runtime_hurtbox_profile() -> Dictionary:
	var profile := {}
	for hurtbox_id in template_json.get("hurtboxes", {}).keys():
		profile[str(hurtbox_id)] = _rect_from_json(template_json["hurtboxes"][hurtbox_id])
	return profile


func _runtime_foot_collision_profile() -> Dictionary:
	var foot: Dictionary = template_json.get("foot_collision", {})
	return {
		"center": _vector_from_json(foot.get("center", {})),
		"radius": _vector_from_json(foot.get("radius", {})),
	}


func _bound_instance() -> Node:
	if bound_instance_ref == null:
		return null
	var instance = bound_instance_ref.get_ref()
	if instance is Node:
		return instance
	return null


func _button(text: String, callback: Callable, width: int = 0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 18)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 8)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _line_edit(callback: Callable) -> LineEdit:
	var input := LineEdit.new()
	_style_control(input, 110, 18)
	input.set_meta("submit_handled", false)
	input.text_submitted.connect(func(_text: String) -> void:
		input.set_meta("submit_handled", true)
		callback.call()
		call_deferred("_clear_line_edit_submit_guard", input)
	)
	input.focus_exited.connect(func() -> void:
		if bool(input.get_meta("submit_handled", false)):
			return
		if not input.is_visible_in_tree():
			return
		callback.call()
	)
	return input


func _clear_line_edit_submit_guard(input: LineEdit) -> void:
	if is_instance_valid(input):
		input.set_meta("submit_handled", false)


func _add_input_grid(parent: VBoxContainer, fields: Array, callback: Callable) -> Dictionary:
	var inputs := {}
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	parent.add_child(grid)
	for field in fields:
		grid.add_child(_compact_label(_field_label(str(field))))
		var input := _line_edit(callback)
		_style_control(input, 34, 16)
		grid.add_child(input)
		inputs[str(field)] = input
	return inputs


func _add_bound_input_grid(parent: VBoxContainer, rows: Array, pair_columns: int = 3) -> Dictionary:
	var inputs := {}
	var grid := GridContainer.new()
	grid.columns = maxi(1, pair_columns) * 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	parent.add_child(grid)
	for row in rows:
		grid.add_child(_compact_label(str(row[0])))
		var input := _line_edit(row[2])
		var width := 42
		if row.size() > 4:
			width = int(row[4])
		_style_control(input, width, 16)
		input.text = str(row[3])
		var property_name := str(row[1])
		set(property_name, input)
		inputs[property_name] = input
		grid.add_child(input)
	return inputs


func _add_option_grid(parent: VBoxContainer, rows: Array, pair_columns: int = 2) -> void:
	var grid := GridContainer.new()
	grid.columns = maxi(1, pair_columns) * 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	parent.add_child(grid)
	for row in rows:
		grid.add_child(_compact_label(str(row[0])))
		var option: OptionButton = row[1]
		grid.add_child(option)


func _field_label(field: String) -> String:
	match field:
		"start_frame":
			return "start"
		"end_frame":
			return "end"
		"center_x":
			return "cx"
		"center_y":
			return "cy"
		"radius_x":
			return "rx"
		"radius_y":
			return "ry"
	return field


func _label(text: String, color: Color = COLOR_LABEL) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _hint_label(text: String) -> Label:
	return _label(text, COLOR_HINT)


func _compact_label(text: String, color: Color = COLOR_LABEL) -> Label:
	var label := _label(text, color)
	label.custom_minimum_size = Vector2(18, 16)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


func _nav_color(key: String) -> Color:
	if key.begins_with("instance"):
		return COLOR_INSTANCE
	if key.begins_with("action"):
		return COLOR_ACTION
	if key.begins_with("move:"):
		return COLOR_MOVE
	if key.begins_with("wardrobe"):
		return COLOR_WARDROBE
	if key.begins_with("runtime"):
		return COLOR_RUNTIME
	return COLOR_CHARACTER


func _current_nav_color() -> Color:
	return _nav_color(current_nav)


func _status_color(text: String) -> Color:
	var lower := text.to_lower()
	if lower.contains("fail") or lower.contains("invalid") or lower.contains("missing"):
		return COLOR_FAIL
	if lower.contains("warn") or lower.contains("placeholder") or lower.contains("bound") or lower.contains("blocked") or lower.contains("minimum") or lower.contains("maximum"):
		return COLOR_WARN
	if lower.contains("pass") or lower.contains("saved") or lower.contains("copied"):
		return COLOR_PASS
	return COLOR_STATUS


func _style_control(control: Control, width: int, height: int) -> void:
	control.custom_minimum_size = Vector2(width, height)
	control.add_theme_font_size_override("font_size", 8)
	if control is OptionButton:
		control.add_theme_font_size_override("font_size", 8)
		control.add_theme_font_size_override("popup_font_size", 8)
		control.add_theme_constant_override("h_separation", 4)
		_style_option_popup(control)
	if not (control is LineEdit):
		control.focus_mode = Control.FOCUS_NONE


func _style_option_popup(option: OptionButton) -> void:
	var popup := option.get_popup()
	if popup == null:
		return
	popup.add_theme_font_size_override("font_size", 8)
	popup.add_theme_constant_override("v_separation", 0)
	popup.add_theme_constant_override("item_start_padding", 2)
	popup.add_theme_constant_override("item_end_padding", 2)
	var blank_icon := _blank_popup_icon()
	for icon_name in ["checked", "unchecked", "radio_checked", "radio_unchecked"]:
		popup.add_theme_icon_override(icon_name, blank_icon)


func _blank_popup_icon() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _move_section_index(section: String) -> int:
	for i in 5:
		match i:
			0:
				if section == "summary":
					return i
			1:
				if section == "timing":
					return i
			2:
				if section == "damage":
					return i
			3:
				if section == "hitbox":
					return i
			4:
				if section == "events":
					return i
	return -1


func _select_option(option: OptionButton, value: String) -> void:
	if option == null:
		return
	for i in option.item_count:
		if option.get_item_text(i) == value:
			option.select(i)
			return


func _set_inputs(inputs: Dictionary, values: Dictionary) -> void:
	for key in inputs.keys():
		inputs[key].text = str(values.get(key, "0"))


func _number_from(inputs: Dictionary, key: String) -> float:
	var input: LineEdit = inputs[key]
	if input.text.is_valid_float():
		return float(input.text)
	return 0.0


func _validate_number_inputs(inputs: Dictionary, fields: Array) -> bool:
	var invalid: Array = []
	for field in fields:
		var key := str(field)
		if not inputs.has(key):
			continue
		var input: LineEdit = inputs[key]
		var ok := input != null and input.text.is_valid_float()
		_set_line_edit_valid(input, ok)
		if not ok:
			invalid.append(key)
	if invalid.is_empty():
		return true
	_set_status("invalid numeric input: %s" % ", ".join(invalid))
	return false


func _set_line_edit_valid(input: LineEdit, valid: bool) -> void:
	if input == null:
		return
	if valid:
		input.remove_theme_color_override("font_color")
	else:
		input.add_theme_color_override("font_color", COLOR_FAIL)


func _diagnostic_codes(diagnostics: Array) -> String:
	var codes: Array = []
	for diagnostic in diagnostics:
		if typeof(diagnostic) == TYPE_DICTIONARY:
			codes.append(str(diagnostic.get("code", diagnostic)))
		else:
			codes.append(str(diagnostic))
	if codes.is_empty():
		return "unknown"
	return ", ".join(codes)


func _is_hitbox_id_valid(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^hit_[a-z0-9_]+$")
	return expression.search(value) != null


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
		status_label.add_theme_color_override("font_color", _status_color(text))


func _set_errors(errors: Array) -> Array:
	_set_status("validation FAIL: %s" % ", ".join(errors))
	return errors


func _on_template_selected(index: int) -> void:
	load_template_id(template_select.get_item_text(index))


func _on_bind_player_pressed() -> void:
	bind_player_requested.emit()


func _on_bind_dummy_pressed() -> void:
	bind_dummy_requested.emit()


func _on_npc_template_selected(index: int) -> void:
	if npc_template_select == null or index < 0 or index >= npc_template_select.item_count:
		return
	npc_template_id = npc_template_select.get_item_text(index)
	npc_template_selected.emit(npc_template_id)
	_set_npc_status("NPC template selected: %s" % npc_template_id)


func _on_add_npc_pressed() -> void:
	add_npc_requested.emit(npc_template_id)
	_set_npc_status("add NPC requested: %s" % npc_template_id)


func _on_remove_selected_npc_pressed() -> void:
	remove_selected_npc_requested.emit()
	_set_npc_status("remove NPC requested: %d" % (selected_npc_index + 1))


func _on_npc_previous_pressed() -> void:
	_select_npc_index(selected_npc_index - 1, true)


func _on_npc_next_pressed() -> void:
	_select_npc_index(selected_npc_index + 1, true)


func _on_bind_npc_pressed() -> void:
	_select_npc_index(selected_npc_index, true)


func _select_npc_index(index: int, emit_request: bool) -> void:
	selected_npc_index = clampi(index, 0, maxi(0, npc_count_current - 1))
	_refresh_npc_controls()
	if emit_request:
		bind_npc_requested.emit(selected_npc_index)
		_set_npc_status("bind NPC requested: %d" % (selected_npc_index + 1))


func _on_apply_bound_pressed() -> void:
	apply_to_bound_instance()


func _on_navigation_selected(index: int) -> void:
	if index < 0 or index >= nav_keys.size():
		return
	current_nav = str(nav_keys[index])
	if current_nav.begins_with("move:"):
		var move_id := current_nav.substr(5)
		if moves_json.has(move_id) and selected_move != move_id:
			selected_move = move_id
			current_move_section = "summary"
	_refresh_fields()


func _on_action_coverage_selected(index: int) -> void:
	if coverage_list == null or index < 0 or index >= coverage_list.item_count:
		return
	var action_id := str(coverage_list.get_item_metadata(index))
	current_action_id = action_id
	var row := _coverage_row_for(action_id)
	var move_id := str(row.get("backing_move_id", ""))
	if moves_json.has(move_id):
		selected_move = move_id
	_refresh_fields()


func _on_preview_selected_action_pressed() -> void:
	current_nav = "action_preview"
	_refresh_fields()


func _on_preview_action_selected(index: int) -> void:
	var rows: Array = coverage.get("rows", [])
	if index < 0 or index >= rows.size():
		return
	select_action(str(rows[index].get("action_id", "")))


func _on_preview_play_pressed() -> void:
	preview_play()


func _on_preview_pause_pressed() -> void:
	preview_pause()


func _on_preview_first_pressed() -> void:
	preview_first()


func _on_preview_step_back_pressed() -> void:
	preview_step_backward()


func _on_preview_step_pressed() -> void:
	preview_step_forward()


func _on_preview_last_pressed() -> void:
	preview_last()


func _on_preview_frame_slider_changed(value: float) -> void:
	set_preview_frame(int(round(value)))


func _on_preview_reset_pressed() -> void:
	preview_reset()


func _on_frame_slot_insert_before_shift_pressed() -> void:
	insert_empty_frame_slot(_current_sequence_ref(), preview_frame, true)


func _on_frame_slot_insert_after_shift_pressed() -> void:
	insert_empty_frame_slot(_current_sequence_ref(), preview_frame + 1, true)


func _on_frame_slot_remove_pressed() -> void:
	remove_frame_slot(_current_sequence_ref(), preview_frame)


func _on_frame_slot_replace_pressed() -> void:
	if frame_slot_path_input == null:
		return
	replace_frame_slot(_current_sequence_ref(), preview_frame, frame_slot_path_input.text.strip_edges())


func _on_frame_slot_mark_empty_pressed() -> void:
	mark_frame_slot(_current_sequence_ref(), preview_frame, "empty")


func _on_frame_slot_mark_missing_pressed() -> void:
	mark_frame_slot(_current_sequence_ref(), preview_frame, "missing")


func _on_frame_slot_mark_placeholder_pressed() -> void:
	mark_frame_slot(_current_sequence_ref(), preview_frame, "placeholder")


func _on_preview_half_speed_pressed() -> void:
	set_preview_speed(0.5)


func _on_preview_normal_speed_pressed() -> void:
	set_preview_speed(1.0)


func _on_preview_hurt_toggled(value: bool) -> void:
	preview_show_hurtboxes = value
	_refresh_action_preview()


func _on_preview_hit_toggled(value: bool) -> void:
	preview_show_hitboxes = value
	_refresh_action_preview()


func _on_preview_foot_toggled(value: bool) -> void:
	preview_show_foot = value
	_refresh_action_preview()


func _on_preview_window_toggle_pressed() -> void:
	toggle_preview_window()


func _on_preview_edit_move_pressed() -> void:
	var row := _coverage_row_for(current_action_id)
	var move_id := str(row.get("backing_move_id", selected_move))
	if moves_json.has(move_id):
		selected_move = move_id
	current_nav = "move:%s" % selected_move
	current_move_section = "summary"
	_refresh_fields()


func _on_preview_edit_hitbox_pressed() -> void:
	var row := _coverage_row_for(current_action_id)
	var move_id := str(row.get("backing_move_id", selected_move))
	if moves_json.has(move_id):
		selected_move = move_id
	current_nav = "move:%s" % selected_move
	current_move_section = "hitbox"
	_refresh_fields()


func _on_preview_edit_hurt_pressed() -> void:
	current_nav = "character_hurtboxes"
	_refresh_fields()


func _on_preview_edit_foot_pressed() -> void:
	current_nav = "character_foot"
	_refresh_fields()


func _on_wardrobe_generate_stub_pressed() -> void:
	_set_status("wardrobe generation stub: no external generation called")


func _on_move_section_selected(index: int) -> void:
	if move_section_list == null or index < 0 or index >= move_section_list.item_count:
		return
	current_move_section = str(move_section_list.get_item_metadata(index))
	_refresh_fields()


func _on_move_selected(index: int) -> void:
	select_move(move_select.get_item_text(index))


func _on_sprite_set_selected(index: int) -> void:
	set_sprite_set_ref(sprite_set_select.get_item_text(index))


func _on_copy_pressed() -> void:
	copy_template()


func _on_save_pressed() -> void:
	save_all()


func _on_reload_pressed() -> void:
	reload_current()


func _on_check_pressed() -> void:
	validate_current()


func _on_exact_pressed() -> void:
	save_reload_exact()


func _on_sprite_ref_submitted() -> void:
	if sprite_ref_input == null:
		return
	set_sprite_set_ref(sprite_ref_input.text)


func _on_hp_submitted() -> void:
	if hp_input != null and hp_input.text.is_valid_int():
		set_hp(int(hp_input.text))


func _on_move_type_selected(index: int) -> void:
	if move_type_input == null:
		return
	set_move_scalar("move_type", move_type_input.get_item_text(index))


func _on_state_context_selected(index: int) -> void:
	if state_context_input == null:
		return
	set_move_scalar("state_context_override", state_context_input.get_item_text(index))


func _on_frame_count_submitted() -> void:
	if frame_count_input != null and frame_count_input.text.is_valid_int():
		set_move_scalar("frame_count", int(frame_count_input.text))


func _on_active_start_submitted() -> void:
	_update_active_window_from_inputs()


func _on_active_end_submitted() -> void:
	_update_active_window_from_inputs()


func _update_active_window_from_inputs() -> void:
	if active_start_input == null or active_end_input == null:
		return
	if active_start_input.text.is_valid_int() and active_end_input.text.is_valid_int():
		set_move_active_window(int(active_start_input.text), int(active_end_input.text))


func _on_damage_submitted() -> void:
	if damage_input != null and damage_input.text.is_valid_int():
		set_move_scalar("damage", int(damage_input.text))


func _on_hitstop_submitted() -> void:
	if hitstop_input != null and hitstop_input.text.is_valid_int():
		set_move_scalar("hitstop_frames", int(hitstop_input.text))


func _on_multi_hit_toggled(value: bool) -> void:
	set_move_scalar("multi_hit", value)


func _on_hurtbox_selected(index: int) -> void:
	if hurtbox_select != null:
		current_hurtbox_id = hurtbox_select.get_item_text(index)
	_refresh_fields()


func _on_box_fields_submitted() -> void:
	var changed := false
	if hurtbox_select != null and not hurt_inputs.is_empty():
		if not _validate_number_inputs(hurt_inputs, ["x", "y", "w", "h"]):
			return
		current_hurtbox_id = hurtbox_select.get_item_text(hurtbox_select.selected)
		template_json["hurtboxes"][current_hurtbox_id] = _rect_json({
			"x": _number_from(hurt_inputs, "x"),
			"y": _number_from(hurt_inputs, "y"),
			"w": _number_from(hurt_inputs, "w"),
			"h": _number_from(hurt_inputs, "h"),
		})
		changed = true
	if not foot_inputs.is_empty():
		if not _validate_number_inputs(foot_inputs, ["center_x", "center_y", "radius_x", "radius_y"]):
			return
		template_json["foot_collision"] = {
			"center": {"x": _number_from(foot_inputs, "center_x"), "y": _number_from(foot_inputs, "center_y")},
			"radius": {"x": maxf(1.0, _number_from(foot_inputs, "radius_x")), "y": maxf(1.0, _number_from(foot_inputs, "radius_y"))},
		}
		changed = true
	if hitbox_id_input != null and not hitbox_inputs.is_empty():
		var hitbox_id := hitbox_id_input.text.strip_edges()
		var hitbox_id_valid := _is_hitbox_id_valid(hitbox_id)
		_set_line_edit_valid(hitbox_id_input, hitbox_id_valid)
		if not hitbox_id_valid:
			_set_status("invalid hitbox_id: must match ^hit_[a-z0-9_]+$")
			return
		if not _validate_number_inputs(hitbox_inputs, ["start_frame", "end_frame", "x", "y", "w", "h"]):
			return
		var move := selected_move_json()
		if move["hitboxes"].is_empty():
			move["hitboxes"].append({})
		move["hitboxes"][0] = {
			"hitbox_id": hitbox_id,
			"active_window": {
				"start_frame": int(_number_from(hitbox_inputs, "start_frame")),
				"end_frame": int(_number_from(hitbox_inputs, "end_frame")),
			},
			"rect": _rect_json({
				"x": _number_from(hitbox_inputs, "x"),
				"y": _number_from(hitbox_inputs, "y"),
				"w": _number_from(hitbox_inputs, "w"),
				"h": _number_from(hitbox_inputs, "h"),
			}),
		}
		changed = true
	if changed:
		_refresh_fields()


func _on_events_apply_pressed() -> void:
	var json := JSON.new()
	if json.parse(events_text.text) != OK or typeof(json.data) != TYPE_ARRAY:
		_set_status("events JSON invalid")
		return
	set_move_events(json.data)
	var errors := validate_current()
	if errors.is_empty():
		_set_status("events applied")


func _on_runtime_start_pressed() -> void:
	runtime_start_selected_move()
	_set_status("runtime start %s" % selected_move)


func _on_runtime_one_pressed() -> void:
	runtime_advance_frame(1)
	_set_status("runtime +1 frame")


func _on_runtime_four_pressed() -> void:
	runtime_advance_frame(4)
	_set_status("runtime +4 frames")


func _on_runtime_idle_pressed() -> void:
	runtime_reset_idle()
	_set_status("runtime idle")
