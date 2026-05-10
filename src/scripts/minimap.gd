extends Control

# Top-down minimap (V0.20 — arch-based).
# Draws a polyline through the track's arches (Arch_1 → Arch_2 → ... → loop)
# and every active racer as a colored dot.

@export var race_manager_path: NodePath

const PADDING := 10.0
const FALLBACK_HALF_SPAN := 120.0  # m — used when no arches exist yet

var _race_manager: Node


func _ready() -> void:
	_race_manager = get_node_or_null(race_manager_path)
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _arch_positions() -> PackedVector3Array:
	var pts := PackedVector3Array()
	if _race_manager == null:
		return pts
	if not "_arches" in _race_manager:
		return pts
	var arches: Array = _race_manager._arches
	for a in arches:
		if a is Node3D:
			pts.append((a as Node3D).global_position)
	return pts


func _draw() -> void:
	var sz: Vector2 = size
	var center: Vector2 = sz * 0.5

	var arches: PackedVector3Array = _arch_positions()
	# Compute world-space bounds for scaling
	var min_x: float = -FALLBACK_HALF_SPAN
	var max_x: float = FALLBACK_HALF_SPAN
	var min_z: float = -FALLBACK_HALF_SPAN
	var max_z: float = FALLBACK_HALF_SPAN
	if arches.size() > 0:
		min_x = arches[0].x
		max_x = arches[0].x
		min_z = arches[0].z
		max_z = arches[0].z
		for v in arches:
			if v.x < min_x: min_x = v.x
			if v.x > max_x: max_x = v.x
			if v.z < min_z: min_z = v.z
			if v.z > max_z: max_z = v.z
		# Pad bounds 30% so dots near the edge are visible
		var px: float = (max_x - min_x) * 0.3
		var pz: float = (max_z - min_z) * 0.3
		min_x -= px; max_x += px
		min_z -= pz; max_z += pz

	var span_x: float = max(1.0, max_x - min_x)
	var span_z: float = max(1.0, max_z - min_z)
	var sx: float = (sz.x - PADDING * 2.0) / span_x
	var sy: float = (sz.y - PADDING * 2.0) / span_z
	var sc: float = min(sx, sy)
	var cx: float = (min_x + max_x) * 0.5
	var cz: float = (min_z + max_z) * 0.5

	# Background
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.10, 0.06, 0.65))
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.95, 0.95, 0.92, 0.7), false, 1.5)

	# Arch polyline (closed loop)
	if arches.size() >= 2:
		var poly: PackedVector2Array = PackedVector2Array()
		for v in arches:
			poly.append(Vector2((v.x - cx) * sc, (v.z - cz) * sc) + center)
		# close loop
		poly.append(poly[0])
		draw_polyline(poly, Color(0.95, 0.95, 0.92, 0.85), 1.5)
		# Mark arch corners
		for v in arches:
			var p: Vector2 = Vector2((v.x - cx) * sc, (v.z - cz) * sc) + center
			draw_circle(p, 2.5, Color(1, 1, 0.4, 0.85))

	# Racer dots
	if _race_manager and _race_manager.has_method("get_minimap_dots"):
		for dot in _race_manager.get_minimap_dots():
			var p: Vector2 = Vector2((dot.pos.x - cx) * sc, (dot.pos.z - cz) * sc) + center
			var r: float = 5.0 if dot.is_player else 4.0
			draw_circle(p, r, dot.color)
			if dot.is_player:
				draw_arc(p, r + 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 1.8)
