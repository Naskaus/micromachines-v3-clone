extends Camera3D

# Multi-target chase cam — follows the midpoint of all assigned targets, with adaptive height
# that zooms out when targets spread apart. Single-target mode (target_path) is preserved for
# backward compat (used by V0.4 single-player).

@export var target_path: NodePath  # legacy single-target (used by V0.4)
@export var target_paths: Array[NodePath] = []  # multi-target (V0.5+)
@export var height: float = 22.0       # base height above midpoint
@export var max_height: float = 80.0   # cap when targets are far apart
@export var zoom_per_meter: float = 0.18  # +0.18m height per 1m of separation
@export var back_offset: float = 6.0   # backward offset (in -Z direction = "north")
@export var smoothing: float = 5.0

var _targets: Array = []

# Shake state — public via add_shake() from car/race events
var _shake_intensity: float = 0.0
const SHAKE_DECAY := 6.0  # decays per second


func add_shake(amount: float) -> void:
	if amount > _shake_intensity:
		_shake_intensity = amount


func _ready() -> void:
	if target_path and not target_path.is_empty():
		var t: Node3D = get_node_or_null(target_path) as Node3D
		if t:
			_targets.append(t)
	for tp in target_paths:
		var t: Node3D = get_node_or_null(tp) as Node3D
		if t and not _targets.has(t):
			_targets.append(t)


# Replace the active target list (used by race_manager mode selector + leader switching).
func set_targets_to(nodes: Array) -> void:
	_targets.clear()
	for n in nodes:
		if n != null:
			_targets.append(n)


# Used by race_manager to switch to single-target leader chase mode.
func set_leader_target(node: Node3D) -> void:
	if node == null:
		return
	set_targets_to([node])


func _physics_process(delta: float) -> void:
	if _targets.is_empty():
		return

	# Compute midpoint of all targets
	var midpoint: Vector3 = Vector3.ZERO
	for t in _targets:
		midpoint += t.global_position
	midpoint /= float(_targets.size())

	# Find max distance from midpoint to any target — drives the zoom-out
	var max_dist: float = 0.0
	for t in _targets:
		var d: float = t.global_position.distance_to(midpoint)
		if d > max_dist:
			max_dist = d

	var adaptive_height: float = clamp(height + max_dist * zoom_per_meter, height, max_height)

	# Single target: use the existing chase-cam (behind in target's local frame).
	# Multi-target: position straight above midpoint, with small +Z back offset.
	var jitter: Vector3 = Vector3.ZERO
	if _shake_intensity > 0.001:
		jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity
		_shake_intensity = max(0.0, _shake_intensity - SHAKE_DECAY * delta)
	if _targets.size() == 1:
		var car_basis: Basis = _targets[0].transform.basis
		var local_offset: Vector3 = Vector3(0.0, adaptive_height, back_offset)
		var desired_pos: Vector3 = _targets[0].global_position + car_basis * local_offset + jitter
		global_position = global_position.lerp(desired_pos, clamp(smoothing * delta, 0.0, 1.0))
		look_at(_targets[0].global_position, Vector3.UP)
	else:
		var desired_pos: Vector3 = midpoint + Vector3(0.0, adaptive_height, back_offset) + jitter
		global_position = global_position.lerp(desired_pos, clamp(smoothing * delta, 0.0, 1.0))
		look_at(midpoint, Vector3.UP)
