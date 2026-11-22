extends Node

const EFFECTS := "res://assets/audio/lakeside/"
const SCORE := "res://assets/audio/bgm/campfire.mp3"

var _music: AudioStreamPlayer
var _feet: AudioStreamPlayer
var _weapon: AudioStreamPlayer
var _strike: AudioStreamPlayer
var _ground: Array[AudioStream] = []
var _wood: AudioStream
var _stone: AudioStream
var _swish: AudioStream
var _impact: AudioStream
var _last_ground := -1

func _ready() -> void:
	_music = _player(1)
	_feet = _player(2)
	_weapon = _player(2)
	_strike = _player(2)
	for sample in ["footstep00.ogg", "footstep06.ogg", "footstep09.ogg"]:
		_ground.append(load(EFFECTS + sample) as AudioStream)
	_wood = load(EFFECTS + "wood-step.ogg") as AudioStream
	_stone = load(EFFECTS + "stone-step.ogg") as AudioStream
	_swish = load(EFFECTS + "swish.wav") as AudioStream
	_impact = load(EFFECTS + "wood-impact.ogg") as AudioStream
	var imported_score := load(SCORE) as AudioStreamMP3
	var score := imported_score.duplicate() as AudioStreamMP3 if imported_score else null
	if score:
		score.loop = true
		_music.stream = score
		_process(0.0)
		_music.play()

func _process(_delta: float) -> void:
	var music_gain := 0.0 if PrologueState.bgm_muted else PrologueState.bgm_volume * 0.29
	_music.volume_db = linear_to_db(maxf(music_gain, 0.0001))

func _player(polyphony: int) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.max_polyphony = polyphony
	add_child(voice)
	return voice

func _play(voice: AudioStreamPlayer, sample: AudioStream, gain: float) -> void:
	if sample and PrologueState.sfx_volume > 0.01:
		voice.stream = sample
		voice.pitch_scale = randf_range(0.93, 1.07)
		voice.volume_db = linear_to_db(PrologueState.sfx_volume * gain)
		voice.play()

func step(on_wood: bool, on_stone: bool) -> void:
	if on_wood:
		_play(_feet, _wood, 0.15)
		return
	if on_stone:
		_play(_feet, _stone, 0.16)
		return
	_last_ground = (_last_ground + randi_range(1, _ground.size() - 1)) % _ground.size()
	_play(_feet, _ground[_last_ground], 0.18)

func swing() -> void:
	_play(_weapon, _swish, 0.24)

func impact() -> void:
	_play(_strike, _impact, 0.36)
