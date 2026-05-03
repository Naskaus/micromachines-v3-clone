extends Node

# Multiplayer manager — runs alongside RaceManager when network mode is active.
# Responsibilities:
#   - Send local P1 state @ 20Hz (position, yaw, speed)
#   - Spawn/update ghost cars from remote peer state
#   - Despawn ghosts on player_left
#
# Designed to be IDLE if NetworkClient.room_code is empty (solo mode).

const GhostCar = preload("res://scripts/ghost_car.gd")
const SEND_RATE_HZ := 20.0
const SEND_INTERVAL := 1.0 / SEND_RATE_HZ

@export var local_player_path: NodePath
@export var ghost_parent_path: NodePath  # parent node for ghost car nodes (usually Main root)

var _local_player: Node3D = null
var _ghost_parent: Node = null
var _ghosts: Dictionary = {}  # player_id (int) → GhostCar instance
var _send_accum: float = 0.0
var _next_color_index: int = 1  # 0 reserved for local player palette


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if local_player_path and not local_player_path.is_empty():
		_local_player = get_node_or_null(local_player_path) as Node3D
	if ghost_parent_path and not ghost_parent_path.is_empty():
		_ghost_parent = get_node_or_null(ghost_parent_path)
	if _ghost_parent == null:
		_ghost_parent = get_parent()

	if NetworkClient:
		NetworkClient.peer_state.connect(_on_peer_state)
		NetworkClient.player_left.connect(_on_player_left)


func is_active() -> bool:
	return NetworkClient and NetworkClient.room_code != ""


func _process(delta: float) -> void:
	if not is_active() or _local_player == null:
		return
	_send_accum += delta
	if _send_accum >= SEND_INTERVAL:
		_send_accum = 0.0
		_send_local_state()


func _send_local_state() -> void:
	if _local_player == null or not is_instance_valid(_local_player):
		return
	# Skip frozen state — saves bandwidth pre-race
	if _local_player.has_method("is_frozen"):
		if _local_player.is_frozen():
			return
	var pos: Vector3 = _local_player.global_position
	var yaw: float = _local_player.rotation.y
	var speed: float = 0.0
	if _local_player is RigidBody3D:
		speed = (_local_player as RigidBody3D).linear_velocity.length()
	NetworkClient.send_state({
		"x": pos.x, "y": pos.y, "z": pos.z,
		"yaw": yaw,
		"v": speed,
	})


func _on_peer_state(player_id: int, msg: Dictionary) -> void:
	if player_id < 0:
		return
	var ghost: Node = _ghosts.get(player_id, null)
	if ghost == null:
		ghost = _spawn_ghost(player_id)
	if ghost == null:
		return
	var pos: Vector3 = Vector3(
		float(msg.get("x", 0.0)),
		float(msg.get("y", 0.5)),
		float(msg.get("z", 0.0))
	)
	var yaw: float = float(msg.get("yaw", 0.0))
	var v: float = float(msg.get("v", 0.0))
	if ghost.has_method("update_state"):
		ghost.update_state(pos, yaw, v)


func _spawn_ghost(player_id: int) -> Node:
	if _ghost_parent == null:
		return null
	var ghost = GhostCar.new()
	ghost.name = "Ghost_%d" % player_id
	ghost.setup(player_id, _next_color_index)
	_next_color_index += 1
	_ghost_parent.add_child(ghost)
	_ghosts[player_id] = ghost
	return ghost


func _on_player_left(player_id: int) -> void:
	if not _ghosts.has(player_id):
		return
	var ghost: Node = _ghosts[player_id]
	if is_instance_valid(ghost):
		ghost.queue_free()
	_ghosts.erase(player_id)


func clear_all_ghosts() -> void:
	for pid in _ghosts.keys():
		var g: Node = _ghosts[pid]
		if is_instance_valid(g):
			g.queue_free()
	_ghosts.clear()
	_next_color_index = 1
