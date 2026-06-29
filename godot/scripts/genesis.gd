extends Control
class_name Genesis

signal request_playground

const RebuildData = preload("res://godot/scripts/rebuild_data.gd")
const RebuildValidator = preload("res://godot/scripts/rebuild_validator.gd")

var current_character_id = "adam"
var selected_definition = {}
var selector: OptionButton
var summary_label: Label
var raw_editor: TextEdit
var validation_output: TextEdit


func _ready() -> void:
	_build_ui()
	_load_character("adam")


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root = HBoxContainer.new()
	root.name = "GenesisWorkspace"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	add_child(root)

	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(240, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)

	var title = Label.new()
	title.text = "Genesis"
	title.add_theme_font_size_override("font_size", 20)
	left.add_child(title)

	selector = OptionButton.new()
	selector.add_item("Adam", 0)
	selector.set_item_metadata(0, "adam")
	selector.add_item("Cain", 1)
	selector.set_item_metadata(1, "cain")
	selector.item_selected.connect(_on_character_selected)
	left.add_child(selector)

	var validate_button = Button.new()
	validate_button.text = "Validate"
	validate_button.pressed.connect(_on_validate_pressed)
	left.add_child(validate_button)

	var save_button = Button.new()
	save_button.text = "Save JSON"
	save_button.pressed.connect(_on_save_pressed)
	left.add_child(save_button)

	var reload_button = Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(_on_reload_pressed)
	left.add_child(reload_button)

	var smoke_button = Button.new()
	smoke_button.text = "Playground Smoke"
	smoke_button.pressed.connect(func(): request_playground.emit())
	left.add_child(smoke_button)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.text = "No definition loaded."
	left.add_child(summary_label)

	validation_output = TextEdit.new()
	validation_output.custom_minimum_size = Vector2(220, 180)
	validation_output.editable = false
	left.add_child(validation_output)

	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)

	var editor_title = Label.new()
	editor_title.text = "SpriteDefinition JSON Draft"
	right.add_child(editor_title)

	raw_editor = TextEdit.new()
	raw_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raw_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raw_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(raw_editor)


func _load_character(character_id: String) -> void:
	current_character_id = character_id
	selected_definition = RebuildData.load_character(character_id)
	if selected_definition.has("_error"):
		raw_editor.text = ""
		validation_output.text = selected_definition["_error"]
		return
	raw_editor.text = RebuildData.pretty_json(selected_definition)
	_update_summary(selected_definition)
	_validate_definition(selected_definition)


func _on_character_selected(index: int) -> void:
	_load_character(str(selector.get_item_metadata(index)))


func _on_validate_pressed() -> void:
	var parsed = RebuildData.parse_json_text(raw_editor.text)
	if parsed.has("_error"):
		validation_output.text = parsed["_error"]
		return
	_validate_definition(parsed)


func _on_save_pressed() -> void:
	var parsed = RebuildData.parse_json_text(raw_editor.text)
	if parsed.has("_error"):
		validation_output.text = "Save blocked: %s" % parsed["_error"]
		return
	var report = RebuildValidator.validate_character(parsed)
	if not bool(report.get("ok", false)):
		validation_output.text = "Save blocked.\n%s" % RebuildValidator.report_to_text(report)
		return
	var character_id = str(parsed.get("id", current_character_id))
	var result = RebuildData.save_json(RebuildData.character_path(character_id), parsed)
	if bool(result.get("ok", false)):
		selected_definition = parsed
		current_character_id = character_id
		validation_output.text = "Saved %s\n\n%s" % [result.get("path", ""), RebuildValidator.report_to_text(report)]
		_update_summary(parsed)
	else:
		validation_output.text = "Save failed: %s" % result.get("error", "unknown")


func _on_reload_pressed() -> void:
	_load_character(current_character_id)


func _validate_definition(definition: Dictionary) -> void:
	var report = RebuildValidator.validate_character(definition)
	validation_output.text = RebuildValidator.report_to_text(report)


func _update_summary(definition: Dictionary) -> void:
	var template = definition.get("character_template", {})
	var lines = [
		"id: %s" % definition.get("id", ""),
		"role/faction: %s / %s" % [definition.get("role", ""), definition.get("faction", "")],
		"spawn: %s" % str(definition.get("spawn", {})),
		"input: %s" % str(definition.get("input", {})),
		"hp: %s" % template.get("hp_max", ""),
		"moves: %s" % str(template.get("equipped_moves", [])),
		"hurtboxes: %s" % str(template.get("hurtboxes", []).size() if typeof(template.get("hurtboxes", [])) == TYPE_ARRAY else 0),
		"sprite_set: %s" % template.get("sprite_set_path", "")
	]
	summary_label.text = "\n".join(lines)
