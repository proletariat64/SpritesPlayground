extends Control

const GENESIS_SCENE = preload("res://godot/scenes/Genesis.tscn")
const PLAYGROUND_SCENE = preload("res://godot/scenes/Playground.tscn")
const RebuildInput = preload("res://godot/scripts/rebuild_input.gd")

var content: Control
var active_node: Node = null


func _ready() -> void:
	_ensure_input_actions()
	_build_shell()
	_show_playground()
	print("SpritesPlayground M1 shell ready")


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root = VBoxContainer.new()
	root.name = "Shell"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var topbar = HBoxContainer.new()
	topbar.name = "Topbar"
	topbar.custom_minimum_size = Vector2(0, 36)
	topbar.add_theme_constant_override("separation", 6)
	root.add_child(topbar)

	var title = Label.new()
	title.text = "SpritesPlayground M1"
	title.custom_minimum_size = Vector2(172, 0)
	title.add_theme_font_size_override("font_size", 15)
	topbar.add_child(title)

	var genesis_button = Button.new()
	genesis_button.text = "Genesis"
	genesis_button.pressed.connect(_show_genesis)
	topbar.add_child(genesis_button)

	var playground_button = Button.new()
	playground_button.text = "Playground"
	playground_button.pressed.connect(_show_playground)
	topbar.add_child(playground_button)

	var help = Label.new()
	help.text = "WASD move  J punch/combo  F1/F2/F3 overlays"
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_font_size_override("font_size", 11)
	topbar.add_child(help)

	content = Control.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(content)


func _show_genesis() -> void:
	_clear_content()
	var genesis = GENESIS_SCENE.instantiate()
	genesis.request_playground.connect(_show_playground)
	content.add_child(genesis)
	genesis.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_node = genesis


func _show_playground() -> void:
	_clear_content()
	var playground = PLAYGROUND_SCENE.instantiate()
	content.add_child(playground)
	var content_size = get_viewport_rect().size - Vector2(0, 36)
	var scale_factor = min(content_size.x / 640.0, content_size.y / 360.0)
	playground.scale = Vector2(scale_factor, scale_factor)
	playground.position = Vector2((content_size.x - 640.0 * scale_factor) * 0.5, 0)
	active_node = playground


func _clear_content() -> void:
	if active_node != null and is_instance_valid(active_node):
		active_node.queue_free()
	active_node = null
	if content == null:
		return
	for child in content.get_children():
		child.queue_free()


func _ensure_input_actions() -> void:
	RebuildInput.ensure_actions()
