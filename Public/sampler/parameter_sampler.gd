@tool
class_name ParameterSampler
extends Resource

## 参数采样器基类：决定"在曲线上取哪些 t 值"。
## 子类实现 sample_values() 返回参数列表。

func sample_values() -> Array[float]:
	return []
