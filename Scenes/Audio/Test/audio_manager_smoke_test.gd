extends Node

const SFX_PING: AudioSfxEvent = preload("res://data/audio/test/test_ping.tres")
const SFX_HIT: AudioSfxEvent = preload("res://data/audio/test/test_hit.tres")
const SFX_FOLLOW_LOOP: AudioSfxEvent = preload("res://data/audio/test/test_follow_loop.tres")
const SFX_INTERRUPT: AudioSfxEvent = preload("res://data/audio/test/test_interrupt.tres")
const SFX_ONCE_PER_FRAME: AudioSfxEvent = preload("res://data/audio/test/test_once_per_frame.tres")
const BGM_STAGE: AudioBgmTrack = preload("res://data/audio/test/test_stage.tres")
const BGM_BOSS_INTRO: AudioBgmTrack = preload("res://data/audio/test/test_boss_intro.tres")
const BGM_BOSS: AudioBgmTrack = preload("res://data/audio/test/test_boss.tres")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_tests")


# 使用真实 Autoload 和真实音频资源验证公共接口，失败时让 Godot 返回非零退出码。
func _run_tests() -> void:
	_configure_test_data()

	var first_ping: Node = AudioManager.play_sfx("test_ping")
	_check(first_ping != null, "字符串事件名可以播放音效")
	AudioManager.stop_sfx(first_ping)
	var reused_ping: Node = AudioManager.play_sfx_id(1)
	_check(reused_ping != null, "数字 id 可以播放音效")
	_check(reused_ping == first_ping, "停止后的普通播放器会回到对象池并被复用")
	AudioManager.stop_sfx(reused_ping)
	var overlap_ping_a: Node = AudioManager.play_sfx("test_ping")
	var overlap_ping_b: Node = AudioManager.play_sfx("test_ping")
	_check(overlap_ping_a != null and overlap_ping_b != null and overlap_ping_a != overlap_ping_b, "允许重叠的同名音效会使用两个播放器")
	AudioManager.stop_sfx(overlap_ping_a)
	AudioManager.stop_sfx(overlap_ping_b)

	var source: Node2D = Node2D.new()
	add_child(source)
	source.global_position = Vector2(120.0, 240.0)
	var follow_player: Node = AudioManager.play_sfx_follow("test_follow_loop", source)
	_check(follow_player is AudioStreamPlayer2D, "跟随音效使用 AudioStreamPlayer2D")
	source.global_position = Vector2(420.0, 360.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check((follow_player as AudioStreamPlayer2D).global_position == source.global_position, "2D 播放器每帧跟随目标位置")
	AudioManager.stop_sfx(follow_player)

	var first_limited: Node = AudioManager.play_sfx("test_once_per_frame")
	var second_limited: Node = AudioManager.play_sfx("test_once_per_frame")
	_check(first_limited != null and second_limited == null, "同一事件每帧最多播放一次")
	AudioManager.stop_sfx(first_limited)

	var first_interrupt: Node = AudioManager.play_sfx("test_interrupt")
	var second_interrupt: Node = AudioManager.play_sfx("test_interrupt")
	_check(first_interrupt != null and second_interrupt == first_interrupt, "同名打断会回收并复用上一播放器")
	AudioManager.stop_sfx(second_interrupt)

	_check(AudioManager.get_bgm_length("test_stage") > 1.0, "外部可以读取 BGM 长度")
	_check(AudioManager.play_bgm_id(101, 0.0, 0.0), "数字 id 可以播放 BGM")
	_check(AudioManager.get_current_bgm_name() == "test_stage", "可以读取当前 BGM 名称")
	AudioManager.set_bgm_layer_enabled(true, 0.0)
	_check(AudioManager.play_bgm("test_boss_intro", 0.0, 0.0), "Boss 前奏可以独立播放")
	_check(AudioManager.queue_bgm_after_current_loop("test_boss", 0.0), "Boss 正式曲可以排队到前奏结束")

	AudioManager.stop_bgm(0.0)
	AudioManager.stop_sfx_by_event("test_follow_loop")
	source.queue_free()

	if _failures.is_empty():
		print("AudioManager smoke test passed: 13 checks")
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error("AudioManager smoke test failed: %s" % failure)
	get_tree().quit(1)


func _configure_test_data() -> void:
	AudioManager.sfx_events = [
		SFX_PING,
		SFX_HIT,
		SFX_FOLLOW_LOOP,
		SFX_INTERRUPT,
		SFX_ONCE_PER_FRAME
	]
	AudioManager.bgm_tracks = [BGM_STAGE, BGM_BOSS_INTRO, BGM_BOSS]
	AudioManager.rebuild_config_index()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
