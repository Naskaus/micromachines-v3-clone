extends Area3D

# Yellow zone on the track. When a car body enters, calls apply_boost on it.

@export var boost_duration: float = 1.2  # short burst
@export var boost_factor: float = 1.75   # snap from 42 → 73.5 m/s (bots survive, kick still feels arcade)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_boost"):
		body.apply_boost(boost_duration, boost_factor)
		# Only play SFX for the player car (avoid bot-spam)
		if body.get("player_id") != null and AudioManager:
			AudioManager.play("boost")
