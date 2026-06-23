extends PanelContainer
class_name CreatorLabV03Panel

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Runtime := preload("res://godot/scripts/prd_v0_3_runtime.gd")

var template_json: Dictionary = {}
var sprite_set_json: Dictionary = {}
var moves_json: Dictionary = {}
var selected_move: String = "idle"
var runtime: RefCounted = Runtime.new()

var template_select: OptionButton
var move_select: OptionButton
var sprite_set_select: OptionButton
var status_label: Label
var runtime_label: Label
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


func setup() -> void:
	_build_ui()
	load_template_id("combat_gray_s64")


func load_template_id(template_id: String) -> Array:
	template_json = DataStore.load_template(template_id)
	if template_json.is_empty():
		return _set_errors(["missing template %s" % template_id])
	sprite_set_json = DataStore.load_sprite_set(str(template_json["sprite_set_ref"]))
	moves_json.clear()
	for move_id in template_json["equipped_moves"]:
		moves_json[str(move_id)] = DataStore.load_move(str(move_id))
	selected_move = str(template_json["equipped_moves"][0])
	_refresh_options()
	_refresh_fields()
	return validate_current()


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
	_set_status("saved %s" % str(template_json["template_id"]))


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
		_set_status("save/reload exact PASS")
	else:
		_set_status("save/reload exact FAIL")
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
		selected_move = move_id
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


func wardrobe_coverage() -> Dictionary:
	var missing_mapping: Array = []
	var missing_clips: Array = []
	var missing_sequences: Array = []
	var mapping: Dictionary = sprite_set_json.get("required_moves_mapping", {})
	var clips: Dictionary = sprite_set_json.get("animation_clips", {})
	var sequences: Dictionary = sprite_set_json.get("frame_sequences", {})
	for move_id in template_json.get("equipped_moves", []):
		var id := str(move_id)
		if not mapping.has(id):
			missing_mapping.append(id)
			continue
		var clip_id := str(mapping[id])
		if not clips.has(clip_id):
			missing_clips.append(clip_id)
			continue
		var sequence_id := str(clips[clip_id].get("frame_sequence_ref", ""))
		if not sequences.has(sequence_id):
			missing_sequences.append(sequence_id)
	return {
		"missing_mapping": missing_mapping,
		"missing_clips": missing_clips,
		"missing_sequences": missing_sequences,
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
	custom_minimum_size = Vector2(320, 346)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	var title := Label.new()
	title.text = "Creator Lab v0.3"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	root.add_child(title)

	var top := HBoxContainer.new()
	root.add_child(top)
	template_select = OptionButton.new()
	_style_control(template_select, 120, 18)
	template_select.item_selected.connect(_on_template_selected)
	top.add_child(template_select)
	top.add_child(_button("Copy", _on_copy_pressed))
	top.add_child(_button("Save", _on_save_pressed))
	top.add_child(_button("Reload", _on_reload_pressed))
	top.add_child(_button("Check", _on_check_pressed))
	top.add_child(_button("Exact", _on_exact_pressed))

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(312, 258)
	tabs.add_theme_font_size_override("font_size", 8)
	root.add_child(tabs)
	_build_template_tab(tabs)
	_build_box_tab(tabs)
	_build_move_tab(tabs)
	_build_wardrobe_tab(tabs)
	_build_runtime_tab(tabs)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 8)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)


func _build_template_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Template"
	tab.add_theme_constant_override("separation", 2)
	tabs.add_child(tab)
	tab.add_child(_label("sprite_set_ref"))
	sprite_ref_input = _line_edit(_on_sprite_ref_submitted)
	tab.add_child(sprite_ref_input)
	tab.add_child(_label("hp"))
	hp_input = _line_edit(_on_hp_submitted)
	tab.add_child(hp_input)
	tab.add_child(_label("selected move"))
	move_select = OptionButton.new()
	_style_control(move_select, 154, 18)
	move_select.item_selected.connect(_on_move_selected)
	tab.add_child(move_select)


func _build_box_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Box"
	tab.add_theme_constant_override("separation", 2)
	tabs.add_child(tab)
	hurtbox_select = OptionButton.new()
	for id in ["hurt_head", "hurt_upper_body", "hurt_lower_body"]:
		hurtbox_select.add_item(id)
	hurtbox_select.item_selected.connect(_on_hurtbox_selected)
	_style_control(hurtbox_select, 154, 18)
	tab.add_child(hurtbox_select)
	tab.add_child(_label("hurtbox"))
	hurt_inputs = _add_input_grid(tab, ["x", "y", "w", "h"], _on_box_fields_submitted)
	tab.add_child(_label("foot"))
	foot_inputs = _add_input_grid(tab, ["center_x", "center_y", "radius_x", "radius_y"], _on_box_fields_submitted)
	tab.add_child(_label("first hitbox"))
	hitbox_id_input = _line_edit(_on_box_fields_submitted)
	tab.add_child(hitbox_id_input)
	hitbox_inputs = _add_input_grid(tab, ["start_frame", "end_frame", "x", "y", "w", "h"], _on_box_fields_submitted)


func _build_move_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Move"
	tab.add_theme_constant_override("separation", 2)
	tabs.add_child(tab)
	move_type_input = OptionButton.new()
	for id in ["utility", "locomotion", "combat", "reaction"]:
		move_type_input.add_item(id)
	move_type_input.item_selected.connect(_on_move_type_selected)
	_style_control(move_type_input, 120, 18)
	tab.add_child(move_type_input)

	state_context_input = OptionButton.new()
	for id in ["", "idle", "walk", "dash", "jump", "hurt", "dead"]:
		state_context_input.add_item(id)
	state_context_input.item_selected.connect(_on_state_context_selected)
	_style_control(state_context_input, 120, 18)
	tab.add_child(state_context_input)

	for row in [
		["frames", "frame_count_input", _on_frame_count_submitted],
		["start", "active_start_input", _on_active_start_submitted],
		["end", "active_end_input", _on_active_end_submitted],
		["damage", "damage_input", _on_damage_submitted],
		["hitstop", "hitstop_input", _on_hitstop_submitted],
	]:
		tab.add_child(_label(str(row[0])))
		var input := _line_edit(row[2])
		set(str(row[1]), input)
		tab.add_child(input)
	multi_hit_input = CheckBox.new()
	multi_hit_input.text = "multi_hit"
	multi_hit_input.toggled.connect(_on_multi_hit_toggled)
	multi_hit_input.add_theme_font_size_override("font_size", 8)
	tab.add_child(multi_hit_input)
	tab.add_child(_label("events JSON"))
	events_text = TextEdit.new()
	events_text.custom_minimum_size = Vector2(250, 54)
	events_text.add_theme_font_size_override("font_size", 8)
	tab.add_child(events_text)
	tab.add_child(_button("Apply Events", _on_events_apply_pressed))


func _build_wardrobe_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Wardrobe"
	tabs.add_child(tab)
	sprite_set_select = OptionButton.new()
	_style_control(sprite_set_select, 154, 18)
	sprite_set_select.item_selected.connect(_on_sprite_set_selected)
	tab.add_child(sprite_set_select)
	tab.add_child(_button("Validate", _on_check_pressed))


func _build_runtime_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Runtime"
	tab.add_theme_constant_override("separation", 2)
	tabs.add_child(tab)
	var row := HBoxContainer.new()
	tab.add_child(row)
	row.add_child(_button("Start", _on_runtime_start_pressed))
	row.add_child(_button("+1", _on_runtime_one_pressed))
	row.add_child(_button("+4", _on_runtime_four_pressed))
	row.add_child(_button("Idle", _on_runtime_idle_pressed))
	runtime_label = Label.new()
	runtime_label.add_theme_font_size_override("font_size", 8)
	runtime_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(runtime_label)


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


func _refresh_fields() -> void:
	if hp_input != null:
		hp_input.text = str(int(template_json.get("hp", 0)))
	if sprite_ref_input != null:
		sprite_ref_input.text = str(template_json.get("sprite_set_ref", ""))
	if moves_json.has(selected_move):
		var move := selected_move_json()
		_select_option(move_type_input, str(move.get("move_type", "")))
		_select_option(state_context_input, str(move.get("state_context_override", "")))
		frame_count_input.text = str(int(move.get("frame_count", 0)))
		active_start_input.text = str(int(move.get("active_window", {}).get("start_frame", 0)))
		active_end_input.text = str(int(move.get("active_window", {}).get("end_frame", 0)))
		damage_input.text = str(int(move.get("damage", 0)))
		hitstop_input.text = str(int(move.get("hitstop_frames", 0)))
		multi_hit_input.button_pressed = bool(move.get("multi_hit", false))
		if hurtbox_select != null:
			var hurtbox_id := hurtbox_select.get_item_text(hurtbox_select.selected)
			var hurt: Dictionary = template_json.get("hurtboxes", {}).get(hurtbox_id, {})
			_set_inputs(hurt_inputs, hurt)
		var foot: Dictionary = template_json.get("foot_collision", {})
		if not foot.is_empty():
			_set_inputs(foot_inputs, {
				"center_x": foot["center"]["x"],
				"center_y": foot["center"]["y"],
				"radius_x": foot["radius"]["x"],
				"radius_y": foot["radius"]["y"],
			})
		if not move.get("hitboxes", []).is_empty():
			var hitbox: Dictionary = move["hitboxes"][0]
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
		events_text.text = JSON.stringify(move.get("events", []), "\t", true)
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


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 18)
	button.add_theme_font_size_override("font_size", 8)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _line_edit(callback: Callable) -> LineEdit:
	var input := LineEdit.new()
	_style_control(input, 110, 18)
	input.text_submitted.connect(func(_text: String) -> void:
		callback.call()
	)
	input.focus_exited.connect(callback)
	return input


func _add_input_grid(parent: VBoxContainer, fields: Array, callback: Callable) -> Dictionary:
	var inputs := {}
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	parent.add_child(grid)
	for field in fields:
		grid.add_child(_label(str(field)))
		var input := _line_edit(callback)
		_style_control(input, 42, 16)
		grid.add_child(input)
		inputs[str(field)] = input
	return inputs


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	return label


func _style_control(control: Control, width: int, height: int) -> void:
	control.custom_minimum_size = Vector2(width, height)
	control.add_theme_font_size_override("font_size", 8)
	if not (control is LineEdit):
		control.focus_mode = Control.FOCUS_NONE


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


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _set_errors(errors: Array) -> Array:
	_set_status("validation FAIL: %s" % ", ".join(errors))
	return errors


func _on_template_selected(index: int) -> void:
	load_template_id(template_select.get_item_text(index))


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
	set_sprite_set_ref(sprite_ref_input.text)


func _on_hp_submitted() -> void:
	if hp_input.text.is_valid_int():
		set_hp(int(hp_input.text))


func _on_move_type_selected(index: int) -> void:
	set_move_scalar("move_type", move_type_input.get_item_text(index))


func _on_state_context_selected(index: int) -> void:
	set_move_scalar("state_context_override", state_context_input.get_item_text(index))


func _on_frame_count_submitted() -> void:
	if frame_count_input.text.is_valid_int():
		set_move_scalar("frame_count", int(frame_count_input.text))


func _on_active_start_submitted() -> void:
	_update_active_window_from_inputs()


func _on_active_end_submitted() -> void:
	_update_active_window_from_inputs()


func _update_active_window_from_inputs() -> void:
	if active_start_input.text.is_valid_int() and active_end_input.text.is_valid_int():
		set_move_active_window(int(active_start_input.text), int(active_end_input.text))


func _on_damage_submitted() -> void:
	if damage_input.text.is_valid_int():
		set_move_scalar("damage", int(damage_input.text))


func _on_hitstop_submitted() -> void:
	if hitstop_input.text.is_valid_int():
		set_move_scalar("hitstop_frames", int(hitstop_input.text))


func _on_multi_hit_toggled(value: bool) -> void:
	set_move_scalar("multi_hit", value)


func _on_hurtbox_selected(_index: int) -> void:
	_refresh_fields()


func _on_box_fields_submitted() -> void:
	if hurtbox_select == null:
		return
	var hurtbox_id := hurtbox_select.get_item_text(hurtbox_select.selected)
	template_json["hurtboxes"][hurtbox_id] = _rect_json({
		"x": _number_from(hurt_inputs, "x"),
		"y": _number_from(hurt_inputs, "y"),
		"w": _number_from(hurt_inputs, "w"),
		"h": _number_from(hurt_inputs, "h"),
	})
	template_json["foot_collision"] = {
		"center": {"x": _number_from(foot_inputs, "center_x"), "y": _number_from(foot_inputs, "center_y")},
		"radius": {"x": maxf(1.0, _number_from(foot_inputs, "radius_x")), "y": maxf(1.0, _number_from(foot_inputs, "radius_y"))},
	}
	set_first_hitbox(
		hitbox_id_input.text,
		int(_number_from(hitbox_inputs, "start_frame")),
		int(_number_from(hitbox_inputs, "end_frame")),
		{
			"x": _number_from(hitbox_inputs, "x"),
			"y": _number_from(hitbox_inputs, "y"),
			"w": _number_from(hitbox_inputs, "w"),
			"h": _number_from(hitbox_inputs, "h"),
		}
	)


func _on_events_apply_pressed() -> void:
	var json := JSON.new()
	if json.parse(events_text.text) != OK or typeof(json.data) != TYPE_ARRAY:
		_set_status("events JSON invalid")
		return
	set_move_events(json.data)


func _on_runtime_start_pressed() -> void:
	runtime_start_selected_move()


func _on_runtime_one_pressed() -> void:
	runtime_advance_frame(1)


func _on_runtime_four_pressed() -> void:
	runtime_advance_frame(4)


func _on_runtime_idle_pressed() -> void:
	runtime_reset_idle()
