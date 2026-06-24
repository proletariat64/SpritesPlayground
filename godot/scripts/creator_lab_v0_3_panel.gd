extends PanelContainer
class_name CreatorLabV03Panel

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Runtime := preload("res://godot/scripts/prd_v0_3_runtime.gd")
const COLOR_TITLE := Color(0.72, 0.86, 1.0)
const COLOR_LABEL := Color(0.82, 0.88, 0.95)
const COLOR_HINT := Color(0.56, 0.64, 0.72)
const COLOR_CHARACTER := Color(0.56, 0.82, 1.0)
const COLOR_MOVE := Color(1.0, 0.78, 0.42)
const COLOR_WARDROBE := Color(0.62, 0.88, 0.58)
const COLOR_RUNTIME := Color(0.84, 0.72, 1.0)
const COLOR_PASS := Color(0.42, 0.88, 0.56)
const COLOR_FAIL := Color(1.0, 0.42, 0.36)
const COLOR_STATUS := Color(0.72, 0.78, 0.84)

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
	custom_minimum_size = Vector2(480, 336)
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
	title.text = "Creator Lab v0.3"
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
	top.add_child(_button("Save", _on_save_pressed))
	top.add_child(_button("Check", _on_check_pressed))

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 3)
	root.add_child(tools)
	tools.add_child(_button("Reload", _on_reload_pressed))
	tools.add_child(_button("Roundtrip", _on_exact_pressed))

	var main := HBoxContainer.new()
	main.custom_minimum_size = Vector2(466, 242)
	main.add_theme_constant_override("separation", 4)
	root.add_child(main)

	var nav_box := VBoxContainer.new()
	nav_box.custom_minimum_size = Vector2(96, 238)
	nav_box.add_theme_constant_override("separation", 2)
	main.add_child(nav_box)
	nav_box.add_child(_label("1 Choose", COLOR_CHARACTER))
	navigation_list = ItemList.new()
	navigation_list.custom_minimum_size = Vector2(96, 216)
	navigation_list.add_theme_font_size_override("font_size", 8)
	navigation_list.item_selected.connect(_on_navigation_selected)
	nav_box.add_child(navigation_list)

	var values_scroll := ScrollContainer.new()
	values_scroll.custom_minimum_size = Vector2(132, 238)
	values_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(values_scroll)
	values_panel = VBoxContainer.new()
	values_panel.custom_minimum_size = Vector2(120, 0)
	values_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values_panel.add_theme_constant_override("separation", 2)
	values_scroll.add_child(values_panel)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(230, 238)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(detail_scroll)
	detail_panel = VBoxContainer.new()
	detail_panel.custom_minimum_size = Vector2(218, 0)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_constant_override("separation", 2)
	detail_scroll.add_child(detail_panel)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 8)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)


func _refresh_navigation() -> void:
	if navigation_list == null:
		return
	navigation_list.clear()
	nav_keys.clear()
	_add_nav_item("Template", "character_template")
	_add_nav_item("Hurtboxes", "character_hurtboxes")
	_add_nav_item("Foot", "character_foot")
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
	move_select = null
	sprite_set_select = null
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
	move_section_list = null


func _build_values_panel() -> void:
	values_panel.add_child(_label("2 Overview", _current_nav_color()))
	match current_nav:
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
			for move_id in sprite_set_json.get("required_moves_mapping", {}).keys():
				_add_value(str(move_id), str(sprite_set_json["required_moves_mapping"][move_id]))
		"wardrobe_clips":
			for clip_id in sprite_set_json.get("animation_clips", {}).keys():
				var clip: Dictionary = sprite_set_json["animation_clips"][clip_id]
				_add_value(str(clip_id), "seq:%s" % str(clip.get("frame_sequence_ref", "")))
		"wardrobe_sequences":
			for sequence_id in sprite_set_json.get("frame_sequences", {}).keys():
				_add_value(str(sequence_id), "%s frames" % str(sprite_set_json["frame_sequences"][sequence_id].size()))
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


func _build_template_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Character data", COLOR_CHARACTER))
	parent.add_child(_label("sprite set"))
	sprite_ref_input = _line_edit(_on_sprite_ref_submitted)
	sprite_ref_input.text = str(template_json.get("sprite_set_ref", ""))
	parent.add_child(sprite_ref_input)
	parent.add_child(_label("hp"))
	hp_input = _line_edit(_on_hp_submitted)
	hp_input.text = str(int(template_json.get("hp", 0)))
	parent.add_child(hp_input)
	parent.add_child(_label("current move"))
	move_select = OptionButton.new()
	_style_control(move_select, 154, 18)
	for move_id in template_json.get("equipped_moves", []):
		move_select.add_item(str(move_id))
		if str(move_id) == selected_move:
			move_select.select(move_select.item_count - 1)
	move_select.item_selected.connect(_on_move_selected)
	parent.add_child(move_select)
	parent.add_child(_button("Duplicate", _on_copy_pressed, 70))


func _build_hurtbox_detail(parent: VBoxContainer) -> void:
	parent.add_child(_label("Hurtbox - where this character can be hit", COLOR_CHARACTER))
	hurtbox_select = OptionButton.new()
	for id in template_json.get("hurtboxes", {}).keys():
		hurtbox_select.add_item(str(id))
		if str(id) == current_hurtbox_id:
			hurtbox_select.select(hurtbox_select.item_count - 1)
	hurtbox_select.item_selected.connect(_on_hurtbox_selected)
	_style_control(hurtbox_select, 154, 18)
	parent.add_child(hurtbox_select)
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
	_style_control(move_select, 154, 18)
	for move_id in template_json.get("equipped_moves", []):
		move_select.add_item(str(move_id))
		if str(move_id) == selected_move:
			move_select.select(move_select.item_count - 1)
	move_select.item_selected.connect(_on_move_selected)
	parent.add_child(move_select)
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
	parent.add_child(_label("move type"))
	move_type_input = OptionButton.new()
	for id in ["utility", "locomotion", "combat", "reaction"]:
		move_type_input.add_item(id)
	move_type_input.item_selected.connect(_on_move_type_selected)
	_style_control(move_type_input, 188, 18)
	_select_option(move_type_input, str(move.get("move_type", "")))
	parent.add_child(move_type_input)
	parent.add_child(_label("state context"))
	state_context_input = OptionButton.new()
	for id in ["", "idle", "walk", "dash", "jump", "hurt", "dead"]:
		state_context_input.add_item(id)
	state_context_input.item_selected.connect(_on_state_context_selected)
	_style_control(state_context_input, 188, 18)
	_select_option(state_context_input, str(move.get("state_context_override", "")))
	parent.add_child(state_context_input)
	multi_hit_input = CheckBox.new()
	multi_hit_input.text = "multi_hit"
	multi_hit_input.button_pressed = bool(move.get("multi_hit", false))
	multi_hit_input.toggled.connect(_on_multi_hit_toggled)
	multi_hit_input.add_theme_font_size_override("font_size", 8)
	parent.add_child(multi_hit_input)
	parent.add_child(_hint_label("Use middle panel for Timing, Hitbox, Events."))


func _build_move_timing_detail(parent: VBoxContainer, move: Dictionary) -> void:
	parent.add_child(_label("Timing", COLOR_MOVE))
	for row in [
		["frames", "frame_count_input", _on_frame_count_submitted, int(move.get("frame_count", 0))],
		["start", "active_start_input", _on_active_start_submitted, int(move.get("active_window", {}).get("start_frame", 0))],
		["end", "active_end_input", _on_active_end_submitted, int(move.get("active_window", {}).get("end_frame", 0))],
	]:
		parent.add_child(_label(str(row[0])))
		var input := _line_edit(row[2])
		input.text = str(row[3])
		set(str(row[1]), input)
		parent.add_child(input)


func _build_move_damage_detail(parent: VBoxContainer, move: Dictionary) -> void:
	parent.add_child(_label("Damage", COLOR_MOVE))
	for row in [
		["damage", "damage_input", _on_damage_submitted, int(move.get("damage", 0))],
		["hitstop", "hitstop_input", _on_hitstop_submitted, int(move.get("hitstop_frames", 0))],
	]:
		parent.add_child(_label(str(row[0])))
		var input := _line_edit(row[2])
		input.text = str(row[3])
		set(str(row[1]), input)
		parent.add_child(input)
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
	parent.add_child(_label("Wardrobe coverage - sprite mapping", COLOR_WARDROBE))
	sprite_set_select = OptionButton.new()
	_style_control(sprite_set_select, 154, 18)
	for id in DataStore.list_sprite_set_ids():
		sprite_set_select.add_item(id)
		if id == str(template_json.get("sprite_set_ref", "")):
			sprite_set_select.select(sprite_set_select.item_count - 1)
	sprite_set_select.item_selected.connect(_on_sprite_set_selected)
	parent.add_child(sprite_set_select)
	var coverage := wardrobe_coverage()
	parent.add_child(_label("missing move mapping: %s" % str(coverage["missing_mapping"].size())))
	parent.add_child(_label("missing animation clips: %s" % str(coverage["missing_clips"].size())))
	parent.add_child(_label("missing frame sequences: %s" % str(coverage["missing_sequences"].size())))
	parent.add_child(_button("Validate", _on_check_pressed, 64))


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


func _add_value(label_text: String, value_text: String) -> void:
	values_panel.add_child(_label("%s: %s" % [label_text, value_text], COLOR_HINT))


func _rect_summary(rect: Dictionary) -> String:
	return "x:%s y:%s w:%s h:%s" % [rect.get("x", 0), rect.get("y", 0), rect.get("w", 0), rect.get("h", 0)]


func _xy_summary(value: Dictionary) -> String:
	return "x:%s y:%s" % [value.get("x", 0), value.get("y", 0)]


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
	_refresh_navigation()


func _refresh_fields() -> void:
	_refresh_three_panel()
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


func _button(text: String, callback: Callable, width: int = 0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 18)
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
		callback.call()
	)
	return input


func _clear_line_edit_submit_guard(input: LineEdit) -> void:
	if is_instance_valid(input):
		input.set_meta("submit_handled", false)


func _add_input_grid(parent: VBoxContainer, fields: Array, callback: Callable) -> Dictionary:
	var inputs := {}
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	parent.add_child(grid)
	for field in fields:
		grid.add_child(_label(_field_label(str(field))))
		var input := _line_edit(callback)
		_style_control(input, 42, 16)
		grid.add_child(input)
		inputs[str(field)] = input
	return inputs


func _field_label(field: String) -> String:
	match field:
		"start_frame":
			return "start"
		"end_frame":
			return "end"
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


func _nav_color(key: String) -> Color:
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
