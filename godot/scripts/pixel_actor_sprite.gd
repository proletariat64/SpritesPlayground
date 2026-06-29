extends Node2D
class_name PixelActorSprite

var actor: Node = null
var palette = {}


func setup(owner_actor: Node, sprite_set: Dictionary) -> void:
	actor = owner_actor
	palette = sprite_set.get("palette", {})
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if actor == null:
		return
	var blackboard = actor.blackboard
	var facing_scale = -1.0 if blackboard.facing == "west" else 1.0
	var bob = 0.0
	if blackboard.state == "walk":
		bob = sin(float(blackboard.runtime_frame) * 0.4) * 2.0
	if blackboard.state == "hurt":
		bob = -2.0
	if blackboard.state == "dead":
		_draw_dead()
		return

	draw_rect(Rect2(Vector2(-15, -51 + bob), Vector2(30, 48)), Color(palette.get("outline", "#111827")))
	draw_rect(Rect2(Vector2(-11, -47 + bob), Vector2(22, 20)), Color(palette.get("shirt", "#2f80a8")))
	draw_rect(Rect2(Vector2(-10, -63 + bob), Vector2(20, 18)), Color(palette.get("skin", "#f1c27d")))
	draw_rect(Rect2(Vector2(-12, -65 + bob), Vector2(24, 6)), Color(palette.get("hair", "#2f1e16")))
	draw_rect(Rect2(Vector2(-10, -28 + bob), Vector2(8, 25)), Color(palette.get("pants", "#374151")))
	draw_rect(Rect2(Vector2(2, -28 + bob), Vector2(8, 25)), Color(palette.get("pants", "#374151")))
	draw_rect(Rect2(Vector2(6 * facing_scale, -44 + bob), Vector2(8 * facing_scale, 9)), Color(palette.get("skin", "#f1c27d")))
	if blackboard.state == "attack":
		var extension = 12.0 + float(blackboard.authored_frame % 4) * 2.0
		draw_rect(Rect2(Vector2(10 * facing_scale, -43 + bob), Vector2(extension * facing_scale, 7)), Color(palette.get("accent", "#f2c94c")))
	draw_rect(Rect2(Vector2(-9, -58 + bob), Vector2(4, 3)), Color("#111827"))
	draw_rect(Rect2(Vector2(5, -58 + bob), Vector2(4, 3)), Color("#111827"))


func _draw_dead() -> void:
	draw_rect(Rect2(Vector2(-25, -16), Vector2(50, 13)), Color(palette.get("outline", "#111827")))
	draw_rect(Rect2(Vector2(-21, -19), Vector2(42, 12)), Color(palette.get("shirt", "#c65d5d")))
	draw_rect(Rect2(Vector2(14, -22), Vector2(18, 14)), Color(palette.get("skin", "#d08b5b")))
