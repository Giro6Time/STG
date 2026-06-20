class_name Enemy
extends Area2D

@export var max_hp: int = 10
@export var contact_damage: int = 1
@export var bullet_scene: PackedScene
@export var shot_cd :float = 1
@export var bullet_speed = 200

@onready var shot_point: Marker2D = $ShotPoint
@onready var bullet_layer: BulletLayer = get_tree().current_scene.get_node("BulletLayer")

var hp: int = 0
var timer: float = 0

func _ready() -> void:
	DebugHelper.register_debug_drawable(self)
	add_to_group("enemies")
	hp = max_hp
	body_entered.connect(_on_body_entered)
	
	
func _process(delta: float) -> void:
	delay_shooting(delta)
	
func delay_shooting(delta: float) -> bool:
	timer += delta
	if timer >= shot_cd:
		timer = 0
		bullet_layer.spawn_bullet(
			bullet_scene,
			shot_point.global_position,
			{
				"velocity": Vector2.DOWN,
				"speed": bullet_speed,
				"damage": 1,
				"collision_layer": CollisionLayers.ENEMY_BULLET,
				"collision_mask": CollisionLayers.PLAYER
			}
		)
		return true
	return false

func take_damage(damage: int) -> void:
	hp -= damage
	DebugState.debug_log("Enemy hit: %d/%d (-%d)" % [hp, max_hp, damage])
	print("Enemy HP: ", hp)

	if hp <= 0:
		die()


func die() -> void:
	DebugState.debug_log("Enemy destroyed")
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)


func _draw() -> void:
	DebugHelper.draw_collision_shape(self, self as Area2D)
