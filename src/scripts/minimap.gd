extends Control

const PathUtils = preload("res://scripts/path_utils.gd")

# Top-down minimap showing the FIGURE-8 circuit and every active racer as a colored dot.

@export var race_manager_path: NodePath

const PADDING := 10.0  # px between the oval and the frame

var _race_manager: Node


func _ready() -> void:
	_race_manager = get_node_or_null(race_manager_path)
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var sz: Vector2 = size
	var center: Vector2 = sz * 0.5

	# Figure-8 spans X ± OVAL_A horizontally and ± (OVAL_H + OVAL_B) vertically
	var span_x: float = PathUtils.OVAL_A * 2.0
	var span_z: float = (PathUtils.OVAL_H + PathUtils.OVAL_B) * 2.0
	var sx: float = (sz.x - PADDING * 2.0) / span_x
	var sy: float = (sz.y - PADDING * 2.0) / span_z
	var sc: float = min(sx, sy)

	# Background
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.10, 0.06, 0.65))
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.95, 0.95, 0.92, 0.7), false, 1.5)

	# Two oval outlines (figure-8)
	var n: int = 48
	for cz in [-PathUtils.OVAL_H, PathUtils.OVAL_H]:
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(n + 1):
			var t: float = float(i) / float(n) * TAU
			pts.append(Vector2(PathUtils.OVAL_A * cos(t) * sc, (cz + PathUtils.OVAL_B * sin(t)) * sc) + center)
		draw_polyline(pts, Color(0.95, 0.95, 0.92, 0.85), 1.5)

	# Racer dots
	if _race_manager and _race_manager.has_method("get_minimap_dots"):
		for dot in _race_manager.get_minimap_dots():
			var p: Vector2 = Vector2(dot.pos.x * sc, dot.pos.z * sc) + center
			var r: float = 5.0 if dot.is_player else 4.0
			draw_circle(p, r, dot.color)
			if dot.is_player:
				draw_arc(p, r + 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 1.8)
