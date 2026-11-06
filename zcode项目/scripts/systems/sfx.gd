## 音效播放器（极简）：预加载全部 WAV，用一个 AudioStreamPlayer 轮播。
##
## 为什么不做成 Autoload：目前只有战斗场景需要音效，避免全局状态；
## 以后主菜单/抽奖要用，再抽成 Autoload 即可（接口不变）。

const STREAMS := {
	"ui_click": preload("res://assets/audio/ui_click.wav"),
	"attack": preload("res://assets/audio/attack.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"skill": preload("res://assets/audio/skill.wav"),
	"death": preload("res://assets/audio/death.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"),
	"turn": preload("res://assets/audio/turn.wav"),
}

## 各音效的基准音量（dB），避免大招音压过普攻
const VOLUMES := {
	"ui_click": -12.0,
	"attack": -6.0,
	"hit": -4.0,
	"skill": -3.0,
	"death": -3.0,
	"victory": -2.0,
	"defeat": -3.0,
	"turn": -10.0,
}


static func play(player: AudioStreamPlayer, sfx_name: String) -> void:
	if player == null:
		return
	var stream: AudioStream = STREAMS.get(sfx_name, null)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = float(VOLUMES.get(sfx_name, -6.0))
	player.play()
