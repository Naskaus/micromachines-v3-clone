extends Node

# Multiplayer manager — runs alongside RaceManager when network mode is active.
#
# v0.17.x : send local P1 state @ 20Hz, spawn ghost cars from peer state.
# v0.19.0 : when local client is host, ALSO register + send state for bots
# (their player_id is negative). Other clients spawn ghost cars for both
# human peers AND bot peers exactly the same way — the visual difference
# is just color & label, the network layer is identical.

const GhostCar = preload("res://scripts/ghost_car.gd")
const SEND_RATE_HZ := 20.0
const SEND_INTERVAL := 1.0 / SEND_RATE_HZ

@export var local_player_path: NodePath
@export var ghost_parent_path: NodePath  # parent node for ghost car nodes (usually Main root)
@export var bot_paths: Array[NodePath] = []  # host syncs these with negative ids (-1, -2, …)

var _local_player: Node3D = null
var _ghost_parent: Node = null
var _bots: Array = []                 # Node3D bots, host only
var _bot_ids: Array[int] = []         # parallel to _bots
var _bot_registered: bool = false
var _ghosts: Dictionary = {}          # player_id → GhostCar
var _ghost_color_cache: Dictionary = {}  # player_id → palette index
var _send_accum: float = 0.0
var _next_color_index: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if local_player_path and not local_player_path.is_empty():
		_local_player = get_node_or_null(local_player_path) as Node3D
	if ghost_parent_path and not ghost_parent_path.is_empty():
		_ghost_parent = get_node_or_null(ghost_parent_path)
	if _ghost_parent == null:
		_ghost_parent = get_parent()
	# Resolve host-side bots — used in network races to fill the peloton.
	_bots.clear()
	_bot_ids.clear()
	for i in range(bot_paths.size()):
		var b: Node = get_node_or_null(bot_paths[i])
		if b is Node3D:
			_bots.append(b)
			_bot_ids.append(-(i + 1))  # -1, -2, -3, -4, …

	if NetworkClient:
		NetworkClient.peer_state.connect(_on_peer_state)
		NetworkClient.player_left.connect(_on_player_left)
		NetworkClient.race_start_signal.connect(_on_race_start)


func is_active() -> bool:
	return NetworkClient and NetworkClient.room_code != ""


func _on_race_start() -> void:
	# Host registers all its bots with the server right when the race starts so
	# the other clients spawn matching ghosts before the first state packet.
	if NetworkClient and NetworkClient.is_host and not _bot_registered:
		_register_bots()
		_bot_registered = true


func _register_bots() -> void:
	for i in range(_bots.size()):
		var b: Node = _bots[i]
		var color: Color = Color(0.6, 0.6, 0.6)
		if "bot_color" in b:
			color = b.bot_color
		NetworkClient.register_bot(_bot_ids[i], color)


func _process(delta: float) -> void:
	if not is_active() or _local_player == null:
		return
	_send_accum += delta
	if _send_accum >= SEND_INTERVAL:
		_send_accum = 0.0
		_send_local_state()
		if NetworkClient.is_host:
			_send_bots_state()


func _send_local_state() -> void:
	if _local_player == null or not is_instance_valid(_local_player):
		return
	if _local_player.has_method("is_frozen") and _local_player.is_frozen():
		return
	NetworkClient.send_state(_state_payload(_local_player))


func _send_bots_state() -> void:
	# Host only — each bot is a "peer" from the network's perspective.
	for i in range(_bots.size()):
		var b: Node = _bots[i]
		if not is_instance_valid(b):
			continue
		if b.has_method("is_frozen") and b.is_frozen():
			continue
		var payload: Dictionary = _state_payload(b)
		NetworkClient.send_bot_state(_bot_ids[i], payload)


func _state_payload(racer: Node) -> Dictionary:
	var pos: Vector3 = racer.global_position
	var yaw: float = racer.rotation.y if racer is Node3D else 0.0
	var speed: float = 0.0
	if racer is RigidBody3D:
		speed = (racer as RigidBody3D).linear_velocity.length()
	var phase: float = 0.0
	if "_path_phase" in racer:
		phase = racer._path_phase
	# Race-progress fields, when the racer exposes them via shared duck-typing.
	var laps: int = 0
	var next_arch: int = 0
	if racer.has_meta("race_laps"):
		laps = int(racer.get_meta("race_laps"))
	if racer.has_meta("race_next_arch"):
		next_arch = int(racer.get_meta("race_next_arch"))
	var finished: bool = false
	if racer.has_meta("race_finished"):
		finished = bool(racer.get_meta("race_finished"))
	return {
		"x": pos.x, "y": pos.y, "z": pos.z,
		"yaw": yaw, "v": speed,
		"phase": phase,
		"laps": laps,
		"next_arch": next_arch,
		"finished": finished,
	}


func _on_peer_state(player_id: int, msg: Dictionary) -> void:
	# v0.19.0: bots have player_id < 0 (host-registered). They render exactly
	# like human ghosts — same code path, just a different palette index.
	if player_id == 0:
		return
	if NetworkClient and player_id == NetworkClient.my_player_id:
		return  # don't ghost ourselves
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
	# Bots get a stable color slot based on |player_id| - 1 so all clients agree
	# on which ghost is which bot. Humans use the rolling counter.
	var idx: int
	if player_id < 0:
		idx = (-player_id) % 6  # bot palette slot
	else:
		idx = _next_color_index
		_next_color_index += 1
	_ghost_color_cache[player_id] = idx
	ghost.setup(player_id, idx)
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
	_bot_registered = false


# Public — race_manager queries this to know which network ghosts are alive,
# so it can include them when the server-rendered race_state references them.
func get_ghost(player_id: int) -> Node:
	return _ghosts.get(player_id, null)


func all_ghosts() -> Dictionary:
	return _ghosts
