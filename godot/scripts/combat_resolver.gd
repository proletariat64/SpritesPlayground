extends Node
class_name CombatResolver

var actors: Array = []
var hit_registry = {}
var last_results: Array = []
var hit_log: Array = []


func set_actors(next_actors: Array) -> void:
	actors = next_actors


func tick() -> void:
	last_results.clear()
	for attacker in actors:
		if attacker == null or not attacker.loaded_ok:
			continue
		for hitbox in attacker.combat_ports.get_active_hitboxes():
			_resolve_hitbox(hitbox)


func _resolve_hitbox(hitbox: Dictionary) -> void:
	for target in actors:
		if target == null or target == hitbox.get("attacker") or not target.loaded_ok:
			continue
		if target.blackboard.faction == hitbox.get("attacker").blackboard.faction:
			continue
		var selected = _select_hurtbox(hitbox, target.combat_ports.get_hurtboxes())
		if selected.is_empty():
			continue
		var key = "%s|%s|%s" % [
			str(hitbox.get("attack_instance_id", "")),
			str(hitbox.get("hitbox_id", "")),
			str(selected.get("target_id", ""))
		]
		if hit_registry.has(key):
			continue
		hit_registry[key] = true
		var damage = max(0, int(hitbox.get("atk", 0)) - int(selected.get("def", 0)))
		var result = {
			"attacker_id": hitbox.get("attacker_id", ""),
			"target_id": selected.get("target_id", ""),
			"attack_instance_id": hitbox.get("attack_instance_id", ""),
			"hitbox_id": hitbox.get("hitbox_id", ""),
			"hurtbox_id": selected.get("hurtbox_id", ""),
			"hitbox_atk": int(hitbox.get("atk", 0)),
			"selected_hurtbox_def": int(selected.get("def", 0)),
			"damage": damage,
			"hitstun_frames": int(hitbox.get("hitstun_frames", 0)),
			"hitstop_frames": int(hitbox.get("hitstop_frames", 0)),
			"reaction_tag": hitbox.get("reaction_tag", "hurt_light"),
			"formula": "max(0, hitbox_atk - selected_hurtbox_def)"
		}
		last_results.append(result)
		hit_log.append(result)
		target.receive_hurt_result(result)


func _select_hurtbox(hitbox: Dictionary, hurtboxes: Array) -> Dictionary:
	var contacts = []
	var hit_rect: Rect2 = hitbox.get("rect", Rect2())
	for hurtbox in hurtboxes:
		var hurt_rect: Rect2 = hurtbox.get("rect", Rect2())
		if hit_rect.intersects(hurt_rect, true):
			contacts.append(hurtbox)
	if contacts.is_empty():
		return {}
	contacts.sort_custom(func(a, b):
		if int(a.get("priority", 0)) != int(b.get("priority", 0)):
			return int(a.get("priority", 0)) > int(b.get("priority", 0))
		if float(a.get("area", 0.0)) != float(b.get("area", 0.0)):
			return float(a.get("area", 0.0)) < float(b.get("area", 0.0))
		return int(a.get("registration_order", 0)) < int(b.get("registration_order", 0))
	)
	return contacts[0]
