extends CharacterBody2D

@export var move_speed: float = 320.0
@export var slow_speed: float = 140.0

@export var bullet_scene: PackedScene
@export var fire_interval: float = 0.08

@onready var shot_point: Marker2D = $ShotPoint
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var bullet_layer: BulletLayer = get_tree().current_scene.get_node("BulletLayer")
var _fire_timer: float = 0.0

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
	var current_speed := slow_speed if Input.is_action_pressed("slow_move") else move_speed
	velocity = input_dir * current_speed

	_handle_animation(input_dir.x)
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
			"damage": 1
		}
	)


func _clamp_to_screen() -> void:
	var viewport_rect := get_viewport_rect()
	position.x = clamp(position.x, 0.0, viewport_rect.size.x)
	position.y = clamp(position.y, 0.0, viewport_rect.size.y)
	
func _handle_animation(x_direction: float) -> void:
	if (x_direction - 0.001 > 0):
		anim_player.play("MoveRight")
	elif (x_direction + 0.001 < 0):
		anim_player.play("MoveLeft")
	else:
		anim_player.play("Idle")
