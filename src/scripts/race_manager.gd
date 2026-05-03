extends Node

const PathUtils = preload("res://scripts/path_utils.gd")

# Race orchestrator — countdown → lap counting → win condition → results.
# Cars are frozen during pre-race + countdown, unfrozen on GO, frozen again on race end.
# V0.5: supports multiple human players (racers tagged "is_player").
# V0.6: camera follows the LEADER (highest race progress). Stragglers more than
# ELIMINATION_DIST_FROM_LEADER from the leader are eliminated (frozen + greyed).
# Race ends when only 1 active racer remains, OR all human players done/eliminated,
# OR a player completes TOTAL_LAPS.

const TOTAL_LAPS := 3
const COUNTDOWN_SECONDS := 3
const MIN_LAP_TIME := 4.0    # debounce — must be < fastest possible lap
const ELIMINATION_DIST_FROM_LEADER := 120.0  # m — racers beyond this are eliminated
const LEADER_CHANGE_HYSTERESIS := 0.03  # 3% lap progress buffer to avoid camera flicker

# Figure-8 path constants live in PathUtils.gd

enum State { MENU, PRE_RACE, COUNTDOWN, RACING, FINISHED }

@export var player_paths: Array[NodePath] = []  # human players (P1, P2, ...)
@export var bot_paths: Array[NodePath] = []
@export var finish_line_path: NodePath  # legacy — unused now
@export var arch_paths: Array[NodePath] = []  # 4 arches in racing order (Arch_1..Arch_4); lap = pass all 4 in order
@export var camera_path: NodePath  # camera follows the current leader
@export var menu_label_path: NodePath
@export var countdown_label_path: NodePath
@export var race_info_label_path: NodePath
@export var results_label_path: NodePath
@export var speedometer_label_path: NodePath

var _state: State = State.MENU
var _race_start_time: float = 0.0
var _players: Array = []
var _racers: Array = []
var _racer_data: Dictionary = {}
var _finish_order: Array = []
var _eliminated: Array = []
var _current_leader: Node = null
var _num_players: int = 1

var _camera: Node = null
var _menu_label: Label
var _countdown_label: Label
var _race_info_label: Label
var _results_label: Label
var _speedometer_label: Label

# Cached arch references for dynamic highlight (next-target glow)
const ARCH_COLOR_NAMES: Array[String] = ["VERTE", "JAUNE", "ORANGE", "CYAN", "ROUGE", "VIOLETTE"]
const HIGHLIGHT_EMISSION := 4.0  # multiplier on the next arch
const NORMAL_EMISSION := 1.5     # baseline
var _arch_nodes: Array[Area3D] = []
var _arch_meshes: Array = []  # array of arrays — _arch_meshes[i] = [PillarLeft, PillarRight, Crossbar]
var _last_highlighted_idx: int = -1


func _ready() -> void:
	_menu_label = get_node_or_null(menu_label_path) as Label
	_countdown_label = get_node_or_null(countdown_label_path) as Label
	_race_info_label = get_node_or_null(race_info_label_path) as Label
	_results_label = get_node_or_null(results_label_path) as Label
	_speedometer_label = get_node_or_null(speedometer_label_path) as Label
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

	# Wire 4 arches — lap requires passing them in order (0→1→2→3→0)
	# Also cache mesh children for dynamic emission tweaks (highlight next arch).
	for i in range(arch_paths.size()):
		var arch: Area3D = get_node_or_null(arch_paths[i]) as Area3D
		if arch:
			arch.body_entered.connect(_on_arch_entered.bind(i))
			_arch_nodes.append(arch)
			var meshes: Array = []
			for child_name in ["PillarLeft", "PillarRight", "Crossbar"]:
				var m: MeshInstance3D = arch.get_node_or_null(child_name) as MeshInstance3D
				if m:
					# Make material unique per arch so we can tweak emission per arch
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

	# Freeze everyone, hide race-time HUD, show MENU
	for r in _racers:
		r.freeze = true
	if _race_info_label:
		_race_info_label.visible = false
	if _countdown_label:
		_countdown_label.visible = false
	if _menu_label:
		_menu_label.text = "MICROMACHINES V3 CLONE\n\n[1]  1 JOUEUR  (A/D)\n[2]  2 JOUEURS  (A/D + J/L)\n\n[BACKSPACE] reset"
		_menu_label.visible = true
	_state = State.MENU
	if AudioManager:
		AudioManager.play_music("menu")


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
		"next_arch_index": 0,  # 0..3, which arch the racer must hit next; lap completes on hitting arch 3
	}


func _start_countdown() -> void:
	# F1-style: 3 short low beeps (1 per second) then 1 long high beep + GO
	_state = State.COUNTDOWN
	_update_leader_and_camera()
	for n in range(COUNTDOWN_SECONDS, 0, -1):
		if _countdown_label:
			_countdown_label.text = str(n)
			_countdown_label.visible = true
		if AudioManager:
			AudioManager.play("countdown_beep", 0.0, 0.85)  # low beep
		await get_tree().create_timer(1.0).timeout
	if _countdown_label:
		_countdown_label.text = "GO !"
	if AudioManager:
		AudioManager.play("go", 6.0, 1.4)  # bright high beep — race start
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
		# Reset lap-start clock so the first lap timer begins at GO
		_racer_data[r].last_lap_time = _race_start_time


func _on_arch_entered(body: Node, arch_idx: int) -> void:
	# 4 arches in racing order. Racer must pass arch_idx == data.next_arch_index, else ignored.
	# Hitting arch 3 (last) with next_arch_index==3 completes a lap.
	if _state != State.RACING:
		return
	if not _racer_data.has(body):
		return
	var data: Dictionary = _racer_data[body]
	if data.finished or _eliminated.has(body):
		return
	if arch_idx != data.next_arch_index:
		return  # out-of-order pass — ignore
	var last_arch_idx: int = arch_paths.size() - 1
	if arch_idx == last_arch_idx:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - data.last_lap_time < MIN_LAP_TIME:
			return  # debounce — would-be sub-MIN_LAP_TIME lap
		var lap_duration: float = now - data.last_lap_time
		data.lap_times.append(lap_duration)
		data.last_lap_time = now
		data.laps += 1
		data.next_arch_index = 0
		# Lap complete chime — player only
		if data.is_player and AudioManager:
			AudioManager.play("lap_complete", 0.0, 1.0)
		if data.laps >= TOTAL_LAPS:
			data.finished = true
			data.finish_time = now - _race_start_time
			_finish_order.append(body)
			if data.is_player and AudioManager:
				AudioManager.play("win", 4.0, 1.0)
			_check_race_end()
	else:
		data.next_arch_index = arch_idx + 1
		# Arch pass chime — subtle ding
		if data.is_player and AudioManager:
			AudioManager.play("arch_pass", -6.0, 1.3)


func _check_race_end() -> void:
	# Race ends when:
	#   - All human players are done (finished or eliminated), OR
	#   - All racers have finished
	# Race continues as long as any human player is still in (even if all bots are out).
	var all_players_done: bool = true
	for p in _players:
		if not _racer_data[p].finished and not _eliminated.has(p):
			all_players_done = false
			break
	var all_done: bool = _finish_order.size() >= _racers.size()
	if all_players_done or all_done:
		_end_race()


func _end_race() -> void:
	_state = State.FINISHED
	for r in _racers:
		r.freeze = true
	var unfinished: Array = []
	for r in _racers:
		if not _racer_data[r].finished:
			unfinished.append(r)
	# Sort: non-eliminated first by progress, eliminated at the bottom
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
		_feed_progress_gaps_to_players()
		_check_eliminations()
		_update_race_hud()
		_update_speedometer()
		_update_arch_highlight()


func _update_arch_highlight() -> void:
	# Highlight P1's next target arch by boosting its emission energy.
	# Only updates when the target index changes (cheap).
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
	# Apply: target gets HIGHLIGHT_EMISSION, others NORMAL_EMISSION.
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
	# Color-code: white normal, yellow fast, orange boosting
	if s >= 90.0:
		_speedometer_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1, 1))
	elif s >= 50.0:
		_speedometer_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3, 1))
	else:
		_speedometer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1))


func _feed_progress_gaps_to_players() -> void:
	# Each player learns how far behind the actual race leader they are (in laps).
	# This drives the player car's catch-up rubber-banding.
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
			gap = 0.0  # player is leader — no boost needed
		p.set_race_progress_gap(gap)


func _input(event: InputEvent) -> void:
	# Touch (mobile/web): tap the screen to start solo mode from menu, or restart from results
	if event is InputEventScreenTouch and event.pressed:
		if _state == State.MENU:
			_start_with_mode(1)
			return
		if _state == State.FINISHED:
			get_tree().reload_current_scene()
			return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# BACKSPACE restarts at ANY time (returns to menu)
	if event.keycode == KEY_BACKSPACE:
		get_tree().reload_current_scene()
		return
	# MENU: 1 or 2 to pick player count
	if _state == State.MENU:
		if event.keycode == KEY_1:
			_start_with_mode(1)
		elif event.keycode == KEY_2:
			_start_with_mode(2)
		return
	# ENTER restarts only from results screen
	if _state == State.FINISHED and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_tree().reload_current_scene()


func _start_with_mode(num_players: int) -> void:
	_num_players = num_players
	# Hide menu, show race HUD
	if _menu_label:
		_menu_label.visible = false
	if _race_info_label:
		_race_info_label.text = "Préparez-vous…"
		_race_info_label.visible = true
	# Filter players: keep only the first num_players. Excluded players get hidden + collisionless.
	var keep_players: Array = []
	for i in range(_players.size()):
		if i < num_players:
			keep_players.append(_players[i])
		else:
			_remove_racer_from_race(_players[i])
	_players = keep_players
	# Point camera at the active players (midpoint mode for now; switches to leader at GO)
	if _camera and _camera.has_method("set_targets_to"):
		_camera.set_targets_to(_players)
	_state = State.PRE_RACE
	call_deferred("_start_countdown")


func _remove_racer_from_race(racer: Node) -> void:
	# Excludes racer from race tracking and hides them visually + physically
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
	# Camera prefers the best active PLAYER (so player always sees themselves),
	# falls back to the leading bot if no player is active.
	var camera_target: Node = _pick_camera_target()
	if camera_target == null:
		return
	# Hysteresis: don't switch camera target unless the new one is meaningfully ahead
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


func _pick_camera_target() -> Node:
	# Best active human player wins
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
	# No active player → fallback to actual race leader (likely a bot)
	var rankings: Array = _compute_rankings()
	for r in rankings:
		if not _eliminated.has(r) and not _racer_data[r].finished:
			return r
	return null


func _get_race_leader() -> Node:
	# Highest-progress active racer (regardless of player/bot) — used for elimination distance
	var rankings: Array = _compute_rankings()
	for r in rankings:
		if not _eliminated.has(r) and not _racer_data[r].finished:
			return r
	return null


func _check_eliminations() -> void:
	# Eliminations are relative to the ACTUAL race leader, not the camera target
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
	# Hide entirely + disable collision so the carcass doesn't litter the track as an invisible obstacle
	racer.visible = false
	for child in racer.get_children():
		if child is CollisionShape3D:
			child.disabled = true
	_check_race_end()


func _update_race_hud() -> void:
	if _race_info_label == null or _players.is_empty():
		return
	var rankings: Array = _compute_rankings()
	var lines: Array[String] = []
	# Show the actual race leader at the top (not the camera target)
	var race_leader: Node = _get_race_leader()
	if race_leader and _racer_data.has(race_leader):
		var ld: Dictionary = _racer_data[race_leader]
		lines.append("LEADER : %s — Tour %d/%d" % [ld.name, min(ld.laps + 1, TOTAL_LAPS), TOTAL_LAPS])
	# Show each player's status
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
		# Player guidance: next arch to hit
		var next_idx: int = d.next_arch_index
		if next_idx >= 0 and next_idx < ARCH_COLOR_NAMES.size():
			lines.append("       → Prochaine arche : %s" % ARCH_COLOR_NAMES[next_idx])
	_race_info_label.text = "\n".join(lines)


func _place_label(n: int) -> String:
	if n == 1:
		return "1er"
	return "%de" % n


func _compute_rankings() -> Array:
	var sorted_racers: Array = _racers.duplicate()
	sorted_racers.sort_custom(func(a, b): return _racer_progress(a) > _racer_progress(b))
	return sorted_racers


func _racer_progress(racer: Node) -> float:
	# Progress = laps + segment + phase_fine_tiebreaker.
	# Each arch = 1/N of the lap (N = arch count). Cheaters can't gain laps without passing all N in order.
	var data: Dictionary = _racer_data[racer]
	var laps: float = float(data.laps)
	var arch_count: float = max(1.0, float(arch_paths.size()))
	var seg: float = float(data.next_arch_index) / arch_count
	# Tiny fine-grained tiebreaker: position along the racing line within the segment
	var fine: float = 0.0
	if "_path_phase" in racer:
		fine = racer._path_phase * 0.001  # << seg weight, used purely for tie-breaking
	return laps + seg + fine


# Phase-from-position helper (still useful for HUD widgets)
func _racer_phase(racer: Node) -> float:
	if "_path_phase" in racer:
		return racer._path_phase
	return PathUtils.phase_from_position(racer.global_position)


# Public API for HUD widgets (minimap)
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


# Public API for HUD widgets (speedometer) — returns P1's forward speed in m/s
func get_player_speed() -> float:
	if _players.is_empty():
		return 0.0
	var p: Node = _players[0]
	if not (p is RigidBody3D):
		return 0.0
	var fwd: Vector3 = -p.transform.basis.z
	return p.linear_velocity.dot(fwd)
