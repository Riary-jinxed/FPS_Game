# Base commune des arènes de zone : briques de décor, jump pads, néons qui clignotent.
# Chaque zone (city.gd, foundry.gd) étend ce script et remplit perches, pads, anchors,
# puis redéfinit collapse() (phase 2 du boss), over_pit() et hazard_at() si elle en a besoin.
extends Node3D

const HALF := 40.0
const PLAZA := 12.0          # demi-taille de la zone centrale (point de retour après une chute)

var perches: Array[Vector3] = []   # postes des snipers
var anchors: Array[Vector3] = []   # socles des bras mécaniques
var pads: Array = []               # { pos, push, power, node, ring }
var tiles: Array = []              # dalles qui peuvent tomber (zone 1)
var collapsed := false             # phase 2 du boss déclenchée
var phase2_text := "L'arène change"
var flickers: Array = []           # néons qui clignotent { mat, base, seed, speed }
var _rng := RandomNumberGenerator.new()

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for f in flickers:
		var on := 1.0
		var s: float = sin(t * f.speed + f.seed)
		if s > 0.97:
			on = 0.15
		f.mat.emission_energy_multiplier = f.base * on

# ---------- À redéfinir par zone ----------
func follow(_p: Vector3) -> void:
	pass

func tick(_delta: float) -> void:
	# avance les effets de la phase 2 pendant le jeu (pas pendant la pause ni les écrans)
	pass

func collapse() -> void:
	collapsed = true

func calm() -> void:
	# boss de zone vaincu
	pass

func reset() -> void:
	collapsed = false

func over_pit(_p: Vector3) -> bool:
	return false

func hazard_at(_p: Vector3, _on_floor: bool) -> float:
	# dégâts par seconde du décor à cette position (métal en fusion...)
	return 0.0

# ---------- Matériaux ----------
func _neon(c: Color, energy := 3.0, flicker := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	if flicker:
		flickers.append({ "mat": m, "base": energy, "seed": _rng.randf() * 100.0, "speed": _rng.randf_range(1.5, 4.0) })
	return m

func _concrete(c := Color("232a36")) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	return m

# ---------- Briques ----------
func _box(pos: Vector3, size: Vector3, mat: Material, collide := true, parent: Node3D = self) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new(); shape.size = size
		col.shape = shape
		body.add_child(col)
		root = body
	else:
		root = Node3D.new()
	root.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	root.add_child(mi)
	parent.add_child(root)
	return root

func _cyl(pos: Vector3, radius: float, height: float, mat: Material, collide := true) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new(); shape.radius = radius; shape.height = height
		col.shape = shape
		body.add_child(col)
		root = body
	else:
		root = Node3D.new()
	root.position = pos
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	root.add_child(mi)
	add_child(root)
	return root

func _bounds() -> void:
	# murs invisibles au-dessus des toits : on ne sort pas de l'arène
	for wall in [[Vector3(0, 40, -HALF - 0.5), Vector3(HALF * 2, 80, 1)], [Vector3(0, 40, HALF + 0.5), Vector3(HALF * 2, 80, 1)],
			[Vector3(-HALF - 0.5, 40, 0), Vector3(1, 80, HALF * 2)], [Vector3(HALF + 0.5, 40, 0), Vector3(1, 80, HALF * 2)]]:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new(); shape.size = wall[1]
		col.shape = shape
		body.add_child(col)
		body.position = wall[0]
		add_child(body)

func _add_pad(pos: Vector3, push: Vector3, power: float, color := Color("3fd0c9")) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2; cm.bottom_radius = 1.3; cm.height = 0.12
	mi.mesh = cm
	mi.material_override = _neon(color, 3.5)
	mi.position = pos + Vector3(0, 0.06, 0)
	add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 1.35; tm.outer_radius = 1.5
	ring.mesh = tm
	ring.material_override = _neon(Color("ffffff"), 2.0)
	ring.position = pos + Vector3(0, 0.1, 0)
	add_child(ring)
	pads.append({ "pos": pos, "push": push, "power": power, "node": mi, "ring": ring })
