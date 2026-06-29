extends Node2D
class_name DebugOverlay

var actor: Node = null
var show_hitboxes = true
var show_hurtboxes = true
var show_foot_anchor = true


func setup(owner_actor: Node) -> void:
	actor = owner_actor
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if actor == null:
		return
	if show_hurtboxes:
		for hurtbox in actor.combat_ports.get_hurtboxes():
			_draw_global_rect(hurtbox.rect, Color(0.22, 0.62, 0.83, 0.25), Color(0.22, 0.62, 0.83, 0.9))
	if show_hitboxes:
		for hitbox in actor.combat_ports.get_active_hitboxes():
			_draw_global_rect(hitbox.rect, Color(0.86, 0.32, 0.32, 0.28), Color(0.86, 0.32, 0.32, 0.95))
	if show_foot_anchor:
		var foot = actor.get_foot_rect_global()
		_draw_global_rect(foot, Color(0.95, 0.75, 0.18, 0.24), Color(0.95, 0.75, 0.18, 0.95))
		draw_line(to_local(actor.global_position + Vector2(-5, 0)), to_local(actor.global_position + Vector2(5, 0)), Color("#f2c94c"), 1.0)
		draw_line(to_local(actor.global_position + Vector2(0, -5)), to_local(actor.global_position + Vector2(0, 5)), Color("#f2c94c"), 1.0)


func _draw_global_rect(global_rect: Rect2, fill: Color, stroke: Color) -> void:
	var local_rect = Rect2(to_local(global_rect.position), global_rect.size)
	draw_rect(local_rect, fill, true)
	draw_rect(local_rect, stroke, false, 1.0)
