extends RigidBody3D

# Micromachines V3 clone — Car controller
# Auto-acceleration + 2-button steering. Drift via low lateral friction.
#
# ╔═══════════════════════════════════════════════════════════════════╗
# ║  BASELINE V0.1 — LOCKED 2026-05-02 — confirmed by Seb "trop bien" ║
# ║  Pre-req: Car.tscn must use PhysicsMaterial(friction=0)           ║
# ║  If you change anything below, BUMP THE VERSION + DATE.           ║
# ╚═══════════════════════════════════════════════════════════════════╝

@export var player_id: int = 1  # 1..4 — maps to InputMap actions p<N>_left / p<N>_right
@export var hud_label_path: NodePath
@export var spawn_pos: Vector3 = Vector3(0.0, 0.5, 80.0)
@export var spawn_yaw_deg: float = -90.0  # rotation around Y at spawn
@export var car_color: Color = Color(0.9, 0.2, 0.2, 1.0)  # body color (overrides Mat_red)
@export var respawn_keycode: int = KEY_R  # which key respawns this car

# --- Tuning constants (BASELINE V0.1) ---
const TOP_SPEED := 28.0          # m/s — cruise speed
const ACCEL := 50.0              # m/s² — snappy launch, overcomes residual damping
const TURN_RATE := 3.4           # rad/s — yaw rate at full speed
const TURN_RATE_LOW_SPEED := 2.0 # rad/s — yaw rate when nearly stopped (less twitchy)
const LATERAL_GRIP := 8.0        # how hard we kill sideways velocity (higher = less slide)
const DRIFT_GRIP := 3.0          # lateral grip when player is hard-turning (drift)
const HARD_TURN_SPEED_FACTOR := 0.7  # speed must be >70% top to "drift"

# --- Test toggle (T cycles slow/normal/fast, R respawns) ---
const SPEED_MODES := ["SLOW", "NORMAL", "FAST"]
const SPEED_FACTORS := [0.5, 1.0, 1.5]
var _speed_mode := 1
var _current_top_speed := TOP_SPEED

# --- Boost (set by boost pads) ---
var _boost_until: float = 0.0
var _boost_factor: float = 1.0

var _left_action: String
var _right_action: String
var _hud_label: Label


func apply_boost(duration: float, factor: float) -> void:
	_boost_until = Time.get_ticks_msec() / 1000.0 + duration
	_boost_factor = factor


func _effective_top_speed() -> float:
	var s: float = _current_top_speed
	if Time.get_ticks_msec() / 1000.0 < _boost_until:
		s *= _boost_factor
	return s


func _ready() -> void:
	_left_action = "p%d_left" % player_id
	_right_action = "p%d_right" % player_id
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 0.5
	angular_damp = 4.0
	if hud_label_path and not hud_label_path.is_empty():
		_hud_label = get_node_or_null(hud_label_path) as Label
	# Recolor the body mesh
	var mesh: MeshInstance3D = $MeshInstance3D
	var src_mat: Material = mesh.get_active_material(0)
	var mat: StandardMaterial3D = (src_mat.duplicate() if src_mat else StandardMaterial3D.new())
	mat.albedo_color = car_color
	mesh.set_surface_override_material(0, mat)
	_apply_speed_mode()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# T toggles speed mode for player 1 only (debug feature)
		if event.keycode == KEY_T and player_id == 1:
			_speed_mode = (_speed_mode + 1) % SPEED_MODES.size()
			_apply_speed_mode()
		elif event.keycode == respawn_keycode:
			_respawn()


func _apply_speed_mode() -> void:
	_current_top_speed = TOP_SPEED * SPEED_FACTORS[_speed_mode]
	if _hud_label:
		_hud_label.text = "Speed: %s  (top %.0f m/s)\n[T] cycle  [R] respawn  [A/D] steer" % [SPEED_MODES[_speed_mode], _current_top_speed]


func _respawn() -> void:
	global_position = spawn_pos
	rotation = Vector3(0.0, deg_to_rad(spawn_yaw_deg), 0.0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if freeze:
		return
	var fwd: Vector3 = -transform.basis.z
	var right: Vector3 = transform.basis.x
	var vel: Vector3 = linear_velocity
	var fwd_speed: float = vel.dot(fwd)
	var lateral_speed: float = vel.dot(right)

	# --- AUTO-ACCELERATION ---
	var top: float = _effective_top_speed()
	if fwd_speed < top:
		apply_central_force(fwd * ACCEL * mass)

	# --- STEERING (2 buttons only) ---
	var steer_input: float = 0.0
	if Input.is_action_pressed(_left_action):
		steer_input += 1.0
	if Input.is_action_pressed(_right_action):
		steer_input -= 1.0

	var speed_ratio: float = clamp(fwd_speed / top, 0.0, 1.0)
	var turn_rate: float = lerp(TURN_RATE_LOW_SPEED, TURN_RATE, speed_ratio)
	angular_velocity.y = steer_input * turn_rate

	# --- DRIFT / GRIP ---
	var is_hard_turning: bool = abs(steer_input) > 0.5 and speed_ratio > HARD_TURN_SPEED_FACTOR
	var grip: float = DRIFT_GRIP if is_hard_turning else LATERAL_GRIP
	var lateral_correction: Vector3 = -right * lateral_speed * grip * delta
	apply_central_impulse(lateral_correction * mass)
