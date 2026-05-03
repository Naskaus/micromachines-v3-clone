extends Button

# Toggles SFX or music mute via AudioManager. Reads category from metadata "category"
# (one of: "sfx", "music"). Updates own icon to reflect state.


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if AudioManager == null:
		return
	var cat: String = str(get_meta("category", "sfx"))
	var now_muted: bool
	if cat == "music":
		now_muted = AudioManager.toggle_music()
		text = "🔇" if now_muted else "🎵"
	else:
		now_muted = AudioManager.toggle_sfx()
		text = "🔇" if now_muted else "🔊"
