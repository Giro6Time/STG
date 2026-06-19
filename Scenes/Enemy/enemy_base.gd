class_name Enemy
extends Area2D

@export var max_hp: int = 10
@export var contact_damage: int = 1

var hp: int = 0


func _ready() -> void:
	hp = max_hp
	body_entered.connect(_on_body_entered)


func take_damage(damage: int) -> void:
	hp -= damage
	print("Enemy HP: ", hp)

	if hp <= 0:
		die()


func die() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)
