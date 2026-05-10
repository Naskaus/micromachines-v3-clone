extends Button

# Cycles the selected track and reloads the scene. Visible only at MENU state
# (RaceManager hides it once the race starts via process_mode magic — easier:
# we just always show it; it's a HUD button).

func _ready() -> void:
	_refresh_label()
	pressed.connect(_on_pressed)


func _refresh_label() -> void:
	var t: Dictionary = Globals.current_track()
	text = "🏁 %s" % str(t.get("name", "?"))


func _on_pressed() -> void:
	Globals.cycle_next()
	# Reload the scene so the new track is instanced (label refresh happens in _ready)
	get_tree().reload_current_scene()
