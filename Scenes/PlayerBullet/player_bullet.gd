extends Area2D

@export var speed: float = 900.0

func _process(delta: float) -> void:
	position.y -= speed * delta

	if position.y < -32.0:
		queue_free()
