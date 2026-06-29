extends Node
class_name LifeRuntime

var actor: Node = null
var blackboard: Node = null


func setup(owner_actor: Node, owner_blackboard: Node) -> void:
	actor = owner_actor
	blackboard = owner_blackboard


func apply_hurt_result(result: Dictionary) -> void:
	if blackboard == null or blackboard.state == "dead":
		return
	blackboard.last_hurt_result = result
	var damage = int(result.get("damage", 0))
	blackboard.hp = max(0, blackboard.hp - damage)
	if blackboard.hp <= 0:
		actor.state_driver.request_event("ev_dead", result)
	else:
		actor.state_driver.request_event("ev_hurt", result)
