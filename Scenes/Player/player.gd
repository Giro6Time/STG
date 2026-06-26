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


# 初始化玩家血量并注册调试碰撞绘制。
func _ready() -> void:
	DebugHelper.register_debug_drawable(self)
	hp = max_hp


# 每个物理帧处理玩家移动和射击输入。
func _physics_process(delta: float) -> void:
	_handle_move(delta)
	_handle_shoot(delta)


# 根据输入、慢速键和屏幕边界更新玩家移动。
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


# 按射击键和冷却时间控制玩家开火。
func _handle_shoot(delta: float) -> void:
	_fire_timer -= delta

	if not Input.is_action_pressed("shoot"):
		return

	if _fire_timer > 0.0:
		return

	_fire_timer = fire_interval
	_spawn_bullet()


# 在射击点生成玩家子弹并设置玩家弹碰撞数据。
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


# 处理玩家受伤、日志输出和死亡判定。
func take_damage(damage: int) -> void:
	if DebugState.invincible_enabled:
		DebugState.debug_log("Player damage ignored: %d" % damage, "Player")
		return

	hp -= damage
	DebugState.debug_log("Player hit: %d/%d (-%d)" % [hp, max_hp, damage], "Player")
	print("Player HP: ", hp)

	if hp <= 0:
		die()


# 玩家死亡时移除自身节点。
func die() -> void:
	queue_free()


# 把玩家位置限制在当前视口范围内。
func _clamp_to_screen() -> void:
	var viewport_rect := get_viewport_rect()
	position.x = clamp(position.x, 0.0, viewport_rect.size.x)
	position.y = clamp(position.y, 0.0, viewport_rect.size.y)
	
# 根据水平移动和慢速状态切换玩家动画与判定点显示。
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


# 在调试模式下绘制玩家碰撞形状。
func _draw() -> void:
	DebugHelper.draw_collision_shape(self, self as CharacterBody2D)
