extends Node2D
## 模拟玩家：注册 players group，供 AIM_PLAYER 方向模式自机狙。
func _ready() -> void:
	add_to_group("players")
