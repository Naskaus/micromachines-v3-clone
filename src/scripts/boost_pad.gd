extends Area3D

# Yellow zone on the track. When a car body enters, calls apply_boost on it.

@export var boost_duration: float = 2.0
@export var boost_factor: float = 1.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_boost"):
		body.apply_boost(boost_duration, boost_factor)
