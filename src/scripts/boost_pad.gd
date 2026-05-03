extends Area3D

# Yellow zone on the track. When a car body enters, calls apply_boost on it.

@export var boost_duration: float = 1.2  # short, violent burst
@export var boost_factor: float = 2.5    # snap from 42 → 105 m/s (halfway between tame and brutal)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_boost"):
		body.apply_boost(boost_duration, boost_factor)
