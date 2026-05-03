extends Button

# Toggles fullscreen mode. Works on desktop, web and mobile.
# On web/iOS, the click counts as the required user gesture for the Fullscreen API.


func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh_label()


func _on_pressed() -> void:
	var mode: int = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Defer label refresh so the mode change has taken effect
	call_deferred("_refresh_label")


func _refresh_label() -> void:
	var mode: int = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		text = "⛶ EXIT"
	else:
		text = "⛶ FULL"
