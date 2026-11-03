class_name Sfx
extends Node
## 音效播放器：play("hit") 播放 assets/sfx/hit.wav。
## 同一个音效 60 毫秒内只播一次（范围技能同时打到好几个人时不会叠成爆音）。M 键静音。

const DIR := "res://assets/sfx/"
const POOL := 8

var muted := false
var _players: Array[AudioStreamPlayer] = []
var _streams := {}
var _last_played := {}
var _next := 0


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if muted or sound == "":
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 60:
		return
	_last_played[sound] = now
	if not _streams.has(sound):
		var path := DIR + sound + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	if _streams[sound] == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.volume_db = -6.0 + volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)     # 轻微随机音高，听起来不那么机械
	p.play()


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		for p in _players:
			p.stop()
	return muted
