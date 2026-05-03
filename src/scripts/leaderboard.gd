extends Control

# Vertical mini-leaderboard — MMV3 PS1 style.
# Black totem panel with 6 colored "helmet" circles stacked top→bottom.
# Top = 1st place, glowing ring around the leader. Reorders dynamically.

@export var race_manager_path: NodePath = NodePath("../../RaceManager")

const SLOT_HEIGHT := 44     # space per car slot (helmet + gap)
const HELMET_SIZE := 36     # diameter of the helmet circle
const PANEL_PAD := 10       # padding inside the black panel
const PANEL_WIDTH := 56

var _race_manager: Node = null
var _panel: ColorRect = null
var _helmet_root: Control = null
var _racer_to_helmet: Dictionary = {}  # racer Node → Control wrapper


func _ready() -> void:
	_race_manager = get_node_or_null(race_manager_path)
	if _race_manager == null:
		return

	# Black panel background (the "totem")
	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.05, 0.08, 0.85)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_PAD * 2 + SLOT_HEIGHT * 6)
	_panel.position = Vector2(0, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# Container for helmets (so we don't re-anchor every helmet)
	_helmet_root = Control.new()
	_helmet_root.position = Vector2(PANEL_PAD, PANEL_PAD)
	_helmet_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_helmet_root)

	await get_tree().process_frame  # wait for race_manager._ready
	_build_helmets()


func _build_helmets() -> void:
	var racers: Array = _read_racers()
	var players: Array = _read_players()
	for r in racers:
		var color: Color = _color_for_racer(r)
		var is_player: bool = r in players
		var helmet: Control = _make_helmet(color, is_player)
		_racer_to_helmet[r] = helmet
		_helmet_root.add_child(helmet)
	# Layout in starting order
	var i: int = 0
	for r in racers:
		var helmet: Control = _racer_to_helmet[r]
		helmet.position = Vector2(0, i * SLOT_HEIGHT)
		i += 1
	# Resize panel to actual count
	_panel.size.y = PANEL_PAD * 2 + SLOT_HEIGHT * racers.size() - (SLOT_HEIGHT - HELMET_SIZE)


func _make_helmet(color: Color, is_player: bool) -> Control:
	var wrap: Control = Control.new()
	wrap.custom_minimum_size = Vector2(HELMET_SIZE, HELMET_SIZE)
	wrap.size = Vector2(HELMET_SIZE, HELMET_SIZE)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Outer glow ring (only visible when this car is the leader)
	var glow: ColorRect = ColorRect.new()
	glow.name = "Glow"
	glow.color = Color(1.0, 1.0, 0.4, 0.0)  # invisible by default; alpha set when leader
	glow.size = Vector2(HELMET_SIZE + 6, HELMET_SIZE + 6)
	glow.position = Vector2(-3, -3)
	wrap.add_child(glow)

	# Helmet body (colored circle approx — using a square ColorRect; rounded effect via 2 layered rects)
	var helmet: ColorRect = ColorRect.new()
	helmet.name = "Body"
	helmet.color = color
	helmet.size = Vector2(HELMET_SIZE, HELMET_SIZE)
	helmet.position = Vector2(0, 0)
	wrap.add_child(helmet)

	# Visor strip — darker horizontal band across the middle (gives "helmet" look)
	var visor: ColorRect = ColorRect.new()
	visor.color = Color(0, 0, 0, 0.55)
	visor.size = Vector2(HELMET_SIZE, 8)
	visor.position = Vector2(0, HELMET_SIZE * 0.42)
	wrap.add_child(visor)

	# Player highlight: small "P" letter top-left
	if is_player:
		var p: Label = Label.new()
		p.text = "★"
		p.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		p.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		p.add_theme_constant_override("outline_size", 4)
		p.add_theme_font_size_override("font_size", 14)
		p.position = Vector2(-2, -10)
		wrap.add_child(p)
	return wrap


func _process(_delta: float) -> void:
	if _race_manager == null or _racer_to_helmet.is_empty():
		return
	var rankings: Array = _read_rankings()
	for i in range(rankings.size()):
		var r: Node = rankings[i]
		var helmet: Control = _racer_to_helmet.get(r)
		if helmet == null:
			continue
		var target_y: float = i * SLOT_HEIGHT
		helmet.position.y = lerp(helmet.position.y, target_y, 0.18)
		# Glow on leader (i == 0)
		var glow: ColorRect = helmet.get_node_or_null("Glow") as ColorRect
		if glow:
			glow.color.a = 0.65 if i == 0 else 0.0
		# Fade if eliminated
		var is_elim: bool = _is_eliminated(r)
		helmet.modulate.a = 0.30 if is_elim else 1.0


# --- Helpers reading from race_manager ---

func _read_racers() -> Array:
	if _race_manager and "_racers" in _race_manager:
		return _race_manager._racers
	return []


func _read_players() -> Array:
	if _race_manager and "_players" in _race_manager:
		return _race_manager._players
	return []


func _read_rankings() -> Array:
	if _race_manager and _race_manager.has_method("_compute_rankings"):
		return _race_manager._compute_rankings()
	return _read_racers()


func _color_for_racer(r: Node) -> Color:
	if "car_color" in r:
		return r.car_color
	if "bot_color" in r:
		return r.bot_color
	return Color.WHITE


func _is_eliminated(r: Node) -> bool:
	if _race_manager and "_eliminated" in _race_manager:
		var elim: Array = _race_manager._eliminated
		return r in elim
	return false
