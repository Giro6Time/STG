extends Node2D

enum SfxId {
	PING = 1,
	HIT = 2,
	FOLLOW_LOOP = 3,
	INTERRUPT = 4,
	ONCE_PER_FRAME = 5
}

enum BgmId {
	STAGE = 101,
	BOSS_INTRO = 102,
	BOSS = 103
}

const SFX_EVENTS: Array[AudioSfxEvent] = [
	preload("res://data/audio/test/test_ping.tres"),
	preload("res://data/audio/test/test_hit.tres"),
	preload("res://data/audio/test/test_follow_loop.tres"),
	preload("res://data/audio/test/test_interrupt.tres"),
	preload("res://data/audio/test/test_once_per_frame.tres")
]
const BGM_TRACKS: Array[AudioBgmTrack] = [
	preload("res://data/audio/test/test_stage.tres"),
	preload("res://data/audio/test/test_boss_intro.tres"),
	preload("res://data/audio/test/test_boss.tres")
]

@onready var _moving_source: Node2D = %MovingSource
@onready var _status_label: Label = %StatusLabel
@onready var _follow_button: Button = %FollowButton
@onready var _layer_button: Button = %LayerButton

var _elapsed: float = 0.0
var _follow_player: Node
var _layer_enabled: bool = false
var _last_action: String = "测试数据已载入"
var _previous_sfx_events: Array[AudioSfxEvent] = []
var _previous_bgm_tracks: Array[AudioBgmTrack] = []


func _ready() -> void:
	_save_and_apply_test_data()
	_connect_buttons()
	_refresh_status()


func _process(delta: float) -> void:
	_elapsed += delta
	_moving_source.position.x = 320.0 + sin(_elapsed * 1.4) * 230.0
	queue_redraw()
	_refresh_status()


func _draw() -> void:
	draw_line(Vector2(70.0, 655.0), Vector2(570.0, 655.0), Color("51606b"), 2.0)
	draw_circle(_moving_source.position, 15.0, Color("efb366"))
	draw_circle(_moving_source.position, 5.0, Color("f8f4e8"))


# 测试场景退出时恢复原有配置，避免编辑器内切换场景后遗留测试事件。
func _exit_tree() -> void:
	if not is_instance_valid(AudioManager):
		return
	AudioManager.stop_bgm(0.0)
	for event in SFX_EVENTS:
		AudioManager.stop_sfx_by_event(event.event_name)
	AudioManager.sfx_events = _previous_sfx_events
	AudioManager.bgm_tracks = _previous_bgm_tracks
	AudioManager.rebuild_config_index()


func _save_and_apply_test_data() -> void:
	for event in AudioManager.sfx_events:
		_previous_sfx_events.append(event)
	for track in AudioManager.bgm_tracks:
		_previous_bgm_tracks.append(track)
	AudioManager.sfx_events = SFX_EVENTS
	AudioManager.bgm_tracks = BGM_TRACKS
	AudioManager.rebuild_config_index()


func _connect_buttons() -> void:
	%PingNameButton.pressed.connect(_play_ping_by_name)
	%PingIdButton.pressed.connect(_play_ping_by_id)
	%HitAtButton.pressed.connect(_play_hit_at_source)
	%FollowButton.pressed.connect(_toggle_follow_loop)
	%InterruptButton.pressed.connect(_play_interrupt_pair)
	%OncePerFrameButton.pressed.connect(_play_once_per_frame_burst)
	%StageBgmButton.pressed.connect(_play_stage_bgm)
	%LayerButton.pressed.connect(_toggle_bgm_layer)
	%StopBgmButton.pressed.connect(_stop_bgm)
	%BossIntroButton.pressed.connect(_play_boss_intro)
	%QueueBossButton.pressed.connect(_queue_boss_theme)


func _play_ping_by_name() -> void:
	AudioManager.play_sfx("test_ping", {"volume_db": -6.0})
	_last_action = "字符串事件：test_ping，临时音量 -6 dB"


func _play_ping_by_id() -> void:
	AudioManager.play_sfx_id(SfxId.PING)
	_last_action = "enum/id：SfxId.PING"


func _play_hit_at_source() -> void:
	AudioManager.play_sfx_id_at(SfxId.HIT, _moving_source.global_position)
	_last_action = "2D 定点音效：test_hit"


func _toggle_follow_loop() -> void:
	if _follow_player != null:
		AudioManager.stop_sfx(_follow_player)
		_follow_player = null
		_follow_button.text = "启动跟随循环"
		_last_action = "跟随循环已停止并回收"
		return

	_follow_player = AudioManager.play_sfx_follow("test_follow_loop", _moving_source)
	_follow_button.text = "停止跟随循环"
	_last_action = "循环音效正在跟随移动声源"


func _play_interrupt_pair() -> void:
	AudioManager.play_sfx("test_interrupt")
	AudioManager.play_sfx("test_interrupt")
	_last_action = "连续触发两次，第二次打断第一次"


func _play_once_per_frame_burst() -> void:
	var accepted_count: int = 0
	for _index in range(8):
		if AudioManager.play_sfx("test_once_per_frame") != null:
			accepted_count += 1
	_last_action = "同帧触发 8 次，实际播放 %d 次" % accepted_count


func _play_stage_bgm() -> void:
	AudioManager.play_bgm_id(BgmId.STAGE, 1.0, 0.5)
	_layer_enabled = false
	_layer_button.text = "开启节奏层"
	_last_action = "舞台 BGM 淡入，第二通道保持静音"


func _toggle_bgm_layer() -> void:
	_layer_enabled = not _layer_enabled
	AudioManager.set_bgm_layer_enabled(_layer_enabled, 0.6)
	_layer_button.text = "关闭节奏层" if _layer_enabled else "开启节奏层"
	_last_action = "第二通道%s" % ("淡入" if _layer_enabled else "淡出")


func _stop_bgm() -> void:
	AudioManager.stop_bgm(0.8)
	_layer_enabled = false
	_layer_button.text = "开启节奏层"
	_last_action = "BGM 淡出停止"


func _play_boss_intro() -> void:
	AudioManager.play_bgm("test_boss_intro", 0.4, 0.4)
	_layer_enabled = false
	_layer_button.text = "开启节奏层"
	_last_action = "Boss 前奏开始循环"


func _queue_boss_theme() -> void:
	var queued: bool = AudioManager.queue_bgm_after_current_loop("test_boss", 0.0)
	_last_action = "Boss 正式曲已排队，将在本轮前奏结束时切换" if queued else "排队失败：曲目未配置"


func _refresh_status() -> void:
	var track_name: String = AudioManager.get_current_bgm_name()
	if track_name == "":
		track_name = "无"
	var playback_position: float = AudioManager.get_bgm_playback_position()
	var track_length: float = AudioManager.get_bgm_length(AudioManager.get_current_bgm_name())
	_status_label.text = "最近操作：%s\nBGM：%s  %.2f / %.2f 秒\n移动声源：x = %.1f" % [
		_last_action,
		track_name,
		playback_position,
		track_length,
		_moving_source.position.x
	]
