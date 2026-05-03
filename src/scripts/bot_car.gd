extends RigidBody3D

const PathUtils = preload("res://scripts/path_utils.gd")

# AI bot car — follows the FIGURE-8 path defined by PathUtils.
# Each bot tracks its own _path_phase and steers toward path_at(phase + lookahead).
# Magnetic pull-back if the bot strays too far from path_at(phase).
# Same physics tuning as player (BASELINE V0.3) for symmetric collisions.

@export var bot_color: Color = Color(0.2, 0.4, 0.9, 1.0)
@export var skill: float = 1.0  # multiplies top speed
@export var player_path: NodePath
@export var racing_line_offset: float = 0.0  # m perpendicular to centerline (- inner, + outer)
@export var driving_imperfection: float = 0.25  # 0 = perfect line, 0.5 = drunken sailor
@export var car_model_path: String = ""
@export var car_model_scale: float = 1.0
@export var car_model_y_offset: float = -0.25
@export var initial_path_phase: float = 0.0  # where to start on the figure-8

# BASELINE V0.3 physics
const TOP_SPEED := 42.0
const ACCEL := 20.0
const TURN_RATE := 3.4
const TURN_RATE_LOW_SPEED := 2.0
const TURN_RATE_DRIFT_BONUS := 1.20
const LATERAL_GRIP := 8.0
const DRIFT_GRIP := 1.8
const HARD_TURN_SPEED_FACTOR := 0.55
const STEER_TOP_LOSS := 0.15

# Off-track + path
const TRACK_HALF_WIDTH := 6.0
const OFF_TRACK_MALUS := 0.5
const OFF_PATH_THRESHOLD := 7.0  # m from preferred path before magnetic pull engages
const PATH_PULL_FORCE := 6.0    # N per meter of off-path offset (gentle nudge, not catapult)

# AI tuning
const LOOKAHEAD_PHASE := 0.012   # ~6m of path ahead per meter of advance
const STEER_GAIN := 2.0
const RAYCAST_LENGTH := 7.0
const AVOID_STEER_BLEND := 0.7

# Rubber-banding (catch-up vs P1)
const RUBBER_MAX := 0.50
const RUBBER_DEAD_ZONE := 0.02

var _base_top_speed: float = TOP_SPEED
var _bot_top_speed: float = TOP_SPEED
var _player: Node3D = null
var _path_phase: float = 0.0

# Boost
var _boost_until: float = 0.0
var _boost_factor: float = 1.0

# Particle FX
var _smoke_left: CPUParticles3D
var _smoke_right: CPUParticles3D
var _boost_trail: CPUParticles3D

# Driving imperfection
var _noise_phase: float = 0.0


func apply_boost(duration: float, factor: float) -> void:
	_boost_until = Time.get_ticks_msec() / 1000.0 + duration
	_boost_factor = factor
	# Snap velocity instantly forward — same as player
	var fwd: Vector3 = -transform.basis.z
	var fwd_speed: float = linear_velocity.dot(fwd)
	var target: float = _bot_top_speed * factor
	if fwd_speed < target:
		var lateral: Vector3 = linear_velocity - fwd * fwd_speed
		linear_velocity = fwd * target + lateral


func _effective_top_speed() -> float:
	var s: float = _bot_top_speed
	if Time.get_ticks_msec() / 1000.0 < _boost_until:
		s *= _boost_factor
	return s


func _off_track_factor() -> float:
	# Distance to closest of the two ovals
	var p: Vector3 = global_position
	var d_top: float = _dist_to_ellipse_center(p, -PathUtils.OVAL_H)
	var d_bot: float = _dist_to_ellipse_center(p, PathUtils.OVAL_H)
	var d: float = min(d_top, d_bot)
	if d > TRACK_HALF_WIDTH:
		return OFF_TRACK_MALUS
	return 1.0


func _dist_to_ellipse_center(pos: Vector3, cz: float) -> float:
	var fx: float = pos.x
	var fz: float = pos.z - cz
	var a2: float = PathUtils.OVAL_A * PathUtils.OVAL_A
	var b2: float = PathUtils.OVAL_B * PathUtils.OVAL_B
	var f: float = (fx * fx) / a2 + (fz * fz) / b2 - 1.0
	var gx: float = 2.0 * fx / a2
	var gz: float = 2.0 * fz / b2
	var gmag: float = sqrt(gx * gx + gz * gz)
	return abs(f) / max(gmag, 0.0001)


func _ready() -> void:
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 0.5
	angular_damp = 4.0
	_base_top_speed = TOP_SPEED * skill
	_bot_top_speed = _base_top_speed
	_noise_phase = randf_range(0.0, TAU)
	# Derive path phase from actual spawn position (avoids huge off-path values when grid spawns spread cars)
	_path_phase = PathUtils.phase_from_position(global_position)
	if player_path and not player_path.is_empty():
		_player = get_node_or_null(player_path) as Node3D

	# Try Kenney .glb first; fallback to primitives
	if not _build_car_visual_from_glb():
		_build_car_visual(bot_color)
	# Particle FX
	_smoke_left = _make_smoke_emitter(Vector3(-0.45, 0.0, 0.95))
	_smoke_right = _make_smoke_emitter(Vector3(0.45, 0.0, 0.95))
	_boost_trail = _make_boost_emitter(Vector3(0.0, 0.05, 1.05))
	add_child(_smoke_left)
	add_child(_smoke_right)
	add_child(_boost_trail)


func _build_car_visual_from_glb() -> bool:
	if car_model_path.is_empty():
		return false
	var packed: PackedScene = load(car_model_path) as PackedScene
	if packed == null:
		push_warning("[bot_car.gd] Could not load model: " + car_model_path)
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


func _physics_process(delta: float) -> void:
	if freeze:
		return

	var pos: Vector3 = global_position

	# 1. Lookahead target on the figure-8 path (with optional offset perpendicular)
	var target: Vector3 = PathUtils.path_at(_path_phase + LOOKAHEAD_PHASE)
	target.y = pos.y
	if abs(racing_line_offset) > 0.001:
		var tangent: Vector3 = PathUtils.tangent_at(_path_phase + LOOKAHEAD_PHASE)
		var perp: Vector3 = Vector3(-tangent.z, 0, tangent.x)  # 90° rotation in XZ
		target += perp * racing_line_offset

	# 2. Compute path proximity (used only for avoidance dodge direction now — NO magnetic pull)
	var path_pt: Vector3 = PathUtils.path_at(_path_phase)
	path_pt.y = pos.y
	var to_path: Vector3 = path_pt - pos
	to_path.y = 0.0

	# 3. Physics inputs
	var fwd: Vector3 = -transform.basis.z
	var right: Vector3 = transform.basis.x
	var vel: Vector3 = linear_velocity
	var fwd_speed: float = vel.dot(fwd)
	var lateral_speed: float = vel.dot(right)

	# 4. Rubber-banding vs P1
	if _player:
		var p_phase: float = PathUtils.phase_from_position(_player.global_position)
		var t_diff: float = wrapf(_path_phase - p_phase, -0.5, 0.5)  # signed lap fraction
		var rubber: float = 1.0
		if abs(t_diff) > RUBBER_DEAD_ZONE:
			rubber = 1.0 + clamp(t_diff / 0.25, -1.0, 1.0) * RUBBER_MAX
		_bot_top_speed = _base_top_speed * rubber

	# 5. (Magnetic pull removed — was catapulting bots into walls. Steering alone keeps them on path.)

	# 6. Steering: cross product fwd × to_target
	var to_target: Vector3 = target - pos
	to_target.y = 0.0
	var centerline_steer: float = 0.0
	if to_target.length_squared() > 0.0001:
		var cross_y: float = fwd.z * to_target.x - fwd.x * to_target.z
		var fwd_xz_len: float = sqrt(fwd.x * fwd.x + fwd.z * fwd.z)
		var to_target_len: float = to_target.length()
		var sin_angle: float = cross_y / (fwd_xz_len * to_target_len + 0.0001)
		centerline_steer = clamp(sin_angle * STEER_GAIN, -1.0, 1.0)

	# 7. Obstacle avoidance via raycast
	var avoid_steer: float = 0.0
	var avoid_active: bool = false
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_origin: Vector3 = pos + Vector3(0, 0.3, 0)
	var ray_end: Vector3 = ray_origin + fwd * RAYCAST_LENGTH
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self.get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_body: Object = hit.get("collider")
		if hit_body and not (hit_body is RigidBody3D):
			var to_hit: Vector3 = hit.position - pos
			to_hit.y = 0.0
			var hit_cross: float = fwd.z * to_hit.x - fwd.x * to_hit.z
			if abs(hit_cross) < 0.5:
				if to_path.length() > 0.5:
					var center_cross: float = fwd.z * to_path.x - fwd.x * to_path.z
					avoid_steer = sign(center_cross) * 0.9
				else:
					avoid_steer = 0.9
			else:
				avoid_steer = -sign(hit_cross) * 0.9
			avoid_active = true

	# 8. Driving imperfection — sinusoidal wobble
	if driving_imperfection > 0.001:
		var t_now: float = Time.get_ticks_msec() / 1000.0
		var noise: float = sin(t_now * 1.7 + _noise_phase) * 0.65 + sin(t_now * 0.43 + _noise_phase * 1.7) * 0.45
		centerline_steer += noise * driving_imperfection

	# 9. Combine steer
	var steer_input: float
	if avoid_active:
		steer_input = lerp(centerline_steer, avoid_steer, AVOID_STEER_BLEND)
	else:
		steer_input = centerline_steer
	steer_input = clamp(steer_input, -1.0, 1.0)

	# 10. Auto-acceleration with off-track + steer drag
	var top: float = _effective_top_speed() * _off_track_factor() * (1.0 - abs(steer_input) * STEER_TOP_LOSS)
	if fwd_speed < top:
		apply_central_force(fwd * ACCEL * mass)

	# 11. Apply yaw rate (drift bonus when hard-turning)
	var speed_ratio: float = clamp(fwd_speed / top, 0.0, 1.0)
	var is_hard_turning: bool = abs(steer_input) > 0.5 and speed_ratio > HARD_TURN_SPEED_FACTOR
	var turn_rate: float = lerp(TURN_RATE_LOW_SPEED, TURN_RATE, speed_ratio)
	if is_hard_turning:
		turn_rate *= TURN_RATE_DRIFT_BONUS
	angular_velocity.y = steer_input * turn_rate

	# 12. Drift / lateral grip
	var grip: float = DRIFT_GRIP if is_hard_turning else LATERAL_GRIP
	var lateral_correction: Vector3 = -right * lateral_speed * grip * delta
	apply_central_impulse(lateral_correction * mass)

	# 13. Re-anchor _path_phase to actual position each frame (no drift, no false lap detection)
	_path_phase = PathUtils.phase_from_position(pos)

	# 14. Particle FX
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
