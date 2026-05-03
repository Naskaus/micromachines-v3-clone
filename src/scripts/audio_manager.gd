extends Node

# Global audio manager (autoload).
# - Pool of AudioStreamPlayers for one-shot SFX
# - Dedicated looping engine player with pitch tied to player speed (call set_engine_speed_ratio every frame)

const SFX_PATHS := {
	# F1-style countdown: 3 short beeps + 1 long beep
	"countdown_beep": "res://assets/audio/bong_001.ogg",
	"go": "res://assets/audio/select_005.ogg",
	# Race events
	"boost": "res://assets/audio/upgrade1.ogg",
	"arch_pass": "res://assets/audio/coin1.ogg",
	"lap_complete": "res://assets/audio/secret1.ogg",
	"win": "res://assets/audio/congratulations.ogg",
	"defeat": "res://assets/audio/gameover1.ogg",
	# Crashes
	"hit_light": "res://assets/audio/hit1.ogg",
	"hit_heavy": "res://assets/audio/explosion1.ogg",
	# Drift / skid
	"skid": "res://assets/audio/skid.ogg",
}

const ENGINE_PATH := "res://assets/audio/engine3.ogg"
const ENGINE_PITCH_IDLE := 0.55     # lower idle = softer rumble
const ENGINE_PITCH_MAX := 1.4       # less screech at top speed
const ENGINE_VOLUME_DB := -30.0     # very ambient — barely there

const MUSIC_RACE := "res://assets/audio/retro_reggae.ogg"  # Kenney Music Loops > Retro Reggae (CC0)
const MUSIC_MENU := "res://assets/audio/mishief_stroll.ogg"
const MUSIC_VOLUME_DB := -4.0

const POOL_SIZE := 8
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

var _engine_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null

var sfx_muted: bool = false
var music_muted: bool = false


func _ready() -> void:
	for key in SFX_PATHS:
		var s: AudioStream = load(SFX_PATHS[key]) as AudioStream
		if s:
			_streams[key] = s
		else:
			push_warning("AudioManager: failed to load %s" % SFX_PATHS[key])
	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Player_%d" % i
		add_child(p)
		_players.append(p)

	# Engine loop player
	var engine_stream: AudioStream = load(ENGINE_PATH) as AudioStream
	if engine_stream:
		_engine_player = AudioStreamPlayer.new()
		_engine_player.name = "EnginePlayer"
		_engine_player.stream = engine_stream
		_engine_player.volume_db = ENGINE_VOLUME_DB
		_engine_player.pitch_scale = ENGINE_PITCH_IDLE
		if engine_stream is AudioStreamOggVorbis:
			(engine_stream as AudioStreamOggVorbis).loop = true
		add_child(_engine_player)

	# Music player (separate from SFX pool)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)


func play(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if sfx_muted:
		return
	if not _streams.has(key):
		push_warning("AudioManager: unknown SFX key '%s'" % key)
		return
	var p: AudioStreamPlayer = null
	for player in _players:
		if not player.playing:
			p = player
			break
	if p == null:
		p = _players[_next_player]
		_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[key]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func toggle_sfx() -> bool:
	# Returns the new muted state (true = now muted)
	sfx_muted = not sfx_muted
	if _engine_player:
		_engine_player.volume_db = -80.0 if sfx_muted else ENGINE_VOLUME_DB
	return sfx_muted


func toggle_music() -> bool:
	music_muted = not music_muted
	if _music_player:
		_music_player.volume_db = -80.0 if music_muted else MUSIC_VOLUME_DB
	return music_muted


func start_engine() -> void:
	if _engine_player and not _engine_player.playing:
		_engine_player.play()


func stop_engine() -> void:
	if _engine_player and _engine_player.playing:
		_engine_player.stop()


func set_engine_speed_ratio(ratio: float) -> void:
	if _engine_player == null:
		return
	var clamped: float = clamp(ratio, 0.0, 1.0)
	_engine_player.pitch_scale = lerp(ENGINE_PITCH_IDLE, ENGINE_PITCH_MAX, clamped)


func play_music(track: String) -> void:
	# track ∈ {"race", "menu"}
	if _music_player == null:
		return
	var path: String = MUSIC_RACE if track == "race" else MUSIC_MENU
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()
