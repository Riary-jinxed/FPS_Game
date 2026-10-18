# Lecteur de musique : même logique que music/music.js du prototype web.
# Dépose les mp3 Suno dans res://music/ (zone 1) et res://music/zoneN/ (zones suivantes).
# Une piste absente est ignorée ; une piste de zone manquante reprend celle de la zone 1.
extends Node

const DIR := "res://music/"
const TRACKS := {
	"menu": ["menu.mp3"],
	"wave": ["wave_1.mp3", "wave_2.mp3", "wave_3.mp3"], # tourne d'une vague à l'autre
	"boss": ["boss.mp3"],
	"miniboss": ["miniboss.mp3", "boss.mp3"],         # mini-boss du round 5 : repli sur boss.mp3
	"shop": ["shop.mp3", "augment.mp3"],
	"boss2": ["boss_phase2.mp3", "boss.mp3"],           # phase 2 : repli sur boss.mp3
	"augment": ["augment.mp3"],
	"victory": ["victory.mp3", "augment.mp3"],
	"over": ["gameover.mp3"],
}
const SHARED := { "menu": true, "over": true } # communs à toutes les zones
const FADE := 1.2
const SETTINGS := "user://settings.cfg"

var volume := 0.6
var muted := false
var ducked := false
var zone := 1
var wave_idx := 0
var current_key := ""
var current: AudioStreamPlayer = null
var spare: AudioStreamPlayer = null
var cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	current = AudioStreamPlayer.new(); add_child(current)
	spare = AudioStreamPlayer.new(); add_child(spare)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		volume = cfg.get_value("music", "volume", volume)
		muted = cfg.get_value("music", "muted", muted)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("music", "volume", volume)
	cfg.set_value("music", "muted", muted)
	cfg.save(SETTINGS)

func _target() -> float:
	return 0.0 if muted else volume * (0.35 if ducked else 1.0)

func _stream(path: String) -> AudioStream:
	if cache.has(path):
		return cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(DIR + path):
		s = load(DIR + path)
		if s is AudioStreamMP3:
			s.loop = not path.contains("gameover")
		elif s is AudioStreamOggVorbis:
			s.loop = not path.contains("gameover")
	cache[path] = s
	return s

func _candidates(key: String) -> Array:
	var list: Array = TRACKS.get(key, [])
	if key == "wave" and list.size() > 0:
		var s := wave_idx % list.size()
		list = list.slice(s) + list.slice(0, s)
	var out := []
	for f in list:
		if zone > 1 and not SHARED.has(key):
			out.append("zone%d/%s" % [zone, f])
		out.append(f)
	return out

func _fade(p: AudioStreamPlayer, to: float, stop_after := false) -> void:
	var from := db_to_linear(p.volume_db)
	var tw := create_tween()
	tw.tween_method(func(v: float): p.volume_db = linear_to_db(maxf(v, 0.0001)), from, to, FADE)
	if stop_after:
		tw.tween_callback(p.stop)

func play(key: String) -> void:
	if key == current_key:
		return # on garde la même piste pendant la vague
	var stream: AudioStream = null
	for c in _candidates(key):
		stream = _stream(c)
		if stream:
			break
	if key == "wave":
		wave_idx += 1
	current_key = key
	if current.playing:
		_fade(current, 0.0, true)
		var t := current; current = spare; spare = t
	if stream == null:
		return
	current.stream = stream
	current.volume_db = -80.0
	current.play()
	_fade(current, _target())

func set_zone(n: int) -> void:
	n = maxi(1, n)
	if n != zone:
		zone = n
		wave_idx = 0

func duck(on: bool) -> void:
	ducked = on
	if current.playing:
		_fade(current, _target())

func toggle_mute() -> bool:
	muted = not muted
	_save()
	if current.playing:
		_fade(current, _target())
	return muted
