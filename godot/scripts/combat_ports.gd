extends Node
class_name CombatPorts

var actor: Node = null
var blackboard: Node = null
var definition = {}


func setup(owner_actor: Node, owner_blackboard: Node, loaded_definition: Dictionary) -> void:
	actor = owner_actor
	blackboard = owner_blackboard
	definition = loaded_definition


func get_hurtboxes() -> Array:
	var result = []
	if actor == null or blackboard == null or blackboard.state == "dead":
		return result
	var template = definition.get("character_template", {})
	var hurtboxes = template.get("hurtboxes", [])
	if typeof(hurtboxes) != TYPE_ARRAY:
		return result
	for i in range(hurtboxes.size()):
		var hurtbox = hurtboxes[i]
		if typeof(hurtbox) != TYPE_DICTIONARY:
			continue
		if not bool(hurtbox.get("enabled", true)):
			continue
		var rect = actor.local_rect_to_global(hurtbox.get("rect", {}))
		result.append({
			"target": actor,
			"target_id": blackboard.actor_id,
			"hurtbox_id": str(hurtbox.get("id", "hurtbox")),
			"rect": rect,
			"priority": int(hurtbox.get("priority", 0)),
			"def": int(hurtbox.get("def", 0)),
			"registration_order": i,
			"area": rect.size.x * rect.size.y
		})
	return result


func get_active_hitboxes() -> Array:
	if actor == null:
		return []
	return actor.move_runtime.get_active_hitboxes()
