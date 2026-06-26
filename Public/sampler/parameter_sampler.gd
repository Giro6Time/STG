@tool
class_name ParameterSampler
extends Resource


# 返回本次采样要使用的参数列表，基类默认不产生采样。
func sample_values() -> Array[float]:
	return []
