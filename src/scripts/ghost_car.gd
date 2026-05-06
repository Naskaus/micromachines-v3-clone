extends CharacterBody3D

# Visual-physical car for a remote network player.
#
# v0.17.x : pure visual Node3D — cars phased through each other.
# v0.19.0 : extends CharacterBody3D with a CollisionShape3D so cars actually
# bump and push at the figure-8 crossing. State updates are still the source
# of truth — we move the body kinematically toward the network position so
# physics handles contact response without overriding the host's authority.
#
# collision_layer = 2 (cars), collision_mask = 1 | 2 (world + cars)

const COLORS: Array[Color] = [
	Color(0.95, 0.30, 0.85, 1),
	Color(0.30, 0.95, 0.95, 1),
	Color(0.95, 0.85, 0.30, 1),
	Color(0.50, 1.00, 0.30, 1),
	Color(1.00, 0.55, 0.20, 1),
	Color(0.65, 0.40, 1.00, 1),
]

const MODELS: Array[String] = [
	"res://assets/cars/race-future.glb",
	"res://assets/cars/sedan-sports.glb",
	"res://assets/cars/hatchback-sports.glb",
	"res://assets/cars/race.glb",
	"res://assets/cars/kart-oobi.glb",
	"res://assets/cars/tractor.glb",
]

const INTERP_RATE := 12.0

@export var player_id: int = 0
@export var color_index: int = 0

var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _target_speed: float = 0.0
var _has_state: bool = false
var _model_root: Node3D = null
var _name_label: Label3D = null
var _is_eliminated: bool = false


func setup(pid: int, idx: int) -> void:
	player_id = pid
	color_index = idx % COLORS.size()


func _ready() -> void:
	# v0.19.1: stay on default layer 1 / mask 1 so we collide with the world
	# and other cars without breaking BoostPad/Area3D detection. The whole
	# point of CharacterBody3D vs the old Node3D is that we now have a body
	# at all — the layer doesn't need to be escalated for that.
	collision_layer = 1
	collision_mask = 1
	# Box shape sized to the car (matches Car.tscn convention)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 0.5, 2.0)
	col.shape = box
	col.position = Vector3(0, 0.0, 0)
	add_child(col)

	# Visual: load Kenney GLB
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

	_name_label = Label3D.new()
	if player_id < 0:
		_name_label.text = "BOT %d" % (-player_id)
	else:
		_name_label.text = "P%d" % player_id
	_name_label.font_size = 64
	_name_label.outline_size = 16
	_name_label.modulate = COLORS[color_index % COLORS.size()]
	_name_label.outline_modulate = Color(0, 0, 0, 1)
	_name_label.position = Vector3(0, 2.0, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	add_child(_name_label)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = COLORS[color_index % COLORS.size()]
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.position = Vector3(0, 0.3, 0)
	add_child(light)


func _apply_color(node: Node, tint: Color) -> void:
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
		# First state — snap immediately so we don't catapult from origin.
		global_position = pos
		rotation = Vector3(0, yaw, 0)
		_has_state = true


func set_eliminated(elim: bool) -> void:
	# Spectator mode (Q5): greyed + no collision + dimmed.
	# Node3D has no `modulate`, so we tweak the model's materials directly.
	if _is_eliminated == elim:
		return
	_is_eliminated = elim
	if elim:
		_apply_spectator_tint(_model_root, true)
		for c in get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
		if _name_label:
			_name_label.text = "%s — SPECTATEUR" % _name_label.text
			_name_label.modulate = Color(0.7, 0.7, 0.7, 0.85)
	else:
		_apply_spectator_tint(_model_root, false)
		for c in get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = false


func _apply_spectator_tint(node: Node, on: bool) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var sc: int = (mi.mesh.get_surface_count() if mi.mesh else 0)
		for i in range(sc):
			var src: Material = mi.get_active_material(i)
			if src is StandardMaterial3D:
				var mat: StandardMaterial3D = src.duplicate() as StandardMaterial3D
				if on:
					mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)
					mat.emission_energy_multiplier = 0.05
				else:
					mat.albedo_color = Color(1, 1, 1, 1)
				mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_apply_spectator_tint(c, on)


func _physics_process(delta: float) -> void:
	if not _has_state:
		return
	# Kinematic chase toward the network-reported position. velocity is set so
	# move_and_slide() handles wall + car collisions cleanly.
	var t: float = clamp(delta * INTERP_RATE, 0.0, 1.0)
	var desired_pos: Vector3 = global_position.lerp(_target_pos, t)
	var dpos: Vector3 = desired_pos - global_position
	if delta > 0.0001:
		velocity = dpos / delta
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	# Yaw is purely visual — interpolate independently of the physics body.
	var current_yaw: float = rotation.y
	var new_yaw: float = lerp_angle(current_yaw, _target_yaw, t)
	rotation = Vector3(0, new_yaw, 0)
