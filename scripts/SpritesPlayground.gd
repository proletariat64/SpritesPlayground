extends Control
class_name SpritesPlayground

const SpriteCatalogRef := preload("res://scripts/SpriteCatalog.gd")
const SpritesPlaygroundActorRef := preload("res://scripts/SpritesPlaygroundActor.gd")
const SpriteStateCellRef := preload("res://scripts/SpriteStateCell.gd")

@onready var actor_bar: HBoxContainer = %ActorBar
@onready var direction_bar: GridContainer = %DirectionBar
@onready var action_list: ItemList = %ActionList
@onready var state_grid: GridContainer = %StateGrid
@onready var preview_slot: Control = %PreviewSlot
@onready var debug_label: Label = %DebugLabel

var actor_ids := PackedStringArray()
var current_actor_id := ""
var current_frames: SpriteFrames
var current_action := ""
var current_direction := "east"
var preview_actor: AnimatedSprite2D

func _ready() -> void:
	action_list.item_selected.connect(func(index: int) -> void:
		select_action(action_list.get_item_text(index))
	)
	_build_direction_bar()
	_load_actors()

func _process(_delta: float) -> void:
	if preview_actor != null:
		debug_label.text = preview_actor.debug_text()

func _load_actors() -> void:
	actor_ids = SpriteCatalogRef.load_actor_ids()
	for child in actor_bar.get_children():
		child.queue_free()

	for actor_id in actor_ids:
		var button := Button.new()
		button.text = actor_id
		button.custom_minimum_size = Vector2(96, 24)
		button.pressed.connect(func(id := actor_id) -> void:
			select_actor(id)
		)
		actor_bar.add_child(button)

	if actor_ids.is_empty():
		debug_label.text = "warning: no SpriteFrames resources found in res://resources/sprite_frames"
		return

	select_actor(actor_ids[0])

func _build_direction_bar() -> void:
	for direction: String in SpriteCatalogRef.DIRECTIONS:
		var button := Button.new()
		button.text = _direction_label(direction)
		button.tooltip_text = direction
		button.custom_minimum_size = Vector2(52, 22)
		button.toggle_mode = true
		button.pressed.connect(func(dir: String = direction) -> void:
			select_direction(dir)
		)
		direction_bar.add_child(button)

func select_actor(actor_id: String) -> void:
	current_actor_id = actor_id
	current_frames = SpriteCatalogRef.load_sprite_frames(actor_id)
	var actions: PackedStringArray = SpriteCatalogRef.list_actions(current_frames)
	current_action = "idle_breath" if actions.has("idle_breath") else (actions[0] if not actions.is_empty() else "")
	current_direction = "east"
	_rebuild_preview()
	_rebuild_action_list(actions)
	_rebuild_state_grid(actions)

func select_direction(direction: String) -> void:
	current_direction = direction
	_update_direction_buttons()
	if preview_actor != null:
		preview_actor.play_state(current_action, current_direction)

func select_action(action: String) -> void:
	current_action = action
	if preview_actor != null:
		preview_actor.play_state(current_action, current_direction)

func _rebuild_preview() -> void:
	if preview_actor != null:
		preview_actor.queue_free()

	preview_actor = SpritesPlaygroundActorRef.new()
	preview_actor.position = preview_slot.size * 0.5
	preview_actor.scale = Vector2(1.25, 1.25)
	preview_slot.add_child(preview_actor)
	preview_actor.setup(current_actor_id, current_frames)
	preview_actor.play_state(current_action, current_direction)
	_update_direction_buttons()

func _rebuild_action_list(actions: PackedStringArray) -> void:
	action_list.clear()
	for action_name in actions:
		action_list.add_item(action_name)

func _rebuild_state_grid(actions: PackedStringArray) -> void:
	for child in state_grid.get_children():
		child.queue_free()

	for action_name in actions:
		var cell: Button = SpriteStateCellRef.new()
		cell.setup(current_actor_id, current_frames, action_name)
		cell.state_selected.connect(select_action)
		state_grid.add_child(cell)

func _update_direction_buttons() -> void:
	for child in direction_bar.get_children():
		if child is Button:
			child.button_pressed = child.tooltip_text == current_direction

func _direction_label(direction: String) -> String:
	match direction:
		"east":
			return "E"
		"southeast":
			return "SE"
		"south":
			return "S"
		"southwest":
			return "SW"
		"west":
			return "W"
		"northwest":
			return "NW"
		"north":
			return "N"
		"northeast":
			return "NE"
	return direction
