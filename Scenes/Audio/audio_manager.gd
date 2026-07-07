class_name GameAudioManager
extends Node

const MIN_VOLUME_DB: float = -80.0

@export var sfx_events: Array[AudioSfxEvent] = []
@export var bgm_tracks: Array[AudioBgmTrack] = []
@export var initial_sfx_pool_size: int = 12
@export var initial_sfx_2d_pool_size: int = 24

var _sfx_by_name: Dictionary = {}
var _sfx_by_id: Dictionary = {}
var _bgm_by_name: Dictionary = {}
var _bgm_by_id: Dictionary = {}
var _free_sfx_players: Array[AudioStreamPlayer] = []
var _free_sfx_2d_players: Array[AudioStreamPlayer2D] = []
var _active_sfx_players: Dictionary = {}
var _active_sfx_by_event: Dictionary = {}
var _played_sfx_frame_by_event: Dictionary = {}

var _bgm_primary: AudioStreamPlayer
var _bgm_layer: AudioStreamPlayer
var _current_bgm_track: AudioBgmTrack
var _pending_bgm_track: AudioBgmTrack
var _pending_bgm_fade_in: float = 0.0
var _pending_bgm_from_position: float = 0.0
var _queued_bgm_track_name: String = ""
var _queued_bgm_fade_in: float = 0.0
var _bgm_layer_enabled: bool = false
var _bgm_tween: Tween
var _layer_tween: Tween


# 建立音频池和配置索引，Autoload 初始化后即可被玩法脚本调用。
func _ready() -> void:
	_rebuild_config_index()
	_create_bgm_players()
	_warmup_sfx_pool()


# 每帧同步跟随目标的位置，并清理已经失效的绑定。
func _process(_delta: float) -> void:
	for player in _active_sfx_players.keys().duplicate():
		var state: Dictionary = _active_sfx_players[player]
		var follow_target: Node2D = state.get("follow_target") as Node2D
		if follow_target == null:
			continue
		if not is_instance_valid(follow_target):
			_stop_sfx_player(player)
			continue

		if player is AudioStreamPlayer2D:
			(player as AudioStreamPlayer2D).global_position = follow_target.global_position


# 重新扫描 Inspector 中配置的音效和 BGM 资源。
func rebuild_config_index() -> void:
	_rebuild_config_index()


# 播放普通音效，适合 UI 或不需要空间定位的声音。
func play_sfx(event_name: String, options: Dictionary = {}) -> Node:
	return _play_sfx_internal(event_name, options)


# 通过数字 id 播放音效，适合调用侧使用 enum。
func play_sfx_id(event_id: int, options: Dictionary = {}) -> Node:
	var event: AudioSfxEvent = _sfx_by_id.get(event_id) as AudioSfxEvent
	if event == null:
		push_warning("SFX event id not found: %d" % event_id)
		return null

	return _play_sfx_internal(event.event_name, options)


# 在世界坐标播放 2D 音效，用于子弹、命中、爆炸等空间声音。
func play_sfx_at(event_name: String, global_position: Vector2, options: Dictionary = {}) -> Node:
	options = options.duplicate()
	options["position"] = global_position
	options["use_2d_player"] = true
	return _play_sfx_internal(event_name, options)


# 通过数字 id 在世界坐标播放 2D 音效。
func play_sfx_id_at(event_id: int, global_position: Vector2, options: Dictionary = {}) -> Node:
	var event: AudioSfxEvent = _sfx_by_id.get(event_id) as AudioSfxEvent
	if event == null:
		push_warning("SFX event id not found: %d" % event_id)
		return null

	return play_sfx_at(event.event_name, global_position, options)


# 播放会跟随目标移动的 2D 音效，目标失效后会自动停止并回收播放器。
func play_sfx_follow(event_name: String, follow_target: Node2D, options: Dictionary = {}) -> Node:
	options = options.duplicate()
	options["follow_target"] = follow_target
	options["use_2d_player"] = true
	if follow_target != null:
		options["position"] = follow_target.global_position

	return _play_sfx_internal(event_name, options)


# 通过数字 id 播放跟随场景对象移动的 2D 音效。
func play_sfx_id_follow(event_id: int, follow_target: Node2D, options: Dictionary = {}) -> Node:
	var event: AudioSfxEvent = _sfx_by_id.get(event_id) as AudioSfxEvent
	if event == null:
		push_warning("SFX event id not found: %d" % event_id)
		return null

	return play_sfx_follow(event.event_name, follow_target, options)


# 停止指定音效播放器，通常用于手动结束循环音效。
func stop_sfx(player: Node) -> void:
	_stop_sfx_player(player)


# 停止某个事件名下所有正在播放的音效。
func stop_sfx_by_event(event_name: String) -> void:
	var players: Array = _active_sfx_by_event.get(event_name, []).duplicate()
	for player in players:
		_stop_sfx_player(player)


# 播放 BGM，支持淡入淡出，并让第二通道从相同时间点开始保持节奏同步。
func play_bgm(track_name: String, fade_in: float = 0.5, fade_out: float = 0.5, from_position: float = 0.0) -> bool:
	var track: AudioBgmTrack = _bgm_by_name.get(track_name) as AudioBgmTrack
	if track == null:
		push_warning("BGM track not found: %s" % track_name)
		return false

	_queued_bgm_track_name = ""
	if _bgm_primary != null and _bgm_primary.playing and fade_out > 0.0:
		_pending_bgm_track = track
		_pending_bgm_fade_in = fade_in
		_pending_bgm_from_position = from_position
		_fade_out_current_bgm(fade_out)
	else:
		_fade_out_current_bgm(0.0)
		_start_bgm_track(track, fade_in, from_position)
	return true


# 通过数字 id 播放 BGM，适合调用侧使用 enum。
func play_bgm_id(track_id: int, fade_in: float = 0.5, fade_out: float = 0.5, from_position: float = 0.0) -> bool:
	var track: AudioBgmTrack = _bgm_by_id.get(track_id) as AudioBgmTrack
	if track == null:
		push_warning("BGM track id not found: %d" % track_id)
		return false

	return play_bgm(track.track_name, fade_in, fade_out, from_position)


# 停止当前 BGM。
func stop_bgm(fade_out: float = 0.5) -> void:
	_queued_bgm_track_name = ""
	_pending_bgm_track = null
	_fade_out_current_bgm(fade_out)
	_current_bgm_track = null


# 设置第二 BGM 通道的启用状态，高潮鼓点等内容可以用淡入淡出自然进入。
func set_bgm_layer_enabled(enabled: bool, fade_time: float = 0.5) -> void:
	_bgm_layer_enabled = enabled
	if _bgm_layer == null:
		return

	var target_volume: float = _get_current_layer_volume()
	if not enabled:
		target_volume = MIN_VOLUME_DB

	_tween_player_volume(_bgm_layer, target_volume, fade_time, true)


# 当前 BGM 本轮播放结束后切到下一首；要求音频资源本身不要开启内部 loop。
func queue_bgm_after_current_loop(track_name: String, fade_in: float = 0.0) -> bool:
	if not _bgm_by_name.has(track_name):
		push_warning("BGM track not found: %s" % track_name)
		return false

	_queued_bgm_track_name = track_name
	_queued_bgm_fade_in = fade_in
	return true


# 返回配置中的 BGM 长度，不要求当前正在播放。
func get_bgm_length(track_name: String) -> float:
	var track: AudioBgmTrack = _bgm_by_name.get(track_name) as AudioBgmTrack
	if track == null:
		return 0.0

	return track.get_length()


# 返回当前 BGM 播放位置，用于外部对齐演出或第二通道逻辑。
func get_bgm_playback_position() -> float:
	if _bgm_primary == null:
		return 0.0
	if not _bgm_primary.playing:
		return 0.0

	return _bgm_primary.get_playback_position()


# 返回当前曲目名，空字符串表示没有曲目在播放。
func get_current_bgm_name() -> String:
	if _current_bgm_track == null:
		return ""

	return _current_bgm_track.track_name


# 音效内部播放入口，统一处理池化、打断、每帧限制、循环和跟随目标。
func _play_sfx_internal(event_name: String, options: Dictionary) -> Node:
	var event: AudioSfxEvent = _sfx_by_name.get(event_name) as AudioSfxEvent
	if event == null:
		push_warning("SFX event not found: %s" % event_name)
		return null

	if event.once_per_frame:
		var current_frame: int = Engine.get_process_frames()
		if _played_sfx_frame_by_event.get(event_name, -1) == current_frame:
			return null
		_played_sfx_frame_by_event[event_name] = current_frame

	if event.same_event_policy == AudioSfxEvent.SameEventPolicy.INTERRUPT_PREVIOUS:
		stop_sfx_by_event(event_name)

	var active_count: int = (_active_sfx_by_event.get(event_name, []) as Array).size()
	if event.max_instances > 0 and active_count >= event.max_instances:
		return null

	var use_2d_player: bool = bool(options.get("use_2d_player", event.use_2d_player))
	var player: Node = _take_sfx_player(use_2d_player)
	if player == null:
		return null

	_setup_sfx_player(player, event, options)
	_register_active_sfx_player(player, event, options)

	if player is AudioStreamPlayer2D:
		(player as AudioStreamPlayer2D).play()
	elif player is AudioStreamPlayer:
		(player as AudioStreamPlayer).play()

	return player


# 根据配置创建普通或 2D 播放器。
func _take_sfx_player(use_2d_player: bool) -> Node:
	if use_2d_player:
		if _free_sfx_2d_players.is_empty():
			_free_sfx_2d_players.append(_create_sfx_2d_player())
		return _free_sfx_2d_players.pop_back()

	if _free_sfx_players.is_empty():
		_free_sfx_players.append(_create_sfx_player())
	return _free_sfx_players.pop_back()


# 写入音效播放参数，调用侧 options 可以临时覆盖音量、音调和总线。
func _setup_sfx_player(player: Node, event: AudioSfxEvent, options: Dictionary) -> void:
	var volume_db: float = float(options.get("volume_db", event.volume_db))
	var pitch_scale: float = float(options.get("pitch_scale", event.pitch_scale))
	var bus: StringName = StringName(options.get("bus", event.bus))
	var position: Vector2 = options.get("position", Vector2.ZERO) as Vector2

	if player is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = player as AudioStreamPlayer2D
		player_2d.stream = event.stream
		player_2d.volume_db = volume_db
		player_2d.pitch_scale = pitch_scale
		player_2d.bus = bus
		player_2d.global_position = position
	elif player is AudioStreamPlayer:
		var plain_player: AudioStreamPlayer = player as AudioStreamPlayer
		plain_player.stream = event.stream
		plain_player.volume_db = volume_db
		plain_player.pitch_scale = pitch_scale
		plain_player.bus = bus


# 记录活跃音效状态，供完成回调、循环和跟随逻辑使用。
func _register_active_sfx_player(player: Node, event: AudioSfxEvent, options: Dictionary) -> void:
	var event_name: String = event.event_name
	var follow_target: Node2D = options.get("follow_target") as Node2D
	var state: Dictionary = {
		"event": event,
		"event_name": event_name,
		"follow_target": follow_target
	}
	_active_sfx_players[player] = state

	if not _active_sfx_by_event.has(event_name):
		_active_sfx_by_event[event_name] = []
	(_active_sfx_by_event[event_name] as Array).append(player)


# 音效自然播放完成时，循环音效重新播放，否则放回对象池。
func _on_sfx_player_finished(player: Node) -> void:
	var state: Dictionary = _active_sfx_players.get(player, {})
	var event: AudioSfxEvent = state.get("event") as AudioSfxEvent
	if event != null and event.loop:
		if player is AudioStreamPlayer2D:
			(player as AudioStreamPlayer2D).play()
		elif player is AudioStreamPlayer:
			(player as AudioStreamPlayer).play()
		return

	_recycle_sfx_player(player)


# 停止并回收音效播放器。
func _stop_sfx_player(player: Node) -> void:
	if player == null:
		return
	if not _active_sfx_players.has(player):
		return

	if player is AudioStreamPlayer2D:
		(player as AudioStreamPlayer2D).stop()
	elif player is AudioStreamPlayer:
		(player as AudioStreamPlayer).stop()

	_recycle_sfx_player(player)


# 清理活跃索引并把播放器放回对应池。
func _recycle_sfx_player(player: Node) -> void:
	var state: Dictionary = _active_sfx_players.get(player, {})
	var event_name: String = state.get("event_name", "")

	if event_name != "" and _active_sfx_by_event.has(event_name):
		(_active_sfx_by_event[event_name] as Array).erase(player)

	_active_sfx_players.erase(player)

	if player is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = player as AudioStreamPlayer2D
		player_2d.stream = null
		player_2d.global_position = Vector2.ZERO
		_free_sfx_2d_players.append(player_2d)
	elif player is AudioStreamPlayer:
		var plain_player: AudioStreamPlayer = player as AudioStreamPlayer
		plain_player.stream = null
		_free_sfx_players.append(plain_player)


# 创建普通音效播放器，并绑定完成回调。
func _create_sfx_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "SfxPlayer"
	add_child(player)
	player.finished.connect(_on_sfx_player_finished.bind(player))
	return player


# 创建 2D 音效播放器，并绑定完成回调。
func _create_sfx_2d_player() -> AudioStreamPlayer2D:
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.name = "SfxPlayer2D"
	add_child(player)
	player.finished.connect(_on_sfx_player_finished.bind(player))
	return player


# 预热音效池，减少首次弹幕密集播放时的节点创建。
func _warmup_sfx_pool() -> void:
	for _index in range(initial_sfx_pool_size):
		_free_sfx_players.append(_create_sfx_player())

	for _index in range(initial_sfx_2d_pool_size):
		_free_sfx_2d_players.append(_create_sfx_2d_player())


# 创建 BGM 双通道播放器。
func _create_bgm_players() -> void:
	_bgm_primary = AudioStreamPlayer.new()
	_bgm_primary.name = "BgmPrimary"
	add_child(_bgm_primary)
	_bgm_primary.finished.connect(_on_bgm_primary_finished)

	_bgm_layer = AudioStreamPlayer.new()
	_bgm_layer.name = "BgmLayer"
	add_child(_bgm_layer)
	_bgm_layer.finished.connect(_on_bgm_layer_finished)


# 启动指定 BGM，并让第二通道用同一个起点对齐节奏。
func _start_bgm_track(track: AudioBgmTrack, fade_in: float, from_position: float) -> void:
	if _bgm_tween != null:
		_bgm_tween.kill()
		_bgm_tween = null

	_current_bgm_track = track
	_bgm_layer_enabled = track.start_with_layer

	_bgm_primary.stream = track.primary_stream
	_bgm_primary.bus = track.bus
	_bgm_primary.volume_db = MIN_VOLUME_DB if fade_in > 0.0 else track.volume_db
	_bgm_primary.play(from_position)
	_tween_player_volume(_bgm_primary, track.volume_db, fade_in, false)

	_bgm_layer.stop()
	_bgm_layer.stream = track.layer_stream
	_bgm_layer.bus = track.bus
	if track.layer_stream != null:
		_bgm_layer.volume_db = _get_current_layer_volume() if _bgm_layer_enabled and fade_in <= 0.0 else MIN_VOLUME_DB
		_bgm_layer.play(from_position)
		if _bgm_layer_enabled:
			_tween_player_volume(_bgm_layer, track.layer_volume_db, fade_in, true)

	DebugState.debug_log("Play BGM: %s" % track.track_name, "Audio")


# 当前 BGM 淡出；真正换曲由新曲立即启动或 finished 回调处理。
func _fade_out_current_bgm(fade_out: float) -> void:
	if _bgm_primary == null:
		return

	if _bgm_tween != null:
		_bgm_tween.kill()

	if fade_out <= 0.0:
		_bgm_primary.stop()
		_bgm_layer.stop()
		return

	_bgm_tween = create_tween()
	_bgm_tween.set_parallel(true)
	_bgm_tween.tween_property(_bgm_primary, "volume_db", MIN_VOLUME_DB, fade_out)
	_bgm_tween.tween_property(_bgm_layer, "volume_db", MIN_VOLUME_DB, fade_out)
	_bgm_tween.finished.connect(_on_bgm_fade_out_finished)


# 淡出完成后停止播放器，避免静音状态继续消耗播放位置。
func _on_bgm_fade_out_finished() -> void:
	_bgm_primary.stop()
	_bgm_layer.stop()

	if _pending_bgm_track != null:
		var next_track: AudioBgmTrack = _pending_bgm_track
		var fade_in: float = _pending_bgm_fade_in
		var from_position: float = _pending_bgm_from_position
		_pending_bgm_track = null
		_start_bgm_track(next_track, fade_in, from_position)


# 主通道完成时处理 loop 或排队切歌；这是前奏循环后无缝进入正曲的关键钩子。
func _on_bgm_primary_finished() -> void:
	if _current_bgm_track == null:
		return

	if _queued_bgm_track_name != "":
		var next_track: AudioBgmTrack = _bgm_by_name.get(_queued_bgm_track_name) as AudioBgmTrack
		_queued_bgm_track_name = ""
		if next_track != null:
			_start_bgm_track(next_track, _queued_bgm_fade_in, 0.0)
		return

	if _current_bgm_track.loop:
		_start_bgm_track(_current_bgm_track, 0.0, 0.0)


# 第二通道一般跟随主通道；如果主通道仍在播放，第二通道自然结束时按当前位置补齐。
func _on_bgm_layer_finished() -> void:
	if _current_bgm_track == null:
		return
	if _current_bgm_track.layer_stream == null:
		return
	if not _bgm_primary.playing:
		return

	_bgm_layer.play(_bgm_primary.get_playback_position())


# 当前曲目第二通道目标音量。
func _get_current_layer_volume() -> float:
	if _current_bgm_track == null:
		return MIN_VOLUME_DB

	return _current_bgm_track.layer_volume_db


# 淡入淡出单个播放器音量。
func _tween_player_volume(player: AudioStreamPlayer, target_volume: float, fade_time: float, is_layer: bool) -> void:
	if player == null:
		return

	if is_layer and _layer_tween != null:
		_layer_tween.kill()

	if fade_time <= 0.0:
		player.volume_db = target_volume
		return

	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_volume, fade_time)
	if is_layer:
		_layer_tween = tween


# 将 Inspector 配置转成字典索引，缺失或重复 id 会给出 warning。
func _rebuild_config_index() -> void:
	_sfx_by_name.clear()
	_sfx_by_id.clear()
	for event in sfx_events:
		if event == null:
			continue
		if not event.is_valid_event():
			push_warning("Invalid SFX event ignored.")
			continue
		if _sfx_by_name.has(event.event_name):
			push_warning("Duplicate SFX event overwritten: %s" % event.event_name)
		_sfx_by_name[event.event_name] = event
		if event.event_id >= 0:
			if _sfx_by_id.has(event.event_id):
				push_warning("Duplicate SFX event id overwritten: %d" % event.event_id)
			_sfx_by_id[event.event_id] = event

	_bgm_by_name.clear()
	_bgm_by_id.clear()
	for track in bgm_tracks:
		if track == null:
			continue
		if not track.is_valid_track():
			push_warning("Invalid BGM track ignored.")
			continue
		if _bgm_by_name.has(track.track_name):
			push_warning("Duplicate BGM track overwritten: %s" % track.track_name)
		_bgm_by_name[track.track_name] = track
		if track.track_id >= 0:
			if _bgm_by_id.has(track.track_id):
				push_warning("Duplicate BGM track id overwritten: %d" % track.track_id)
			_bgm_by_id[track.track_id] = track
