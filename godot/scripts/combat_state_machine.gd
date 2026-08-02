extends Node
class_name CombatStateMachine

const STATE_IDLE := "idle"
const STATE_WALK := "walk"
const STATE_DASH := "dash"
const STATE_JUMP := "jump"
const STATE_ATTACK := "attack"
const STATE_HURT := "hurt"
const STATE_DEAD := "dead"
const EVENT_FINISHED := &"ev_finished"
const ENTER_STATE_EVENT_PREFIX := "ev_enter_"
const FINISHED_ROUTER_STATE := "finished_router"
const LIMBO_UPDATE_MODE_MANUAL := 2
const AUTHORITY_STATES := [STATE_IDLE, STATE_WALK, STATE_DASH, STATE_JUMP, STATE_ATTACK, STATE_HURT, STATE_DEAD]

const DIRECTION_SECTORS := {
	"e": 0.0,
	"se": 45.0,
	"s": 90.0,
	"sw": 135.0,
	"w": 180.0,
	"nw": -135.0,
	"n": -90.0,
	"ne": -45.0,
}
const SECTOR_HALF_WIDTH := 22.5
const DIRECTION_HYSTERESIS := 6.0
const LOCOMOTION_START_SECONDS := 2.0 / 12.0
const LOCOMOTION_STOP_SECONDS := 2.0 / 12.0
const LOCOMOTION_TURN_SECONDS := 4.0 / 12.0
const JUMP_START_SECONDS := 3.0 / 12.0
const JUMP_LAND_SECONDS := 3.0 / 12.0
const NORMAL_JUMP_SECONDS := 0.75
const BIG_JUMP_SECONDS := 0.9
const KNOCKDOWN_FALL_SECONDS := 6.0 / 12.0
const KNOCKDOWN_DOWN_SECONDS := 6.0 / 12.0
const KNOCKDOWN_GET_UP_SECONDS := 5.0 / 12.0

var current_state: String = STATE_IDLE
var current_move: String = ""
var current_state_context: String = STATE_IDLE
var velocity: Vector2 = Vector2.ZERO
var visual_jump_offset: float = 0.0
var state_elapsed: float = 0.0
var facing: int = 1
var locked_attack_facing: int = 1
var locomotion_direction: String = "e"
var locomotion_mode: String = "walk"
var locomotion_phase: String = ""
var locomotion_phase_elapsed: float = 0.0
var jump_mode: String = "jump"
var jump_phase: String = ""
var reaction_mode: String = "hurt"
var reaction_phase: String = ""
var death_phase: String = ""

var walk_speed: float = 95.0
var run_speed: float = 150.0
var dash_speed: float = 240.0
var dash_duration: float = 0.18
var jump_height: float = 34.0
var hurt_duration: float = 0.28

var _move_executor: Node
var _attack_started_airborne: bool = false
var _airborne_attack_start_offset: float = 0.0
var _finish_uses_requested_context: bool = false
var _state_authority_hsm: Node
var _state_authority_states: Dictionary = {}
var _state_authority_backend: String = "missing_limboai"


func configure(move_executor: Node) -> void:
	_move_executor = move_executor
	_install_state_authority()
	_move_executor.move_started.connect(_on_move_started)
	_move_executor.move_finished.connect(_on_move_finished)
	_move_executor.state_context_requested.connect(_on_state_context_requested)


func request_action(action_id: String) -> bool:
	if current_state == STATE_DEAD:
		return false
	if current_state == STATE_HURT:
		return false
	if current_state == STATE_ATTACK:
		return false

	match action_id:
		STATE_DASH:
			_enter_state(STATE_DASH)
			return true
		STATE_JUMP:
			jump_mode = "jump"
			_enter_state(STATE_JUMP)
			jump_phase = "start"
			return true
		"big_jump":
			jump_mode = "big_jump"
			_enter_state(STATE_JUMP)
			jump_phase = "start"
			return true
	return false


func can_start_attack(allow_airborne: bool = false) -> bool:
	if allow_airborne and current_state == STATE_JUMP:
		return true
	return current_state in [STATE_IDLE, STATE_WALK]


func state_authority_backend() -> String:
	return _state_authority_backend


func state_authority_state() -> String:
	if _state_authority_hsm == null or not is_instance_valid(_state_authority_hsm):
		return ""
	var active_state = _state_authority_hsm.call("get_active_state")
	return str(active_state.name) if active_state is Node else ""


func reset_to_idle() -> void:
	_move_executor.cancel()
	velocity = Vector2.ZERO
	visual_jump_offset = 0.0
	locomotion_direction = "e"
	locomotion_mode = "walk"
	locomotion_phase = ""
	locomotion_phase_elapsed = 0.0
	jump_mode = "jump"
	jump_phase = ""
	reaction_mode = "hurt"
	reaction_phase = ""
	death_phase = ""
	_attack_started_airborne = false
	_airborne_attack_start_offset = 0.0
	_finish_uses_requested_context = false
	current_state_context = STATE_IDLE
	current_move = STATE_IDLE
	_enter_state(STATE_IDLE)


func enter_hurt(knockdown: bool = false) -> void:
	if current_state == STATE_DEAD:
		return
	_move_executor.cancel()
	_attack_started_airborne = false
	_airborne_attack_start_offset = 0.0
	current_move = ""
	_enter_state(STATE_HURT)
	reaction_mode = "knockdown" if knockdown else "hurt"
	reaction_phase = "fall_down" if knockdown else "hurt"


func enter_dead() -> void:
	_move_executor.cancel()
	_attack_started_airborne = false
	_airborne_attack_start_offset = 0.0
	current_move = ""
	velocity = Vector2.ZERO
	visual_jump_offset = 0.0
	_enter_state(STATE_DEAD)
	death_phase = "fall_down"


func tick(delta: float, input_vector: Vector2, run_requested: bool = false) -> void:
	velocity = Vector2.ZERO
	state_elapsed += delta
	locomotion_phase_elapsed += delta

	if current_state != STATE_ATTACK:
		if input_vector.x < -0.05:
			facing = -1
		elif input_vector.x > 0.05:
			facing = 1

	match current_state:
		STATE_DEAD:
			visual_jump_offset = 0.0
			_update_death_phase()
			return
		STATE_ATTACK:
			facing = locked_attack_facing
			if _attack_started_airborne:
				var total_frames := maxi(2, int(_move_executor.active_move.get("total_frames", 2)))
				var attack_progress := clampf(float(_move_executor.current_frame()) / float(total_frames - 1), 0.0, 1.0)
				visual_jump_offset = lerpf(_airborne_attack_start_offset, 0.0, attack_progress)
			else:
				visual_jump_offset = 0.0
			var movement_was_hitstopped: bool = _move_executor.is_hitstopped()
			_move_executor.tick(delta)
			if _move_executor.is_executing() and not movement_was_hitstopped and not _move_executor.is_hitstopped():
				velocity = _move_executor.authored_velocity()
			return
		STATE_HURT:
			visual_jump_offset = 0.0
			if reaction_mode == "knockdown":
				_update_reaction_phase()
				if state_elapsed >= KNOCKDOWN_FALL_SECONDS + KNOCKDOWN_DOWN_SECONDS + KNOCKDOWN_GET_UP_SECONDS:
					_enter_locomotion(input_vector, run_requested)
			elif state_elapsed >= hurt_duration:
				_enter_locomotion(input_vector, run_requested)
			return
		STATE_DASH:
			velocity = Vector2(float(facing) * dash_speed, 0.0)
			visual_jump_offset = 0.0
			if state_elapsed >= dash_duration:
				_enter_locomotion(input_vector, run_requested)
			return
		STATE_JUMP:
			var total_duration := BIG_JUMP_SECONDS if jump_mode == "big_jump" else NORMAL_JUMP_SECONDS
			var height := jump_height * 1.4 if jump_mode == "big_jump" else jump_height
			var progress := clampf(state_elapsed / total_duration, 0.0, 1.0)
			visual_jump_offset = -sin(progress * PI) * height
			velocity = input_vector.normalized() * walk_speed
			_update_jump_phase(total_duration)
			if state_elapsed >= total_duration:
				visual_jump_offset = 0.0
				_enter_locomotion(input_vector, run_requested)
			return

	_enter_locomotion(input_vector, run_requested)


func current_frame() -> int:
	if current_state == STATE_ATTACK:
		return _move_executor.current_frame()
	return int(floor(state_elapsed * 12.0))


func presentation_animation_base() -> String:
	match current_state:
		STATE_JUMP:
			if jump_mode == "jump" and jump_phase == "land":
				return "eden_land"
			return "eden_%s_%s" % [jump_mode, jump_phase]
		STATE_HURT:
			if reaction_mode == "knockdown":
				return "eden_%s" % reaction_phase
			return "hurt"
		STATE_DEAD:
			return "eden_%s" % death_phase
	return ""


func _update_jump_phase(total_duration: float) -> void:
	if state_elapsed < JUMP_START_SECONDS:
		jump_phase = "start"
	elif state_elapsed >= total_duration - JUMP_LAND_SECONDS:
		jump_phase = "land"
	else:
		jump_phase = "air"


func _update_reaction_phase() -> void:
	if state_elapsed < KNOCKDOWN_FALL_SECONDS:
		reaction_phase = "fall_down"
	elif state_elapsed < KNOCKDOWN_FALL_SECONDS + KNOCKDOWN_DOWN_SECONDS:
		reaction_phase = "down"
	else:
		reaction_phase = "get_up"


func _update_death_phase() -> void:
	death_phase = "fall_down" if state_elapsed < KNOCKDOWN_FALL_SECONDS else "down"


func _enter_locomotion(input_vector: Vector2, run_requested: bool = false) -> void:
	visual_jump_offset = 0.0
	var moving := input_vector.length() > 0.05
	if moving:
		var previous_direction := locomotion_direction
		var target_mode := "run" if run_requested else "walk"
		_update_locomotion_direction(input_vector)
		if current_state != STATE_WALK:
			_enter_state(STATE_WALK)
			locomotion_mode = target_mode
			_enter_locomotion_phase("start")
		elif locomotion_mode != target_mode:
			locomotion_mode = target_mode
			_enter_locomotion_phase("start")
		elif locomotion_direction != previous_direction and locomotion_phase != "start":
			_enter_locomotion_phase("turn")
		elif locomotion_phase == "start" and locomotion_phase_elapsed >= LOCOMOTION_START_SECONDS:
			_enter_locomotion_phase("loop")
		elif locomotion_phase == "turn" and locomotion_phase_elapsed >= LOCOMOTION_TURN_SECONDS:
			_enter_locomotion_phase("loop")
		elif locomotion_phase == "stop":
			_enter_locomotion_phase("start")
		var speed := run_speed if locomotion_mode == "run" else walk_speed
		velocity = input_vector.normalized() * speed
		current_move = locomotion_mode
	elif current_state == STATE_WALK:
		velocity = Vector2.ZERO
		if locomotion_phase != "stop":
			_enter_locomotion_phase("stop")
		elif locomotion_phase_elapsed >= LOCOMOTION_STOP_SECONDS:
			_enter_state(STATE_IDLE)
	else:
		velocity = Vector2.ZERO
		if current_state != STATE_IDLE:
			_enter_state(STATE_IDLE)
		else:
			current_move = STATE_IDLE


func locomotion_animation_base() -> String:
	if current_state != STATE_WALK:
		return "idle"
	if locomotion_phase.is_empty():
		return locomotion_mode
	return "%s_%s" % [locomotion_mode, locomotion_phase]


func _enter_locomotion_phase(phase: String) -> void:
	locomotion_phase = phase
	locomotion_phase_elapsed = 0.0


func _update_locomotion_direction(input_vector: Vector2) -> void:
	if input_vector.length() <= 0.05:
		return
	var angle := rad_to_deg(atan2(input_vector.y, input_vector.x))
	var current_angle: float = DIRECTION_SECTORS[locomotion_direction]
	if absf(_angle_delta(angle, current_angle)) <= SECTOR_HALF_WIDTH + DIRECTION_HYSTERESIS:
		return
	locomotion_direction = _nearest_direction(angle)


func _nearest_direction(angle: float) -> String:
	var best := "e"
	var best_delta := INF
	for direction in DIRECTION_SECTORS:
		var delta := absf(_angle_delta(angle, DIRECTION_SECTORS[direction]))
		if delta < best_delta:
			best_delta = delta
			best = direction
	return best


func _angle_delta(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


func _enter_state(state_id: String) -> void:
	if _state_authority_backend == "limboai" and _state_authority_hsm != null:
		_state_authority_hsm.call("dispatch", StringName(ENTER_STATE_EVENT_PREFIX + state_id))
	else:
		_apply_state_entry(state_id)


func _apply_state_entry(state_id: String) -> void:
	current_state = state_id
	state_elapsed = 0.0
	if state_id != STATE_WALK:
		locomotion_phase = ""
		locomotion_phase_elapsed = 0.0
	if state_id != STATE_JUMP:
		jump_phase = ""
	if state_id != STATE_HURT:
		reaction_phase = ""
	if state_id != STATE_DEAD:
		death_phase = ""
	if state_id != STATE_ATTACK:
		current_move = state_id


func _on_move_finished(_move_id: String) -> void:
	if current_state != STATE_ATTACK:
		return
	var finished_context := current_state_context if _finish_uses_requested_context else STATE_IDLE
	_attack_started_airborne = false
	_airborne_attack_start_offset = 0.0
	_finish_uses_requested_context = false
	visual_jump_offset = 0.0
	current_move = ""
	_enter_finished_context(finished_context)


func _on_move_started(move_id: String) -> void:
	if current_state == STATE_DEAD or current_state == STATE_HURT:
		return
	_attack_started_airborne = current_state == STATE_JUMP
	_airborne_attack_start_offset = visual_jump_offset if _attack_started_airborne else 0.0
	locked_attack_facing = facing
	var authored_context := str(_move_executor.active_move.get("state_context_override", STATE_IDLE))
	current_state_context = authored_context if _is_known_state_context(authored_context) else STATE_IDLE
	_finish_uses_requested_context = false
	current_move = move_id
	_enter_state(STATE_ATTACK)


func _on_state_context_requested(state_context: String) -> void:
	if current_state != STATE_ATTACK or not _is_known_state_context(state_context):
		return
	current_state_context = state_context
	_finish_uses_requested_context = true


func _enter_finished_context(state_context: String) -> void:
	var finished_context := state_context if _is_known_state_context(state_context) else STATE_IDLE
	_prepare_finished_context(finished_context)
	if _state_authority_backend == "limboai" and _state_authority_hsm != null:
		_state_authority_hsm.call("dispatch", EVENT_FINISHED)
		_state_authority_hsm.call("dispatch", StringName(ENTER_STATE_EVENT_PREFIX + finished_context))
	else:
		_apply_state_entry(finished_context)


func _prepare_finished_context(state_context: String) -> void:
	match state_context:
		STATE_JUMP:
			jump_mode = "jump"
			jump_phase = "air"
		STATE_HURT:
			reaction_mode = "hurt"
			reaction_phase = "hurt"
		STATE_DEAD:
			velocity = Vector2.ZERO
			visual_jump_offset = 0.0
			death_phase = "fall_down"


func _install_state_authority() -> void:
	_state_authority_backend = "missing_limboai"
	_state_authority_states.clear()
	if not ClassDB.class_exists("LimboHSM") or not ClassDB.class_exists("LimboState"):
		push_error("LimboAI 1.8.0 is required for live state authority")
		return
	var candidate_hsm = ClassDB.instantiate("LimboHSM")
	var candidate_states := {}
	for state_id in AUTHORITY_STATES:
		candidate_states[state_id] = ClassDB.instantiate("LimboState")
	candidate_states[FINISHED_ROUTER_STATE] = ClassDB.instantiate("LimboState")
	if not candidate_hsm is Node or not _has_methods(candidate_hsm, ["add_transition", "initialize", "set_active", "dispatch", "set_update_mode", "get_active_state"]):
		_dispose_candidate(candidate_hsm)
		_dispose_candidates(candidate_states.values())
		return
	for state_id in candidate_states:
		var candidate_state = candidate_states[state_id]
		if not candidate_state is Node or not _has_methods(candidate_state, ["named", "call_on_enter"]):
			_dispose_candidate(candidate_hsm)
			_dispose_candidates(candidate_states.values())
			return

	_state_authority_hsm = candidate_hsm
	_state_authority_hsm.name = "live_state_authority_hsm"
	add_child(_state_authority_hsm)
	for state_id in AUTHORITY_STATES:
		var state: Node = candidate_states[state_id]
		state.call("named", state_id)
		state.call("call_on_enter", Callable(self, "_apply_state_entry").bind(state_id))
		_state_authority_hsm.add_child(state)
		_state_authority_states[state_id] = state
	var finished_router: Node = candidate_states[FINISHED_ROUTER_STATE]
	finished_router.call("named", FINISHED_ROUTER_STATE)
	_state_authority_hsm.add_child(finished_router)
	_state_authority_states[FINISHED_ROUTER_STATE] = finished_router
	for source_id in AUTHORITY_STATES:
		for target_id in AUTHORITY_STATES:
			_state_authority_hsm.call(
				"add_transition",
				_state_authority_states[source_id],
				_state_authority_states[target_id],
				StringName(ENTER_STATE_EVENT_PREFIX + target_id)
			)
	_state_authority_hsm.call(
		"add_transition",
		_state_authority_states[STATE_ATTACK],
		_state_authority_states[FINISHED_ROUTER_STATE],
		EVENT_FINISHED
	)
	for target_id in [STATE_IDLE, STATE_WALK, STATE_DASH, STATE_JUMP, STATE_HURT, STATE_DEAD]:
		_state_authority_hsm.call(
			"add_transition",
			_state_authority_states[FINISHED_ROUTER_STATE],
			_state_authority_states[target_id],
			StringName(ENTER_STATE_EVENT_PREFIX + target_id)
		)
	_state_authority_hsm.call("set_update_mode", LIMBO_UPDATE_MODE_MANUAL)
	_state_authority_hsm.call("initialize", self)
	_state_authority_hsm.call("set_active", true)
	_state_authority_backend = "limboai"


func _has_methods(candidate: Object, method_names: Array) -> bool:
	for method_name in method_names:
		if not candidate.has_method(str(method_name)):
			return false
	return true


func _dispose_candidates(candidates: Array) -> void:
	for candidate in candidates:
		_dispose_candidate(candidate)


func _dispose_candidate(candidate: Object) -> void:
	if candidate == null:
		return
	if candidate is Node and candidate.get_parent() != null:
		candidate.get_parent().remove_child(candidate)
	candidate.free()


func _is_known_state_context(state_context: String) -> bool:
	return state_context in [STATE_IDLE, STATE_WALK, STATE_DASH, STATE_JUMP, STATE_HURT, STATE_DEAD]
