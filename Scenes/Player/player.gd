extends CharacterBody2D

@export var move_speed: float = 320.0
@export var slow_speed: float = 140.0
@export var max_hp: int = 3

@export var bullet_scene: PackedScene
@export var fire_interval: float = 0.08

@onready var shot_point: Marker2D = $ShotPoint
@onready var hb_sprite: Sprite2D = $HBSprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var bullet_layer: BulletLayer = get_tree().current_scene.get_node("BulletLayer")
var _fire_timer: float = 0.0
var hp: int = 0


func _ready() -> void:
	_connect_debug_draw_signals()
	hp = max_hp


func _physics_process(delta: float) -> void:
	_handle_move(delta)
	_handle_shoot(delta)


func _handle_move(delta: float) -> void:
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	var slow_move: bool = Input.is_action_pressed("slow_move")
	var current_speed := slow_speed if slow_move else move_speed
	velocity = input_dir * current_speed

	_handle_animation(input_dir.x, slow_move)
	move_and_slide()
	_clamp_to_screen()


func _handle_shoot(delta: float) -> void:
	_fire_timer -= delta

	if not Input.is_action_pressed("shoot"):
		return

	if _fire_timer > 0.0:
		return

	_fire_timer = fire_interval
	_spawn_bullet()


func _spawn_bullet() -> void:
	if bullet_layer == null:
		return
	bullet_layer.spawn_bullet(
		bullet_scene,
		shot_point.global_position,
		{
			"velocity": Vector2.UP,
			"speed": 900.0,
			"damage": 1,
			"collision_layer": CollisionLayers.PLAYER_BULLET,
			"collision_mask": CollisionLayers.ENEMY
		}
	)


func take_damage(damage: int) -> void:
	hp -= damage
	DebugState.debug_log("Player hit: %d/%d (-%d)" % [hp, max_hp, damage])
	print("Player HP: ", hp)

	if hp <= 0:
		die()


func die() -> void:
	queue_free()


func _clamp_to_screen() -> void:
	var viewport_rect := get_viewport_rect()
	position.x = clamp(position.x, 0.0, viewport_rect.size.x)
	position.y = clamp(position.y, 0.0, viewport_rect.size.y)
	
func _handle_animation(x_direction: float, slow: bool) -> void:
	if (slow):
		hb_sprite.visible = true
	else:
		hb_sprite.visible = false

	if (x_direction - 0.001 > 0):
		anim_player.play("MoveRight")
	elif (x_direction + 0.001 < 0):
		anim_player.play("MoveLeft")
	else:
		anim_player.play("Idle")

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
