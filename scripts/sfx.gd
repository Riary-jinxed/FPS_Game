# Bruitages synthétisés au lancement (aucun fichier son nécessaire).
# Chaque son : forme d'onde, fréquence de départ, fréquence d'arrivée, durée, volume.
extends Node

const DEFS := {
	"rifle": ["square", 220, 60, 0.08, 0.12],
	"shotgun": ["saw", 120, 30, 0.2, 0.22],
	"uzi": ["square", 340, 110, 0.05, 0.07],
	"pistol": ["square", 420, 150, 0.06, 0.09],
	"blast": ["saw", 95, 25, 0.28, 0.26],
	"revolver": ["saw", 170, 40, 0.3, 0.24],
	"hit": ["tri", 900, 600, 0.05, 0.08],
	"kill": ["square", 500, 1200, 0.1, 0.1],
	"hurt": ["saw", 160, 70, 0.18, 0.2],
	"dash": ["sine", 300, 900, 0.12, 0.1],
	"slide": ["saw", 90, 60, 0.3, 0.05],
	"boss": ["saw", 60, 40, 1.2, 0.25],
	"pickup": ["sine", 600, 1300, 0.15, 0.12],
	"reload": ["tri", 300, 200, 0.12, 0.08],
	"spin": ["sine", 500, 1500, 0.25, 0.06],
	"click": ["square", 1400, 900, 0.04, 0.1],
	"pump": ["saw", 200, 90, 0.1, 0.14],
	"ping": ["sine", 1800, 2400, 0.15, 0.15],
	"boom": ["saw", 90, 30, 0.45, 0.3],
	"style": ["tri", 700, 1400, 0.12, 0.08],
	"dodge": ["sine", 900, 400, 0.2, 0.12],
	"orb": ["sine", 200, 120, 0.2, 0.06],
	"charge": ["sine", 220, 900, 0.5, 0.07],
	"skill": ["saw", 70, 420, 0.7, 0.22],
	"buy": ["tri", 800, 1700, 0.14, 0.12],
	"glitch": ["square", 90, 1500, 0.3, 0.07],
	"level": ["sine", 500, 1600, 0.4, 0.13],
	"pad": ["sine", 180, 1300, 0.3, 0.13],
	"wall": ["tri", 260, 520, 0.12, 0.07],
	"deny": ["square", 200, 140, 0.15, 0.08],
}
const RATE := 22050
const VOICES := 12

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in DEFS:
		var d: Array = DEFS[k]
		streams[k] = _make(d[0], float(d[1]), float(d[2]), float(d[3]), float(d[4]))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play(name: String) -> void:
	if not streams.has(name):
		return
	var p := players[next]
	next = (next + 1) % VOICES
	p.stream = streams[name]
	p.play()

func _make(wave: String, f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE) + 64
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := minf(t / dur, 1.0)
		var f := f0 * pow(f1 / f0, k)
		phase = fmod(phase + f / RATE, 1.0)
		var s := 0.0
		match wave:
			"square": s = 1.0 if phase < 0.5 else -1.0
			"saw": s = phase * 2.0 - 1.0
			"tri": s = 1.0 - 4.0 * absf(phase - 0.5)
			_: s = sin(phase * TAU)
		var g := vol * pow(0.001 / vol, k) if t < dur else 0.0
		data.encode_s16(i * 2, int(clampf(s * g * 1.6, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
