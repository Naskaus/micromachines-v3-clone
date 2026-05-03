extends RigidBody3D

# AI bot car — projects its position onto the oval centerline at every frame, then targets
# a point a small angle ahead. Adds a "magnetic" corrective force to pull the bot back to
# the centerline if it strays beyond 70% of the track half-width. This guarantees the bot
# stays between the two white painted lines.
#
# V0.4: + raycast obstacle avoidance (cones, balls, walls) + Mario-Kart-style rubber-banding
# (top speed scales ±15% based on parametric distance to player).

@export var bot_color: Color = Color(0.2, 0.4, 0.9, 1.0)
@export var skill: float = 1.0  # 0.5 = sluggish, 1.5 = aggressive (multiplies top speed)
@export var player_path: NodePath  # set in Main.tscn — used for rubber-banding
@export var racing_line_offset: float = 0.0  # m perpendicular to centerline (- inner, + outer)

# Same physics baseline as player (BASELINE V0.3 — slow ramp + steer drag + better drift)
const TOP_SPEED := 42.0
const ACCEL := 20.0
const TURN_RATE := 3.4
const TURN_RATE_LOW_SPEED := 2.0
const TURN_RATE_DRIFT_BONUS := 1.20
const LATERAL_GRIP := 8.0
const DRIFT_GRIP := 1.8
const HARD_TURN_SPEED_FACTOR := 0.55
const STEER_TOP_LOSS := 0.15

# Oval (must match Track01.tscn / pool_felt shader / race_manager)
const OVAL_A := 140.0
const OVAL_B := 80.0
const TRACK_HALF_WIDTH := 6.0
const OFF_TRACK_MALUS := 0.5  # 50% top speed when bot strays beyond track band

# AI tuning
const LOOKAHEAD_RAD := 0.18           # ~10° around the oval — distance to look ahead
const STEER_GAIN := 2.0               # steering aggressiveness
const OFF_TRACK_THRESHOLD := 4.2      # 70% of track half width (6m) — start pulling back
const CENTERLINE_FORCE := 25.0        # N per meter of off-track offset

# Obstacle avoidance
const RAYCAST_LENGTH := 7.0           # m — how far ahead we look for obstacles
const AVOID_STEER_BLEND := 0.7        # 0=ignore obstacles, 1=ignore centerline; blend factor

# Rubber-banding (catch-up / slow-down based on parametric distance to player)
const RUBBER_MAX := 0.50              # ±50% top-speed adjustment — leaders brake harder when they pull away
const RUBBER_DEAD_ZONE := 0.02        # rad ≈ 4m of arc — kicks in almost immediately

var _base_top_speed: float = TOP_SPEED
var _bot_top_speed: float = TOP_SPEED
var _player: Node3D = null

# Boost (set by boost pads)
var _boost_until: float = 0.0
var _boost_factor: float = 1.0


func apply_boost(duration: float, factor: float) -> void:
	_boost_until = Time.get_ticks_msec() / 1000.0 + duration
	_boost_factor = factor


func _effective_top_speed() -> float:
	var s: float = _bot_top_speed
	if Time.get_ticks_msec() / 1000.0 < _boost_until:
		s *= _boost_factor
	return s


# Returns the bot's preferred-line point at parametric angle t (centerline + offset along normal).
func _preferred_point_at(t: float) -> Vector3:
	var center: Vector3 = Vector3(OVAL_A * cos(t), 0.5, OVAL_B * sin(t))
	if abs(racing_line_offset) < 0.001:
		return center
	# Outward unit normal to ellipse at angle t
	var nx: float = cos(t) / OVAL_A
	var nz: float = sin(t) / OVAL_B
	var nlen: float = sqrt(nx * nx + nz * nz)
	if nlen < 0.0001:
		return center
	nx /= nlen
	nz /= nlen
	return center + Vector3(nx * racing_line_offset, 0.0, nz * racing_line_offset)


func _off_track_factor() -> float:
	# Distance to actual centerline (not preferred line) — bot in painted band = no malus
	var p: Vector3 = global_position
	var t: float = atan2(p.z / OVAL_B, p.x / OVAL_A)
	var dx: float = p.x - OVAL_A * cos(t)
	var dz: float = p.z - OVAL_B * sin(t)
	if (dx * dx + dz * dz) > (TRACK_HALF_WIDTH * TRACK_HALF_WIDTH):
		return OFF_TRACK_MALUS
	return 1.0


func _ready() -> void:
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 0.5
	angular_damp = 4.0
	_base_top_speed = TOP_SPEED * skill
	_bot_top_speed = _base_top_speed
	if player_path and not player_path.is_empty():
		_player = get_node_or_null(player_path) as Node3D

	# Recolor mesh
	var mesh: MeshInstance3D = $MeshInstance3D
	var src_mat: Material = mesh.get_active_material(0)
	var mat: StandardMaterial3D = (src_mat.duplicate() if src_mat else StandardMaterial3D.new())
	mat.albedo_color = bot_color
	mesh.set_surface_override_material(0, mat)


func _physics_process(delta: float) -> void:
	if freeze:
		return

	var pos: Vector3 = global_position

	# 1. Project current position onto the oval (parametric angle t)
	var cur_t: float = atan2(pos.z / OVAL_B, pos.x / OVAL_A)

	# 2. Look ahead in the racing direction along the bot's PREFERRED LINE (with offset)
	var look_t: float = cur_t - LOOKAHEAD_RAD
	var target: Vector3 = _preferred_point_at(look_t)
	target.y = pos.y

	# 3. Compute closest point on bot's PREFERRED line for magnetic pull-back
	var preferred_pt: Vector3 = _preferred_point_at(cur_t)
	preferred_pt.y = pos.y
	var to_centerline: Vector3 = preferred_pt - pos  # named "centerline" for legacy, now means preferred line
	to_centerline.y = 0.0
	var off_track_dist: float = to_centerline.length()

	# 4. Compute physics inputs
	var fwd: Vector3 = -transform.basis.z
	var right: Vector3 = transform.basis.x
	var vel: Vector3 = linear_velocity
	var fwd_speed: float = vel.dot(fwd)
	var lateral_speed: float = vel.dot(right)

	# 5. Rubber-banding: scale top speed based on parametric distance to player
	if _player:
		var player_t: float = atan2(_player.global_position.z / OVAL_B, _player.global_position.x / OVAL_A)
		# Player goes CCW (decreasing t). bot_t > player_t = bot is behind. wrap to [-π, π].
		var t_diff: float = wrapf(cur_t - player_t, -PI, PI)
		var rubber: float = 1.0
		if abs(t_diff) > RUBBER_DEAD_ZONE:
			rubber = 1.0 + clamp(t_diff / (PI * 0.5), -1.0, 1.0) * RUBBER_MAX
		_bot_top_speed = _base_top_speed * rubber

	# 6. Magnetic pull back to centerline if off-track
	if off_track_dist > OFF_TRACK_THRESHOLD:
		var pull_strength: float = (off_track_dist - OFF_TRACK_THRESHOLD) * CENTERLINE_FORCE
		apply_central_force(to_centerline.normalized() * pull_strength * mass)

	# 7. Centerline-following steering
	var to_target: Vector3 = target - pos
	to_target.y = 0.0
	var centerline_steer: float = 0.0
	if to_target.length_squared() > 0.0001:
		var cross_y: float = fwd.z * to_target.x - fwd.x * to_target.z
		var fwd_xz_len: float = sqrt(fwd.x * fwd.x + fwd.z * fwd.z)
		var to_target_len: float = to_target.length()
		var sin_angle: float = cross_y / (fwd_xz_len * to_target_len + 0.0001)
		centerline_steer = clamp(sin_angle * STEER_GAIN, -1.0, 1.0)

	# 8. Obstacle avoidance via forward raycast
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
				# Obstacle dead ahead — dodge TOWARD the bot's preferred line
				# (turning away from the obstacle and back to the racing line at once)
				if to_centerline.length() > 0.5:
					var center_cross: float = fwd.z * to_centerline.x - fwd.x * to_centerline.z
					avoid_steer = sign(center_cross) * 0.9
				else:
					avoid_steer = 0.9
			else:
				avoid_steer = -sign(hit_cross) * 0.9
			avoid_active = true

	# 9. Combine steer
	var steer_input: float
	if avoid_active:
		steer_input = lerp(centerline_steer, avoid_steer, AVOID_STEER_BLEND)
	else:
		steer_input = centerline_steer
	steer_input = clamp(steer_input, -1.0, 1.0)

	# 10. Auto-acceleration (top × off-track malus × steer drag)
	var top: float = _effective_top_speed() * _off_track_factor() * (1.0 - abs(steer_input) * STEER_TOP_LOSS)
	if fwd_speed < top:
		apply_central_force(fwd * ACCEL * mass)

	# 11. Apply angular velocity (yaw rate scales with current speed; drift boost when hard turning)
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
