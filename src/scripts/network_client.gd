extends Node

# Multiplayer WebSocket client (autoload).
# Connects to wss://mv3-server.naskaus.com, supports create_room/join_room/send_state.
# Phase 1: pure relay — server forwards state messages between peers.

signal connected
signal disconnected
signal room_joined(code: String, is_host: bool, my_player_id: int, peers: Array)
signal player_joined(player_id: int)
signal player_left(player_id: int)
signal peer_state(player_id: int, state: Dictionary)
signal race_start_signal
signal error_received(msg: String)

const SERVER_URL := "wss://mv3-server.naskaus.com"
const RECONNECT_DELAY := 1.5  # seconds between detecting drop and dialing back

var _socket: WebSocketPeer = WebSocketPeer.new()
var _connected: bool = false
var my_player_id: int = -1
var room_code: String = ""
var is_host: bool = false
var peer_ids: Array[int] = []

# Reconnection state. Mobile browsers tear the WebSocket down whenever the
# tab loses focus (Seb tabs out to WhatsApp to share the code → the room
# evaporated). The server now keeps abandoned rooms warm for 5 minutes and
# we re-dial here with either "reclaim" (if we were the host) or "join".
var _user_disconnected: bool = true   # true = user-initiated, don't auto-reconnect
var _saved_room_code: String = ""
var _saved_was_host: bool = false
var _pending_rejoin_kind: String = ""  # "reclaim" or "join", set before connect_to_server()
var _reconnect_in_flight: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func connect_to_server() -> void:
	if _connected:
		return
	var err := _socket.connect_to_url(SERVER_URL)
	if err != OK:
		push_warning("NetworkClient: connect_to_url returned %d" % err)


func disconnect_from_server() -> void:
	# User-initiated leave — purge our reconnect state so we don't rubber-band
	# back into the room they just chose to abandon.
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
	# Used after a mid-session drop to walk back into a room the server has
	# kept warm in its grace window.
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


func send_start() -> void:
	# Host triggers race start
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
			# Re-dialed after a drop and we still have a room to walk back into.
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
	# Only kick in when the drop wasn't user-initiated AND we had a room.
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
			var peers_raw = msg.get("peers", [])
			peer_ids.clear()
			for p in peers_raw:
				peer_ids.append(int(p))
			# Snapshot for autoreconnect — if we get dropped, this is what we
			# walk back into via reclaim/join.
			_saved_room_code = room_code
			_saved_was_host = is_host
			_user_disconnected = false
			emit_signal("room_joined", room_code, is_host, my_player_id, peer_ids.duplicate())
		"player_joined":
			var pid: int = int(msg.get("player_id", -1))
			if pid >= 0 and not peer_ids.has(pid):
				peer_ids.append(pid)
			emit_signal("player_joined", pid)
		"player_left":
			var pid_l: int = int(msg.get("player_id", -1))
			peer_ids.erase(pid_l)
			emit_signal("player_left", pid_l)
		"state":
			var pid_s: int = int(msg.get("player_id", -1))
			emit_signal("peer_state", pid_s, msg)
		"start":
			emit_signal("race_start_signal")
		"error":
			emit_signal("error_received", str(msg.get("msg", "unknown error")))
