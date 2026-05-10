extends RigidBody3D

# AI bot car — V0.20 arch-based.
# Each frame, bot reads its target arch position from meta (set by race_manager)
# and steers toward it. No path/spline lookahead anymore.
# Rubber-banding compares arches_passed vs P1.

@export var bot_color: Color = Color(0.2, 0.4, 0.9, 1.0)
@export var skill: float = 1.0
@export var player_path: NodePath
@export var car_model_path: String = ""
@export var car_model_scale: float = 1.0
@export var car_model_y_offset: float = -0.25

# BASELINE V0.3 physics — v0.18.0 -20% scale
const TOP_SPEED := 33.6
const ACCEL := 16.0
const TURN_RATE := 3.4
const TURN_RATE_LOW_SPEED := 2.0
const TURN_RATE_DRIFT_BONUS := 1.20
const LATERAL_GRIP := 8.0
const DRIFT_GRIP := 1.8
const HARD_TURN_SPEED_FACTOR := 0.55
const STEER_TOP_LOSS := 0.15

# AI tuning
const STEER_GAIN := 2.0
const RAYCAST_LENGTH := 13.0          # forward raycast — bumped for arch-based steering
const RAYCAST_SIDE_LENGTH := 8.0      # ±35° side raycasts — early-warn when fwd ray misses corner-clipping
const RAYCAST_SIDE_ANGLE_DEG := 35.0
const AVOID_STEER_BLEND := 0.85       # higher prio to avoidance vs centerline (was 0.7)
const AVOID_BRAKE_FRACTION := 0.55    # cap top speed at 55% when an obstacle is close
const NOISE_SCALE := 0.25

# Rubber-banding (vs player). Compares arches_passed delta.
# +1 arch ahead of player → bot slowed by 18%; +1 arch behind → boosted by 18%.
const RUBBER_PER_ARCH := 0.18
const RUBBER_MAX := 0.50
const RUBBER_DEAD_ZONE_ARCHES := 1

var _base_top_speed: float = TOP_SPEED
var _bot_top_speed: float = TOP_SPEED
var _player: Node3D = null

# Boost
var _boost_until: float = 0.0
var _boost_factor: float = 1.0

# Particle FX
var _smoke_left: CPUParticles3D
var _smoke_right: CPUParticles3D
var _boost_trail: CPUParticles3D

# Driving imperfection
var _noise_phase: float = 0.0
@export var driving_imperfection: float = 0.25

# Navigation (Tier 2 — A* around walls / decor)
var _nav_agent: NavigationAgent3D = null
var _last_nav_target: Vector3 = Vector3.ZERO

# Stuck detection (Tier 1 fallback when nav fails)
const STUCK_SPEED_THRESHOLD := 1.5    # m/s — below = potentially stuck
const STUCK_TIME := 1.5                # s — must be slow this long
const STUCK_RECOVERY_TIME := 1.2       # s — wiggle/reverse for this long
var _stuck_timer: float = 0.0
var _recovery_timer: float = 0.0
var _recovery_dir: int = 1             # 1 or -1 — alternates the wiggle


func apply_boost(duration: float, factor: float) -> void:
	_boost_until = Time.get_ticks_msec() / 1000.0 + duration
	_boost_factor = factor
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


func _ready() -> void:
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 0.5
	angular_damp = 4.0
	collision_layer = 1
	collision_mask = 1
	_base_top_speed = TOP_SPEED * skill
	_bot_top_speed = _base_top_speed
	_noise_phase = randf_range(0.0, TAU)
	if player_path and not player_path.is_empty():
		_player = get_node_or_null(player_path) as Node3D

	if not _build_car_visual_from_glb():
		_build_car_visual(bot_color)
	_smoke_left = _make_smoke_emitter(Vector3(-0.45, 0.0, 0.95))
	_smoke_right = _make_smoke_emitter(Vector3(0.45, 0.0, 0.95))
	_boost_trail = _make_boost_emitter(Vector3(0.0, 0.05, 1.05))
	add_child(_smoke_left)
	add_child(_smoke_right)
	add_child(_boost_trail)

	# NavigationAgent3D for A* pathfinding around obstacles
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 2.0
	_nav_agent.target_desired_distance = 3.0
	_nav_agent.path_max_distance = 20.0
	_nav_agent.avoidance_enabled = false  # we handle car-vs-car via raycast
	add_child(_nav_agent)


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


func _arches_passed_for(node: Node) -> int:
	if node == null:
		return 0
	if node.has_meta("race_arches_passed_total"):
		return int(node.get_meta("race_arches_passed_total", 0))
	return 0


func _physics_process(delta: float) -> void:
	if freeze:
		return

	var pos: Vector3 = global_position

	# 1. Final goal = next arch position (pushed by race_manager).
	#    Steering target = next path waypoint from NavigationAgent3D, falling
	#    back to the arch directly if no path is available.
	var goal_pos: Vector3 = pos
	var has_goal: bool = false
	if has_meta("race_next_arch_pos"):
		goal_pos = get_meta("race_next_arch_pos") as Vector3
		has_goal = true

	var target_pos: Vector3 = goal_pos
	var has_target: bool = has_goal
	if has_goal and _nav_agent != null:
		# Update agent target only when the arch changes (avoid recompute every frame)
		if _last_nav_target.distance_squared_to(goal_pos) > 0.25:
			_nav_agent.target_position = goal_pos
			_last_nav_target = goal_pos
		var nav_next: Vector3 = _nav_agent.get_next_path_position()
		# If the agent has a path, use the next waypoint; otherwise the arch itself.
		if not _nav_agent.is_navigation_finished() and pos.distance_squared_to(nav_next) > 0.04:
			target_pos = nav_next

	# 2. Steering inputs
	var fwd: Vector3 = -transform.basis.z
	var right: Vector3 = transform.basis.x
	var vel: Vector3 = linear_velocity
	var fwd_speed: float = vel.dot(fwd)
	var lateral_speed: float = vel.dot(right)

	# 2b. Stuck detection — track low-speed time, trigger recovery if persistent
	if _recovery_timer > 0.0:
		_recovery_timer -= delta
		# Force a hard alternating steer + reverse during recovery
		var rec_steer: float = float(_recovery_dir) * 1.0
		var rev_force: Vector3 = -fwd * ACCEL * mass * 0.6
		apply_central_force(rev_force)
		angular_velocity.y = rec_steer * TURN_RATE_LOW_SPEED * 1.4
		# Skip the rest of normal driving
		_update_particles(fwd, false)
		return
	if abs(fwd_speed) < STUCK_SPEED_THRESHOLD and has_goal:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_TIME:
			_recovery_timer = STUCK_RECOVERY_TIME
			_recovery_dir = -_recovery_dir  # alternate L/R each trigger
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

	# 3. Rubber-banding vs P1 by arches_passed delta
	if _player:
		var my_passed: int = _arches_passed_for(self)
		var p_passed: int = _arches_passed_for(_player)
		var diff: int = my_passed - p_passed
		if abs(diff) > RUBBER_DEAD_ZONE_ARCHES:
			var sign_d: int = -1 if diff > 0 else 1
			var mag: float = clamp(float(abs(diff) - RUBBER_DEAD_ZONE_ARCHES) * RUBBER_PER_ARCH, 0.0, RUBBER_MAX)
			var rubber: float = 1.0 + float(sign_d) * mag
			_bot_top_speed = _base_top_speed * rubber
		else:
			_bot_top_speed = _base_top_speed

	# 4. Steering toward target arch
	var centerline_steer: float = 0.0
	if has_target:
		var to_target: Vector3 = target_pos - pos
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			var cross_y: float = fwd.z * to_target.x - fwd.x * to_target.z
			var fwd_xz_len: float = sqrt(fwd.x * fwd.x + fwd.z * fwd.z)
			var to_target_len: float = to_target.length()
			var sin_angle: float = cross_y / (fwd_xz_len * to_target_len + 0.0001)
			centerline_steer = clamp(sin_angle * STEER_GAIN, -1.0, 1.0)

	# 5. Obstacle avoidance via 3-raycast cone (forward + ±RAYCAST_SIDE_ANGLE_DEG)
	# Each ray hits → contribute to avoid_steer with a sign opposite to the hit's lateral.
	# Side rays are weaker than forward.
	var avoid_steer: float = 0.0
	var avoid_active: bool = false
	var avoid_close: bool = false
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_origin: Vector3 = pos + Vector3(0, 0.3, 0)
	var side_angle: float = deg_to_rad(RAYCAST_SIDE_ANGLE_DEG)
	var sin_a: float = sin(side_angle)
	var cos_a: float = cos(side_angle)
	# Build the 3 ray dirs in XZ-plane around fwd
	var fwd_xz: Vector3 = Vector3(fwd.x, 0, fwd.z).normalized()
	var ray_dirs_lengths: Array = [
		[fwd_xz, RAYCAST_LENGTH, 1.0],                                                # forward
		[Vector3(fwd_xz.x * cos_a - fwd_xz.z * sin_a, 0, fwd_xz.x * sin_a + fwd_xz.z * cos_a), RAYCAST_SIDE_LENGTH, 0.55],  # +35° (left turn)
		[Vector3(fwd_xz.x * cos_a + fwd_xz.z * sin_a, 0, -fwd_xz.x * sin_a + fwd_xz.z * cos_a), RAYCAST_SIDE_LENGTH, 0.55], # -35° (right turn)
	]
	var nearest_hit_dist: float = INF
	for entry in ray_dirs_lengths:
		var dir: Vector3 = entry[0]
		var length: float = entry[1]
		var weight: float = entry[2]
		var ray_end: Vector3 = ray_origin + dir * length
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.exclude = [self.get_rid()]
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_body: Object = hit.get("collider")
		if hit_body == null or hit_body is RigidBody3D:
			continue  # ignore other cars
		var hit_pos: Vector3 = hit.position
		var to_hit: Vector3 = hit_pos - pos
		to_hit.y = 0.0
		var hit_cross: float = fwd.z * to_hit.x - fwd.x * to_hit.z
		# Steer in the OPPOSITE lateral direction
		var steer_delta: float = 0.0
		if abs(hit_cross) < 0.3:
			# Pile devant — break tie based on which side the target arch is on
			steer_delta = -sign(centerline_steer + 0.001) * 0.95
		else:
			steer_delta = -sign(hit_cross) * 0.95
		avoid_steer += steer_delta * weight
		avoid_active = true
		var d: float = to_hit.length()
		if d < nearest_hit_dist:
			nearest_hit_dist = d
		if d < 5.0:
			avoid_close = true
	avoid_steer = clamp(avoid_steer, -1.0, 1.0)

	# 6. Driving imperfection — sinusoidal wobble
	if driving_imperfection > 0.001:
		var t_now: float = Time.get_ticks_msec() / 1000.0
		var noise: float = sin(t_now * 1.7 + _noise_phase) * 0.65 + sin(t_now * 0.43 + _noise_phase * 1.7) * 0.45
		centerline_steer += noise * driving_imperfection * NOISE_SCALE

	# 7. Combine steer
	var steer_input: float
	if avoid_active:
		steer_input = lerp(centerline_steer, avoid_steer, AVOID_STEER_BLEND)
	else:
		steer_input = centerline_steer
	steer_input = clamp(steer_input, -1.0, 1.0)

	# 8. Auto-acceleration with steer drag (no off-track penalty in arch-based)
	#    Cap top speed when obstacle is very close so the bot has time to actually turn.
	var top: float = _effective_top_speed() * (1.0 - abs(steer_input) * STEER_TOP_LOSS)
	if avoid_close:
		top *= AVOID_BRAKE_FRACTION
	if fwd_speed < top:
		apply_central_force(fwd * ACCEL * mass)

	# 9. Apply yaw rate (drift bonus when hard-turning)
	var speed_ratio: float = clamp(fwd_speed / max(top, 0.01), 0.0, 1.0)
	var is_hard_turning: bool = abs(steer_input) > 0.5 and speed_ratio > HARD_TURN_SPEED_FACTOR
	var turn_rate: float = lerp(TURN_RATE_LOW_SPEED, TURN_RATE, speed_ratio)
	if is_hard_turning:
		turn_rate *= TURN_RATE_DRIFT_BONUS
	angular_velocity.y = steer_input * turn_rate

	# 10. Drift / lateral grip
	var grip: float = DRIFT_GRIP if is_hard_turning else LATERAL_GRIP
	var lateral_correction: Vector3 = -right * lateral_speed * grip * delta
	apply_central_impulse(lateral_correction * mass)

	# 11. Particle FX
	_update_particles(fwd, is_hard_turning)


func _update_particles(fwd: Vector3, drifting: bool) -> void:
	var back_dir: Vector3 = -fwd
	if _smoke_left:
		_smoke_left.emitting = drifting
		_smoke_left.direction = back_dir + Vector3(0, 0.5, 0)
	if _smoke_right:
		_smoke_right.emitting = drifting
		_smoke_right.direction = back_dir + Vector3(0, 0.5, 0)
	if _boost_trail:
		var boost_active: bool = (Time.get_ticks_msec() / 1000.0) < _boost_until
		_boost_trail.emitting = boost_active
		_boost_trail.direction = back_dir
