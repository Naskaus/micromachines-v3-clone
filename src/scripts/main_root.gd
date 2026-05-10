extends Node3D

# Main.tscn root. Instances the currently-selected track from Globals at _ready,
# and gives it a stable name so RaceManager's NodePath resolves regardless of
# which track is active.

const TRACK_NODE_NAME := "Track"


func _ready() -> void:
	var t: Dictionary = Globals.current_track()
	var path: String = String(t.get("scene", ""))
	if path.is_empty():
		push_warning("[Main] No track selected — falling back to Pool Felt")
		path = "res://scenes/tracks/Track_Pool_Felt.tscn"
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[Main] Could not load track scene: " + path)
		return
	var inst: Node = packed.instantiate()
	inst.name = TRACK_NODE_NAME
	# Insert as the FIRST child so RaceManager's _ready (lower in tree) finds it
	# during its own initialisation.
	add_child(inst)
	move_child(inst, 0)
	print("[Main] Track loaded: %s (%s)" % [t.get("name", "?"), path])
