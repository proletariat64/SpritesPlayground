extends PanelContainer
class_name CreatorLabPanel

const CreatorDataStoreScript := preload("res://godot/scripts/creator_data_store.gd")

var player: Node2D
var template_json: Dictionary = {}
var move_json: Dictionary = {}
var sprite_set_json: Dictionary = {}
var selected_hurtbox := "hurt_head"
var selected_move := "basic_punch"

var template_select: OptionButton
var hurtbox_select: OptionButton
var move_select: OptionButton
var sprite_set_select: OptionButton
var status_label: Label
var missing_label: Label

var hurt_spins := {}
var foot_spins := {}
var move_spins := {}
var hitbox_spins := {}


func setup(target_player: Node2D) -> void:
	player = target_player
	_build_ui()
	_load_template("combat_gray_s64")


func _build_ui() -> void:
	custom_minimum_size = Vector2(300, 340)
	position = Vector2(332, 8)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := Label.new()
	title.text = "Creator Lab v1"
	title.add_theme_font_size_override("font_size", 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(_button("Hide", _on_hide_pressed))

	var template_row := HBoxContainer.new()
	root.add_child(template_row)
	template_select = OptionButton.new()
	template_select.custom_minimum_size = Vector2(150, 24)
	template_select.item_selected.connect(_on_template_selected)
	template_row.add_child(template_select)
	template_row.add_child(_button("Copy", _on_copy_template_pressed))
	template_row.add_child(_button("Apply", _apply_to_playground))

	root.add_child(_section_label("Box Editor"))
	hurtbox_select = OptionButton.new()
	for id in ["hurt_head", "hurt_upper_body", "hurt_lower_body"]:
		hurtbox_select.add_item(id)
	hurtbox_select.item_selected.connect(_on_hurtbox_selected)
	root.add_child(hurtbox_select)
	hurt_spins = _add_rect_editor(root, "hurt", _on_hurtbox_spin_changed)
	foot_spins = _add_ellipse_editor(root, _on_foot_spin_changed)

	root.add_child(_section_label("Move Lab"))
	move_select = OptionButton.new()
	for id in ["basic_punch", "basic_kick"]:
		move_select.add_item(id)
	move_select.item_selected.connect(_on_move_selected)
	root.add_child(move_select)
	move_spins = _add_move_editor(root, _on_move_spin_changed)
	hitbox_spins = _add_rect_editor(root, "hitbox", _on_hitbox_spin_changed)

	root.add_child(_section_label("Wardrobe"))
	sprite_set_select = OptionButton.new()
	sprite_set_select.item_selected.connect(_on_sprite_set_selected)
	root.add_child(sprite_set_select)
	missing_label = Label.new()
	missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	missing_label.add_theme_font_size_override("font_size", 8)
	root.add_child(missing_label)
	root.add_child(_button("Generate Missing Animation", _on_generate_stub_pressed))

	var save_row := HBoxContainer.new()
	root.add_child(save_row)
	save_row.add_child(_button("Save", _on_save_pressed))
	save_row.add_child(_button("Reload", _on_reload_pressed))
	save_row.add_child(_button("Save+Reload Check", _on_save_reload_check_pressed))

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 8)
	root.add_child(status_label)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	return label


func _add_rect_editor(parent: VBoxContainer, prefix: String, callback: Callable) -> Dictionary:
	var spins := {}
	for field in ["x", "y", "w", "h"]:
		spins[field] = _add_spin_row(parent, "%s_%s" % [prefix, field], -160, 160, callback)
	return spins


func _add_ellipse_editor(parent: VBoxContainer, callback: Callable) -> Dictionary:
	var spins := {}
	for field in ["center_x", "center_y", "radius_x", "radius_y"]:
		spins[field] = _add_spin_row(parent, "foot_%s" % field, -160, 160, callback)
	return spins


func _add_move_editor(parent: VBoxContainer, callback: Callable) -> Dictionary:
	var spins := {}
	for field in ["frame_count", "startup_frames", "active_start_frame", "active_end_frame", "recovery_frames", "damage"]:
		spins[field] = _add_spin_row(parent, field, 0, 180, callback)
	return spins


func _add_spin_row(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, callback: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(118, 18)
	label.add_theme_font_size_override("font_size", 8)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.custom_minimum_size = Vector2(72, 20)
	spin.value_changed.connect(callback)
	row.add_child(spin)
	return spin


func _load_template(template_id: String) -> void:
	template_json = CreatorDataStoreScript.load_template_json(template_id)
	selected_move = str(template_json.get("base_attack_moves", ["basic_punch"])[0])
	move_json = CreatorDataStoreScript.load_move_json(selected_move)
	sprite_set_json = CreatorDataStoreScript.load_sprite_set_json(str(template_json.get("sprite_set_id", "gray_dummy_s64")))
	_refresh_template_options()
	_refresh_sprite_set_options()
	_refresh_fields()
	_apply_to_playground()
	_set_status("loaded %s" % template_id)


func _refresh_template_options() -> void:
	var ids := CreatorDataStoreScript.list_template_ids()
	template_select.clear()
	for id in ids:
		template_select.add_item(id)
		if id == str(template_json.get("template_id", "")):
			template_select.select(template_select.item_count - 1)


func _refresh_sprite_set_options() -> void:
	var ids := CreatorDataStoreScript.list_sprite_set_ids()
	sprite_set_select.clear()
	for id in ids:
		sprite_set_select.add_item(id)
		if id == str(template_json.get("sprite_set_id", "")):
			sprite_set_select.select(sprite_set_select.item_count - 1)


func _refresh_fields() -> void:
	var hurt: Dictionary = template_json["hurtboxes"][selected_hurtbox]
	for field in ["x", "y", "w", "h"]:
		hurt_spins[field].set_value_no_signal(float(hurt[field]))

	var foot: Dictionary = template_json["foot_collision"]
	foot_spins["center_x"].set_value_no_signal(float(foot["center"]["x"]))
	foot_spins["center_y"].set_value_no_signal(float(foot["center"]["y"]))
	foot_spins["radius_x"].set_value_no_signal(float(foot["radius"]["x"]))
	foot_spins["radius_y"].set_value_no_signal(float(foot["radius"]["y"]))

	for field in move_spins.keys():
		move_spins[field].set_value_no_signal(float(move_json.get(field, 0)))

	var hitbox: Dictionary = move_json["hitboxes"][0]
	var rect: Dictionary = hitbox["rect"]
	for field in ["x", "y", "w", "h"]:
		hitbox_spins[field].set_value_no_signal(float(rect[field]))
	_update_missing_label()


func _on_template_selected(index: int) -> void:
	_load_template(template_select.get_item_text(index))


func _on_hurtbox_selected(index: int) -> void:
	selected_hurtbox = hurtbox_select.get_item_text(index)
	_refresh_fields()


func _on_move_selected(index: int) -> void:
	selected_move = move_select.get_item_text(index)
	move_json = CreatorDataStoreScript.load_move_json(selected_move)
	_refresh_fields()


func _on_sprite_set_selected(index: int) -> void:
	var sprite_set_id := sprite_set_select.get_item_text(index)
	template_json["sprite_set_id"] = sprite_set_id
	sprite_set_json = CreatorDataStoreScript.load_sprite_set_json(sprite_set_id)
	_update_missing_label()
	_set_status("selected sprite set %s" % sprite_set_id)


func _on_hurtbox_spin_changed(_value: float) -> void:
	var hurt: Dictionary = template_json["hurtboxes"][selected_hurtbox]
	for field in ["x", "y", "w", "h"]:
		hurt[field] = hurt_spins[field].value
	_apply_to_playground()


func _on_foot_spin_changed(_value: float) -> void:
	template_json["foot_collision"]["center"]["x"] = foot_spins["center_x"].value
	template_json["foot_collision"]["center"]["y"] = foot_spins["center_y"].value
	template_json["foot_collision"]["radius"]["x"] = maxf(1.0, foot_spins["radius_x"].value)
	template_json["foot_collision"]["radius"]["y"] = maxf(1.0, foot_spins["radius_y"].value)
	_apply_to_playground()


func _on_move_spin_changed(_value: float) -> void:
	for field in move_spins.keys():
		move_json[field] = int(move_spins[field].value)
	move_json["hitboxes"][0]["frame_start"] = int(move_json["active_start_frame"])
	move_json["hitboxes"][0]["frame_end"] = int(move_json["active_end_frame"])
	_refresh_fields()


func _on_hitbox_spin_changed(_value: float) -> void:
	var rect: Dictionary = move_json["hitboxes"][0]["rect"]
	for field in ["x", "y", "w", "h"]:
		rect[field] = hitbox_spins[field].value


func _on_copy_template_pressed() -> void:
	create_editable_copy()


func create_editable_copy(copy_id: String = "") -> String:
	var source_id := str(template_json["template_id"])
	var new_id := copy_id if not copy_id.is_empty() else _next_copy_id(source_id)
	template_json = CreatorDataStoreScript.duplicate_template(source_id, new_id)
	_refresh_template_options()
	_refresh_fields()
	_apply_to_playground()
	_set_status("created editable copy %s" % new_id)
	return new_id


func _next_copy_id(source_id: String) -> String:
	var base_id := "%s_copy" % source_id
	var ids := CreatorDataStoreScript.list_template_ids()
	if not ids.has(base_id):
		return base_id
	var i := 2
	while ids.has("%s_%d" % [base_id, i]):
		i += 1
	return "%s_%d" % [base_id, i]


func _on_save_pressed() -> void:
	_save_all()
	_set_status("saved %s + %s" % [template_json["template_id"], move_json["move_id"]])


func _on_reload_pressed() -> void:
	_load_template(str(template_json["template_id"]))


func _on_save_reload_check_pressed() -> void:
	var before := JSON.stringify({"template": template_json, "move": move_json}, "\t", true)
	var template_id := str(template_json["template_id"])
	var move_id := str(move_json["move_id"])
	_save_all()
	var reloaded_template := CreatorDataStoreScript.load_template_json(template_id)
	var reloaded_move := CreatorDataStoreScript.load_move_json(move_id)
	var after := JSON.stringify({"template": reloaded_template, "move": reloaded_move}, "\t", true)
	if before == after:
		_set_status("save/reload exact: PASS")
	else:
		_set_status("save/reload exact: FAIL")
	template_json = reloaded_template
	move_json = reloaded_move
	_apply_to_playground()


func _on_hide_pressed() -> void:
	visible = false


func _save_all() -> void:
	var template_id := str(template_json["template_id"])
	var move_id := str(move_json["move_id"])
	CreatorDataStoreScript.save_template_json(template_json)
	CreatorDataStoreScript.save_move_json(move_json)
	template_json = CreatorDataStoreScript.load_template_json(template_id)
	move_json = CreatorDataStoreScript.load_move_json(move_id)
	sprite_set_json = CreatorDataStoreScript.load_sprite_set_json(str(template_json["sprite_set_id"]))
	_refresh_fields()
	_apply_to_playground()


func _apply_to_playground() -> void:
	if player == null:
		return
	var runtime_template := CreatorDataStoreScript.template_json_to_runtime(template_json)
	runtime_template["move_templates"][str(move_json["move_id"])] = CreatorDataStoreScript.move_json_to_runtime(move_json)
	player.apply_runtime_template(runtime_template)


func _on_generate_stub_pressed() -> void:
	var missing := _missing_animations()
	_set_status("generation stub queued for: %s" % (", ".join(missing) if missing.size() > 0 else "none"))


func _update_missing_label() -> void:
	var missing := _missing_animations()
	missing_label.text = "sprite_set=%s\nmissing=%s" % [
		str(sprite_set_json.get("sprite_set_id", "")),
		", ".join(missing) if missing.size() > 0 else "none",
	]


func _missing_animations() -> Array:
	var required: Array = []
	required.append_array(template_json.get("base_actions", []))
	required.append_array(template_json.get("base_attack_moves", []))
	var animations: Dictionary = sprite_set_json.get("animations", {})
	var missing: Array = []
	for id in required:
		if not animations.has(str(id)):
			missing.append(str(id))
	for id in sprite_set_json.get("missing_animations", []):
		if not missing.has(str(id)):
			missing.append(str(id))
	missing.sort()
	return missing


func _set_status(text: String) -> void:
	status_label.text = text
