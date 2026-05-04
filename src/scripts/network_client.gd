extends Node

# Multiplayer WebSocket client (autoload).
# Connects to wss://mv3-server.naskaus.com.
#
# v0.19.0: server became an authoritative bookkeeper — we now relay extra
# Phase 3 messages: register_bot (host registers synthetic bot peers),
# set_options (lobby toggle for elimination mode), elim_event (host signals
# a life lost / perma), and a periodic race_state from server (5Hz) carrying
# leader_id + rankings + lives + elimination_mode. Pre-existing relay
# messages (state, start, ping) are unchanged.

signal connected
signal disconnected
signal room_joined(code: String, is_host: bool, my_player_id: int, peers: Array, options: Dictionary)
signal player_joined(player_id: int, role: String)
signal player_left(player_id: int)
signal peer_state(player_id: int, state: Dictionary)
signal race_start_signal
signal race_state_received(state: Dictionary)
signal options_changed(options: Dictionary)
signal elim_event(target_id: int, reason: String, lives: int, eliminated: bool)
signal error_received(msg: String)

const SERVER_URL := "wss://mv3-server.naskaus.com"
const RECONNECT_DELAY := 1.5

var _socket: WebSocketPeer = WebSocketPeer.new()
var _connected: bool = false
var my_player_id: int = -1
var room_code: String = ""
var is_host: bool = false
var peer_ids: Array[int] = []
var elimination_mode: String = "lives3"  # "lives3" | "perma"

var _user_disconnected: bool = true
var _saved_room_code: String = ""
var _saved_was_host: bool = false
var _pending_rejoin_kind: String = ""
var _reconnect_in_flight: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_connected_to_server() -> bool:
	return _connected


func is_in_room() -> bool:
	return room_code != ""


func connect_to_server() -> void:
	if _connected:
		return
	var err := _socket.connect_to_url(SERVER_URL)
	if err != OK:
		push_warning("NetworkClient: connect_to_url returned %d" % err)


func disconnect_from_server() -> void:
	_user_disconnected = true
	_saved_room_code = ""
	_saved_was_host = false
	_pending_rejoin_kind = ""
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_connected = false
	my_player_id = -1
	room_code = ""
	is_host = false
	peer_ids.clear()


func create_room() -> void:
	_user_disconnected = false
	if not _connected:
		connect_to_server()
		await connected
	_send({"type": "create"})


func join_room(code: String) -> void:
	_user_disconnected = false
	if not _connected:
		connect_to_server()
		await connected
	_send({"type": "join", "code": code.strip_edges()})


func reclaim_room(code: String) -> void:
	_user_disconnected = false
	if not _connected:
		connect_to_server()
		await connected
	_send({"type": "reclaim", "code": code.strip_edges()})


func send_state(state: Dictionary) -> void:
	if not _connected or room_code == "":
		return
	state["type"] = "state"
	_send(state)


# Host echoes a bot's state. The server tags it as bot_id (negative) when
# broadcasting, so other clients render it as a ghost car like any peer.
func send_bot_state(bot_id: int, state: Dictionary) -> void:
	if not _connected or room_code == "" or not is_host:
		return
	state["type"] = "state"
	state["for_bot"] = bot_id
	_send(state)


# Host registers a synthetic bot peer (server gives it an id < 0 spot in the room).
func register_bot(bot_id: int, color: Color) -> void:
	if not _connected or room_code == "" or not is_host:
		return
	_send({
		"type": "register_bot",
		"bot_id": bot_id,
		"color": [color.r, color.g, color.b],
	})


# Host toggles room option in the lobby (lives3 vs perma).
func set_elimination_mode(mode: String) -> void:
	if not _connected or room_code == "" or not is_host:
		return
	if mode != "lives3" and mode != "perma":
		mode = "lives3"
	_send({"type": "set_options", "elimination_mode": mode})


# Host reports an elimination decision (life lost or perma-out).
func send_elim_event(target_id: int, reason: String) -> void:
	if not _connected or room_code == "" or not is_host:
		return
	_send({"type": "elim_event", "for": target_id, "reason": reason})


func send_start() -> void:
	if not _connected or room_code == "" or not is_host:
		return
	_send({"type": "start"})


func _send(msg: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify(msg))


func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state: int = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			_reconnect_in_flight = false
			emit_signal("connected")
			if _pending_rejoin_kind != "" and _saved_room_code != "":
				_send({"type": _pending_rejoin_kind, "code": _saved_room_code})
				_pending_rejoin_kind = ""
		while _socket.get_available_packet_count() > 0:
			var raw: PackedByteArray = _socket.get_packet()
			_handle_message(raw.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_connected = false
			emit_signal("disconnected")
			_maybe_autoreconnect()


func _maybe_autoreconnect() -> void:
	if _user_disconnected:
		return
	if _saved_room_code == "":
		return
	if _reconnect_in_flight:
		return
	_reconnect_in_flight = true
	_pending_rejoin_kind = "reclaim" if _saved_was_host else "join"
	await get_tree().create_timer(RECONNECT_DELAY).timeout
	if _connected:
		_reconnect_in_flight = false
		return
	connect_to_server()


func _handle_message(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	var mtype: String = str(msg.get("type", ""))
	match mtype:
		"joined":
			room_code = str(msg.get("code", ""))
			is_host = bool(msg.get("is_host", false))
			my_player_id = int(msg.get("player_id", -1))
			elimination_mode = str(msg.get("elimination_mode", "lives3"))
			var peers_raw = msg.get("peers", [])
			peer_ids.clear()
			for p in peers_raw:
				peer_ids.append(int(p))
			_saved_room_code = room_code
			_saved_was_host = is_host
			_user_disconnected = false
			emit_signal("room_joined", room_code, is_host, my_player_id, peer_ids.duplicate(), {"elimination_mode": elimination_mode})
		"player_joined":
			var pid: int = int(msg.get("player_id", -1))
			var role: String = str(msg.get("role", "human"))
			if pid != my_player_id and not peer_ids.has(pid):
				peer_ids.append(pid)
			emit_signal("player_joined", pid, role)
		"player_left":
			var pid_l: int = int(msg.get("player_id", -1))
			peer_ids.erase(pid_l)
			emit_signal("player_left", pid_l)
		"state":
			var pid_s: int = int(msg.get("player_id", -1))
			emit_signal("peer_state", pid_s, msg)
		"start":
			emit_signal("race_start_signal")
		"race_state":
			emit_signal("race_state_received", msg)
		"options_changed":
			elimination_mode = str(msg.get("elimination_mode", elimination_mode))
			emit_signal("options_changed", {"elimination_mode": elimination_mode})
		"elim_event":
			emit_signal("elim_event",
				int(msg.get("for", -1)),
				str(msg.get("reason", "")),
				int(msg.get("lives", 0)),
				bool(msg.get("eliminated", false)))
		"error":
			emit_signal("error_received", str(msg.get("msg", "unknown error")))
