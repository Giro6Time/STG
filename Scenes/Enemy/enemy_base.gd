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
	_connect_debug_draw_signals()
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

func _connect_debug_draw_signals() -> void:
	DebugState.debug_enabled_changed.connect(_on_debug_draw_changed)
	DebugState.options_changed.connect(_on_debug_draw_options_changed)


func _on_debug_draw_changed(_enabled: bool) -> void:
	queue_redraw()


func _on_debug_draw_options_changed() -> void:
	queue_redraw()


func _draw() -> void:
	_draw_debug_collision_shape()


func _draw_debug_collision_shape() -> void:
	if not DebugState.debug_enabled or not DebugState.show_collision_shapes:
		return

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return

	if shape_node.shape is CircleShape2D:
		var circle_shape := shape_node.shape as CircleShape2D
		var radius_scale = max(abs(shape_node.scale.x), abs(shape_node.scale.y))
		var radius :float = circle_shape.radius * radius_scale
		var color := _get_debug_collision_color()
		var fill_color := Color(color.r, color.g, color.b, 0.14)
		var line_color := Color(color.r, color.g, color.b, 0.95)
		draw_circle(shape_node.position, radius, fill_color)
		draw_arc(shape_node.position, radius, 0.0, TAU, 48, line_color, 1.5)


func _get_debug_collision_color() -> Color:
	if (collision_layer & CollisionLayers.PLAYER) != 0:
		return Color(0.2, 1.0, 0.35, 1.0)
	if (collision_layer & CollisionLayers.PLAYER_BULLET) != 0:
		return Color(0.25, 0.85, 1.0, 1.0)
	if (collision_layer & CollisionLayers.ENEMY) != 0:
		return Color(1.0, 0.25, 0.25, 1.0)
	if (collision_layer & CollisionLayers.ENEMY_BULLET) != 0:
		return Color(1.0, 0.65, 0.15, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)
