extends Node3D

# Visual-only car for a remote network player.
# Receives state updates (position, yaw, speed) and interpolates between them.
# No physics, no collision — pure render.

const COLORS: Array[Color] = [
	Color(0.95, 0.30, 0.85, 1),  # magenta
	Color(0.30, 0.95, 0.95, 1),  # cyan
	Color(0.95, 0.85, 0.30, 1),  # gold
	Color(0.50, 1.00, 0.30, 1),  # neon green
	Color(1.00, 0.55, 0.20, 1),  # orange
	Color(0.65, 0.40, 1.00, 1),  # purple
]

const MODELS: Array[String] = [
	"res://assets/cars/race-future.glb",
	"res://assets/cars/sedan-sports.glb",
	"res://assets/cars/hatchback-sports.glb",
	"res://assets/cars/race.glb",
	"res://assets/cars/kart-oobi.glb",
	"res://assets/cars/tractor.glb",
]

const INTERP_RATE := 12.0  # higher = snappier; lower = smoother but laggier

@export var player_id: int = 0
@export var color_index: int = 0

var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _target_speed: float = 0.0
var _current_pos: Vector3 = Vector3.ZERO
var _current_yaw: float = 0.0
var _has_state: bool = false
var _model_root: Node3D = null
var _name_label: Label3D = null


func setup(pid: int, idx: int) -> void:
	player_id = pid
	color_index = idx % COLORS.size()


func _ready() -> void:
	# Build visual: load Kenney GLB
	var model_path: String = MODELS[color_index % MODELS.size()]
	var packed: PackedScene = load(model_path) as PackedScene
	if packed:
		var inst: Node = packed.instantiate()
		if inst is Node3D:
			_model_root = inst as Node3D
			_model_root.position = Vector3(0, -0.25, 0)
			_model_root.scale = Vector3(1.0, 1.0, 1.0)
			_model_root.rotation_degrees = Vector3(0, 180, 0)
		add_child(inst)
		_apply_color(inst, COLORS[color_index % COLORS.size()])

	# Floating name + neon ring above the ghost
	_name_label = Label3D.new()
	_name_label.text = "P%d" % player_id
	_name_label.font_size = 64
	_name_label.outline_size = 16
	_name_label.modulate = COLORS[color_index % COLORS.size()]
	_name_label.outline_modulate = Color(0, 0, 0, 1)
	_name_label.position = Vector3(0, 2.0, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	add_child(_name_label)

	# Subtle glow ring beneath the car (omnilight)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = COLORS[color_index % COLORS.size()]
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.position = Vector3(0, 0.3, 0)
	add_child(light)


func _apply_color(node: Node, tint: Color) -> void:
	# Apply tint to all mesh materials so each ghost is visually distinct
	# Also re-attach Kenney's colormap atlas (same workaround as car.gd)
	var colormap: Texture2D = load("res://assets/cars/Textures/colormap.png") as Texture2D
	_apply_tint_recursive(node, tint, colormap)


func _apply_tint_recursive(node: Node, tint: Color, colormap: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var sc: int = (mi.mesh.get_surface_count() if mi.mesh else 0)
		for i in range(sc):
			var src: Material = mi.get_active_material(i)
			var mat: StandardMaterial3D = (src.duplicate() as StandardMaterial3D) if src is StandardMaterial3D else StandardMaterial3D.new()
			if colormap:
				mat.albedo_texture = colormap
			# Strong tint to differentiate ghosts even with shared atlas
			mat.albedo_color = tint
			mat.emission_enabled = true
			mat.emission = tint
			mat.emission_energy_multiplier = 0.4
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_apply_tint_recursive(c, tint, colormap)


func update_state(pos: Vector3, yaw: float, speed: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_target_speed = speed
	if not _has_state:
		# First state — snap immediately to avoid an interpolation from origin
		_current_pos = pos
		_current_yaw = yaw
		global_position = pos
		rotation = Vector3(0, yaw, 0)
		_has_state = true


func _process(delta: float) -> void:
	if not _has_state:
		return
	# Interpolate position
	var t: float = clamp(delta * INTERP_RATE, 0.0, 1.0)
	_current_pos = _current_pos.lerp(_target_pos, t)
	_current_yaw = lerp_angle(_current_yaw, _target_yaw, t)
	global_position = _current_pos
	rotation = Vector3(0, _current_yaw, 0)
