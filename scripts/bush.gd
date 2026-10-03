extends Area2D

@export_range(0.0, 1.0) var speed_multiplier: float = 0.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_slow_zone"):
		body.enter_slow_zone(speed_multiplier)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("exit_slow_zone"):
		body.exit_slow_zone()
