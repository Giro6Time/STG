class_name RepeatTimelineDriver
extends TimelineDriver

## 轮次数。≤0 = 无限循环。
@export var rounds: int = 36
## 轮间间隔（秒）。
@export var interval: float = 0.16

## 循环变量（对应 LuaSTG taskrepeat Var 1-4）。
@export var var_names: Array[String] = []
@export var var_inits: Array[float] = []
@export var var_increments: Array[float] = []

## 当前变量值快照（key=变量名）。
var _vars: Dictionary = {}


func begin() -> void:
	super.begin()
	_vars.clear()
	for i in range(var_names.size()):
		if var_names[i] == "":
			continue
		_vars[var_names[i]] = var_inits[i] if i < var_inits.size() else 0.0


func _advance_time(delta: float) -> bool:
	if rounds > 0 and _round >= rounds:
		_completed = true
		return false

	_elapsed += delta
	if _elapsed < interval:
		return false

	_elapsed = 0.0
	# 触发本轮，然后递增变量与轮次
	_trigger_round()
	for i in range(var_names.size()):
		if var_names[i] == "":
			continue
		var inc: float = var_increments[i] if i < var_increments.size() else 0.0
		_vars[var_names[i]] = float(_vars.get(var_names[i], 0.0)) + inc
	_round += 1

	# 无限循环（rounds≤0）永不完成
	if rounds > 0 and _round >= rounds:
		_completed = true
	return true


## 返回当前循环变量值（本轮发射用）。
func get_vars() -> Dictionary:
	return _vars
