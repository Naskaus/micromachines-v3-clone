extends Control

# Multiplayer menu — Create/Join/Lobby states with cyberpunk aesthetic.
# Wires NetworkClient autoload signals and tells RaceManager to start in network mode.

signal multiplayer_race_requested(is_host: bool, room_code: String, peer_ids: Array)
signal solo_race_requested(num_players: int)

enum Step { ROOT, CREATE_LOBBY, JOIN_INPUT, JOIN_LOBBY, CONNECTING, ERROR }

@onready var _root_panel: Control = $RootPanel
@onready var _create_lobby_panel: Control = $CreateLobbyPanel
@onready var _join_input_panel: Control = $JoinInputPanel
@onready var _join_lobby_panel: Control = $JoinLobbyPanel
@onready var _connecting_panel: Control = $ConnectingPanel
@onready var _error_panel: Control = $ErrorPanel

@onready var _btn_solo1: Button = $RootPanel/VBox/BtnSolo1
@onready var _btn_solo2: Button = $RootPanel/VBox/BtnSolo2
@onready var _btn_create: Button = $RootPanel/VBox/BtnCreate
@onready var _btn_join: Button = $RootPanel/VBox/BtnJoin
@onready var _btn_quit: Button = $RootPanel/VBox/BtnQuit
@onready var _orientation_overlay: Control = $OrientationOverlay
@onready var _orientation_icon: Label = $OrientationOverlay/PhoneIcon

@onready var _create_code_label: Label = $CreateLobbyPanel/VBox/CodeLabel
@onready var _create_player_count: Label = $CreateLobbyPanel/VBox/PlayerCountLabel
@onready var _create_player_list: Label = $CreateLobbyPanel/VBox/PlayerListLabel
@onready var _btn_copy_code: Button = $CreateLobbyPanel/VBox/HBox/BtnCopy
@onready var _btn_start_race: Button = $CreateLobbyPanel/VBox/HBox/BtnStart
@onready var _btn_create_back: Button = $CreateLobbyPanel/VBox/BtnBack
@onready var _btn_create_navback: Button = $CreateLobbyPanel/VBox/NavBar/BtnNavBack

@onready var _join_code_input: LineEdit = $JoinInputPanel/VBox/CodeInput
@onready var _btn_join_confirm: Button = $JoinInputPanel/VBox/HBox/BtnConfirm
@onready var _btn_join_back: Button = $JoinInputPanel/VBox/HBox/BtnBack
@onready var _btn_join_navback: Button = $JoinInputPanel/VBox/NavBar/BtnNavBack

@onready var _join_lobby_code: Label = $JoinLobbyPanel/VBox/CodeLabel
@onready var _join_lobby_count: Label = $JoinLobbyPanel/VBox/PlayerCountLabel
@onready var _join_lobby_status: Label = $JoinLobbyPanel/VBox/StatusLabel
@onready var _btn_lobby_leave: Button = $JoinLobbyPanel/VBox/BtnLeave
@onready var _btn_lobby_navback: Button = $JoinLobbyPanel/VBox/NavBar/BtnNavBack

@onready var _connecting_label: Label = $ConnectingPanel/Label
@onready var _error_label: Label = $ErrorPanel/VBox/Label
@onready var _btn_error_back: Button = $ErrorPanel/VBox/BtnBack

@onready var _connection_status: Label = $ConnectionStatus

var _current_step: Step = Step.ROOT
var _is_host: bool = false
var _room_code: String = ""
var _peers: Array = []
var _race_started: bool = false
var _orientation_initialized: bool = false
var _last_was_portrait: bool = false


func _ready() -> void:
	_btn_solo1.pressed.connect(func(): _request_solo(1))
	_btn_solo2.pressed.connect(func(): _request_solo(2))
	_btn_create.pressed.connect(_on_create_pressed)
	_btn_join.pressed.connect(_on_join_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)
	# Orientation watch (mobile portrait → show overlay)
	get_viewport().size_changed.connect(_check_orientation)
	# Belt-and-braces: a 0.4s ticker catches edge cases where size_changed
	# never fires on mobile web (some browsers don't dispatch it on the
	# initial canvas → window resize), and re-checks if the user rotates.
	var orient_timer: Timer = Timer.new()
	orient_timer.wait_time = 0.4
	orient_timer.autostart = true
	orient_timer.timeout.connect(_check_orientation)
	add_child(orient_timer)
	# Defer the first check so the HTML5 canvas has time to match the window.
	call_deferred("_check_orientation")
	_animate_orientation_icon()
	_btn_copy_code.pressed.connect(_on_copy_code)
	_btn_start_race.pressed.connect(_on_start_race_pressed)
	_btn_create_back.pressed.connect(_on_back_to_root)
	_btn_create_navback.pressed.connect(_on_back_to_root)
	_btn_join_confirm.pressed.connect(_on_join_confirm_pressed)
	_btn_join_back.pressed.connect(_on_back_to_root)
	_btn_join_navback.pressed.connect(_on_back_to_root)
	_btn_lobby_leave.pressed.connect(_on_back_to_root)
	_btn_lobby_navback.pressed.connect(_on_back_to_root)
	_btn_error_back.pressed.connect(_on_back_to_root)
	_join_code_input.text_submitted.connect(func(_t): _on_join_confirm_pressed())

	if NetworkClient:
		NetworkClient.connected.connect(_on_net_connected)
		NetworkClient.disconnected.connect(_on_net_disconnected)
		NetworkClient.room_joined.connect(_on_net_room_joined)
		NetworkClient.player_joined.connect(_on_net_player_joined)
		NetworkClient.player_left.connect(_on_net_player_left)
		NetworkClient.race_start_signal.connect(_on_net_race_start)
		NetworkClient.error_received.connect(_on_net_error)

	_show_panel(Step.ROOT)
	_set_connection_status("offline")


func _show_panel(p: Step) -> void:
	_current_step = p
	_root_panel.visible = (p == Step.ROOT)
	_create_lobby_panel.visible = (p == Step.CREATE_LOBBY)
	_join_input_panel.visible = (p == Step.JOIN_INPUT)
	_join_lobby_panel.visible = (p == Step.JOIN_LOBBY)
	_connecting_panel.visible = (p == Step.CONNECTING)
	_error_panel.visible = (p == Step.ERROR)


func _request_solo(num_players: int) -> void:
	_request_fullscreen()
	visible = false
	emit_signal("solo_race_requested", num_players)


func _request_fullscreen() -> void:
	# Browsers only allow fullscreen as a direct response to a user gesture,
	# so we request it from inside button handlers — never on _ready.
	if OS.has_feature("web") or OS.has_feature("mobile"):
		var current: int = DisplayServer.window_get_mode()
		if current != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_quit_pressed() -> void:
	# Try to close the tab. Browsers only honor window.close() for tabs the
	# scripts opened themselves; otherwise we redirect to about:blank as a
	# graceful fallback so the page is unmistakably "gone."
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.close();", true)
		await get_tree().create_timer(0.15).timeout
		JavaScriptBridge.eval("if (!window.closed) { window.location.href = 'about:blank'; }", true)
	else:
		get_tree().quit()


func _get_browser_size() -> Vector2:
	# On web, ask the browser directly for window inner dimensions. Godot's
	# viewport size lags during the initial mobile canvas resize and mis-reports
	# the orientation, so we read window.innerWidth/innerHeight as the source
	# of truth and fall back to the viewport for native builds.
	if OS.has_feature("web"):
		var w_raw: String = str(JavaScriptBridge.eval("window.innerWidth", true))
		var h_raw: String = str(JavaScriptBridge.eval("window.innerHeight", true))
		var w: float = w_raw.to_float()
		var h: float = h_raw.to_float()
		if w > 0 and h > 0:
			return Vector2(w, h)
	return Vector2(get_viewport().get_visible_rect().size)


func _check_orientation() -> void:
	if _orientation_overlay == null:
		return
	var sz: Vector2 = _get_browser_size()
	var portrait: bool = sz.y > sz.x
	# When the user actually flips from portrait to landscape, also request
	# fullscreen — turning the phone is itself a strong "I'm playing now"
	# signal, and most mobile browsers honor a fullscreen request that follows
	# an orientationchange event.
	if _orientation_initialized and _last_was_portrait and not portrait:
		_request_fullscreen()
	_orientation_initialized = true
	_last_was_portrait = portrait
	_orientation_overlay.visible = portrait


func _animate_orientation_icon() -> void:
	if _orientation_icon == null:
		return
	# Tilt the icon back and forth like a phone being flipped, with a brief
	# pause at each end so the gesture reads as "rotate me, please."
	_orientation_icon.pivot_offset = _orientation_icon.size * 0.5
	var t: Tween = create_tween().set_loops()
	t.tween_property(_orientation_icon, "rotation_degrees", -90.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(0.5)
	t.tween_property(_orientation_icon, "rotation_degrees", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(1.2)


func _on_create_pressed() -> void:
	_connecting_label.text = "Connexion au serveur…"
	_show_panel(Step.CONNECTING)
	_set_connection_status("connecting")
	if NetworkClient:
		NetworkClient.create_room()


func _on_join_pressed() -> void:
	_join_code_input.text = ""
	_show_panel(Step.JOIN_INPUT)
	# Two frames: one for visibility flip, one for the LineEdit to be ready.
	# Without this, grab_focus() silently no-ops on the freshly-shown control.
	await get_tree().process_frame
	await get_tree().process_frame
	_join_code_input.editable = true
	_join_code_input.grab_focus()


func _on_join_confirm_pressed() -> void:
	# Sanitize on submit only (strip whitespace, uppercase, keep A-Z).
	var raw: String = _join_code_input.text.strip_edges().to_upper()
	var code: String = ""
	for c in raw:
		if c >= "A" and c <= "Z":
			code += c
	if code.length() != 4:
		_show_error("Le code doit faire 4 lettres.")
		return
	_connecting_label.text = "Connexion à la salle %s…" % code
	_show_panel(Step.CONNECTING)
	_set_connection_status("connecting")
	if NetworkClient:
		NetworkClient.join_room(code)


func _on_copy_code() -> void:
	if _room_code.is_empty():
		return
	DisplayServer.clipboard_set(_room_code)
	_btn_copy_code.text = "✓ COPIÉ"
	get_tree().create_timer(1.4).timeout.connect(func():
		if is_instance_valid(_btn_copy_code):
			_btn_copy_code.text = "📋 COPIER"
	)


func _on_start_race_pressed() -> void:
	if not _is_host:
		return
	if _peers.is_empty():
		# Allow solo-host start (good for testing) — but warn briefly
		_btn_start_race.text = "⚠ AUCUN AUTRE JOUEUR — RECLIC POUR LANCER"
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(_btn_start_race):
			_btn_start_race.text = "▶ DÉMARRER LA COURSE"
		return
	_trigger_multiplayer_start()


func _trigger_multiplayer_start() -> void:
	if _race_started:
		return
	_race_started = true
	_request_fullscreen()
	if NetworkClient and _is_host:
		NetworkClient.send_start()
	visible = false
	emit_signal("multiplayer_race_requested", _is_host, _room_code, _peers.duplicate())


func _on_back_to_root() -> void:
	if NetworkClient and not _room_code.is_empty():
		NetworkClient.disconnect_from_server()
	_room_code = ""
	_is_host = false
	_peers.clear()
	_join_code_input.text = ""  # don't carry stale input back to root
	_set_connection_status("offline")
	_show_panel(Step.ROOT)


func _show_error(msg: String) -> void:
	_error_label.text = msg
	# Clear any stale typed code so the next "Rejoindre" attempt starts blank.
	_join_code_input.text = ""
	_show_panel(Step.ERROR)


# ===== NetworkClient signal handlers =====

func _on_net_connected() -> void:
	_set_connection_status("online")


func _on_net_disconnected() -> void:
	_set_connection_status("offline")
	if _current_step in [Step.CREATE_LOBBY, Step.JOIN_LOBBY, Step.CONNECTING]:
		_show_error("Connexion perdue. Vérifie ton réseau.")


func _on_net_room_joined(code: String, is_host: bool, _my_id: int, peers: Array) -> void:
	_room_code = code
	_is_host = is_host
	_peers = peers.duplicate()
	if is_host:
		_create_code_label.text = code
		_update_create_lobby_ui()
		_show_panel(Step.CREATE_LOBBY)
	else:
		_join_lobby_code.text = code
		_update_join_lobby_ui()
		_show_panel(Step.JOIN_LOBBY)


func _on_net_player_joined(player_id: int) -> void:
	if not _peers.has(player_id):
		_peers.append(player_id)
	if _current_step == Step.CREATE_LOBBY:
		_update_create_lobby_ui()
	elif _current_step == Step.JOIN_LOBBY:
		_update_join_lobby_ui()


func _on_net_player_left(player_id: int) -> void:
	_peers.erase(player_id)
	if _current_step == Step.CREATE_LOBBY:
		_update_create_lobby_ui()
	elif _current_step == Step.JOIN_LOBBY:
		_update_join_lobby_ui()


func _on_net_race_start() -> void:
	# Non-host clients receive this when host triggers start
	if _is_host:
		return
	_trigger_multiplayer_start()


func _on_net_error(msg: String) -> void:
	_show_error(msg)


func _update_create_lobby_ui() -> void:
	var total: int = _peers.size() + 1  # +1 for myself (host)
	_create_player_count.text = "%d / 6 JOUEURS" % total
	var lines: Array[String] = ["▸ TOI (HÔTE)"]
	for pid in _peers:
		lines.append("▸ JOUEUR #%d" % pid)
	_create_player_list.text = "\n".join(lines)


func _update_join_lobby_ui() -> void:
	var total: int = _peers.size() + 1
	_join_lobby_count.text = "%d / 6 JOUEURS" % total
	_join_lobby_status.text = "EN ATTENTE DE L'HÔTE…"


func _set_connection_status(state: String) -> void:
	if _connection_status == null:
		return
	match state:
		"online":
			_connection_status.text = "● ONLINE"
			_connection_status.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		"connecting":
			_connection_status.text = "● CONNEXION…"
			_connection_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_:
			_connection_status.text = "● OFFLINE"
			_connection_status.add_theme_color_override("font_color", Color(0.7, 0.2, 0.4))
