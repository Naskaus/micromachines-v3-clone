extends RigidBody3D

# Player car (V0.20 — arch-based, path-free).
# Auto-acceleration + 2-button steering. Drift via low lateral friction.

@export var player_id: int = 1
@export var hud_label_path: NodePath
@export var spawn_pos: Vector3 = Vector3(0.0, 0.5, 80.0)
@export var spawn_yaw_deg: float = -90.0
@export var car_color: Color = Color(0.9, 0.2, 0.2, 1.0)
@export var car_model_path: String = ""
@export var car_model_scale: float = 1.0
@export var car_model_y_offset: float = -0.25
@export var respawn_keycode: int = KEY_R
@export var reverse_keycode: int = KEY_S
@export var camera_path: NodePath = NodePath("../Camera3D")

# --- Tuning constants (BASELINE V0.3 — slow ramp + steer drag + better drift) ---
const TOP_SPEED := 33.6
const ACCEL := 16.0
const TURN_RATE := 3.4
const TURN_RATE_LOW_SPEED := 2.0
const TURN_RATE_DRIFT_BONUS := 1.20
const LATERAL_GRIP := 8.0
const DRIFT_GRIP := 1.8
const HARD_TURN_SPEED_FACTOR := 0.55
const STEER_TOP_LOSS := 0.15

# --- Player catch-up rubber-banding (aggressive comeback) ---
const PLAYER_RUBBER_MAX := 0.80
const PLAYER_RUBBER_DEAD_ZONE := 0.5
const PLAYER_RUBBER_FULL_GAP := 3.0  # 3+ arches behind leader = max boost

# --- Test toggle ---
const SPEED_MODES := ["SLOW", "NORMAL", "FAST"]
const SPEED_FACTORS := [0.5, 1.0, 1.5]
var _speed_mode := 1
var _current_top_speed := TOP_SPEED

var _boost_until: float = 0.0
var _boost_factor: float = 1.0

const REVERSE_TOP_SPEED := -10.0
const REVERSE_FORCE_FACTOR := 0.7

var _progress_gap_to_leader: float = 0.0  # in arch-units now (was lap fraction)
var _was_drifting: bool = false


func set_race_progress_gap(gap: float) -> void:
	_progress_gap_to_leader = gap


func is_frozen() -> bool:
	return freeze


func _catch_up_factor() -> float:
	if _progress_gap_to_leader <= PLAYER_RUBBER_DEAD_ZONE:
		return 1.0
	var t: float = clamp(_progress_gap_to_leader / PLAYER_RUBBER_FULL_GAP, 0.0, 1.0)
	return 1.0 + t * PLAYER_RUBBER_MAX


var _left_action: String
var _right_action: String
var _hud_label: Label
var _camera: Node = null

var _smoke_left: CPUParticles3D
var _smoke_right: CPUParticles3D
var _boost_trail: CPUParticles3D


func _build_car_visual_from_glb() -> bool:
	if car_model_path.is_empty():
		return false
	var packed: PackedScene = load(car_model_path) as PackedScene
	if packed == null:
		push_warning("[car.gd] Could not load model at: " + car_model_path)
		return false
	var existing: Node = get_node_or_null("MeshInstance3D")
	if existing and existing is MeshInstance3D:
		existing.visible = false
	var inst: Node = packed.instantiate()
	inst.name = "CarModel"
	add_child(inst)
	if inst is Node3D:
		var n3d: Node3D = inst as Node3D
		n3d.position = Vector3(0, car_model_y_offset, 0)
		n3d.scale = Vector3(car_model_scale, car_model_scale, car_model_scale)
		n3d.rotation_degrees = Vector3(0, 180, 0)
	var colormap: Texture2D = load("res://assets/cars/Textures/colormap.png") as Texture2D
	if colormap:
		_apply_colormap_to_meshes(inst, colormap)
	return true


func _apply_colormap_to_meshes(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var sc: int = (mi.mesh.get_surface_count() if mi.mesh else 0)
		for i in range(sc):
			var src: Material = mi.get_active_material(i)
			var mat: StandardMaterial3D = (src.duplicate() as StandardMaterial3D) if src is StandardMaterial3D else StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
			mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_colormap_to_meshes(child, tex)


func _build_car_visual(body_color: Color) -> void:
	var existing: Node = get_node_or_null("MeshInstance3D")
	if existing and existing is MeshInstance3D:
		existing.visible = false
	var chassis: MeshInstance3D = MeshInstance3D.new()
	var cm: BoxMesh = BoxMesh.new()
	cm.size = Vector3(0.95, 0.30, 1.95)
	chassis.mesh = cm
	chassis.position = Vector3(0, -0.05, 0)
	var chassis_mat: StandardMaterial3D = StandardMaterial3D.new()
	chassis_mat.albedo_color = body_color
	chassis_mat.roughness = 0.5
	chassis_mat.metallic = 0.2
	chassis.set_surface_override_material(0, chassis_mat)
	add_child(chassis)
	var cabin: MeshInstance3D = MeshInstance3D.new()
	var cabin_m: BoxMesh = BoxMesh.new()
	cabin_m.size = Vector3(0.75, 0.32, 0.95)
	cabin.mesh = cabin_m
	cabin.position = Vector3(0, 0.26, -0.05)
	var cabin_mat: StandardMaterial3D = StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(body_color.r * 0.55, body_color.g * 0.55, body_color.b * 0.55, 1.0)
	cabin_mat.roughness = 0.3
	cabin.set_surface_override_material(0, cabin_mat)
	add_child(cabin)
	var wheel_positions: Array[Vector3] = [
		Vector3(-0.48, -0.18, 0.62),
		Vector3(0.48, -0.18, 0.62),
		Vector3(-0.48, -0.18, -0.62),
		Vector3(0.48, -0.18, -0.62),
	]
	for wpos in wheel_positions:
		var wheel: MeshInstance3D = MeshInstance3D.new()
		var wm: CylinderMesh = CylinderMesh.new()
		wm.top_radius = 0.20
		wm.bottom_radius = 0.20
		wm.height = 0.16
		wm.radial_segments = 10
		wheel.mesh = wm
		wheel.position = wpos
		wheel.rotation_degrees = Vector3(0, 0, 90)
		var wmat: StandardMaterial3D = StandardMaterial3D.new()
		wmat.albedo_color = Color(0.07, 0.07, 0.07)
		wmat.roughness = 0.95
		wheel.set_surface_override_material(0, wmat)
		add_child(wheel)


func _make_smoke_emitter(local_offset: Vector3) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.position = local_offset
	p.amount = 24
	p.lifetime = 0.55
	p.emitting = false
	p.local_coords = false
	p.spread = 35.0
	p.direction = Vector3(0, 0.4, 1)
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
	p.amount = 80
	p.lifetime = 0.45
	p.emitting = false
	p.local_coords = false
	p.spread = 38.0
	p.direction = Vector3(0, 0.15, 1)
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.color = Color(1.0, 0.45, 0.05, 0.95)
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.05, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15, 1.0)
	mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	p.mesh = mesh
	return p


func apply_boost(duration: float, factor: float) -> void:
	_boost_until = Time.get_ticks_msec() / 1000.0 + duration
	_boost_factor = factor
	var fwd: Vector3 = -transform.basis.z
	var fwd_speed: float = linear_velocity.dot(fwd)
	var target: float = _current_top_speed * factor
	if fwd_speed < target:
		var lateral: Vector3 = linear_velocity - fwd * fwd_speed
		linear_velocity = fwd * target + lateral
	if player_id == 1 and _camera and _camera.has_method("add_shake"):
		_camera.add_shake(1.2)


func _on_collision_impact(_body: Node) -> void:
	if player_id != 1 or _camera == null or not _camera.has_method("add_shake"):
		return
	var v: float = linear_velocity.length()
	if v < 25.0:
		return
	var amount: float = clamp((v - 25.0) * 0.06, 0.4, 2.5)
	_camera.add_shake(amount)
	if AudioManager:
		var key: String = "hit_heavy" if v > 35.0 else "hit_light"
		var pitch: float = clamp(0.9 + v * 0.005, 0.8, 1.3)
		AudioManager.play(key, -6.0, pitch)


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
	collision_layer = 1
	collision_mask = 1
	if hud_label_path and not hud_label_path.is_empty():
		_hud_label = get_node_or_null(hud_label_path) as Label
	if not _build_car_visual_from_glb():
		_build_car_visual(car_color)
	_smoke_left = _make_smoke_emitter(Vector3(-0.45, 0.0, 0.95))
	_smoke_right = _make_smoke_emitter(Vector3(0.45, 0.0, 0.95))
	_boost_trail = _make_boost_emitter(Vector3(0.0, 0.05, 1.05))
	add_child(_smoke_left)
	add_child(_smoke_right)
	add_child(_boost_trail)
	if camera_path and not camera_path.is_empty():
		_camera = get_node_or_null(camera_path)
	if player_id == 1:
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_collision_impact)
	_apply_speed_mode()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
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

	if player_id == 1 and AudioManager:
		var ratio: float = clamp(absf(fwd_speed) / TOP_SPEED, 0.0, 1.5)
		AudioManager.set_engine_speed_ratio(ratio)

	var steer_input: float = 0.0
	if Input.is_action_pressed(_left_action):
		steer_input += 1.0
	if Input.is_action_pressed(_right_action):
		steer_input -= 1.0

	# Effective top: base × catch-up rubber × (1 - steer_drag). No off-track penalty.
	var top: float = _effective_top_speed() * _catch_up_factor() * (1.0 - abs(steer_input) * STEER_TOP_LOSS)
	var reverse_held: bool = Input.is_key_pressed(reverse_keycode)
	if reverse_held and fwd_speed > REVERSE_TOP_SPEED:
		apply_central_force(-fwd * ACCEL * mass * REVERSE_FORCE_FACTOR)
	elif not reverse_held and fwd_speed < top:
		apply_central_force(fwd * ACCEL * mass)

	var speed_ratio: float = clamp(fwd_speed / max(top, 0.01), 0.0, 1.0)
	var is_hard_turning: bool = abs(steer_input) > 0.5 and speed_ratio > HARD_TURN_SPEED_FACTOR
	var turn_rate: float = lerp(TURN_RATE_LOW_SPEED, TURN_RATE, speed_ratio)
	if is_hard_turning:
		turn_rate *= TURN_RATE_DRIFT_BONUS
	angular_velocity.y = steer_input * turn_rate

	_was_drifting = is_hard_turning

	var grip: float = DRIFT_GRIP if is_hard_turning else LATERAL_GRIP
	var lateral_correction: Vector3 = -right * lateral_speed * grip * delta
	apply_central_impulse(lateral_correction * mass)

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
