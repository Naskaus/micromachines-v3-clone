extends Node

# v0.19.0 — MMV3-style off-screen elimination + lives.
#
# Two modes (set in lobby, default lives3):
#   * lives3 — 1.5s off-screen → respawn at back of pack, -1 life. 0 lives = eliminated.
#   * perma  — 1.5s off-screen → eliminated immediately (no respawn).
#
# Elimination semantics (Q5): eliminated cars become SPECTATORS — frozen + greyed
# + collision disabled — but the camera keeps following the leader so they can
# still watch the race finish.
#
# Authority: only the host runs the off-screen detection and decides who loses
# a life. The decision is broadcast via NetworkClient.send_elim_event(); the
# server ratifies it and re-broadcasts to all clients (including host) so
# everyone applies the same visual/state change.

const OFF_SCREEN_FRAMES_THRESHOLD := 90  # 1.5s @ 60fps
const RESPAWN_BEHIND_OFFSET := 8.0       # m — spawn this far behind the previous arch
const RESPAWN_SPEED_FRACTION := 0.5      # half of the leader's speed

@export var camera_path: NodePath
@export var race_manager_path: NodePath
@export var multiplayer_manager_path: NodePath
@export var hud_lives_label_path: NodePath  # optional Label that prints lives lines

var _camera: Node = null
var _race_manager: Node = null
var _multiplayer_manager: Node = null
var _hud_label: Label = null

# tracker_id -> { node, off_frames, lives, spectator, is_local }
var _trackers: Dictionary = {}
var _enabled: bool = false
var _last_authoritative_lives: Dictionary = {}  # from race_state pump


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_camera = get_node_or_null(camera_path)
	_race_manager = get_node_or_null(race_manager_path)
	_multiplayer_manager = get_node_or_null(multiplayer_manager_path)
	_hud_label = get_node_or_null(hud_lives_label_path) as Label
	if NetworkClient:
		NetworkClient.elim_event.connect(_on_elim_event)
		NetworkClient.race_state_received.connect(_on_race_state)


func enable_for(racers: Array, local_player_ids: Array, lives_per_racer: int) -> void:
	# Called by race_manager once the race actually starts.
	# `racers` is an Array of Node3D (cars + bots in solo, or {player_id, node} in MP).
	_trackers.clear()
	for r in racers:
		var entry: Dictionary
		if typeof(r) == TYPE_DICTIONARY:
			entry = r.duplicate()
		else:
			entry = {"node": r, "id": -1, "is_local": true}
		var node = entry.get("node")
		if node == null:
			continue
		entry["off_frames"] = 0
		entry["lives"] = lives_per_racer
		entry["spectator"] = false
		entry["is_local"] = entry.get("is_local", true) and (not (node is Node3D) or true)
		var tracker_id = entry.get("id", -1) if entry.has("id") else 0
		# When we don't have a stable id, use the instance_id so each tracker is unique.
		if tracker_id == 0 or tracker_id == null:
			tracker_id = node.get_instance_id()
		_trackers[tracker_id] = entry
	# Mark whether local human player ids should be excluded from auto-elim
	# (we still apply life loss but the spectator flip is the same).
	for pid in local_player_ids:
		if _trackers.has(pid):
			_trackers[pid]["is_local"] = true
	_enabled = true


func disable() -> void:
	_enabled = false
	_trackers.clear()


func _process(_delta: float) -> void:
	if not _enabled:
		return
	if _camera == null or not _camera.has_method("is_on_screen"):
		return
	# v0.19.1: off-screen elimination is a MULTIPLAYER feature only. Running
	# it in solo eliminated whoever was 3rd-just-behind-the-leader after 1.5s,
	# which is exactly the canonical "P2/P3 racing tight" situation. The solo
	# race already has a 120m distance fallback in race_manager._check_eliminations.
	if NetworkClient == null or not NetworkClient.is_in_room():
		return
	# Only the authoritative side (host) runs the detection in MP.
	if not NetworkClient.is_host:
		return
	for tracker_id in _trackers.keys():
		var t: Dictionary = _trackers[tracker_id]
		if t.get("spectator", false):
			continue
		var node = t.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var on_screen: bool = _camera.is_on_screen(node)
		if on_screen:
			t["off_frames"] = 0
		else:
			t["off_frames"] = int(t.get("off_frames", 0)) + 1
			if t["off_frames"] >= OFF_SCREEN_FRAMES_THRESHOLD:
				t["off_frames"] = 0
				_handle_off_screen(tracker_id, t)


func _handle_off_screen(tracker_id, tracker: Dictionary) -> void:
	var mode: String = "lives3"
	if NetworkClient:
		mode = NetworkClient.elimination_mode
	if mode == "perma":
		_apply_local_elimination(tracker_id, tracker, true)
		_broadcast_elim(tracker_id, "off_screen_perma")
		return
	# lives3
	tracker["lives"] = max(0, int(tracker.get("lives", 3)) - 1)
	if tracker["lives"] <= 0:
		_apply_local_elimination(tracker_id, tracker, true)
		_broadcast_elim(tracker_id, "off_screen_final")
	else:
		_respawn(tracker_id, tracker)
		_broadcast_elim(tracker_id, "off_screen_life_lost")
	_refresh_hud()


func _apply_local_elimination(_tracker_id, tracker: Dictionary, eliminated: bool) -> void:
	tracker["spectator"] = eliminated
	var node = tracker.get("node")
	if node == null or not is_instance_valid(node):
		return
	# Local cars (RigidBody3D) — freeze + grey.
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
		(node as RigidBody3D).linear_velocity = Vector3.ZERO
		(node as RigidBody3D).angular_velocity = Vector3.ZERO
		_grey_node(node)
	# Ghosts have their own set_eliminated().
	if node.has_method("set_eliminated"):
		node.set_eliminated(eliminated)


func _grey_node(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).modulate = Color(0.5, 0.5, 0.5, 0.6)
	# Disable collision so eliminated cars don't block the field
	for c in node.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true


func _respawn(_tracker_id, tracker: Dictionary) -> void:
	var node = tracker.get("node")
	if node == null or not is_instance_valid(node):
		return
	# Arch-based respawn: place behind the previous arch in the leader's sequence,
	# facing the next arch. Falls back to (0,0,0) if track scene is unavailable.
	var pose: Dictionary = _arch_respawn_pose()
	var pos: Vector3 = pose.get("pos", Vector3.ZERO)
	var yaw: float = pose.get("yaw", 0.0)
	pos.y = 0.5
	if node is Node3D:
		(node as Node3D).global_position = pos
		(node as Node3D).rotation = Vector3(0, yaw, 0)
	if node is RigidBody3D:
		var speed: float = _estimate_leader_speed() * RESPAWN_SPEED_FRACTION
		(node as RigidBody3D).linear_velocity = -((node as Node3D).transform.basis.z) * speed
		(node as RigidBody3D).angular_velocity = Vector3.ZERO


func _arch_respawn_pose() -> Dictionary:
	if _race_manager == null:
		return {"pos": Vector3.ZERO, "yaw": 0.0}
	if not "_arches" in _race_manager:
		return {"pos": Vector3.ZERO, "yaw": 0.0}
	var arches: Array = _race_manager._arches
	if arches.is_empty():
		return {"pos": Vector3.ZERO, "yaw": 0.0}
	# Pick the highest-progress racer to anchor the respawn behind
	var best_passed: int = -1
	var best_next_idx: int = 0
	for t in _trackers.values():
		var n = t.get("node")
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_meta("race_laps") or not n.has_meta("race_next_arch"):
			continue
		var laps: int = int(n.get_meta("race_laps", 0))
		var nxt: int = int(n.get_meta("race_next_arch", 0))
		var passed: int = laps * arches.size() + nxt
		if passed > best_passed:
			best_passed = passed
			best_next_idx = nxt
	# Spawn at the arch BEFORE next, offset behind it toward the previous arch direction
	var n_arches: int = arches.size()
	var prev_idx: int = (best_next_idx - 1 + n_arches) % n_arches
	var prev: Node3D = arches[prev_idx] as Node3D
	var nxt_node: Node3D = arches[best_next_idx] as Node3D
	if prev == null or nxt_node == null:
		return {"pos": Vector3.ZERO, "yaw": 0.0}
	var dir_to_next: Vector3 = nxt_node.global_position - prev.global_position
	dir_to_next.y = 0.0
	if dir_to_next.length_squared() < 0.0001:
		dir_to_next = Vector3.FORWARD
	dir_to_next = dir_to_next.normalized()
	var pos: Vector3 = prev.global_position - dir_to_next * RESPAWN_BEHIND_OFFSET
	# yaw = atan2 of forward direction. Forward in Godot car convention = -Z, so:
	var yaw: float = atan2(-dir_to_next.x, -dir_to_next.z)
	return {"pos": pos, "yaw": yaw}


func _estimate_leader_speed() -> float:
	if _race_manager and _race_manager.has_method("get_leader_speed"):
		return float(_race_manager.get_leader_speed())
	return 18.0  # m/s — reasonable baseline


func _broadcast_elim(target_id, reason: String) -> void:
	if NetworkClient and NetworkClient.is_in_room() and NetworkClient.is_host:
		var pid_int: int = -1
		if typeof(target_id) == TYPE_INT:
			pid_int = int(target_id)
		# Negative ids → bot (still valid). Positive → player. instance_id keys
		# (when running solo) aren't network-meaningful; skip the broadcast.
		if abs(pid_int) < 100000:
			NetworkClient.send_elim_event(pid_int, reason)


func _on_elim_event(target_id: int, _reason: String, lives: int, eliminated: bool) -> void:
	# Server-authoritative — every client (incl. host) listens here so the
	# spectator-flip is consistent across the room.
	if not _trackers.has(target_id):
		return
	var t: Dictionary = _trackers[target_id]
	t["lives"] = lives
	if eliminated and not t.get("spectator", false):
		_apply_local_elimination(target_id, t, true)
	_refresh_hud()


func _on_race_state(state: Dictionary) -> void:
	# Periodic 5Hz pump from the server. Mostly a heartbeat for the HUD.
	var lives: Dictionary = state.get("lives", {})
	for k in lives.keys():
		var pid: int = int(k)
		_last_authoritative_lives[pid] = int(lives[k])
		if _trackers.has(pid):
			_trackers[pid]["lives"] = _last_authoritative_lives[pid]
	_refresh_hud()


func get_lives_for(target_id) -> int:
	if _trackers.has(target_id):
		return int(_trackers[target_id].get("lives", 0))
	return 0


func _refresh_hud() -> void:
	if _hud_label == null:
		return
	var lines: Array[String] = []
	for tid in _trackers.keys():
		var t: Dictionary = _trackers[tid]
		var lives: int = int(t.get("lives", 0))
		var label: String = ""
		if typeof(tid) == TYPE_INT and tid > 0:
			label = "P%d" % tid
		elif typeof(tid) == TYPE_INT and tid < 0:
			label = "BOT %d" % (-tid)
		else:
			var n = t.get("node")
			label = n.name if n else "?"
		var hearts: String = "✦".repeat(max(0, lives)) if lives > 0 else "—"
		var status: String = "  SPECTATEUR" if t.get("spectator", false) else ""
		lines.append("%s  %s%s" % [label, hearts, status])
	_hud_label.text = "\n".join(lines)
