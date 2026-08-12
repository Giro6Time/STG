extends Node

# 集成测试：验证 GameOver 场景重载在真实物理碰撞回调中不会触发
# "Removing a CollisionObject node during a physics callback" 错误。
# 复现路径与线上一致：敌方子弹 Area2D 物理碰撞玩家 →
# bullet_base._on_body_entered → player.take_damage → game_over →
# LevelManager._on_player_game_over → reload_current_scene（应被推迟）。
# 重载成功后新实例验证玩家状态复位，证明重载无错误。

const PLAYER_SCENE: PackedScene = preload("res://Scenes/Player/player.tscn")
const ENEMY_BULLET_SCENE: PackedScene = preload("res://Scenes/Bullet/ConcreateScene/TomatoBullet.tscn")
const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")

# 跨场景重载持久（static 属于脚本类，场景重载后保留）：
# false = 首次运行，负责创建攻击子弹；true = 重载后的实例，只验证并退出。
static var _triggered: bool = false

var _player


func _ready() -> void:
	# 用真实 LevelManager 脚本节点 + 真实 Player 场景实例。
	var manager: Node2D = Node2D.new()
	manager.set_script(LEVEL_MANAGER_SCRIPT)

	_player = PLAYER_SCENE.instantiate()
	_player.max_lives = 1  # 一次死亡即 GameOver，加速验证
	_player.position = Vector2(320, 360)

	# 先挂 Player 再挂 manager：LevelManager._ready 需通过 "Player" 子节点连接信号。
	manager.add_child(_player)
	add_child(manager)

	if not _triggered:
		_triggered = true
		# 首次运行：创建一颗真实敌方子弹飞向玩家，靠物理引擎触发碰撞。
		_spawn_attacking_bullet(manager)
	else:
		# 重载后的实例：玩家状态复位即证明重载成功且流程跑通。
		call_deferred("_verify_and_quit")


func _spawn_attacking_bullet(manager: Node2D) -> void:
	var bullet: BulletBase = ENEMY_BULLET_SCENE.instantiate()
	bullet.position = _player.position + Vector2(0, 80)
	bullet.setup(null, bullet.position, {
		"velocity": Vector2.UP,
		"speed": 600.0,
		"collision_layer": CollisionLayers.ENEMY_BULLET,
		"collision_mask": CollisionLayers.PLAYER
	})
	manager.add_child(bullet)


func _verify_and_quit() -> void:
	if _player.lives == 1 and _player.hp == 1 and _player.visible:
		print("game_over reload integration test passed")
		get_tree().quit(0)
	else:
		push_error("game_over reload integration test failed: 重载后玩家状态异常")
		get_tree().quit(1)
