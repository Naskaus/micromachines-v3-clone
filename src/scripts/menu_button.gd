extends Button

# Tiny "← MENU" button in the in-race HUD.
# Tapping it returns to the multiplayer menu (scene reload). Mobile-friendly
# replacement for the BACKSPACE shortcut, which doesn't exist on phones.

func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	get_tree().reload_current_scene()
