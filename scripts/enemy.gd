# Ennemis et boss. Le corps est une boîte de collision (calque 2), le visuel est construit en code.
# Chaque type a son comportement (T.ai) : walk, ranged, drone, kamikaze, sniper, hacker, furnace, arm. Les boss ont un pattern.
# Le temps des ennemis est multiplié par game.enemy_slow (ralenti pendant la Surcharge).
extends CharacterBody3D

var game
var T := {}
var type_name := ""
var hp := 1.0
var max_hp := 1.0
var speed := 1.0
var atk_cd := 0.0
var shoot_cd := 1.0
var flash_t := 0.0
var spawn_t := 0.4
var is_boss := false
var is_mini := false
var B := {}
var phase2 := false
var ability_cd := 4.0
var ability_n := 0
var alive := true
var hop_seed := 0.0
var facing := 0.0
var orbit := 0.0
var cast_t := 0.0
var laser_t := 0.0
var lock_t := 0.0
var laser_aim := Vector3.ZERO
var sweep := {}
var visual: Node3D
var body_mats: Array[StandardMaterial3D] = []
var glow: StandardMaterial3D
var edge: StandardMaterial3D   # contour lumineux de la silhouette, couleur du type
var ring: MeshInstance3D
var laser: MeshInstance3D
var laser_mat: StandardMaterial3D
var legs: Array[Node3D] = []
var boom: Node3D               # bras mécanique : flèche qui tourne
var arm_angle := 0.0
var reformed := false          # golem : déjà reformé une fois
var reform_t := 0.0
# états infligés par les persos, les grenades et les mods
var stun_t := 0.0              # étourdi : ne bouge plus, n'attaque plus
var slow_t := 0.0              # ralenti
var slow_k := 0.5
var bleed_t := 0.0             # saignement / brûlure : dégâts par seconde
var bleed_dps := 0.0
var mark_t := 0.0              # marqué (Iris)
var jam_t := 0.0               # tirs désactivés (brouillage)
var hack_t := 0.0              # piraté : se bat pour le joueur (Iris)
var tag_t := 0.0               # harponné (Nyx)

func setup(g, tname: String, t: Dictionary, mult: float, boss_def := {}) -> void:
	game = g
	type_name = tname
	T = t
	hp = t.hp * mult
	max_hp = hp
	speed = t.speed
	shoot_cd = 1.0 + randf() * 2.0
	ability_cd = 3.0 + randf() * 3.0
	hop_seed = randf() * 10.0
	orbit = randf() * TAU
	if not boss_def.is_empty():
		is_boss = true
		is_mini = boss_def.get("mini", false)
		B = boss_def
		spawn_t = 1.0
		shoot_cd = 2.0
		ability_cd = 4.0

func _ready() -> void:
	collision_layer = 2
	if T.get("fly", false):
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		collision_mask = 1
	else:
		collision_mask = 1 | 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(T.r * 1.6, T.h, T.r * 1.6)
	col.shape = shape
	col.position.y = T.h * 0.5
	add_child(col)
	visual = Node3D.new()
	add_child(visual)
	glow = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = T.color
	glow.emission_enabled = true
	glow.emission = T.color
	glow.emission_energy_multiplier = 3.0
	edge = StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.cull_mode = BaseMaterial3D.CULL_FRONT
	edge.albedo_color = T.color.lightened(0.15)
	_build_visual()
	if is_boss:
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = T.r * 1.5 - 0.1
		tm.outer_radius = T.r * 1.5 + 0.1
		ring.mesh = tm
		ring.material_override = glow
		ring.position.y = 0.2
		visual.add_child(ring)
	if T.ai == "sniper":
		laser = MeshInstance3D.new()
		var lb := BoxMesh.new(); lb.size = Vector3(0.035, 0.035, 1.0)
		laser.mesh = lb
		laser_mat = StandardMaterial3D.new()
		laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		laser_mat.albedo_color = Color(1.0, 0.18, 0.4, 0.7)
		laser.material_override = laser_mat
		laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		laser.top_level = true
		laser.visible = false
		add_child(laser)
	visual.scale = Vector3.ONE * 0.05

# ---------- Visuels ----------
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	m.metallic = 0.5
	m.emission_enabled = true
	m.emission = T.color
	m.emission_energy_multiplier = 0.3
	body_mats.append(m)
	return m

func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	(parent if parent else visual).add_child(mi)
	if m in body_mats:
		# coque retournée un peu plus grande : un liseré de 3 cm tout autour de la pièce
		var o := MeshInstance3D.new()
		o.mesh = bm
		o.material_override = edge
		o.scale = (size + Vector3.ONE * 0.06) / size
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(o)
	return mi

func _build_visual() -> void:
	var r: float = T.r
	var h: float = T.h
	var dark := _mat(T.color.darkened(0.6))
	var mid := _mat(T.color.darkened(0.35))
	var kind: String = T.ai
	if is_boss:
		kind = { "titan": "titan", "glitch": "hacker", "foreman": "furnace", "forge": "forge" }[B.pattern]
	match kind:
		"drone":
			_box(Vector3(r * 1.8, h * 0.45, r * 1.8), Vector3(0, h * 0.5, 0), dark)
			_box(Vector3(r * 0.9, h * 0.2, 0.05), Vector3(0, h * 0.5, -r * 0.92), glow)
			for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var rot := MeshInstance3D.new()
				var cm := CylinderMesh.new(); cm.top_radius = r * 0.45; cm.bottom_radius = r * 0.45; cm.height = 0.03
				rot.mesh = cm
				rot.material_override = glow
				rot.position = Vector3(s.x * r * 0.95, h * 0.8, s.y * r * 0.95)
				visual.add_child(rot)
		"kamikaze":
			_box(Vector3(r * 2.2, h * 1.2, 0.12), Vector3(0, h * 0.5, 0), glow)
			_box(Vector3(r * 2.4, h * 1.35, 0.08), Vector3(0, h * 0.5, 0.06), dark)
			_box(Vector3(0.06, 0.3, 0.06), Vector3(0, h * 1.2, 0), mid)
		"sniper":
			_box(Vector3(r * 1.2, h * 0.65, r * 0.9), Vector3(0, h * 0.42, 0), dark)
			_box(Vector3(r * 0.9, h * 0.25, r * 0.9), Vector3(0, h * 0.88, 0), mid)
			_box(Vector3(r * 0.7, 0.06, 0.03), Vector3(0, h * 0.9, -r * 0.47), glow)
			_box(Vector3(0.08, 0.08, 1.5), Vector3(r * 0.5, h * 0.7, -0.6), mid)
			_box(Vector3(0.1, 0.1, 0.12), Vector3(r * 0.5, h * 0.75, -0.3), glow)
		"hacker":
			_box(Vector3(r * 1.3, h * 0.6, r * 0.9), Vector3(0, h * 0.45, 0), dark)
			_box(Vector3(r * 1.1, h * 0.3, r * 1.1), Vector3(0, h * 0.88, 0), mid)
			_box(Vector3(r * 0.9, h * 0.06, 0.03), Vector3(0, h * 0.9, -r * 0.57), glow)
			_box(Vector3(0.04, h * 0.3, 0.04), Vector3(r * 0.3, h * 1.15, 0), mid)
			_box(Vector3(0.12, 0.12, 0.12), Vector3(r * 0.3, h * 1.3, 0), glow)
			var halo := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = r * 1.1; tm.outer_radius = r * 1.18
			halo.mesh = tm
			halo.material_override = glow
			halo.position.y = h * 0.6
			halo.name = "halo"
			visual.add_child(halo)
			_add_legs(r, h, mid)
		"titan":
			_box(Vector3(r * 1.7, h * 0.42, r * 1.1), Vector3(0, h * 0.62, 0), dark)
			_box(Vector3(r * 2.4, h * 0.14, r * 1.2), Vector3(0, h * 0.8, 0), mid)
			_box(Vector3(r * 0.9, h * 0.16, r * 0.9), Vector3(0, h * 0.94, 0), mid)
			_box(Vector3(r * 0.8, h * 0.035, 0.05), Vector3(0, h * 0.95, -r * 0.47), glow)
			_box(Vector3(r * 1.72, h * 0.03, r * 1.12), Vector3(0, h * 0.5, 0), glow)
			for s in [-1.0, 1.0]:
				_box(Vector3(r * 0.5, h * 0.45, r * 0.5), Vector3(s * r * 1.35, h * 0.55, 0), dark)
				_box(Vector3(r * 0.52, h * 0.03, r * 0.52), Vector3(s * r * 1.35, h * 0.4, 0), glow)
			_add_legs(r, h, dark)
		"furnace":
			# ouvrier-fournaise : torse trapu, ventre de fournaise lumineux, cheminée dans le dos, louche
			_box(Vector3(r * 1.7, h * 0.46, r * 1.2), Vector3(0, h * 0.6, 0), dark)
			_box(Vector3(r * 0.9, h * 0.2, 0.06), Vector3(0, h * 0.55, -r * 0.62), glow)
			_box(Vector3(r * 1.0, h * 0.2, r * 1.0), Vector3(0, h * 0.93, 0), mid)
			_box(Vector3(r * 0.85, h * 0.06, 0.04), Vector3(0, h * 0.94, -r * 0.52), glow)
			_box(Vector3(r * 0.4, h * 0.45, r * 0.4), Vector3(r * 0.35, h * 0.95, r * 0.6), mid)
			_box(Vector3(r * 0.42, h * 0.05, r * 0.42), Vector3(r * 0.35, h * 1.18, r * 0.6), glow)
			for s in [-1.0, 1.0]:
				_box(Vector3(r * 0.45, h * 0.4, r * 0.45), Vector3(s * r * 1.1, h * 0.55, 0), mid)
			_box(Vector3(0.06, 0.06, r * 1.2), Vector3(r * 1.1, h * 0.36, -r * 0.5), mid)
			_box(Vector3(r * 0.5, r * 0.3, r * 0.5), Vector3(r * 1.1, h * 0.34, -r * 1.1), glow)
			_add_legs(r, h, mid)
		"arm":
			# bras mécanique : socle fixe, tourelle, longue flèche qui balaie à hauteur de jambes
			_box(Vector3(r * 2.2, h * 0.3, r * 2.2), Vector3(0, h * 0.15, 0), dark)
			_box(Vector3(r * 1.3, h * 0.5, r * 1.3), Vector3(0, h * 0.55, 0), mid)
			_box(Vector3(r * 1.35, 0.06, r * 1.35), Vector3(0, h * 0.3, 0), glow)
			boom = Node3D.new()
			boom.position.y = h * 0.55
			visual.add_child(boom)
			var reach: float = T.get("reach", 6.5)
			_box(Vector3(0.4, 0.4, reach), Vector3(0, 0, -reach / 2.0), mid, boom)
			_box(Vector3(0.08, 0.1, reach - 0.6), Vector3(0, 0.22, -reach / 2.0), glow, boom)
			_box(Vector3(0.7, 0.6, 0.5), Vector3(0, 0, -reach), dark, boom)
			_box(Vector3(0.5, 0.2, 0.08), Vector3(0, 0, -reach - 0.27), glow, boom)
		"forge":
			# Haut-Fourneau : fournaise sur pattes, gueule lumineuse, deux cheminées, bras-louches
			_box(Vector3(r * 1.8, h * 0.5, r * 1.5), Vector3(0, h * 0.6, 0), dark)
			_box(Vector3(r * 1.0, h * 0.2, 0.08), Vector3(0, h * 0.58, -r * 0.76), glow)
			for k in 4:
				_box(Vector3(0.12, h * 0.2, 0.1), Vector3(-r * 0.36 + k * r * 0.24, h * 0.58, -r * 0.8), dark)
			_box(Vector3(r * 2.1, h * 0.08, r * 1.7), Vector3(0, h * 0.86, 0), mid)
			for s in [-1.0, 1.0]:
				_box(Vector3(r * 0.4, h * 0.35, r * 0.4), Vector3(s * r * 0.55, h * 1.05, r * 0.3), mid)
				_box(Vector3(r * 0.42, h * 0.03, r * 0.42), Vector3(s * r * 0.55, h * 1.23, r * 0.3), glow)
				_box(Vector3(r * 0.45, h * 0.4, r * 0.45), Vector3(s * r * 1.2, h * 0.58, 0), mid)
				_box(Vector3(r * 0.6, r * 0.35, r * 0.6), Vector3(s * r * 1.2, h * 0.32, -r * 0.2), glow)
			_add_legs(r, h, dark)
		_:
			# humanoïdes : silhouette propre à chaque type pour les reconnaître de loin
			var torso_y := h * 0.6
			match type_name:
				"golem":
					# blocs de scories empilés de travers, fissures lumineuses
					var rng := RandomNumberGenerator.new()
					rng.seed = int(hop_seed * 1000.0)
					for k in 7:
						var sz := Vector3(rng.randf_range(0.7, 1.1) * r, rng.randf_range(0.25, 0.4) * h, rng.randf_range(0.7, 1.1) * r)
						var b := _box(sz, Vector3(rng.randf_range(-0.2, 0.2) * r, h * (0.35 + k * 0.09), rng.randf_range(-0.2, 0.2) * r), dark if k % 2 == 0 else mid)
						b.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))
					_box(Vector3(r * 1.5, 0.05, r * 1.3), Vector3(0, h * 0.62, 0), glow)
					_box(Vector3(r * 0.6, h * 0.05, 0.04), Vector3(0, h * 0.95, -r * 0.62), glow)
					for s in [-1.0, 1.0]:
						_box(Vector3(r * 0.55, h * 0.45, r * 0.55), Vector3(s * r * 1.15, h * 0.5, 0), dark)
						_box(Vector3(r * 0.56, 0.05, r * 0.56), Vector3(s * r * 1.15, h * 0.4, 0), glow)
				"runner":
					# petit, penché en avant, crête sur la tête
					var body := _box(Vector3(r * 1.2, h * 0.36, r * 1.2), Vector3(0, h * 0.6, 0.05), dark)
					body.rotation.x = -0.5
					_box(Vector3(r * 0.8, h * 0.24, r * 1.2), Vector3(0, h * 0.82, -r * 0.6), mid)
					_box(Vector3(r * 0.7, h * 0.05, 0.03), Vector3(0, h * 0.84, -r * 1.22), glow)
					_box(Vector3(0.06, h * 0.25, r * 0.9), Vector3(0, h * 1.0, -r * 0.3), glow)
					for s in [-1.0, 1.0]:
						var arm := _box(Vector3(r * 0.22, h * 0.4, r * 0.22), Vector3(s * r * 0.75, h * 0.5, -r * 0.3), mid)
						arm.rotation.x = -0.6
				"brute":
					# épaules énormes, tête rentrée, poing lumineux
					_box(Vector3(r * 1.6, h * 0.45, r * 1.2), Vector3(0, h * 0.58, 0), dark)
					_box(Vector3(r * 2.3, h * 0.16, r * 1.3), Vector3(0, h * 0.8, 0), mid)
					_box(Vector3(r * 0.7, h * 0.16, r * 0.7), Vector3(0, h * 0.9, -r * 0.25), mid)
					_box(Vector3(r * 0.55, h * 0.04, 0.03), Vector3(0, h * 0.91, -r * 0.6), glow)
					_box(Vector3(r * 0.5, h * 0.12, 0.05), Vector3(0, h * 0.62, -r * 0.62), glow)
					for s in [-1.0, 1.0]:
						_box(Vector3(r * 0.5, h * 0.42, r * 0.5), Vector3(s * r * 1.3, h * 0.5, 0), mid)
						_box(Vector3(r * 0.6, r * 0.6, r * 0.6), Vector3(s * r * 1.3, h * 0.27, -r * 0.1), glow)
				"spitter":
					# réservoir lumineux dans le dos et buse sur la tête
					_box(Vector3(r * 1.3, h * 0.42, r * 0.9), Vector3(0, torso_y, 0), dark)
					_box(Vector3(r * 1.0, h * 0.4, r * 0.7), Vector3(0, h * 0.62, r * 0.75), glow)
					_box(Vector3(r * 0.9, h * 0.22, r * 0.9), Vector3(0, h * 0.9, 0), mid)
					_box(Vector3(r * 0.35, r * 0.35, r * 0.9), Vector3(0, h * 0.9, -r * 0.8), mid)
					_box(Vector3(r * 0.25, r * 0.25, 0.05), Vector3(0, h * 0.9, -r * 1.27), glow)
					for s in [-1.0, 1.0]:
						_box(Vector3(r * 0.3, h * 0.34, r * 0.3), Vector3(s * r * 0.85, h * 0.58, 0), mid)
				_:
					# grunt et bouclier : soldat de base, lames sur les bras pour le grunt
					_box(Vector3(r * 1.5, h * 0.42, r * 1.0), Vector3(0, torso_y, 0), dark)
					_box(Vector3(r * 0.5, h * 0.12, 0.05), Vector3(0, torso_y + h * 0.03, -r * 0.52), glow)
					_box(Vector3(r * 1.0, h * 0.24, r * 1.0), Vector3(0, h * 0.92, 0), mid)
					_box(Vector3(r * 0.8, h * 0.05, 0.03), Vector3(0, h * 0.94, -r * 0.52), glow)
					for s in [-1.0, 1.0]:
						_box(Vector3(r * 0.35, h * 0.36, r * 0.35), Vector3(s * r * 0.95, h * 0.58, 0), mid)
						if type_name == "grunt":
							_box(Vector3(0.04, 0.06, r * 1.4), Vector3(s * r * 0.95, h * 0.42, -r * 0.6), glow)
			_add_legs(r, h, mid)
			if T.get("shield", false):
				var sm := StandardMaterial3D.new()
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sm.albedo_color = Color(T.color.r, T.color.g, T.color.b, 0.3)
				sm.cull_mode = BaseMaterial3D.CULL_DISABLED
				_box(Vector3(r * 2.4, h * 0.85, 0.06), Vector3(0, h * 0.5, -r * 1.25), sm)
				for y in [h * 0.93, h * 0.08]:
					_box(Vector3(r * 2.45, 0.05, 0.08), Vector3(0, y, -r * 1.25), glow)
				for x in [-r * 1.2, r * 1.2]:
					_box(Vector3(0.05, h * 0.85, 0.08), Vector3(x, h * 0.5, -r * 1.25), glow)

func _add_legs(r: float, h: float, m: Material) -> void:
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(s * r * 0.4, h * 0.4, 0)
		visual.add_child(leg)
		_box(Vector3(r * 0.42, h * 0.4, r * 0.42), Vector3(0, -h * 0.2, 0), m, leg)
		legs.append(leg)

func center() -> Vector3:
	return global_position + Vector3(0, T.h * 0.5, 0)

func blocks(from: Vector3) -> bool:
	# bouclier frontal : bloque les tirs qui arrivent de face et pas d'au-dessus
	if not T.get("shield", false):
		return false
	var to := from - global_position
	if to.y > T.h + 1.6:
		return false
	to.y = 0.0
	var fwd := Vector3(-sin(facing), 0, -cos(facing))
	return fwd.dot(to.normalized()) > 0.45

# ---------- Boucle ----------
func _physics_process(delta: float) -> void:
	if not alive or game.state != "play":
		return
	var d: float = delta * game.enemy_slow
	if spawn_t > 0.0:
		spawn_t -= d
		visual.scale = Vector3.ONE * clampf(1.0 - maxf(spawn_t, 0.0) * (1.0 if is_boss else 2.0), 0.05, 1.0)
		return
	if reform_t > 0.0:
		# golem brisé : il se reforme sur place, intouchable
		reform_t -= d
		var k := clampf(1.0 - reform_t / 1.8, 0.0, 1.0)
		visual.scale = Vector3(0.85, 0.2 + 0.65 * k, 0.85)
		velocity = Vector3(0, -0.5, 0)
		move_and_slide()
		return
	visual.scale = Vector3.ONE * (0.85 if reformed else 1.0)
	_tick_status(delta)
	if not alive:
		return
	if stun_t > 0.0:
		# étourdi : il tangue sur place
		visual.rotation.z = sin(game.gt * 18.0) * 0.12
		velocity.x = 0.0; velocity.z = 0.0
		if not T.get("fly", false):
			velocity.y = -0.5 if is_on_floor() else velocity.y - 24.0 * delta
		move_and_slide()
		return
	visual.rotation.z = 0.0
	if slow_t > 0.0:
		d *= slow_k
	if hack_t > 0.0 and game.kit.has_method("hacked_ai"):
		game.kit.hacked_ai(self, d)
		if not T.get("fly", false):
			velocity.y = -0.5 if is_on_floor() else velocity.y - 24.0 * delta
		move_and_slide()
		return
	var p = game.player
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var want := atan2(-dir.x, -dir.z)
	if T.get("shield", false):
		facing = rotate_toward(facing, want, 2.0 * d)
	elif T.ai != "arm":
		facing = want
	visual.rotation.y = facing
	if is_boss:
		_boss_ai(dist, dir, d)
	else:
		match T.ai:
			"drone": _drone(d)
			"kamikaze": _kamikaze(d)
			"sniper": _sniper(d)
			"hacker": _hacker(dist, dir, d)
			"furnace": _furnace(dist, dir, d)
			"arm": _arm(d)
			_: _walk(dist, dir, d)
	if not T.get("fly", false):
		velocity.y = -0.5 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	if is_boss and global_position.y < 0.05:
		# les boss planent au-dessus de la fosse
		global_position.y = 0.05
		velocity.y = 0.0
	elif global_position.y < -3.0:
		game.kill_enemy(self, { "src": "fall" })
		return
	_animate(d)
	if game.state != "play" or not alive:
		return
	if flash_t > 0.0:
		flash_t -= delta
	var e := 2.0 if flash_t > 0.0 else 0.3
	for m in body_mats:
		m.emission_energy_multiplier = e

func _tick_status(delta: float) -> void:
	stun_t = maxf(0.0, stun_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	mark_t = maxf(0.0, mark_t - delta)
	jam_t = maxf(0.0, jam_t - delta)
	tag_t = maxf(0.0, tag_t - delta)
	if hack_t > 0.0:
		hack_t -= delta
		if hack_t <= 0.0 and game.kit.has_method("hack_end"):
			game.kit.hack_end(self)
	if bleed_t > 0.0:
		bleed_t -= delta
		game.damage_enemy(self, bleed_dps * delta, center(), { "src": "dot", "quiet": true })

func stun(t: float) -> void:
	if is_boss:
		t *= 0.3
	stun_t = maxf(stun_t, t)

func slow(t: float, k := 0.5) -> void:
	slow_t = maxf(slow_t, t)
	slow_k = k

func bleed(dps: float, t: float) -> void:
	bleed_dps = maxf(bleed_dps if bleed_t > 0.0 else 0.0, dps)
	bleed_t = maxf(bleed_t, t)

func _animate(d: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	var t: float = game.gt * 10.0 * maxf(speed, 3.0) / 6.0 + hop_seed
	for i in legs.size():
		legs[i].rotation.x = sin(t + i * PI) * 0.6 if moving else 0.0
	if T.get("fly", false):
		visual.position.y = sin(game.gt * 3.0 + hop_seed) * 0.12
	var halo := visual.get_node_or_null("halo")
	if halo:
		halo.rotation.y += d * 3.0
		halo.scale = Vector3.ONE * (1.0 + cast_t * 1.4)

func start_reform() -> void:
	reformed = true
	hp = max_hp * 0.6
	reform_t = 1.8
	edge.albedo_color = T.color.darkened(0.25)
	glow.emission_energy_multiplier = 1.6

func _move(dir: Vector3, spd: float) -> void:
	velocity.x = dir.x * spd * game.enemy_slow
	velocity.z = dir.z * spd * game.enemy_slow

func _contact(dist: float, d: float) -> void:
	atk_cd -= d
	var p = game.player
	if dist < T.r + 0.8 and absf(p.global_position.y - global_position.y) < T.h and atk_cd <= 0.0:
		game.hurt_player(T.dmg)
		atk_cd = 0.8

func _shoot_at_player(from: Vector3, spd: float, dmg: float, col: Color, size := 0.2) -> void:
	var p = game.player
	if jam_t > 0.0 or game.kit.hidden_from(from.distance_to(p.global_position)):
		return
	game.fire_shot(from, (p.eye_position() - from).normalized(), spd, dmg, col, size)
	game.sfx.play("orb")

func _walk(dist: float, dir: Vector3, d: float) -> void:
	var spd := speed
	if T.ai == "ranged" and dist < 16.0:
		spd = -speed * 0.6 if dist < 10.0 else 0.0
	if dist > T.r + 0.6 or spd < 0.0:
		_move(dir, spd)
	else:
		_move(dir, 0.0)
	_contact(dist, d)
	if T.ai == "ranged":
		shoot_cd -= d
		if shoot_cd <= 0.0 and dist < 30.0:
			_shoot_at_player(global_position + Vector3(0, T.h * 0.9, 0), 16.0, T.dmg, T.color)
			shoot_cd = 2.0 + randf() * 1.5

func _furnace(dist: float, dir: Vector3, d: float) -> void:
	# fonce au corps à corps et sème des flaques de métal en fusion derrière lui
	_walk(dist, dir, d)
	ability_cd -= d
	if ability_cd <= 0.0 and dist < 26.0:
		game.add_puddle(global_position, 1.5, 6.0, 16.0)
		ability_cd = 2.2 + randf() * 1.2

func _arm(d: float) -> void:
	# balaie en cercle autour du socle, à hauteur de jambes : on saute par-dessus ou on roule
	_move(Vector3.ZERO, 0.0)
	arm_angle = wrapf(arm_angle + d * 1.5, -PI, PI)
	boom.rotation.y = arm_angle
	atk_cd -= d
	var p = game.player
	var rel: Vector3 = p.global_position - global_position
	var hd := Vector2(rel.x, rel.z).length()
	var reach: float = T.get("reach", 6.5)
	if atk_cd > 0.0 or hd > reach + 0.4 or hd < 0.4 or rel.y > 1.2:
		return
	var ang := atan2(-rel.x, -rel.z)
	if absf(angle_difference(arm_angle, ang)) < atan(0.7 / hd) + 0.04:
		if game.hurt_player(T.dmg):
			game.burst(p.global_position + Vector3(0, 0.5, 0), T.color, 8, 6.0)
		atk_cd = 0.7

func _drone(d: float) -> void:
	# tourne autour du joueur en hauteur et tire
	var p = game.player
	orbit += d * 0.6
	var target: Vector3 = p.global_position + Vector3(cos(orbit) * 11.0, 4.5 + sin(hop_seed + game.gt) * 1.0, sin(orbit) * 11.0)
	target.y = maxf(target.y, 3.0)
	var v := (target - global_position)
	var want := v.normalized() * minf(v.length() * 2.0, speed)
	velocity = velocity.lerp(want * game.enemy_slow, minf(1.0, 3.0 * d))
	shoot_cd -= d
	if shoot_cd <= 0.0:
		_shoot_at_player(center(), 18.0, T.dmg, T.color, 0.16)
		shoot_cd = 2.2 + randf()

func _kamikaze(d: float) -> void:
	# fonce sur le joueur et explose au contact
	var p = game.player
	var target: Vector3 = p.global_position + Vector3(0, 1.2, 0)
	var v: Vector3 = target - center()
	velocity = velocity.lerp(v.normalized() * speed * game.enemy_slow, minf(1.0, 4.0 * d))
	if v.length() < 1.3:
		game.kamikaze_blast(self)

func _sniper(d: float) -> void:
	_move(Vector3.ZERO, 0.0)
	var p = game.player
	var eye: Vector3 = global_position + Vector3(0, T.h * 0.75, 0)
	var target: Vector3 = p.eye_position() - Vector3(0, 0.2, 0)
	shoot_cd -= d
	if laser_t <= 0.0 and lock_t <= 0.0:
		laser.visible = false
		if shoot_cd <= 0.0 and not game.ray_world(eye, target):
			laser_t = 1.7
			laser_aim = target
			game.sfx.play("charge")
		return
	if laser_t > 0.0:
		# le laser suit le joueur avec un léger retard
		laser_t -= d
		laser_aim = laser_aim.lerp(target, minf(1.0, 5.0 * d))
		laser_mat.albedo_color = Color(1.0, 0.18, 0.4, 0.35 + 0.4 * (1.0 - laser_t / 1.7))
		if laser_t <= 0.0:
			lock_t = 0.35
			laser_mat.albedo_color = Color(1, 1, 1, 0.95)
	else:
		lock_t -= d
		if lock_t <= 0.0:
			_sniper_fire(eye)
	_draw_laser(eye, laser_aim)

func _sniper_fire(eye: Vector3) -> void:
	var p = game.player
	if jam_t > 0.0:
		return
	var dirv := (laser_aim - eye).normalized()
	var far := eye + dirv * 90.0
	var pe: Vector3 = p.eye_position() - Vector3(0, 0.5, 0)
	var along := (pe - eye).dot(dirv)
	var miss := (eye + dirv * along).distance_to(pe)
	game.tracer(eye, far, T.color)
	game.sfx.play("rifle")
	if along > 0.0 and miss < 0.9 and not game.ray_world(eye, pe):
		game.hurt_player(T.dmg)
	laser.visible = false
	shoot_cd = 2.4 + randf()

func _draw_laser(a: Vector3, b: Vector3) -> void:
	var dirv := (b - a)
	var len := dirv.length()
	dirv = dirv.normalized()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, a + dirv * 90.0, 1)
	var r := space.intersect_ray(q)
	var end: Vector3 = r.position if r else a + dirv * 90.0
	len = a.distance_to(end)
	laser.visible = true
	laser.global_position = (a + end) / 2.0
	laser.look_at(end, Vector3.UP if absf(dirv.y) < 0.99 else Vector3.RIGHT)
	laser.scale = Vector3(1, 1, len)

func _hacker(dist: float, dir: Vector3, d: float) -> void:
	# garde ses distances, brouille le HUD puis se téléporte
	var spd := speed
	if dist < 14.0:
		spd = -speed
	elif dist < 20.0:
		spd = 0.0
	_move(dir, spd)
	_contact(dist, d)
	if cast_t > 0.0:
		cast_t -= d
		_move(dir, 0.0)
		if cast_t <= 0.0:
			cast_t = 0.0
			game.hacker_glitch(2.6)
			_teleport()
		return
	ability_cd -= d
	shoot_cd -= d
	var p = game.player
	if ability_cd <= 0.0 and dist < 32.0 and not game.ray_world(center(), p.eye_position()):
		cast_t = 0.9
		ability_cd = 6.0 + randf() * 3.0
		game.sfx.play("charge")
	elif shoot_cd <= 0.0 and dist < 28.0:
		_shoot_at_player(center() + Vector3(0, 0.4, 0), 18.0, T.dmg, T.color, 0.15)
		shoot_cd = 2.5 + randf()

func _teleport() -> void:
	game.burst(center(), T.color, 14, 6.0)
	global_position = game.spawn_pos(14.0, false, T.r, T.h)
	game.burst(center(), T.color, 14, 6.0)
	game.sfx.play("dash")

# ---------- Boss ----------
func _boss_ai(dist: float, dir: Vector3, d: float) -> void:
	ring.rotation.y += d * 2.0
	if not phase2 and hp < max_hp / 2.0:
		phase2 = true
		speed *= 1.3
		game.boss_phase2(self)
	match B.pattern:
		"glitch": _brouilleur(dist, dir, d)
		"foreman": _foreman(dist, dir, d)
		"forge": _forge(dist, dir, d)
		_: _titan(dist, dir, d)

func _fan(n: int, spread: float, spd: float, dmg: float, size: float) -> void:
	var p = game.player
	var from := global_position + Vector3(0, T.h * 0.85, 0)
	var aim: Vector3 = (p.eye_position() - from).normalized()
	for k in n:
		game.fire_shot(from, aim.rotated(Vector3.UP, (k - (n - 1) / 2.0) * spread), spd, dmg, T.color, size)
	game.sfx.play("orb")

func _brouilleur(dist: float, dir: Vector3, d: float) -> void:
	# mini-boss : un hacker géant qui se téléporte, brouille le HUD et lâche des drones pub
	_move(dir, speed if dist > 16.0 else (-speed * 0.5 if dist < 9.0 else 0.0))
	_contact(dist, d)
	shoot_cd -= d
	ability_cd -= d
	if cast_t > 0.0:
		cast_t -= d
		if cast_t <= 0.0:
			cast_t = 0.0
			game.hacker_glitch(2.0)
			_teleport()
			_fan(7 if phase2 else 5, 0.14, 20.0, 10.0, 0.3)
		return
	if shoot_cd <= 0.0:
		_fan(5 if phase2 else 3, 0.1, 22.0, 10.0, 0.3)
		shoot_cd = 1.0 if phase2 else 1.6
	if ability_cd <= 0.0:
		ability_n += 1
		if ability_n % 2 == 0:
			for k in (7 if phase2 else 5):
				game.to_spawn.append("pub")
			game.spawn_timer = 0.0
			game.hud.banner("Drones pub", "")
		else:
			cast_t = 0.8
			game.sfx.play("charge")
		ability_cd = 3.5 if phase2 else 5.0

func _titan(dist: float, dir: Vector3, d: float) -> void:
	# boss de zone : onde de choc, balayage laser, renforts. Sa phase 2 effondre la dalle centrale.
	_move(dir, speed if dist > T.r + 2.0 else 0.0)
	_contact(dist, d)
	shoot_cd -= d
	ability_cd -= d
	if not sweep.is_empty():
		sweep.t += d
		sweep.next -= d
		if sweep.next <= 0.0:
			var a: float = sweep.a0 + sweep.dir * sweep.t * 2.2
			var from := global_position + Vector3(0, T.h * 0.6, 0)
			for k in 3:
				game.fire_shot(from, Vector3(sin(a), -0.02 + k * 0.05, cos(a)).normalized(), 26.0, 12.0, T.color, 0.3)
			sweep.next = 0.05
		if sweep.t > 1.4:
			sweep = {}
		return
	if shoot_cd <= 0.0:
		_fan(5 if phase2 else 3, 0.12, 20.0, 12.0, 0.35)
		shoot_cd = 1.1 if phase2 else 1.7
	if ability_cd <= 0.0:
		ability_n += 1
		match ability_n % 3:
			0:
				for k in (6 if phase2 else 4):
					game.to_spawn.append("drone" if phase2 and k % 2 == 0 else "runner")
				game.spawn_timer = 0.0
			1:
				for k in 28:
					var a := k / 28.0 * TAU
					game.fire_shot(Vector3(global_position.x, 0.5, global_position.z), Vector3(cos(a), 0, sin(a)), 13.0, 18.0, T.color, 0.4)
				var hop: Vector3 = (game.player.global_position - global_position) * 0.35
				hop.y = 0.0
				if game.is_free(global_position + hop, T.r, T.h):
					global_position += hop
				game.shake = 0.8
				game.sfx.play("boss")
			_:
				var to_p: Vector3 = game.player.global_position - global_position
				var base := atan2(to_p.x, to_p.z)
				var side := 1.0 if randf() < 0.5 else -1.0
				sweep = { "t": 0.0, "next": 0.0, "dir": side, "a0": base - side * 1.5 }
				game.sfx.play("charge")
		ability_cd = 3.5 if phase2 else 5.5

func _lob(n: int, radius: float, dmg: float) -> void:
	# globes de métal lancés en cloche : un cercle d'alerte, puis une flaque
	var p = game.player
	for k in n:
		var off := Vector3.ZERO
		if k > 0:
			var a := randf() * TAU
			off = Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 7.0)
		var at: Vector3 = p.global_position + off
		at.y = 0.0
		game.add_puddle(at, radius, 6.0, dmg, 1.1)
	game.sfx.play("orb")

func _foreman(dist: float, dir: Vector3, d: float) -> void:
	# mini-boss : un ouvrier-fournaise géant. Pluie de métal, renforts, onde de coulée.
	_move(dir, speed if dist > 12.0 else 0.0)
	_contact(dist, d)
	shoot_cd -= d
	ability_cd -= d
	if shoot_cd <= 0.0:
		_fan(5 if phase2 else 3, 0.12, 20.0, 11.0, 0.32)
		shoot_cd = 1.0 if phase2 else 1.6
	if ability_cd <= 0.0:
		ability_n += 1
		match ability_n % 3:
			1: _lob(8 if phase2 else 5, 2.2, 20.0)
			2:
				for k in (5 if phase2 else 3):
					game.to_spawn.append("furnace")
				game.spawn_timer = 0.0
				game.hud.banner("Renforts", "Ouvriers-fournaise")
			_:
				game.add_ring(global_position, 9.0, 24.0, 16.0)
		ability_cd = 3.5 if phase2 else 5.0

func _forge(dist: float, dir: Vector3, d: float) -> void:
	# boss de zone : ondes de coulée à sauter, pluie de métal, golems. Sa phase 2 inonde la halle.
	_move(dir, speed if dist > 16.0 else 0.0)
	_contact(dist, d)
	shoot_cd -= d
	ability_cd -= d
	if shoot_cd <= 0.0:
		_fan(7 if phase2 else 5, 0.1, 21.0, 12.0, 0.35)
		shoot_cd = 1.1 if phase2 else 1.8
	if ability_cd <= 0.0:
		ability_n += 1
		match ability_n % 3:
			1:
				game.add_ring(global_position, 10.0, 34.0, 18.0)
				if phase2:
					game.add_ring(global_position, 10.0, 34.0, 18.0, 0.7)
				game.shake = 0.6
				game.sfx.play("boss")
			2: _lob(9 if phase2 else 6, 2.4, 22.0)
			_:
				for k in (4 if phase2 else 3):
					game.to_spawn.append("golem" if k % 2 == 0 else "furnace")
				game.spawn_timer = 0.0
		ability_cd = 3.6 if phase2 else 5.2
