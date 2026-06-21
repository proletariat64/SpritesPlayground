extends Button
class_name SpriteStateCell

signal state_selected(action: String)

const SpritesPlaygroundActorRef := preload("res://scripts/SpritesPlaygroundActor.gd")

var action := ""
var actor: AnimatedSprite2D

func setup(actor_id: String, frames: SpriteFrames, new_action: String) -> void:
	action = new_action
	custom_minimum_size = Vector2(72, 74)
	text = action
	clip_text = true

	actor = SpritesPlaygroundActorRef.new()
	actor.position = Vector2(36, 28)
	actor.scale = Vector2(0.68, 0.68)
	add_child(actor)
	actor.setup(actor_id, frames)
	actor.play_state(action, "east")

	pressed.connect(func() -> void:
		state_selected.emit(action)
	)

func _process(_delta: float) -> void:
	if actor != null:
		text = "%s\n%d/%d" % [action, actor.frame + 1, actor.frame_count()]
