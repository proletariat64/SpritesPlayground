extends Node
class_name CombatStateMachine

const STATE_IDLE := "idle"
const STATE_WALK := "walk"
const STATE_DASH := "dash"
const STATE_JUMP := "jump"
const STATE_ATTACK := "attack"
const STATE_HURT := "hurt"
const STATE_DEAD := "dead"

var current_state: String = STATE_IDLE
var current_move: String = ""
var velocity: Vector2 = Vector2.ZERO
var visual_jump_offset: float = 0.0
var state_elapsed: float = 0.0
var facing: int = 1
var locked_attack_facing: int = 1

var walk_speed: float = 95.0
var dash_speed: float = 240.0
var dash_duration: float = 0.18
var jump_duration: float = 0.42
var jump_height: float = 34.0
var hurt_duration: float = 0.28

var _move_executor: Node


func configure(move_executor: Node) -> void:
	_move_executor = move_executor
	_move_executor.move_started.connect(_on_move_started)
	_move_executor.move_finished.connect(_on_move_finished)


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
			_enter_state(STATE_JUMP)
			return true
	return false


func can_start_attack() -> bool:
	return current_state in [STATE_IDLE, STATE_WALK]


func reset_to_idle() -> void:
	_move_executor.cancel()
	velocity = Vector2.ZERO
	visual_jump_offset = 0.0
	current_move = STATE_IDLE
	_enter_state(STATE_IDLE)


func enter_hurt() -> void:
	if current_state == STATE_DEAD:
		return
	_move_executor.cancel()
	current_move = ""
	_enter_state(STATE_HURT)


func enter_dead() -> void:
	_move_executor.cancel()
	current_move = ""
	velocity = Vector2.ZERO
	visual_jump_offset = 0.0
	_enter_state(STATE_DEAD)


func tick(delta: float, input_vector: Vector2) -> void:
	velocity = Vector2.ZERO
	state_elapsed += delta

	if current_state != STATE_ATTACK:
		if input_vector.x < -0.05:
			facing = -1
		elif input_vector.x > 0.05:
			facing = 1

	match current_state:
		STATE_DEAD:
			visual_jump_offset = 0.0
			return
		STATE_ATTACK:
			facing = locked_attack_facing
			_move_executor.tick()
			visual_jump_offset = 0.0
			return
		STATE_HURT:
			visual_jump_offset = 0.0
			if state_elapsed >= hurt_duration:
				_enter_locomotion(input_vector)
			return
		STATE_DASH:
			velocity = Vector2(float(facing) * dash_speed, 0.0)
			visual_jump_offset = 0.0
			if state_elapsed >= dash_duration:
				_enter_locomotion(input_vector)
			return
		STATE_JUMP:
			var progress := clampf(state_elapsed / jump_duration, 0.0, 1.0)
			visual_jump_offset = -sin(progress * PI) * jump_height
			velocity = input_vector.normalized() * walk_speed
			if state_elapsed >= jump_duration:
				visual_jump_offset = 0.0
				_enter_locomotion(input_vector)
			return

	_enter_locomotion(input_vector)


func current_frame() -> int:
	if current_state == STATE_ATTACK:
		return _move_executor.current_frame()
	return int(floor(state_elapsed * 8.0))


func _enter_locomotion(input_vector: Vector2) -> void:
	visual_jump_offset = 0.0
	if input_vector.length() > 0.05:
		velocity = input_vector.normalized() * walk_speed
		if current_state != STATE_WALK:
			_enter_state(STATE_WALK)
		else:
			current_move = STATE_WALK
	else:
		velocity = Vector2.ZERO
		if current_state != STATE_IDLE:
			_enter_state(STATE_IDLE)
		else:
			current_move = STATE_IDLE


func _enter_state(state_id: String) -> void:
	current_state = state_id
	state_elapsed = 0.0
	if state_id != STATE_ATTACK:
		current_move = state_id


func _on_move_finished(_move_id: String) -> void:
	if current_state == STATE_ATTACK:
		current_move = ""
		_enter_state(STATE_IDLE)


func _on_move_started(move_id: String) -> void:
	if current_state == STATE_DEAD or current_state == STATE_HURT:
		return
	locked_attack_facing = facing
	current_move = move_id
	_enter_state(STATE_ATTACK)
