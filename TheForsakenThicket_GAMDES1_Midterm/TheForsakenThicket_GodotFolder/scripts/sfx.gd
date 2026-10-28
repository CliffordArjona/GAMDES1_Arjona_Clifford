extends Node
## Sfx (Autoload) - plays sound effects and the zone music.
## All audio lives in assets/generated/audio/*.wav (made by tools/art_audio.py).

const DIR := "res://assets/generated/audio/"
var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_track := ""
const SFX_BASE_DB := -4.0
const MUSIC_BASE_DB := -10.0
var muted := false


func _lin_to_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)

var sfx_volume_db: float:
	get: return SFX_BASE_DB + _lin_to_db(Settings.sfx)

var music_volume_db: float:
	get: return MUSIC_BASE_DB + _lin_to_db(Settings.music)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	_music_a.volume_db = -80.0
	_music_b.volume_db = -80.0
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	for m in [_music_a, _music_b]:
		if m.playing and m.volume_db > -70.0:
			m.volume_db = -80.0 if muted else music_volume_db


func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := DIR + name + ".wav"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


func play(name: String, volume_offset_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted:
		return
	var s := _stream(name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = sfx_volume_db + volume_offset_db
			p.pitch_scale = pitch
			p.play()
			return


func play_varied(name: String, volume_offset_db: float = 0.0) -> void:
	play(name, volume_offset_db, randf_range(0.92, 1.08))


func play_music(track: String) -> void:
	if track == _current_track:
		return
	_current_track = track
	var s := _stream("bgm_" + track)
	if s == null:
		return
	var stream: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.data.size() / 2)
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -60.0 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", -80.0 if muted else music_volume_db, 1.5)
	tw.tween_property(outgoing, "volume_db", -80.0, 1.5)
	tw.chain().tween_callback(outgoing.stop)


func stop_music() -> void:
	_current_track = ""
	for m in [_music_a, _music_b]:
		m.stop()


func toggle_mute() -> void:
	muted = not muted
	for m in [_music_a, _music_b]:
		if m.playing:
			m.volume_db = -80.0 if muted else music_volume_db
