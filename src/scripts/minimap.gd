extends Control

# Top-down minimap showing the oval circuit and every active racer as a colored dot.
# Reads racer state from race_manager via get_minimap_dots().

@export var race_manager_path: NodePath

const OVAL_A := 140.0
const OVAL_B := 80.0
const PADDING := 10.0  # px between oval and frame

var _race_manager: Node


func _ready() -> void:
	_race_manager = get_node_or_null(race_manager_path)
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var sz: Vector2 = size
	var center: Vector2 = sz * 0.5

	# Compute scale so the oval fits with PADDING margins on all sides
	var sx: float = (sz.x - PADDING * 2.0) / (OVAL_A * 2.0)
	var sy: float = (sz.y - PADDING * 2.0) / (OVAL_B * 2.0)
	var sc: float = min(sx, sy)

	# Background
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.10, 0.06, 0.65))
	# Frame
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.95, 0.95, 0.92, 0.7), false, 1.5)

	# Oval outline
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 48
	for i in range(n + 1):
		var t: float = float(i) / float(n) * TAU
		pts.append(Vector2(OVAL_A * cos(t) * sc, OVAL_B * sin(t) * sc) + center)
	draw_polyline(pts, Color(0.95, 0.95, 0.92, 0.85), 1.5)

	# Racer dots
	if _race_manager and _race_manager.has_method("get_minimap_dots"):
		for dot in _race_manager.get_minimap_dots():
			var p: Vector2 = Vector2(dot.pos.x * sc, dot.pos.z * sc) + center
			var r: float = 5.0 if dot.is_player else 4.0
			draw_circle(p, r, dot.color)
			if dot.is_player:
				# White ring around player dot for highlight
				draw_arc(p, r + 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 1.8)
