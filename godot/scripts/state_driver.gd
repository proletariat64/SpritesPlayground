extends Node
class_name StateDriver

const VALID_STATES = ["idle", "walk", "attack", "hurt", "dead"]
const VALID_EVENTS = ["ev_move", "ev_stop", "ev_attack", "ev_hurt", "ev_dead", "ev_finished"]

var actor: Node = null
var blackboard: Node = null
var limbo_available = false
var limbo_node: Node = null
var hurt_timer = 0.0


func setup(owner_actor: Node, owner_blackboard: Node) -> void:
	actor = owner_actor
	blackboard = owner_blackboard
	_init_limbo_probe()


func _process(delta: float) -> void:
	if blackboard == null:
		return
	if blackboard.state == "hurt":
		hurt_timer -= delta
		if hurt_timer <= 0.0 and blackboard.hp > 0:
			request_event("ev_finished")


func request_event(event_id: String, payload = {}) -> bool:
	if blackboard == null:
		return false
	if not VALID_EVENTS.has(event_id):
		push_warning("Unknown StateDriver event: %s" % event_id)
		return false

	match event_id:
		"ev_dead":
			blackboard.state = "dead"
			blackboard.current_move = ""
			blackboard.current_segment = ""
			blackboard.velocity = Vector2.ZERO
			return true
		"ev_hurt":
			if blackboard.state == "dead":
				return false
			blackboard.state = "hurt"
			blackboard.current_move = ""
			blackboard.current_segment = ""
			hurt_timer = float(payload.get("hitstun_frames", 12)) / 12.0
			return true
		"ev_attack":
			if blackboard.state == "dead" or blackboard.state == "hurt":
				return false
			blackboard.state = "attack"
			return true
		"ev_move":
			if blackboard.state == "idle" or blackboard.state == "walk":
				blackboard.state = "walk"
				return true
			return false
		"ev_stop":
			if blackboard.state == "walk":
				blackboard.state = "idle"
				blackboard.velocity = Vector2.ZERO
				return true
			return false
		"ev_finished":
			if blackboard.state == "attack" or blackboard.state == "hurt":
				if blackboard.velocity.length() > 0.01:
					blackboard.state = "walk"
				else:
					blackboard.state = "idle"
				blackboard.current_move = ""
				blackboard.current_segment = ""
				blackboard.authored_frame = 0
				return true

	return false


func _init_limbo_probe() -> void:
	limbo_available = ClassDB.class_exists("LimboHSM")
	if blackboard == null:
		return
	if limbo_available:
		limbo_node = ClassDB.instantiate("LimboHSM")
		if limbo_node != null:
			limbo_node.name = "LimboHSMAdapter"
			add_child(limbo_node)
			blackboard.limbo_status = "loaded:LimboHSM"
		else:
			blackboard.limbo_status = "class_exists_but_instantiate_failed"
	else:
		blackboard.limbo_status = "missing:addons/limboai"
