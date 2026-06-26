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

# 初始化敌人阵营、血量、碰撞回调和调试绘制。
func _ready() -> void:
	DebugHelper.register_debug_drawable(self)
	add_to_group("enemies")
	hp = max_hp
	body_entered.connect(_on_body_entered)
	
	
# 驱动敌人移动并按延迟规则尝试射击。
func _process(delta: float) -> void:
	delay_shooting(delta)
	
# 累计射击冷却，到点后向下生成敌方子弹。
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

# 处理敌人受击后的血量扣减和死亡判定。
func take_damage(damage: int) -> void:
	hp -= damage
	DebugState.debug_log("Enemy hit: %d/%d (-%d)" % [hp, max_hp, damage], "Enemy")
	print("Enemy HP: ", hp)

	if hp <= 0:
		die()


# 销毁敌人节点并输出调试日志。
func die() -> void:
	DebugState.debug_log("Enemy destroyed", "Enemy")
	queue_free()


# 敌人碰到可受伤目标时造成接触伤害。
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)


# 在调试模式下绘制敌人碰撞形状。
func _draw() -> void:
	DebugHelper.draw_collision_shape(self, self as Area2D)
