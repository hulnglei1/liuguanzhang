extends Node
## 全局音频管理（Autoload）：音频总线、BGM 交叉淡入淡出、音量设置持久化。
##
## 为什么用 Autoload：BGM 要跨场景连续（主菜单 → 序章 → 战场），
## 场景内的播放器会随场景销毁，音乐就断了。

const SETTINGS_PATH := "user://settings.json"

const BGM := {
	"menu": preload("res://assets/audio/bgm_menu.ogg"),
	"battle": preload("res://assets/audio/bgm_battle.ogg"),
	"win": preload("res://assets/audio/bgm_win.ogg"),
}

## 0.0 ~ 1.0 的线性音量（存盘用）
var settings := {
	"master": 0.85,
	"bgm": 0.62,
	"sfx": 0.90,
	"fullscreen": false,
}

var _players: Array[AudioStreamPlayer] = []
var _cur: int = 0
var _current_track: String = ""
var _fade: Tween


func _ready() -> void:
	# 无头模式（自动化测试）不初始化音频：
	# 播放器与混音线程在进程退出时可能拖住 quit()，导致测试超时挂死。
	if DisplayServer.get_name() == "headless":
		return
	_ensure_buses()
	load_settings()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "BgmPlayer%d" % i
		p.bus = "BGM"
		p.volume_db = -40.0
		add_child(p)
		_players.append(p)
	apply_settings()


func _ensure_buses() -> void:
	for bus_name in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


## 切 BGM：交叉淡入淡出；同一首重复调用不会重头播
func play_bgm(track: String, fade: float = 0.9) -> void:
	if _players.is_empty():        # 无头模式没有播放器，直接跳过
		return
	if _current_track == track:
		return
	var stream: AudioStream = BGM.get(track, null)
	if stream == null:
		return
	# OGG 默认不循环；菜单/战斗要循环，胜利曲只播一次
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = track != "win"

	var old: AudioStreamPlayer = _players[_cur]
	_cur = 1 - _cur
	var p: AudioStreamPlayer = _players[_cur]
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	_current_track = track

	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(p, "volume_db", 0.0, fade)
	_fade.tween_property(old, "volume_db", -40.0, fade)
	_fade.chain().tween_callback(func() -> void:
		if is_instance_valid(old):
			old.stop()
	)


func stop_bgm(fade: float = 0.6) -> void:
	if _players.is_empty():
		return
	if _current_track == "":
		return
	_current_track = ""
	var p: AudioStreamPlayer = _players[_cur]
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(p, "volume_db", -40.0, fade)
	_fade.tween_callback(func() -> void:
		if is_instance_valid(p):
			p.stop()
	)


# ---------------- 设置 ----------------

func set_volume(kind: String, value: float) -> void:
	settings[kind] = clampf(value, 0.0, 1.0)
	apply_settings()
	save_settings()


func set_fullscreen(on: bool) -> void:
	settings["fullscreen"] = on
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	save_settings()


func apply_settings() -> void:
	_set_bus_volume("Master", float(settings.get("master", 0.85)))
	_set_bus_volume("BGM", float(settings.get("bgm", 0.62)))
	_set_bus_volume("SFX", float(settings.get("sfx", 0.90)))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))
		f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in settings.keys():
			if parsed.has(k):
				settings[k] = parsed[k]
	apply_settings()
	# 恢复全屏状态（窗口模式下不要动）
	if bool(settings.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
