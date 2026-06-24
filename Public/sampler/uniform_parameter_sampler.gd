class_name UniformParameterSampler
extends ParameterSampler

@export var start_t: float = 0.0
@export var end_t: float = 1.0
@export var sample_count: int = 16
@export var include_end: bool = false


# 在起止参数之间生成均匀分布的采样值。
func sample_values() -> Array[float]:
	var result: Array[float] = []
	if sample_count <= 0:
		return result

	if sample_count == 1:
		result.append(start_t)
		return result

	var denominator: float = float(sample_count)
	if include_end:
		denominator = float(sample_count - 1)

	for index in range(sample_count):
		var ratio: float = float(index) / denominator
		result.append(lerp(start_t, end_t, ratio))

	return result
