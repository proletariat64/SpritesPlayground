extends Node
class_name CombatAIController

const DESIRED_DISTANCE := 44.0
const DISTANCE_TOLERANCE := 5.0
const ATTACK_DISTANCE := 54.0
const ATTACK_COOLDOWN := 0.65
const EVENT_TARGET_IN_RANGE := &"target_in_range"
const EVENT_TARGET_OUT_OF_RANGE := &"target_out_of_range"

var agent: Node2D
var target: Node2D
var _attack_cooldown_remaining: float = 0.0
var _attack_index: int = 0
var _backend: String = "missing_limboai"
var _limbo_hsm: Node
var _limbo_movement_intent := Vector2.ZERO


func configure(next_agent: Node2D) -> void:
	agent = next_agent
	_install_limbo_hsm_if_available()


func set_target(next_target: Node2D) -> void:
	target = next_target


func reset() -> void:
	_attack_cooldown_remaining = 0.0
	_attack_index = 0
	_limbo_movement_intent = Vector2.ZERO


func backend() -> String:
	return _backend


func movement_intent(delta: float) -> Vector2:
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if _backend != "limboai" or _limbo_hsm == null:
		return Vector2.ZERO
	_limbo_hsm.call("update", delta)
	return _limbo_movement_intent if _valid_combatants() else Vector2.ZERO


func _limbo_approach_update(_delta: float) -> void:
	if not _valid_combatants():
		_limbo_movement_intent = Vector2.ZERO
		return
	var offset := target.global_position - agent.global_position
	if offset.length() <= DESIRED_DISTANCE + DISTANCE_TOLERANCE:
		_limbo_movement_intent = Vector2.ZERO
		_limbo_hsm.call("dispatch", EVENT_TARGET_IN_RANGE)
		return
	_limbo_movement_intent = offset.normalized()


func _limbo_spacing_attack_update(_delta: float) -> void:
	if not _valid_combatants():
		_limbo_movement_intent = Vector2.ZERO
		return
	var offset := target.global_position - agent.global_position
	var distance := offset.length()
	if distance > DESIRED_DISTANCE + DISTANCE_TOLERANCE:
		_limbo_movement_intent = Vector2.ZERO
		_limbo_hsm.call("dispatch", EVENT_TARGET_OUT_OF_RANGE)
		return
	if distance < DESIRED_DISTANCE - DISTANCE_TOLERANCE:
		_limbo_movement_intent = -offset.normalized()
		return
	_limbo_movement_intent = Vector2.ZERO
	if distance <= ATTACK_DISTANCE and _attack_cooldown_remaining <= 0.0:
		_request_basic_attack()


func _request_basic_attack() -> void:
	var family := "punch" if _attack_index % 2 == 0 else "kick"
	var alternate_family := "kick" if family == "punch" else "punch"
	if agent.request_basic_attack(family) or agent.request_basic_attack(alternate_family):
		_attack_index += 1
		_attack_cooldown_remaining = ATTACK_COOLDOWN


func _valid_combatants() -> bool:
	return (
		agent != null
		and is_instance_valid(agent)
		and target != null
		and is_instance_valid(target)
		and int(agent.current_hp) > 0
		and int(target.current_hp) > 0
	)


func _install_limbo_hsm_if_available() -> void:
	_remove_limbo_hsm()
	if not ClassDB.class_exists("LimboHSM") or not ClassDB.class_exists("LimboState"):
		push_error("LimboAI 1.8.0 is required; run: python3 scripts/install_limboai.py")
		return
	var candidate_hsm = ClassDB.instantiate("LimboHSM")
	var approach_state = ClassDB.instantiate("LimboState")
	var spacing_attack_state = ClassDB.instantiate("LimboState")
	if not candidate_hsm is Node or not approach_state is Node or not spacing_attack_state is Node:
		_dispose_candidate(candidate_hsm)
		_dispose_candidate(approach_state)
		_dispose_candidate(spacing_attack_state)
		return
	var required_hsm_methods := ["add_transition", "initialize", "set_active", "dispatch", "set_update_mode", "update"]
	var required_state_methods := ["named", "call_on_update"]
	if not _has_methods(candidate_hsm, required_hsm_methods) or not _has_methods(approach_state, required_state_methods) or not _has_methods(spacing_attack_state, required_state_methods):
		_dispose_candidate(candidate_hsm)
		_dispose_candidate(approach_state)
		_dispose_candidate(spacing_attack_state)
		return

	_limbo_hsm = candidate_hsm
	_limbo_hsm.name = "limbo_ai_intent_hsm"
	add_child(_limbo_hsm)
	approach_state.call("named", "approach")
	approach_state.call("call_on_update", Callable(self, "_limbo_approach_update"))
	spacing_attack_state.call("named", "spacing_attack")
	spacing_attack_state.call("call_on_update", Callable(self, "_limbo_spacing_attack_update"))
	_limbo_hsm.add_child(approach_state)
	_limbo_hsm.add_child(spacing_attack_state)
	_limbo_hsm.call("add_transition", approach_state, spacing_attack_state, EVENT_TARGET_IN_RANGE)
	_limbo_hsm.call("add_transition", spacing_attack_state, approach_state, EVENT_TARGET_OUT_OF_RANGE)
	_limbo_hsm.call("set_update_mode", 2) # LimboHSM.UpdateMode.MANUAL; CombatCharacter owns the tick.
	_limbo_hsm.call("initialize", agent)
	_limbo_hsm.call("set_active", true)
	_backend = "limboai"


func _remove_limbo_hsm() -> void:
	_backend = "missing_limboai"
	_limbo_movement_intent = Vector2.ZERO
	if _limbo_hsm != null and is_instance_valid(_limbo_hsm):
		if _limbo_hsm.get_parent() != null:
			_limbo_hsm.get_parent().remove_child(_limbo_hsm)
		_limbo_hsm.queue_free()
	_limbo_hsm = null


func _has_methods(candidate: Object, method_names: Array) -> bool:
	for method_name in method_names:
		if not candidate.has_method(str(method_name)):
			return false
	return true


func _dispose_candidate(candidate: Object) -> void:
	if candidate == null:
		return
	if candidate is Node and candidate.get_parent() != null:
		candidate.get_parent().remove_child(candidate)
	candidate.free()
