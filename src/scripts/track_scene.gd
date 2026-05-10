class_name TrackScene
extends Node3D

# Arch-based track orchestrator. Attached to the root of every Track_<X>.tscn.
# Auto-discovers children by name convention and exposes them to the race manager.
#
# Convention:
#   Arches/Arch_1, Arch_2, ...   (Area3D, ArchMarker script preferred but optional)
#   Spawn                         (Node3D — pose for grid origin, faces toward Arch_1)
#   BoostPads/                    (any Area3D children with boost_pad.gd)
#   Ramps/                        (StaticBody3D children — visual + collider)
#   Decor/                        (any MeshInstance3D children — non-collidable)
#   Floor                         (StaticBody3D — track surface)

@export var track_id: String = "pool_felt"
@export var track_name: String = "Pool Felt"
@export var grid_rows: int = 3
@export var grid_cols: int = 2
@export var row_spacing: float = 5.5
@export var col_spacing: float = 3.0

var arches: Array[Node3D] = []
var spawn_slots: Array[Transform3D] = []


func _ready() -> void:
	_collect_arches()
	_compute_spawn_slots()


func _collect_arches() -> void:
	arches.clear()
	var arches_parent: Node = get_node_or_null("Arches")
	if arches_parent == null:
		push_warning("[TrackScene %s] No 'Arches/' child — track has no arches!" % track_id)
		return
	var children: Array[Node] = []
	for c in arches_parent.get_children():
		if c is Node3D and c.name.begins_with("Arch_"):
			children.append(c)
	children.sort_custom(func(a, b): return _arch_index(a.name) < _arch_index(b.name))
	for c in children:
		arches.append(c as Node3D)
	if arches.is_empty():
		push_warning("[TrackScene %s] Arches/ has no Arch_N children" % track_id)
	else:
		var names: Array[String] = []
		for a in arches:
			names.append(a.name)
		print("[TrackScene %s] %d arches: %s" % [track_id, arches.size(), ", ".join(names)])


func _arch_index(arch_name: String) -> int:
	var num_str: String = arch_name.substr(5)
	if num_str.is_valid_int():
		return num_str.to_int()
	return 0


func _compute_spawn_slots() -> void:
	spawn_slots.clear()
	var spawn_node: Node3D = get_node_or_null("Spawn") as Node3D
	if spawn_node == null:
		push_warning("[TrackScene %s] No 'Spawn' child — using origin" % track_id)
		spawn_slots.append(Transform3D.IDENTITY)
		return
	var origin: Vector3 = spawn_node.global_position
	# Spawn forward axis = -Z by Godot convention. Cars line up *behind* spawn (along +Z local).
	var spawn_basis: Basis = spawn_node.global_transform.basis
	var max_slots: int = grid_rows * grid_cols
	for row in range(grid_rows):
		for col in range(grid_cols):
			var local_offset: Vector3 = Vector3(
				(float(col) - (float(grid_cols) - 1.0) * 0.5) * col_spacing,
				0.0,
				float(row) * row_spacing
			)
			var world_offset: Vector3 = spawn_basis * local_offset
			var slot_pos: Vector3 = origin + world_offset
			slot_pos.y = origin.y
			var slot_xform: Transform3D = Transform3D(spawn_basis, slot_pos)
			spawn_slots.append(slot_xform)
			if spawn_slots.size() >= max_slots:
				break
		if spawn_slots.size() >= max_slots:
			break


func get_arch_position(idx: int) -> Vector3:
	if idx < 0 or idx >= arches.size():
		return Vector3.ZERO
	return arches[idx].global_position


func arch_count() -> int:
	return arches.size()
