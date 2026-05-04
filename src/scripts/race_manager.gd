extends Node

const PathUtils = preload("res://scripts/path_utils.gd")

# Race orchestrator — solo + MP-host mode runs full simulation locally and
# pushes per-racer state up to the server. MP-client mode renders the server's
# race_state instead of computing its own ranking.
#
# v0.19.0 (Phase 3) changes:
#   * Sets meta on each racer (race_laps / race_next_arch / race_finished) so
#     multiplayer_manager can include them in state packets.
#   * In MP-client mode, _state_runs_locally = false → skip arch detection,
#     elimination, leader pick. Subscribe to NetworkClient.race_state_received
#     and use that for HUD + camera leader.
#   * Wires elimination_manager once the race starts.

const TOTAL_LAPS := 3
const COUNTDOWN_SECONDS := 3
const MIN_LAP_TIME := 4.0
const ELIMINATION_DIST_FROM_LEADER := 120.0  # m — solo fallback only
const LEADER_CHANGE_HYSTERESIS := 0.03
const POST_FIRST_FINISH_TIMEOUT := 18.0

enum State { MENU, PRE_RACE, COUNTDOWN, RACING, FINISHED }

@export var player_paths: Array[NodePath] = []
@export var bot_paths: Array[NodePath] = []
@export var finish_line_path: NodePath
@export var arch_paths: Array[NodePath] = []
@export var camera_path: NodePath
@export var menu_label_path: NodePath
@export var countdown_label_path: NodePath
@export var race_info_label_path: NodePath
@export var results_label_path: NodePath
@export var speedometer_label_path: NodePath
@export var multiplayer_menu_path: NodePath
@export var multiplayer_manager_path: NodePath
@export var elimination_manager_path: NodePath
@export var lives_label_path: NodePath

var _state: State = State.MENU
var _race_start_time: float = 0.0
var _players: Array = []
var _racers: Array = []
var _racer_data: Dictionary = {}
var _finish_order: Array = []
var _eliminated: Array = []
var _current_leader: Node = null
var _num_players: int = 1
var _first_finish_time: float = -1.0

var _camera: Node = null
var _menu_label: Label
var _countdown_label: Label
var _race_info_label: Label
var _results_label: Label
var _speedometer_label: Label
var _multiplayer_menu: Node = null
var _multiplayer_manager: Node = null
var _elimination_manager: Node = null
var _lives_label: Label
var _is_network_race: bool = false
var _is_network_host: bool = false
# Network state runs locally for solo + MP-host. Off for MP-client (server is authority).
var _state_runs_locally: bool = true
# Cache of latest authoritative race_state from server, used by MP-client renderer.
var _last_race_state: Dictionary = {}

const ARCH_COLOR_NAMES: Array[String] = ["VERTE", "JAUNE", "ORANGE", "CYAN", "ROUGE", "VIOLETTE"]
const HIGHLIGHT_EMISSION := 4.0
const NORMAL_EMISSION := 1.5
var _arch_nodes: Array[Area3D] = []
var _arch_meshes: Array = []
var _arch_phases: Array[float] = []
var _last_highlighted_idx: int = -1


func _ready() -> void:
	_menu_label = get_node_or_null(menu_label_path) as Label
	_countdown_label = get_node_or_null(countdown_label_path) as Label
	_race_info_label = get_node_or_null(race_info_label_path) as Label
	_results_label = get_node_or_null(results_label_path) as Label
	_speedometer_label = get_node_or_null(speedometer_label_path) as Label
	_lives_label = get_node_or_null(lives_label_path) as Label
	_camera = get_node_or_null(camera_path)

	for i in range(player_paths.size()):
		var p: Node = get_node_or_null(player_paths[i])
		if p:
			var label: String = ("P%d" % (i + 1))
			_players.append(p)
			_register_racer(p, label, true)
	for bp in bot_paths:
		var b: Node = get_node_or_null(bp)
		if b:
			_register_racer(b, b.name, false)

	for i in range(arch_paths.size()):
		var arch: Area3D = get_node_or_null(arch_paths[i]) as Area3D
		if arch:
			arch.body_entered.connect(_on_arch_entered.bind(i))
			_arch_nodes.append(arch)
			_arch_phases.append(PathUtils.phase_from_position(arch.global_position))
			var meshes: Array = []
			for child_name in ["PillarLeft", "PillarRight", "Crossbar"]:
				var m: MeshInstance3D = arch.get_node_or_null(child_name) as MeshInstance3D
				if m:
					var mat: StandardMaterial3D = m.get_active_material(0) as StandardMaterial3D
					if mat:
						mat = mat.duplicate() as StandardMaterial3D
						m.set_surface_override_material(0, mat)
						meshes.append(mat)
			_arch_meshes.append(meshes)
		else:
			push_warning("RaceManager: arch_paths[%d] is missing" % i)

	if _results_label:
		_results_label.visible = false

	for r in _racers:
		r.freeze = true
	if _race_info_label:
		_race_info_label.visible = false
	if _countdown_label:
		_countdown_label.visible = false

	if multiplayer_menu_path and not multiplayer_menu_path.is_empty():
		_multiplayer_menu = get_node_or_null(multiplayer_menu_path)
	if multiplayer_manager_path and not multiplayer_manager_path.is_empty():
		_multiplayer_manager = get_node_or_null(multiplayer_manager_path)
	if elimination_manager_path and not elimination_manager_path.is_empty():
		_elimination_manager = get_node_or_null(elimination_manager_path)

	if _multiplayer_menu:
		if _menu_label:
			_menu_label.visible = false
		if _multiplayer_menu.has_signal("solo_race_requested"):
			_multiplayer_menu.solo_race_requested.connect(_on_solo_race_requested)
		if _multiplayer_menu.has_signal("multiplayer_race_requested"):
			_multiplayer_menu.multiplayer_race_requested.connect(_on_multiplayer_race_requested)
	else:
		if _menu_label:
			_menu_label.text = "MICROMACHINES V3 CLONE\n\n[1]  1 JOUEUR  (A/D)\n[2]  2 JOUEURS  (A/D + J/L)\n\n[BACKSPACE] reset"
			_menu_label.visible = true
	_state = State.MENU
	if AudioManager:
		AudioManager.play_music("menu")

	if NetworkClient:
		NetworkClient.race_state_received.connect(_on_network_race_state)


func _on_solo_race_requested(num_players: int) -> void:
	_is_network_race = false
	_is_network_host = false
	_state_runs_locally = true
	_start_with_mode(num_players)


func _on_multiplayer_race_requested(host: bool, _code: String, _peers: Array) -> void:
	_is_network_race = true
	_is_network_host = host
	# Server is authoritative. Host still runs the local sim (for bots etc.)
	# and broadcasts state. Client only renders.
	_state_runs_locally = host
	# Host: keep its own bots, they'll be registered by multiplayer_manager.
	# Client: drop bots from the local lineup — they're rendered as ghosts.
	if not host:
		for bp in bot_paths:
			var b: Node = get_node_or_null(bp)
			if b:
				_remove_racer_from_race(b)
	_start_with_mode(1)


func _register_racer(racer: Node, display_name: String, is_player: bool) -> void:
	_racers.append(racer)
	_racer_data[racer] = {
		"name": display_name,
		"is_player": is_player,
		"laps": 0,
		"last_lap_time": 0.0,
		"last_phase": 0.0,
		"lap_times": [] as Array[float],
		"finish_time": 0.0,
		"finished": false,
		"next_arch_index": 0,
	}
	if racer is Node:
		racer.set_meta("race_laps", 0)
		racer.set_meta("race_next_arch", 0)
		racer.set_meta("race_finished", false)


func _start_countdown() -> void:
	_state = State.COUNTDOWN
	_update_leader_and_camera()
	for n in range(COUNTDOWN_SECONDS, 0, -1):
		if _countdown_label:
			_countdown_label.text = str(n)
			_countdown_label.visible = true
		if AudioManager:
			AudioManager.play("countdown_beep", -6.0, 0.85)
		await get_tree().create_timer(1.0).timeout
	if _countdown_label:
		_countdown_label.text = "GO !"
	if AudioManager:
		AudioManager.play("go", 0.0, 1.2)
		AudioManager.start_engine()
		AudioManager.play_music("race")
	await get_tree().create_timer(0.8).timeout
	if _countdown_label:
		_countdown_label.visible = false
	_start_race()


func _start_race() -> void:
	_state = State.RACING
	_race_start_time = Time.get_ticks_msec() / 1000.0
	for r in _racers:
		r.freeze = false
		_racer_data[r].last_lap_time = _race_start_time
	# Wire elimination tracker — applies to both solo (camera-edge fallback) and
	# MP-host (off-screen → broadcast via NetworkClient). MP-client stays passive
	# and reacts to elim_event broadcasts received from the server.
	_wire_elimination_manager()


func _wire_elimination_manager() -> void:
	if _elimination_manager == null:
		return
	if not _elimination_manager.has_method("enable_for"):
		return
	var lives_per_racer: int = 3
	if NetworkClient and NetworkClient.is_in_room() and NetworkClient.elimination_mode == "perma":
		lives_per_racer = 1
	var entries: Array = []
	# Local racers (humans + own bots when host)
	for r in _racers:
		if not is_instance_valid(r):
			continue
		var entry: Dictionary = {"node": r, "is_local": true}
		if r in _players:
			entry["id"] = r.player_id if "player_id" in r else (_players.find(r) + 1)
		else:
			entry["id"] = r.get_instance_id()
		entries.append(entry)
	# Remote ghosts (MP only)
	if _is_network_race and _multiplayer_manager and _multiplayer_manager.has_method("all_ghosts"):
		var ghosts: Dictionary = _multiplayer_manager.all_ghosts()
		for pid in ghosts.keys():
			var g: Node = ghosts[pid]
			if g and is_instance_valid(g):
				entries.append({"node": g, "id": int(pid), "is_local": false})
	# Local player ids — used by elimination_manager so it knows which trackers
	# correspond to humans on this device.
	var local_ids: Array = []
	for p in _players:
		if "player_id" in p:
			local_ids.append(p.player_id)
	_elimination_manager.enable_for(entries, local_ids, lives_per_racer)


func _on_arch_entered(body: Node, arch_idx: int) -> void:
	if _state != State.RACING:
		return
	if not _state_runs_locally:
		return  # MP-client doesn't run lap logic
	if not _racer_data.has(body):
		return
	var data: Dictionary = _racer_data[body]
	if data.finished or _eliminated.has(body):
		return
	if arch_idx != data.next_arch_index:
		return
	var last_arch_idx: int = arch_paths.size() - 1
	if arch_idx == last_arch_idx:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - data.last_lap_time < MIN_LAP_TIME:
			return
		var lap_duration: float = now - data.last_lap_time
		data.lap_times.append(lap_duration)
		data.last_lap_time = now
		data.laps += 1
		data.next_arch_index = 0
		_publish_meta(body, data)
		if data.is_player and AudioManager:
			AudioManager.play("lap_complete", -4.0, 1.0)
		if data.laps >= TOTAL_LAPS:
			data.finished = true
			data.finish_time = now - _race_start_time
			_finish_order.append(body)
			_publish_meta(body, data)
			if data.is_player and AudioManager:
				AudioManager.play("win", 0.0, 1.0)
			_check_race_end()
	else:
		data.next_arch_index = arch_idx + 1
		_publish_meta(body, data)
		if data.is_player and AudioManager:
			AudioManager.play("arch_pass", -12.0, 1.3)


func _publish_meta(racer: Node, data: Dictionary) -> void:
	racer.set_meta("race_laps", int(data.laps))
	racer.set_meta("race_next_arch", int(data.next_arch_index))
	racer.set_meta("race_finished", bool(data.finished))


func _check_race_end() -> void:
	if not _state_runs_locally:
		return
	if _first_finish_time < 0.0 and _finish_order.size() > 0:
		_first_finish_time = Time.get_ticks_msec() / 1000.0
	var racers_done: int = 0
	for r in _racers:
		if _racer_data[r].finished or _eliminated.has(r):
			racers_done += 1
	if racers_done >= _racers.size():
		_end_race()
		return
	var all_players_done: bool = true
	for p in _players:
		if not _racer_data[p].finished and not _eliminated.has(p):
			all_players_done = false
			break
	if all_players_done and _first_finish_time > 0.0:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _first_finish_time > POST_FIRST_FINISH_TIMEOUT:
			_end_race()


func _end_race() -> void:
	_state = State.FINISHED
	for r in _racers:
		r.freeze = true
	if _elimination_manager and _elimination_manager.has_method("disable"):
		_elimination_manager.disable()
	var unfinished: Array = []
	for r in _racers:
		if not _racer_data[r].finished:
			unfinished.append(r)
	unfinished.sort_custom(func(a, b):
		var a_elim: bool = _eliminated.has(a)
		var b_elim: bool = _eliminated.has(b)
		if a_elim != b_elim:
			return not a_elim
		return _racer_progress(a) > _racer_progress(b)
	)
	var lines: Array[String] = ["[ COURSE TERMINÉE ]", ""]
	var idx: int = 0
	for r in _finish_order:
		var d: Dictionary = _racer_data[r]
		lines.append("%s — %s — %.1fs" % [_place_label(idx + 1), d.name, d.finish_time])
		idx += 1
	for r in unfinished:
		var d: Dictionary = _racer_data[r]
		var status: String = "ÉLIMINÉ" if _eliminated.has(r) else "DNF"
		lines.append("%s — %s — %s (%d/%d tours)" % [_place_label(idx + 1), d.name, status, d.laps, TOTAL_LAPS])
		idx += 1
	lines.append("")
	lines.append("[ENTER] ou [BACKSPACE] pour relancer")
	if _results_label:
		_results_label.text = "\n".join(lines)
		_results_label.visible = true


func _process(_delta: float) -> void:
	if _state == State.PRE_RACE or _state == State.FINISHED:
		return
	_update_leader_and_camera()
	if _state == State.RACING:
		if _state_runs_locally:
			_feed_progress_gaps_to_players()
			_check_eliminations()
			_check_phase_passes()
			if _first_finish_time > 0.0:
				_check_race_end()
		_update_race_hud()
		_update_speedometer()
		_update_arch_highlight()


func _check_phase_passes() -> void:
	if _arch_phases.is_empty():
		return
	var max_passes_per_racer: int = 3
	for racer in _racers:
		if not _racer_data.has(racer):
			continue
		var data: Dictionary = _racer_data[racer]
		if data.finished or _eliminated.has(racer):
			continue
		if not "_path_phase" in racer:
			continue
		var passes: int = 0
		while passes < max_passes_per_racer:
			var next_idx: int = data.next_arch_index
			if next_idx < 0 or next_idx >= _arch_phases.size():
				break
			var arch_phase: float = _arch_phases[next_idx]
			var racer_phase: float = racer._path_phase
			var delta: float = wrapf(racer_phase - arch_phase, -0.5, 0.5)
			if delta <= 0.0 or delta > 0.30:
				break
			_on_arch_entered(racer, next_idx)
			if data.next_arch_index == next_idx:
				break
			passes += 1


func _update_arch_highlight() -> void:
	if _players.is_empty() or _arch_meshes.is_empty():
		return
	var p1: Node = _players[0]
	if not _racer_data.has(p1):
		return
	var data: Dictionary = _racer_data[p1]
	if data.finished or _eliminated.has(p1):
		return
	var target_idx: int = data.next_arch_index
	if target_idx == _last_highlighted_idx:
		return
	for i in range(_arch_meshes.size()):
		var energy: float = HIGHLIGHT_EMISSION if i == target_idx else NORMAL_EMISSION
		for mat in _arch_meshes[i]:
			if mat is StandardMaterial3D:
				mat.emission_energy_multiplier = energy
	_last_highlighted_idx = target_idx


func _update_speedometer() -> void:
	if _speedometer_label == null:
		return
	var s: float = get_player_speed()
	_speedometer_label.text = "%d m/s" % round(s)
	if s >= 90.0:
		_speedometer_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1, 1))
	elif s >= 50.0:
		_speedometer_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3, 1))
	else:
		_speedometer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1))


func _feed_progress_gaps_to_players() -> void:
	var leader: Node = _get_race_leader()
	if leader == null:
		return
	var leader_progress: float = _racer_progress(leader)
	for p in _players:
		if not p.has_method("set_race_progress_gap"):
			continue
		if _eliminated.has(p) or _racer_data[p].finished:
			p.set_race_progress_gap(0.0)
			continue
		var gap: float = leader_progress - _racer_progress(p)
		if gap < 0.0:
			gap = 0.0
		p.set_race_progress_gap(gap)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if _state == State.MENU:
			var mp_visible: bool = _multiplayer_menu != null and _multiplayer_menu.visible
			if mp_visible:
				return
			_start_with_mode(1)
			return
		if _state == State.FINISHED:
			get_tree().reload_current_scene()
			return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_BACKSPACE:
		get_tree().reload_current_scene()
		return
	if _state == State.MENU:
		var mp_visible: bool = _multiplayer_menu != null and _multiplayer_menu.visible
		if mp_visible:
			return
		if event.keycode == KEY_1:
			_start_with_mode(1)
		elif event.keycode == KEY_2:
			_start_with_mode(2)
		return
	if _state == State.FINISHED and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_tree().reload_current_scene()


func _start_with_mode(num_players: int) -> void:
	_num_players = num_players
	if _menu_label:
		_menu_label.visible = false
	if _race_info_label:
		_race_info_label.text = "Préparez-vous…"
		_race_info_label.visible = true
	var keep_players: Array = []
	for i in range(_players.size()):
		if i < num_players:
			keep_players.append(_players[i])
		else:
			_remove_racer_from_race(_players[i])
	_players = keep_players
	if _camera and _camera.has_method("set_targets_to"):
		_camera.set_targets_to(_players)
	_state = State.PRE_RACE
	call_deferred("_start_countdown")


func _remove_racer_from_race(racer: Node) -> void:
	_racers.erase(racer)
	_racer_data.erase(racer)
	if racer is RigidBody3D:
		racer.freeze = true
		racer.linear_velocity = Vector3.ZERO
		racer.angular_velocity = Vector3.ZERO
	racer.visible = false
	for child in racer.get_children():
		if child is CollisionShape3D:
			child.disabled = true


func _update_leader_and_camera() -> void:
	# In MP-client mode, leader_id comes from the server's race_state.
	if not _state_runs_locally and _is_network_race:
		_apply_network_leader_to_camera()
		return
	var camera_target: Node = _pick_camera_target()
	if camera_target == null:
		return
	if camera_target != _current_leader and _current_leader != null and _racer_data.has(_current_leader):
		var still_active: bool = not _eliminated.has(_current_leader) and not _racer_data[_current_leader].finished
		if still_active:
			var cur_prog: float = _racer_progress(_current_leader)
			var new_prog: float = _racer_progress(camera_target)
			if new_prog < cur_prog + LEADER_CHANGE_HYSTERESIS:
				return
	if camera_target != _current_leader:
		_current_leader = camera_target
		if _camera and _camera.has_method("set_leader_target"):
			_camera.set_leader_target(camera_target)


func _apply_network_leader_to_camera() -> void:
	# B1 — shared leader-cam from server's authoritative leader_id.
	if _last_race_state.is_empty():
		return
	var leader_id_v = _last_race_state.get("leader_id", null)
	if leader_id_v == null:
		return
	var leader_id: int = int(leader_id_v)
	var node: Node = _resolve_network_node(leader_id)
	if node == null or node == _current_leader:
		return
	_current_leader = node
	if _camera and _camera.has_method("set_leader_target"):
		_camera.set_leader_target(node)


func _resolve_network_node(player_id: int) -> Node:
	# Local human → P1
	if NetworkClient and player_id == NetworkClient.my_player_id:
		if _players.size() > 0:
			return _players[0]
	if _multiplayer_manager and _multiplayer_manager.has_method("get_ghost"):
		var g: Node = _multiplayer_manager.get_ghost(player_id)
		if g != null and is_instance_valid(g):
			return g
	return null


func _pick_camera_target() -> Node:
	var best_player: Node = null
	var best_player_prog: float = -INF
	for p in _players:
		if _eliminated.has(p):
			continue
		if _racer_data[p].finished:
			continue
		var prog: float = _racer_progress(p)
		if prog > best_player_prog:
			best_player_prog = prog
			best_player = p
	if best_player != null:
		return best_player
	var rankings: Array = _compute_rankings()
	for r in rankings:
		if not _eliminated.has(r) and not _racer_data[r].finished:
			return r
	return null


func _get_race_leader() -> Node:
	var rankings: Array = _compute_rankings()
	for r in rankings:
		if not _eliminated.has(r) and not _racer_data[r].finished:
			return r
	return null


func _check_eliminations() -> void:
	# The elimination_manager handles MP off-screen elim. Solo + MP-host still
	# get this distance-based fallback for completely runaway cars.
	var race_leader: Node = _get_race_leader()
	if race_leader == null:
		return
	var leader_pos: Vector3 = race_leader.global_position
	for r in _racers:
		if r == race_leader:
			continue
		if _eliminated.has(r):
			continue
		if _racer_data[r].finished:
			continue
		var dist: float = r.global_position.distance_to(leader_pos)
		if dist > ELIMINATION_DIST_FROM_LEADER:
			_eliminate(r)


func _eliminate(racer: Node) -> void:
	if _eliminated.has(racer):
		return
	_eliminated.append(racer)
	if racer is RigidBody3D:
		racer.freeze = true
		racer.linear_velocity = Vector3.ZERO
		racer.angular_velocity = Vector3.ZERO
	racer.visible = false
	for child in racer.get_children():
		if child is CollisionShape3D:
			child.disabled = true
	_check_race_end()


func _update_race_hud() -> void:
	if _race_info_label == null or _players.is_empty():
		return
	# In MP-client mode, ranking comes from server. Render that.
	if not _state_runs_locally and _is_network_race and not _last_race_state.is_empty():
		_render_network_hud()
		return
	var rankings: Array = _compute_rankings()
	var lines: Array[String] = []
	var race_leader: Node = _get_race_leader()
	if race_leader and _racer_data.has(race_leader):
		var ld: Dictionary = _racer_data[race_leader]
		lines.append("LEADER : %s — Tour %d/%d" % [ld.name, min(ld.laps + 1, TOTAL_LAPS), TOTAL_LAPS])
	for i in range(_players.size()):
		var p: Node = _players[i]
		if not _racer_data.has(p):
			continue
		var d: Dictionary = _racer_data[p]
		if _eliminated.has(p):
			lines.append("P%d  ÉLIMINÉ" % (i + 1))
			continue
		if d.finished:
			lines.append("P%d  ARRIVÉ — %.1fs" % [i + 1, d.finish_time])
			continue
		var pos: int = 1
		for j in range(rankings.size()):
			if rankings[j] == p:
				pos = j + 1
				break
		var now_t: float = Time.get_ticks_msec() / 1000.0
		var current_lap_time: float = now_t - d.last_lap_time
		var best_lap_str: String = ""
		if d.lap_times.size() > 0:
			var best: float = d.lap_times[0]
			for lt in d.lap_times:
				if lt < best:
					best = lt
			best_lap_str = "  best %.1fs" % best
		lines.append("P%d  Tour %d/%d  %s/%d  ⏱ %.1fs%s" % [i + 1, min(d.laps + 1, TOTAL_LAPS), TOTAL_LAPS, _place_label(pos), _racers.size(), current_lap_time, best_lap_str])
		var next_idx: int = d.next_arch_index
		if next_idx >= 0 and next_idx < ARCH_COLOR_NAMES.size():
			lines.append("       → Prochaine arche : %s" % ARCH_COLOR_NAMES[next_idx])
	_race_info_label.text = "\n".join(lines)


func _render_network_hud() -> void:
	var rankings: Array = _last_race_state.get("rankings", [])
	var lines: Array[String] = []
	var leader_id_v = _last_race_state.get("leader_id", null)
	if leader_id_v != null and not rankings.is_empty():
		var leader_entry: Dictionary = rankings[0]
		var leader_label: String = _label_for_id(int(leader_id_v))
		lines.append("LEADER : %s — Tour %d/%d" % [leader_label, min(int(leader_entry.get("laps", 0)) + 1, TOTAL_LAPS), TOTAL_LAPS])
	# Local player line
	var my_id: int = -1
	if NetworkClient:
		my_id = NetworkClient.my_player_id
	for entry in rankings:
		if int(entry.get("id", -1)) == my_id:
			var lap_v: int = int(entry.get("laps", 0))
			var na: int = int(entry.get("next_arch", 0))
			var pos_idx: int = rankings.find(entry) + 1
			lines.append("P1  Tour %d/%d  %s/%d  (réseau)" % [min(lap_v + 1, TOTAL_LAPS), TOTAL_LAPS, _place_label(pos_idx), rankings.size()])
			if na >= 0 and na < ARCH_COLOR_NAMES.size():
				lines.append("       → Prochaine arche : %s" % ARCH_COLOR_NAMES[na])
			break
	# Lives display when applicable
	var elim_mode: String = str(_last_race_state.get("elimination_mode", "lives3"))
	if elim_mode == "lives3":
		var lives: Dictionary = _last_race_state.get("lives", {})
		if lives.has(str(my_id)):
			var n: int = int(lives[str(my_id)])
			lines.append("       Vies : %s" % ("✦".repeat(max(0, n)) if n > 0 else "—"))
	_race_info_label.text = "\n".join(lines)


func _label_for_id(player_id: int) -> String:
	if player_id < 0:
		return "BOT %d" % (-player_id)
	if NetworkClient and player_id == NetworkClient.my_player_id:
		return "TOI"
	return "P%d" % player_id


func _on_network_race_state(state: Dictionary) -> void:
	_last_race_state = state


func _place_label(n: int) -> String:
	if n == 1:
		return "1er"
	return "%de" % n


func _compute_rankings() -> Array:
	var sorted_racers: Array = _racers.duplicate()
	sorted_racers.sort_custom(func(a, b): return _racer_progress(a) > _racer_progress(b))
	return sorted_racers


func _racer_progress(racer: Node) -> float:
	var data: Dictionary = _racer_data[racer]
	var laps: float = float(data.laps)
	var arch_count: float = max(1.0, float(arch_paths.size()))
	var seg: float = float(data.next_arch_index) / arch_count
	var fine: float = 0.0
	if "_path_phase" in racer:
		fine = racer._path_phase * 0.001
	return laps + seg + fine


func _racer_phase(racer: Node) -> float:
	if "_path_phase" in racer:
		return racer._path_phase
	return PathUtils.phase_from_position(racer.global_position)


# Public API for elimination_manager — gives the leader's path_phase so it can
# respawn carcasses behind the pack.
func get_leader_phase() -> float:
	var leader: Node = _get_race_leader()
	if leader != null:
		return _racer_phase(leader)
	return 0.0


func get_leader_speed() -> float:
	var leader: Node = _get_race_leader()
	if leader is RigidBody3D:
		return (leader as RigidBody3D).linear_velocity.length()
	return 18.0


func get_minimap_dots() -> Array:
	var dots: Array = []
	for r in _racers:
		var color: Color = Color.WHITE
		if "car_color" in r:
			color = r.car_color
		elif "bot_color" in r:
			color = r.bot_color
		if _eliminated.has(r):
			color = Color(0.4, 0.4, 0.4, 0.5)
		dots.append({
			"pos": r.global_position,
			"color": color,
			"is_player": r in _players,
		})
	return dots


func get_player_speed() -> float:
	if _players.is_empty():
		return 0.0
	var p: Node = _players[0]
	if not (p is RigidBody3D):
		return 0.0
	var fwd: Vector3 = -p.transform.basis.z
	return p.linear_velocity.dot(fwd)
