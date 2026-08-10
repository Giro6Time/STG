class_name TimelineDriver
extends Resource

## 时间采样器基类：决定"何时触发一轮发射"。
## 与空间 sampler 同构：空间采样产生 t 列表，时间采样产生 dt 序列。
## 子类实现节奏算法（RepeatTimelineDriver 均匀、未来 UnevenTimelineDriver 不均匀等）。

signal round_triggered(round_index: int)

## 初始等待（秒），任何时间线都可能需要，放基类。
@export var initial_delay: float = 0.0

## 内部状态：当前轮次（从 0 开始）。
var _round: int = 0
var _elapsed: float = 0.0
var _delayed: bool = false
var _completed: bool = false

## 是否已开始（begin 调用后）。
var _started: bool = false


func begin() -> void:
	_round = 0
	_elapsed = 0.0
	_delayed = false
	_completed = false
	_started = true


## 每帧推进。返回 true 表示"本轮触发"（调用方应执行发射）。
func tick(delta: float) -> bool:
	if not _started or _completed:
		return false

	# 初始等待：未到 initial_delay 前不触发任何轮
	if not _delayed:
		_elapsed += delta
		if _elapsed < initial_delay:
			return false
		_delayed = true
		_elapsed = 0.0

	return _advance_time(delta)


## 子类实现：推进时间并返回本轮是否触发。
func _advance_time(_delta: float) -> bool:
	return false


func get_round() -> int:
	return _round


func is_completed() -> bool:
	return _completed


func is_started() -> bool:
	return _started


## 子类在触发一轮时调用。
func _trigger_round() -> bool:
	round_triggered.emit(_round)
	return true
