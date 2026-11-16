extends Node2D

## 弹幕测试场景：扫描 data/danmaku_tests/*.tres 加载全部用例。
## 功能：自动切换/单曲循环(C)/上下个(←→)/重开(R)/隐藏UI(Tab)/搜索/点击跳转。

const TEST_CASES_DIR: String = "res://data/danmaku_tests"

var _test_cases: Array[BulletPatternConfig] = []
var _test_case_names: Array[String] = []
var _demo_index: int = 0
var _pattern: BossBulletPattern
var _elapsed: float = 0.0
var _repeat_current: bool = false

var _ui_layer: CanvasLayer
var _title_label: Label
var _search_edit: LineEdit
var _item_list: ItemList
var _ui_panel: Panel
var _filtered_indices: Array[int] = []


func _ready() -> void:
	_load_test_cases()
	_setup_ui()
	_apply_filter("")
	if _filtered_indices.is_empty():
		push_warning("DanmakuTest: no test cases in %s" % TEST_CASES_DIR)
		return
	_start_demo(_filtered_indices[0])


func _process(delta: float) -> void:
	if _pattern == null:
		return
	_elapsed += delta
	var runtime_data := FlowPhaseRuntimeData.new()
	runtime_data.setup(self, delta, _elapsed)
	_pattern.update_pattern(runtime_data)
	_update_ui()

	if _repeat_current:
		return
	if _elapsed >= _get_current_duration():
		_step_demo(1)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if _search_edit != null and _search_edit.has_focus():
		return
	match event.keycode:
		KEY_LEFT: _step_demo(-1)
		KEY_RIGHT: _step_demo(1)
		KEY_R: _start_demo(_demo_index)
		KEY_C: _repeat_current = not _repeat_current; _update_ui()
		KEY_TAB: _toggle_ui()


func _load_test_cases() -> void:
	_test_cases.clear()
	_test_case_names.clear()
	var dir := DirAccess.open(TEST_CASES_DIR)
	if dir == null:
		push_warning("DanmakuTest: cannot open %s" % TEST_CASES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var case := load(TEST_CASES_DIR.path_join(file_name)) as BulletPatternConfig
			if case != null:
				_test_cases.append(case)
				_test_case_names.append(case.display_name if case.display_name != "" else file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()


func _step_demo(direction: int) -> void:
	if _filtered_indices.is_empty():
		return
	var pos: int = _filtered_indices.find(_demo_index)
	if pos < 0:
		pos = 0
	pos = wrapi(pos + direction, 0, _filtered_indices.size())
	_start_demo(_filtered_indices[pos])


func _start_demo(index: int) -> void:
	_cleanup_pattern()
	_clear_bullets()
	_demo_index = index
	_elapsed = 0.0
	var test_case: BulletPatternConfig = _test_cases[index]
	_pattern = test_case.build(self)
	_pattern.name = "DemoPattern_%d" % index
	add_child(_pattern)
	_pattern.start_pattern(self)
	_update_ui()


func _get_current_duration() -> float:
	if _demo_index >= 0 and _demo_index < _test_cases.size():
		return _test_cases[_demo_index].duration
	return 4.0


func _clear_bullets() -> void:
	var layer := get_tree().get_first_node_in_group(BulletLayer.GROUP_NAME) as BulletLayer
	if layer != null:
		layer.clear_all()


func _cleanup_pattern() -> void:
	if _pattern == null:
		return
	if _pattern.is_inside_tree():
		_pattern.stop_pattern()
		_pattern.queue_free()
	_pattern = null


func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 100
	add_child(_ui_layer)
	_ui_panel = Panel.new()
	_ui_panel.position = Vector2(8, 8)
	_ui_panel.size = Vector2(330, 270)
	_ui_layer.add_child(_ui_panel)
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(12, 12)
	vbox.size = Vector2(306, 246)
	vbox.add_theme_constant_override("separation", 6)
	_ui_panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_title_label)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索演示...（回车播第一个匹配）"
	_search_edit.text_changed.connect(_on_search_text_changed)
	_search_edit.text_submitted.connect(_on_search_submitted)
	vbox.add_child(_search_edit)
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	vbox.add_child(_item_list)


func _toggle_ui() -> void:
	if _ui_panel == null:
		return
	_ui_panel.visible = not _ui_panel.visible
	if not _ui_panel.visible and _search_edit != null and _search_edit.has_focus():
		_search_edit.release_focus()


func _apply_filter(keyword: String) -> void:
	_filtered_indices.clear()
	var lower: String = keyword.strip_edges().to_lower()
	for i in range(_test_cases.size()):
		if lower.is_empty() or _test_case_names[i].to_lower().contains(lower):
			_filtered_indices.append(i)
	_item_list.clear()
	for idx in _filtered_indices:
		_item_list.add_item(_test_case_names[idx])
	if not _filtered_indices.has(_demo_index):
		if not _filtered_indices.is_empty():
			_start_demo(_filtered_indices[0])
	_update_ui()


func _on_search_text_changed(new_text: String) -> void:
	_apply_filter(new_text)


func _on_search_submitted(_new_text: String) -> void:
	if not _filtered_indices.is_empty():
		_start_demo(_filtered_indices[0])
	_search_edit.release_focus()


func _on_item_selected(item_index: int) -> void:
	if item_index >= 0 and item_index < _filtered_indices.size():
		_start_demo(_filtered_indices[item_index])


func _update_ui() -> void:
	if _title_label == null:
		return
	var name: String = ""
	if _demo_index >= 0 and _demo_index < _test_case_names.size():
		name = _test_case_names[_demo_index]
	var wave_text := ""
	if _pattern != null and _pattern.timeline is RepeatTimelineDriver:
		var driver := _pattern.timeline as RepeatTimelineDriver
		if driver.rounds <= 0:
			wave_text = "  波次 ∞（已发 %d）" % driver.get_round()
		else:
			wave_text = "  波次 %d/%d" % [driver.get_round(), driver.rounds]
	_title_label.text = "演示 %d/%d: %s%s\n单曲:%s ←/→切换 R重开 C单曲 Tab隐藏" % [
		_demo_index + 1, _test_cases.size(), name, wave_text,
		"ON" if _repeat_current else "OFF"
	]
	var pos: int = _filtered_indices.find(_demo_index)
	if pos >= 0 and pos < _item_list.item_count:
		_item_list.select(pos)
		_item_list.ensure_current_is_visible()
