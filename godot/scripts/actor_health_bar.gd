extends Node2D
class_name ActorHealthBar

var actor: Node = null


func setup(owner_actor: Node) -> void:
	actor = owner_actor
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if actor == null:
		return
	var blackboard = actor.blackboard
	var width = 42.0
	var pct = 0.0
	if blackboard.hp_max > 0:
		pct = float(blackboard.hp) / float(blackboard.hp_max)
	draw_rect(Rect2(Vector2(-21, -78), Vector2(width, 5)), Color("#111827"))
	draw_rect(Rect2(Vector2(-20, -77), Vector2((width - 2.0) * pct, 3)), Color("#4f9d69" if pct > 0.35 else "#c65d5d"))
