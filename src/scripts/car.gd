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
@export var reverse_keycode: int = KEY_S  # held to reverse out of a stuck spot

# --- Tuning constants (BASELINE V0.3 — slow ramp + steer drag + better drift) ---
const TOP_SPEED := 42.0          # m/s — cruise speed
const ACCEL := 20.0              # m/s² — slow ramp, ~2s from 0 to top
const TURN_RATE := 3.4           # rad/s — yaw rate at full speed
const TURN_RATE_LOW_SPEED := 2.0 # rad/s — yaw rate when nearly stopped (less twitchy)
const TURN_RATE_DRIFT_BONUS := 1.20  # +20% yaw rate when drifting (car pivots more visibly)
const LATERAL_GRIP := 8.0        # how hard we kill sideways velocity (higher = less slide)
const DRIFT_GRIP := 1.8          # lateral grip when drifting — lower = longer slide (was 3.0)
const HARD_TURN_SPEED_FACTOR := 0.55 # speed > 55% top to "drift" — easier to trigger (was 0.7)
const STEER_TOP_LOSS := 0.15     # at full steer, effective top is reduced by this fraction (15%)

# --- Player catch-up rubber-banding (aggressive — make last-place comeback feel real) ---
const PLAYER_RUBBER_MAX := 0.80  # +80% top speed boost at max gap
const PLAYER_RUBBER_DEAD_ZONE := 0.02
const PLAYER_RUBBER_FULL_GAP := 0.10   # 10% lap behind = max boost — kicks in REALLY fast (was 0.15)

# --- Off-track speed malus (track is centerline ± TRACK_HALF_WIDTH) ---
const OVAL_A := 140.0
const OVAL_B := 80.0
const TRACK_HALF_WIDTH := 6.0
const OFF_TRACK_MALUS := 0.5  # 50% top speed when off the painted track

# --- Test toggle (T cycles slow/normal/fast, R respawns) ---
const SPEED_MODES := ["SLOW", "NORMAL", "FAST"]
const SPEED_FACTORS := [0.5, 1.0, 1.5]
var _speed_mode := 1
var _current_top_speed := TOP_SPEED

# --- Boost (set by boost pads) ---
var _boost_until: float = 0.0
var _boost_factor: float = 1.0

# --- Reverse gear ---
const REVERSE_TOP_SPEED := -10.0  # m/s — capped slow reverse for unsticking
const REVERSE_FORCE_FACTOR := 0.7  # multiplier on ACCEL when reversing

# --- Race progress (fed from race_manager for catch-up rubber-banding) ---
var _progress_gap_to_leader: float = 0.0  # >0 means I'm behind leader; updated each frame


func set_race_progress_gap(gap: float) -> void:
	_progress_gap_to_leader = gap


func _catch_up_factor() -> float:
	if _progress_gap_to_leader <= PLAYER_RUBBER_DEAD_ZONE:
		return 1.0
	var t: float = clamp(_progress_gap_to_leader / PLAYER_RUBBER_FULL_GAP, 0.0, 1.0)
	return 1.0 + t * PLAYER_RUBBER_MAX


func _off_track_factor() -> float:
	# Cheap centerline projection via parametric angle
	var p: Vector3 = global_position
	var t: float = atan2(p.z / OVAL_B, p.x / OVAL_A)
	var center_x: float = OVAL_A * cos(t)
	var center_z: float = OVAL_B * sin(t)
	var dx: float = p.x - center_x
	var dz: float = p.z - center_z
	if (dx * dx + dz * dz) > (TRACK_HALF_WIDTH * TRACK_HALF_WIDTH):
		return OFF_TRACK_MALUS
	return 1.0

var _left_action: String
var _right_action: String
var _hud_label: Label

# --- Particle FX (built programmatically in _ready) ---
var _smoke_left: CPUParticles3D
var _smoke_right: CPUParticles3D
var _boost_trail: CPUParticles3D


func _make_smoke_emitter(local_offset: Vector3) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.position = local_offset
	p.amount = 24
	p.lifetime = 0.55
	p.emitting = false
	p.local_coords = false
	p.spread = 35.0
	p.direction = Vector3(0, 0.4, 1)  # updated per frame to match car backward
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.color = Color(0.92, 0.92, 0.92, 0.55)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.92, 0.92, 0.55)
	mesh.material = mat
	p.mesh = mesh
	return p


func _make_boost_emitter(local_offset: Vector3) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.position = local_offset
	p.amount = 80              # 30 → 80 (much denser)
	p.lifetime = 0.45          # 0.30 → 0.45 (longer trail)
	p.emitting = false
	p.local_coords = false
	p.spread = 38.0            # 20 → 38° (wider cone of fire)
	p.direction = Vector3(0, 0.15, 1)
	p.initial_velocity_min = 7.0   # 4 → 7
	p.initial_velocity_max = 12.0  # 6.5 → 12 (fast streaks)
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6   # 0.3 → 0.6 (bigger)
	p.scale_amount_max = 1.5   # 0.6 → 1.5 (much bigger)
	p.color = Color(1.0, 0.45, 0.05, 0.95)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.35         # 0.22 → 0.35
	mesh.height = 0.7          # 0.44 → 0.7
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.05, 0.95)
	# Glow for "fire" effect — particles emit light against the dark felt
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15, 1.0)
	mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	p.mesh = mesh
	return p


func apply_boost(duration: float, factor: float) -> void:
	_boost_until = Time.get_ticks_msec() / 1000.0 + duration
	_boost_factor = factor
	# Snap forward velocity to target instantly — boost should feel VIOLENT
	# Lateral velocity preserved so drift continues
	var fwd: Vector3 = -transform.basis.z
	var fwd_speed: float = linear_velocity.dot(fwd)
	var target: float = _current_top_speed * factor
	if fwd_speed < target:
		var lateral: Vector3 = linear_velocity - fwd * fwd_speed
		linear_velocity = fwd * target + lateral


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
	# Particle FX (drift smoke from rear corners + boost trail from center rear)
	_smoke_left = _make_smoke_emitter(Vector3(-0.45, 0.0, 0.95))
	_smoke_right = _make_smoke_emitter(Vector3(0.45, 0.0, 0.95))
	_boost_trail = _make_boost_emitter(Vector3(0.0, 0.05, 1.05))
	add_child(_smoke_left)
	add_child(_smoke_right)
	add_child(_boost_trail)
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

	# --- STEERING (2 buttons only) — read first because it modulates the effective top speed ---
	var steer_input: float = 0.0
	if Input.is_action_pressed(_left_action):
		steer_input += 1.0
	if Input.is_action_pressed(_right_action):
		steer_input -= 1.0

	# --- REVERSE / AUTO-ACCEL (mutually exclusive) ---
	# Effective top: base × catch-up rubber × off-track malus × (1 - steer_drag)
	var top: float = _effective_top_speed() * _catch_up_factor() * _off_track_factor() * (1.0 - abs(steer_input) * STEER_TOP_LOSS)
	var reverse_held: bool = Input.is_key_pressed(reverse_keycode)
	if reverse_held and fwd_speed > REVERSE_TOP_SPEED:
		apply_central_force(-fwd * ACCEL * mass * REVERSE_FORCE_FACTOR)
	elif not reverse_held and fwd_speed < top:
		apply_central_force(fwd * ACCEL * mass)

	# --- DRIFT detection happens BEFORE the angular_velocity assignment
	# so we can boost yaw rate while drifting (car visibly pivots more)
	var speed_ratio: float = clamp(fwd_speed / top, 0.0, 1.0)
	var is_hard_turning: bool = abs(steer_input) > 0.5 and speed_ratio > HARD_TURN_SPEED_FACTOR
	var turn_rate: float = lerp(TURN_RATE_LOW_SPEED, TURN_RATE, speed_ratio)
	if is_hard_turning:
		turn_rate *= TURN_RATE_DRIFT_BONUS
	angular_velocity.y = steer_input * turn_rate

	# --- DRIFT / GRIP --- (is_hard_turning already computed above)
	var grip: float = DRIFT_GRIP if is_hard_turning else LATERAL_GRIP
	var lateral_correction: Vector3 = -right * lateral_speed * grip * delta
	apply_central_impulse(lateral_correction * mass)

	# --- PARTICLE FX ---
	# Direction updated each frame to match car backward in world frame (local_coords = false)
	var back_dir: Vector3 = -fwd
	if _smoke_left:
		_smoke_left.emitting = is_hard_turning
		_smoke_left.direction = back_dir + Vector3(0, 0.5, 0)
	if _smoke_right:
		_smoke_right.emitting = is_hard_turning
		_smoke_right.direction = back_dir + Vector3(0, 0.5, 0)
	if _boost_trail:
		var boost_active: bool = (Time.get_ticks_msec() / 1000.0) < _boost_until
		_boost_trail.emitting = boost_active
		_boost_trail.direction = back_dir
