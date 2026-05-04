extends Camera3D

# Multi-target chase cam. Single-target = behind-the-leader chase. Multi-target
# = midpoint with adaptive zoom. v0.19.0 added is_on_screen(node) for the
# elimination_manager's off-screen tracker.

@export var target_path: NodePath
@export var target_paths: Array[NodePath] = []
@export var height: float = 22.0
@export var max_height: float = 80.0
@export var zoom_per_meter: float = 0.18
@export var back_offset: float = 6.0
@export var smoothing: float = 5.0
@export var off_screen_margin: float = 8.0  # m — counted off-screen if outside frustum + this margin

var _targets: Array = []

var _shake_intensity: float = 0.0
const SHAKE_DECAY := 6.0


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


func set_targets_to(nodes: Array) -> void:
	_targets.clear()
	for n in nodes:
		if n != null:
			_targets.append(n)


func set_leader_target(node: Node3D) -> void:
	if node == null:
		return
	set_targets_to([node])


func is_on_screen(node: Node3D) -> bool:
	# Used by elimination_manager to detect MMV3-style off-screen stragglers.
	# We accept points slightly outside the frustum (off_screen_margin in world
	# units along the camera-forward plane) so a car kissing the edge isn't
	# flagged as out.
	if node == null or not is_inside_tree():
		return false
	var pos: Vector3 = node.global_position
	if is_position_in_frustum(pos):
		return true
	# Margin check: shift the test point slightly toward the camera and re-test.
	var to_cam: Vector3 = (global_position - pos)
	if to_cam.length() < 0.01:
		return true
	to_cam = to_cam.normalized()
	return is_position_in_frustum(pos + to_cam * off_screen_margin)


func _physics_process(delta: float) -> void:
	if _targets.is_empty():
		return

	var midpoint: Vector3 = Vector3.ZERO
	for t in _targets:
		midpoint += t.global_position
	midpoint /= float(_targets.size())

	var max_dist: float = 0.0
	for t in _targets:
		var d: float = t.global_position.distance_to(midpoint)
		if d > max_dist:
			max_dist = d

	var adaptive_height: float = clamp(height + max_dist * zoom_per_meter, height, max_height)

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
