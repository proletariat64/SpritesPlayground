extends Node2D
class_name VisualPresenter

var actor: Node = null
var sprite_set = {}
@onready var sprite_set_player = $SpriteSetPlayer
@onready var health_bars = $HealthBars
@onready var debug_overlay = $DebugOverlay


func setup(owner_actor: Node, loaded_sprite_set: Dictionary) -> void:
	actor = owner_actor
	sprite_set = loaded_sprite_set
	sprite_set_player.setup(actor, sprite_set)
	health_bars.setup(actor)
	debug_overlay.setup(actor)


func set_overlay_flags(hitboxes: bool, hurtboxes: bool, foot_anchor: bool) -> void:
	debug_overlay.show_hitboxes = hitboxes
	debug_overlay.show_hurtboxes = hurtboxes
	debug_overlay.show_foot_anchor = foot_anchor
	debug_overlay.queue_redraw()
