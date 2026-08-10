class_name PatternEmitter
extends Resource

## 发射执行器：把"空间采样（curve+sampler）+ 发射规则"变成实际子弹。
## 支持全量（emit_once）与逐颗（emit_begin/emit_next_step/emit_stream_tick）。

enum EmissionMode { BURST_ALL, STREAM }

@export var curve: ParametricCurve
@export var sampler: ParameterSampler
@export var spawn_rule: BulletSpawnRule
@export var emission_mode: EmissionMode = EmissionMode.BURST_ALL
@export var stream_interval: float = 0.08

var _stream_values: Array[float] = []
var _stream_index: int = 0
var _stream_bullet_layer: BulletLayer
var _stream_bullet_scene: PackedScene
var _stream_init_data: Dictionary = {}
var _stream_origin: Vector2 = Vector2.ZERO
var _stream_curve: ParametricCurve
var _stream_timer: float = 0.0


## 全量发射一轮，返回本次生成的子弹（供外层如套娃绑定母弹）。
func emit_once(bullet_layer: BulletLayer, bullet_scene: PackedScene, init_data: Dictionary, origin: Vector2) -> Array[BulletBase]:
	var spawned: Array[BulletBase] = []
	if bullet_layer == null:
		return spawned
	var active_curve := _get_active_curve()
	var active_sampler := _get_active_sampler()
	var active_spawn_rule := _get_active_spawn_rule()
	var values: Array[float] = active_sampler.sample_values()
	for index in range(values.size()):
		var t: float = values[index]
		var local_point: Vector2 = active_curve.sample(t)
		var tangent: Vector2 = active_curve.tangent(t)
		var bullet: BulletBase = active_spawn_rule.spawn_from_curve(bullet_layer, bullet_scene, origin, local_point, tangent, init_data)
		if bullet != null:
			spawned.append(bullet)
	return spawned


func emit_begin(bullet_layer: BulletLayer, bullet_scene: PackedScene, init_data: Dictionary, origin: Vector2) -> int:
	if bullet_layer == null:
		return 0
	_stream_bullet_layer = bullet_layer
	_stream_bullet_scene = bullet_scene
	_stream_init_data = init_data
	_stream_origin = origin
	_stream_curve = _get_active_curve()
	_stream_values = _get_active_sampler().sample_values()
	_stream_index = 0
	_stream_timer = 0.0
	return _stream_values.size()


func emit_next_step() -> bool:
	if _stream_index >= _stream_values.size():
		return false
	var active_spawn_rule := _get_active_spawn_rule()
	var t: float = _stream_values[_stream_index]
	_stream_index += 1
	var local_point: Vector2 = _stream_curve.sample(t)
	var tangent: Vector2 = _stream_curve.tangent(t)
	active_spawn_rule.spawn_from_curve(_stream_bullet_layer, _stream_bullet_scene, _stream_origin, local_point, tangent, _stream_init_data)
	return _stream_index < _stream_values.size()


func emit_stream_tick(delta: float) -> bool:
	if _stream_index >= _stream_values.size():
		return false
	_stream_timer -= delta
	if _stream_timer > 0.0:
		return true
	_stream_timer = stream_interval
	emit_next_step()
	return _stream_index < _stream_values.size()


func _get_active_curve() -> ParametricCurve:
	if curve != null:
		return curve
	return CircleParametricCurve.new()


func _get_active_sampler() -> ParameterSampler:
	if sampler != null:
		return sampler
	var default_sampler := UniformParameterSampler.new()
	default_sampler.sample_count = 16
	return default_sampler


func _get_active_spawn_rule() -> BulletSpawnRule:
	if spawn_rule != null:
		return spawn_rule
	return BulletSpawnRule.new()
