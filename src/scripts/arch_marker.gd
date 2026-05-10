class_name ArchMarker
extends Area3D

# Self-contained arch — visual + emission highlight. Race manager subscribes
# to body_entered on each arch via TrackScene.arches and validates the pass
# against car.next_arch_index.
#
# Optional: name colour and label for HUD/menu use. Defaults to neutral white.

@export var label: String = ""
@export var color_name: String = ""

const NORMAL_EMISSION := 1.5
const HIGHLIGHTED_EMISSION := 4.0

var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	for child_name in ["PillarLeft", "PillarRight", "Crossbar"]:
		var m: MeshInstance3D = get_node_or_null(child_name) as MeshInstance3D
		if m == null:
			continue
		var mat: Material = m.get_active_material(0)
		if mat == null or not (mat is StandardMaterial3D):
			continue
		var smat: StandardMaterial3D = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.set_surface_override_material(0, smat)
		_materials.append(smat)


func set_highlighted(highlighted: bool) -> void:
	var energy: float = HIGHLIGHTED_EMISSION if highlighted else NORMAL_EMISSION
	for mat in _materials:
		mat.emission_energy_multiplier = energy
