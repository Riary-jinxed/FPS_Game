# Joueur : déplacements (double saut, roulade, glissade, wall run, wall jump), caméra, arme, rechargements et chargeurs lancés.
# Les entrées sont lues dans read_input() puis appliquées par simulate(intent) : la logique ne lit jamais
# le clavier directement, ce qui permettra plus tard de piloter un coéquipier depuis le réseau.
extends CharacterBody3D

const ThrownMag = preload("res://scripts/thrown_mag.gd")
const M = preload("res://scripts/data.gd").MOVE
const ROLL_DUR := 0.38
const SENS := 0.0022
const JOY_SENS := 3.2
const WALLRUN_DUR := 1.4

var game
var head: Node3D
var cam: Camera3D
var rig: Node3D
var flash: OmniLight3D

var W := {}          # arme de la partie (copie modifiable par les augments)
var ammo := 0
var guns: Array = [] # un ou deux modèles d'arme (les uzis)
var fire_cd := 0.0
var reload_t := 0.0
var reload_fx := {}
var shot_count := 0
var thrown: Array = []

var yaw := 0.0
var pitch := 0.0
var hp := 100.0
var jumps := 0
var roll_cd := 0.0
var roll_t := 0.0
var roll_sign := 1.0
var iframes := 0.0
var dodged := false
var roll_grace := 0.0
var slide_t := 0.0
var bolide := false        # glissade lancée juste après une roulade (arbre : Bolide)
var hit_count := 0         # balles qui ont touché (arbre : Dixième balle)
var recoil_t := 0.0        # propulsé par le recul du Brise-porte (arbre : Recul blessant)
var slide_cd := 0.0
var air := false
var eye := 1.6
var bob := 0.0
var wallrun_t := 0.0
var wallrun_cd := 0.0
var wall_n := Vector3.ZERO
var wall_boost := false        # le mur courant est un panneau à chevrons (fait monter)
var _side_hit: Object = null
var skill := 0.0         # jauge de compétence, 0 à 100
var look_acc := Vector2.ZERO
var sway := Vector2.ZERO   # l'arme traîne derrière le regard
var forced_intent := {}  # rempli par le test auto (et plus tard par le réseau)
var intent := { "move": Vector2.ZERO, "look": Vector2.ZERO, "jump": false, "roll": false, "slide": false, "reload": false, "skill": false, "fire": false }

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.03
	head.add_child(cam)
	rig = Node3D.new()
	cam.add_child(rig)
	flash = OmniLight3D.new()
	flash.light_energy = 0.0
	flash.omni_range = 6.0
	flash.light_color = Color(1.0, 0.67, 0.33)
	rig.add_child(flash)
	# lumière d'appoint froide, courte portée : éclaire l'arme, presque pas le décor
	var fill := OmniLight3D.new()
	fill.light_energy = 0.9
	fill.omni_range = 1.2
	fill.light_color = Color(0.75, 0.82, 1.0)
	fill.position = Vector3(0.1, 0.35, 0.15)
	rig.add_child(fill)

func eye_position() -> Vector3:
	return cam.global_position

# ---------- Préparation d'une partie ----------
func set_weapon(weapon: Dictionary) -> void:
	# changement d'arme en cours de run (arme générique achetée au shop)
	W = weapon
	ammo = W.mag
	reload_t = 0.0
	fire_cd = 0.0
	_build_guns()

func reset(weapon: Dictionary) -> void:
	W = weapon.duplicate(true)
	ammo = W.mag
	hp = 100.0
	yaw = 0.0
	pitch = 0.0
	velocity = Vector3.ZERO
	jumps = 0
	roll_cd = 0.0; roll_t = 0.0; iframes = 0.0; slide_t = 0.0; slide_cd = 0.0; roll_grace = 0.0
	wallrun_t = 0.0; wallrun_cd = 0.0; skill = 0.0
	reload_t = 0.0; fire_cd = 0.0; shot_count = 0
	for t in thrown:
		if is_instance_valid(t):
			t.queue_free()
	thrown.clear()
	global_position = Vector3(0, 0.1, 16)
	_build_guns()

func _mat(c: Color, emissive := false, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		# liseré + légère auto-émission : l'arme reste lisible dans la nuit
		m.rim_enabled = true
		m.rim = 0.6
		m.rim_tint = 0.3
		m.emission_enabled = true
		m.emission = c.lightened(0.2)
		m.emission_energy_multiplier = 0.25
	return m

func _box(parent: Node3D, size: Vector3, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_guns() -> void:
	for G in guns:
		G.g.queue_free()
	guns.clear()
	# métal sombre, grip caoutchouc, liserés lumineux à la couleur de l'arme
	var body := _mat(Color("6a7688"), false, 0.45, 0.35)
	var dark := _mat(Color("3a4250"), false, 0.35, 0.45)
	var grip := _mat(Color("262a32"), false, 0.0, 0.8)
	var trim := _mat(W.color, true)
	var hot := _mat(Color("ffffff"), true)
	var sides := [1.0, -1.0] if W.get("dual", false) else [1.0]
	for side in sides:
		var g := Node3D.new()
		rig.add_child(g)
		var mag: MeshInstance3D
		var muzzle_z := 0.0
		var extra: MeshInstance3D = null
		match W.model:
			"pistols":
				# Jumeaux : pistolets à culasse longue, liseré bleu, chargeur dans la crosse
				_box(g, Vector3(0.05, 0.065, 0.24), body, Vector3(0, 0.02, -0.04))
				_box(g, Vector3(0.052, 0.012, 0.2), trim, Vector3(0, 0.056, -0.05))
				_box(g, Vector3(0.028, 0.028, 0.06), dark, Vector3(0, 0.02, -0.18))
				_box(g, Vector3(0.008, 0.02, 0.008), hot, Vector3(0, 0.065, -0.14))
				for k in 4:
					_box(g, Vector3(0.054, 0.04, 0.008), dark, Vector3(0, 0.02, 0.02 + k * 0.02))
				var pg := _box(g, Vector3(0.045, 0.13, 0.055), grip, Vector3(0, -0.07, 0.05))
				pg.rotation.x = 0.25
				_box(g, Vector3(0.012, 0.03, 0.05), dark, Vector3(0, -0.03, -0.01))
				mag = _box(g, Vector3(0.036, 0.06, 0.04), dark, Vector3(0, -0.135, 0.07))
				_box(mag, Vector3(0.038, 0.02, 0.042), trim, Vector3(0, -0.02, 0))
				muzzle_z = -0.22
			"sawed":
				# Brise-porte : canons sciés superposés, crosse pistolet, bande orange
				extra = _box(g, Vector3(0.001, 0.001, 0.001), body, Vector3(0, 0.02, -0.06)) # pivot des canons
				for y in [0.0, 0.042]:
					_box(extra, Vector3(0.05, 0.04, 0.34), dark, Vector3(0, y, -0.17))
					_box(extra, Vector3(0.03, 0.03, 0.01), hot if y == 0.0 else dark, Vector3(0, y, -0.345))
				_box(extra, Vector3(0.056, 0.012, 0.3), trim, Vector3(0, 0.07, -0.15))
				_box(extra, Vector3(0.06, 0.03, 0.08), body, Vector3(0, -0.035, -0.12))
				_box(g, Vector3(0.08, 0.1, 0.14), body, Vector3(0, 0.02, 0.04))
				_box(g, Vector3(0.082, 0.014, 0.1), trim, Vector3(0, 0.072, 0.04))
				var sg := _box(g, Vector3(0.055, 0.14, 0.06), grip, Vector3(0, -0.07, 0.12))
				sg.rotation.x = 0.35
				_box(g, Vector3(0.012, 0.035, 0.05), dark, Vector3(0, -0.035, 0.05))
				mag = _box(g, Vector3(0.05, 0.05, 0.04), _mat(Color("c0392b"), false, 0.3, 0.6), Vector3(0, 0.04, -0.03)) # cartouches
				muzzle_z = -0.42
			"revolver":
				# Verdict : revolver lourd, barillet cannelé, canon long avec rail
				_box(g, Vector3(0.06, 0.08, 0.16), body, Vector3(0, 0.01, 0.0))
				_box(g, Vector3(0.036, 0.04, 0.3), dark, Vector3(0, 0.03, -0.22))
				_box(g, Vector3(0.02, 0.016, 0.3), trim, Vector3(0, 0.058, -0.22))
				_box(g, Vector3(0.01, 0.02, 0.01), hot, Vector3(0, 0.074, -0.36))
				extra = _box(g, Vector3(0.08, 0.08, 0.09), dark, Vector3(0, 0.015, -0.05)) # barillet
				for k in 3:
					var fl := _box(extra, Vector3(0.084, 0.012, 0.06), trim, Vector3(0, -0.03 + k * 0.03, 0))
					fl.rotation.z = k * 0.6
				_box(g, Vector3(0.02, 0.03, 0.03), dark, Vector3(0, 0.06, 0.07)) # chien
				var rg := _box(g, Vector3(0.05, 0.14, 0.065), grip, Vector3(0, -0.08, 0.08))
				rg.rotation.x = 0.3
				_box(g, Vector3(0.052, 0.04, 0.067), trim, Vector3(0, -0.115, 0.095))
				mag = _box(g, Vector3(0.06, 0.06, 0.02), _mat(Color("d9a441"), false, 0.9, 0.3), Vector3(0, 0.015, 0.0)) # balles
				muzzle_z = -0.38
			"rifle":
				_box(g, Vector3(0.08, 0.1, 0.5), body)
				_box(g, Vector3(0.05, 0.02, 0.44), dark, Vector3(0, 0.06, -0.02))
				_box(g, Vector3(0.086, 0.086, 0.26), dark, Vector3(0, -0.005, -0.33))
				for k in 3:
					_box(g, Vector3(0.09, 0.014, 0.04), trim, Vector3(0, 0.0, -0.25 - k * 0.07))
				_box(g, Vector3(0.03, 0.03, 0.22), dark, Vector3(0, 0.01, -0.56))
				_box(g, Vector3(0.05, 0.05, 0.07), body, Vector3(0, 0.01, -0.68))
				_box(g, Vector3(0.06, 0.09, 0.2), body, Vector3(0, -0.01, 0.33))
				_box(g, Vector3(0.066, 0.13, 0.04), grip, Vector3(0, -0.03, 0.44))
				var gr := _box(g, Vector3(0.045, 0.11, 0.05), grip, Vector3(0, -0.09, 0.12))
				gr.rotation.x = 0.3
				# lunette holographique
				_box(g, Vector3(0.05, 0.05, 0.15), dark, Vector3(0, 0.1, -0.02))
				_box(g, Vector3(0.04, 0.04, 0.01), trim, Vector3(0, 0.1, -0.1))
				_box(g, Vector3(0.012, 0.012, 0.01), hot, Vector3(0, 0.1, 0.056))
				_box(g, Vector3(0.082, 0.012, 0.28), trim, Vector3(0, 0.025, 0.08))
				mag = _box(g, Vector3(0.05, 0.17, 0.08), dark, Vector3(0, -0.13, -0.1))
				_box(mag, Vector3(0.052, 0.07, 0.02), trim, Vector3(0, -0.02, -0.03))
				mag.rotation.x = 0.15
				muzzle_z = -0.72
			"shotgun":
				_box(g, Vector3(0.1, 0.12, 0.36), body, Vector3(0, 0, 0.02))
				for x in [-0.022, 0.022]:
					_box(g, Vector3(0.036, 0.036, 0.52), dark, Vector3(x, 0.025, -0.4))
				_box(g, Vector3(0.02, 0.012, 0.52), trim, Vector3(0, 0.05, -0.4))
				extra = _box(g, Vector3(0.09, 0.075, 0.18), grip, Vector3(0, -0.035, -0.33)) # pompe
				for k in 3:
					_box(extra, Vector3(0.094, 0.01, 0.02), trim, Vector3(0, 0.0, -0.06 + k * 0.06))
				var st := _box(g, Vector3(0.08, 0.1, 0.24), body, Vector3(0, -0.03, 0.32))
				st.rotation.x = -0.12
				_box(g, Vector3(0.085, 0.12, 0.03), grip, Vector3(0, -0.05, 0.45))
				# cartouches de rechange sur le flanc
				for k in 4:
					_box(g, Vector3(0.02, 0.026, 0.055), _mat(Color("ffb000"), true), Vector3(0.058, 0.02, -0.06 + k * 0.045))
				_box(g, Vector3(0.105, 0.016, 0.26), trim, Vector3(0, 0.068, 0.0))
				mag = _box(g, Vector3(0.09, 0.045, 0.13), _mat(Color("8a2a1a"), false, 0.2, 0.7), Vector3(0, -0.075, 0.08)) # cartouchière
				muzzle_z = -0.68
			_:
				_box(g, Vector3(0.065, 0.1, 0.26), body)
				_box(g, Vector3(0.03, 0.02, 0.22), dark, Vector3(0, 0.06, 0))
				_box(g, Vector3(0.01, 0.03, 0.01), trim, Vector3(0, 0.08, -0.1))
				_box(g, Vector3(0.028, 0.028, 0.1), dark, Vector3(0, 0.02, -0.17))
				for k in 3:
					_box(g, Vector3(0.068, 0.012, 0.025), trim, Vector3(0, 0.0, -0.08 + k * 0.05))
				_box(g, Vector3(0.012, 0.012, 0.2), dark, Vector3(0.035 * side, -0.03, 0.17))
				_box(g, Vector3(0.067, 0.016, 0.16), trim, Vector3(0, 0.054, -0.02))
				mag = _box(g, Vector3(0.042, 0.2, 0.05), grip, Vector3(0, -0.14, 0.03))
				_box(mag, Vector3(0.044, 0.08, 0.012), trim, Vector3(0, -0.04, -0.02))
				muzzle_z = -0.23
		# flash de bouche : boule + étoile
		var fm := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05 if W.get("dual", false) else 0.075
		sm.height = sm.radius * 2.0
		fm.mesh = sm
		fm.material_override = _mat(Color("ffd28a"), true)
		fm.position = Vector3(0, 0.01, muzzle_z)
		fm.visible = false
		g.add_child(fm)
		for k in 2:
			var sp := _box(fm, Vector3(0.018, 0.018, 0.22 if not W.get("dual", false) else 0.14), fm.material_override, Vector3.ZERO)
			sp.rotation = Vector3(0, 0, k * PI / 2) + Vector3(0.4 * (k * 2 - 1), 0.4, 0)
		var bx: float = 0.2 * side if W.get("dual", false) else (0.24 if W.model == "shotgun" else 0.22)
		guns.append({ "g": g, "mag": mag, "mag_home": mag.position, "extra_home": extra.transform if extra else Transform3D(), "muzzle": Vector3(0, 0.01, muzzle_z), "fm": fm, "fm_t": 0.0,
			"kick": 0.0, "side": side, "bx": bx, "extra": extra, "ejected": false, "back": false })

func _eject_casing(G: Dictionary) -> void:
	# douille éjectée sur le côté
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 1
	p.lifetime = 0.7
	p.local_coords = false
	p.direction = Vector3(1, 1.2, 0.2)
	p.spread = 15.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -14, 0)
	p.angular_velocity_min = 400.0
	p.angular_velocity_max = 700.0
	var bm := BoxMesh.new()
	var shell: bool = W.model in ["shotgun", "sawed"]
	bm.size = Vector3(0.012, 0.012, 0.03) if not shell else Vector3(0.022, 0.022, 0.05)
	bm.material = _mat(Color("d9a441") if not shell else Color("c0392b"), false, 0.9, 0.3)
	p.mesh = bm
	game.world.add_child(p)
	p.global_transform = G.g.global_transform
	p.global_position = G.g.to_global(Vector3(0.05 * G.side, 0.04, -0.05))
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---------- Entrées ----------
func _unhandled_input(event: InputEvent) -> void:
	if game.state != "play":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_acc += event.relative * SENS

func read_input(delta: float) -> Dictionary:
	# entrées locales (clavier, souris, manette) -> intention du joueur
	var look := look_acc
	look_acc = Vector2.ZERO
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15:
		look += Vector2(stick.x, stick.y * 0.7) * JOY_SENS * delta
	return {
		"move": Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
		"look": look,
		"jump": Input.is_action_just_pressed("jump"),
		"jump_hold": Input.is_action_pressed("jump"),
		"roll": Input.is_action_just_pressed("roll"),
		"slide": Input.is_action_just_pressed("slide"),
		"reload": Input.is_action_just_pressed("reload"),
		"skill": Input.is_action_just_pressed("skill"),
		"grenade": Input.is_action_just_pressed("grenade"),
		"fire": Input.is_action_pressed("fire"),
	}

func move_input() -> Vector3:
	var v2: Vector2 = intent.move
	var v := Vector3(v2.x, 0, v2.y).rotated(Vector3.UP, yaw)
	return v.normalized() if v.length() > 1.0 else v

func jump() -> void:
	var near := Vector3.ZERO
	if wallrun_t <= 0.0 and not is_on_floor() and wallrun_cd <= 0.0:
		near = get_wall_normal() if is_on_wall() else _near_wall()
		if near != Vector3.ZERO and not _wall_ok(near):
			near = Vector3.ZERO
	if wallrun_t > 0.0 or near != Vector3.ZERO:
		# wall jump : on repousse du mur en gardant l'élan (un mur tout proche suffit, même sans le toucher)
		var n := wall_n if wallrun_t > 0.0 else _flat(near)
		var along := Vector3(velocity.x, 0, velocity.z)
		along -= n * along.dot(n)
		velocity = along * 1.05 + n * 8.5
		velocity.y = M.jump
		wallrun_t = 0.0
		wallrun_cd = 0.35
		jumps = 1
		if game.tree.has("m_a1"):
			roll_cd = 0.0
		game.sfx.play("dash")
		game.add_style("WALL JUMP", 15)
		return
	if slide_t > 0.0:
		# saut depuis une glissade : on garde l'élan
		slide_t = 0.0
		velocity.x *= 1.1
		velocity.z *= 1.1
		velocity.y = M.jump
		jumps = 1
		return
	if is_on_floor():
		velocity.y = M.jump
		jumps = 1
	elif jumps < game.up.jumps:
		velocity.y = M.air_jump * (1.2 if game.tree.has("m_a3") else 1.0)
		jumps = maxi(jumps, 1) + 1

func roll() -> void:
	if roll_cd > 0.0 or roll_t > 0.0:
		return
	var f := move_input()
	if f.length() < 0.1:
		f = Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
	var s: float = intent.move.x
	roll_sign = signf(s) if absf(s) > 0.2 else 1.0
	f = f.normalized()
	velocity.x = f.x * 22.0
	velocity.z = f.z * 22.0
	roll_t = ROLL_DUR
	iframes = ROLL_DUR + 0.05
	dodged = false
	slide_t = 0.0
	wallrun_t = 0.0
	roll_cd = game.up.roll_cd
	game.sfx.play("dash")

func slide() -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or slide_t > 0.0 or slide_cd > 0.0 or roll_t > 0.0 or hs < 5.0:
		return
	var k := maxf(hs * 1.2, 16.0 * game.up.slide_boost) / hs
	velocity.x *= k
	velocity.z *= k
	slide_t = 0.8 * (1.4 if game.tree.has("m_g3") else 1.0)
	slide_cd = 0.5
	bolide = roll_grace > 0.0
	game.sfx.play("slide")

func start_reload() -> void:
	if reload_t > 0.0 or ammo == W.mag:
		return
	reload_t = W.reload
	reload_fx = {}
	for G in guns:
		G.ejected = false
		G.back = false
	game.sfx.play("reload")

# ---------- Boucle ----------
func _physics_process(delta: float) -> void:
	if game.state != "play":
		return
	intent = forced_intent.duplicate() if not forced_intent.is_empty() else read_input(delta)
	simulate(intent, delta)

func simulate(it: Dictionary, delta: float) -> void:
	roll_cd = maxf(0.0, roll_cd - delta)
	slide_cd = maxf(0.0, slide_cd - delta)
	wallrun_cd = maxf(0.0, wallrun_cd - delta)
	iframes = maxf(0.0, iframes - delta)
	roll_grace = maxf(0.0, roll_grace - delta)
	recoil_t = maxf(0.0, recoil_t - delta)
	if game.up.regen > 0.0 and hp < game.up.max_hp:
		hp = minf(game.up.max_hp, hp + game.up.regen * delta)
	sway = sway.lerp(Vector2(clampf(it.look.x * 6.0, -0.08, 0.08), clampf(it.look.y * 6.0, -0.06, 0.06)), minf(1.0, 14.0 * delta))
	yaw -= it.look.x
	pitch = clampf(pitch - it.look.y, -1.5, 1.5)

	if it.jump: jump()
	if it.roll: roll()
	if it.slide: slide()
	if it.reload: start_reload()
	if it.skill: game.activate_skill()
	if it.get("grenade", false): game.throw_grenade()

	# arme
	fire_cd -= delta
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			reload_t = 0.0
			ammo = W.mag
			for G in guns:
				G.mag.visible = true
				G.mag.position = G.mag_home
				if G.extra:
					G.extra.transform = G.extra_home
	if it.fire and fire_cd <= 0.0 and reload_t <= 0.0:
		shoot()

	# mouvement
	var wish := move_input()
	if roll_t > 0.0:
		roll_t -= delta
		if roll_t <= 0.0:
			roll_grace = 0.6
	elif slide_t > 0.0:
		slide_t -= delta
		var k := maxf(0.0, 1.0 - (0.75 if game.tree.has("m_g3") else 1.1) * delta)
		velocity.x *= k
		velocity.z *= k
		if Vector2(velocity.x, velocity.z).length() < 5.0 or not is_on_floor():
			slide_t = 0.0
	elif wallrun_t > 0.0:
		_wallrun_step(delta)
	else:
		var spd: float = M.speed * game.up.speed * (1.15 if game.skill_t > 0.0 else 1.0)
		if is_on_floor():
			_ground_move(wish, spd, delta)
		else:
			_air_move(wish, spd, delta)
	if wallrun_t <= 0.0:
		velocity.y -= M.gravity * delta
		if game.tree.has("m_a2") and it.get("jump_hold", false) and velocity.y < 0.0 and not is_on_floor():
			# Planeur : chute lente tant qu'on garde le saut enfoncé
			velocity.y = maxf(velocity.y + M.gravity * 0.7 * delta, -3.5)
	move_and_slide()
	_check_wallrun(it)
	if is_on_floor():
		jumps = 0
	air = (not is_on_floor() and _height() > 0.5) or wallrun_t > 0.0
	rotation.y = yaw
	if global_position.y < -4.0:
		game.player_fell()
	_update_camera(delta, wish)

# ---------- Élan ----------
func _ground_move(wish: Vector3, spd: float, delta: float) -> void:
	# accélération franche, freinage doux, et la vitesse en trop (glissade, jump pad, saut) s'use lentement
	var hv := Vector3(velocity.x, 0, velocity.z)
	var cur := hv.length()
	if wish.length() > 0.1:
		var keep := spd if cur <= spd else move_toward(cur, spd, 7.0 * delta)
		hv = hv.lerp(wish * keep, minf(1.0, M.accel * delta * 0.65))
		if cur > spd:
			hv = hv.normalized() * maxf(hv.length(), keep * 0.98)
	else:
		hv = hv.lerp(Vector3.ZERO, minf(1.0, M.friction * delta))
	velocity.x = hv.x
	velocity.z = hv.z

func _air_move(wish: Vector3, spd: float, delta: float) -> void:
	# en l'air on garde son élan et on peut le diriger, sans gagner de vitesse gratuite
	var hv := Vector3(velocity.x, 0, velocity.z)
	var cap := maxf(hv.length(), spd)
	hv += wish * spd * M.air_accel * delta
	if hv.length() > cap:
		hv = hv.normalized() * cap
	hv *= 1.0 - M.air_drag * delta
	velocity.x = hv.x
	velocity.z = hv.z

# ---------- Wall run ----------
static func _flat(n: Vector3) -> Vector3:
	n.y = 0.0
	return n.normalized()

func _wall_ok(n: Vector3) -> bool:
	return absf(n.y) < 0.3

func _wall_collider() -> Object:
	if is_on_wall():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if absf(c.get_normal().y) < 0.3:
				return c.get_collider()
	return _side_hit

func _check_wallrun(it: Dictionary) -> void:
	if wallrun_t > 0.0:
		var wn := get_wall_normal() if is_on_wall() else _side_wall()
		if is_on_floor():
			_end_wallrun()
		elif wn == Vector3.ZERO:
			# trou entre deux panneaux : on peut se raccrocher tout de suite au suivant
			_end_wallrun(0.0)
		else:
			wall_n = _flat(wn)
			var c := _wall_collider()
			wall_boost = c != null and c.has_meta("boost")
		return
	if is_on_floor() or wallrun_cd > 0.0 or roll_t > 0.0 or it.move.y > -0.3:
		return
	var n := get_wall_normal() if is_on_wall() else _side_wall()
	if n == Vector3.ZERO or not _wall_ok(n) or _height() < 0.8:
		return
	n = _flat(n)
	var along := Vector3(velocity.x, 0, velocity.z)
	along -= n * along.dot(n)
	if along.length() < 4.0:
		return
	wall_n = n
	var wc := _wall_collider()
	wall_boost = wc != null and wc.has_meta("boost")
	wallrun_t = WALLRUN_DUR * game.up.wallrun
	velocity.y = maxf(velocity.y, 2.0)
	jumps = 1
	game.sfx.play("wall")

func _side_wall() -> Vector3:
	# un mur juste à gauche ou à droite compte aussi : pas besoin de foncer dedans pour s'y accrocher
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, yaw)
	_side_hit = null
	for side in [right, -right]:
		var q := PhysicsRayQueryParameters3D.create(from, from + side * 0.9, 1, [get_rid()])
		var r := space.intersect_ray(q)
		if r:
			_side_hit = r.collider
			return r.normal
	return Vector3.ZERO

func _near_wall() -> Vector3:
	# mur à moins d'un mètre dans n'importe quelle direction : permet d'enchaîner les wall jumps dans un puits
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	for k in 8:
		var d := Vector3(0, 0, -1).rotated(Vector3.UP, yaw + k * PI / 4.0)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 1.0, 1, [get_rid()])
		var r := space.intersect_ray(q)
		if r:
			return r.normal
	return Vector3.ZERO

func _wallrun_step(delta: float) -> void:
	wallrun_t -= delta
	var along := Vector3(velocity.x, 0, velocity.z)
	along -= wall_n * along.dot(wall_n)
	if along.length() < 2.0:
		_end_wallrun()
		return
	along = along.normalized() * maxf(along.length(), M.speed * game.up.speed)
	velocity.x = along.x - wall_n.x * 3.0
	velocity.z = along.z - wall_n.z * 3.0
	if wall_boost:
		# panneau à chevrons : il fait monter pendant la course
		velocity.y = move_toward(velocity.y, 2.6, 14.0 * delta)
	else:
		velocity.y = maxf(velocity.y - 5.0 * delta, -1.2)
	if wallrun_t <= 0.0:
		_end_wallrun()

func _end_wallrun(cd := 0.2) -> void:
	wallrun_t = 0.0
	wallrun_cd = cd

func launch(v: Vector3) -> void:
	# jump pad
	velocity = Vector3(velocity.x * 0.5 + v.x, v.y, velocity.z * 0.5 + v.z)
	jumps = 1
	slide_t = 0.0
	wallrun_t = 0.0

func _height() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 50.0, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return global_position.y - r.position.y if r else 50.0

func _update_camera(delta: float, wish: Vector3) -> void:
	# la roulade fait un tour complet, la glissade baisse la vue
	var target_eye := 1.6
	var cam_roll := 0.0
	if roll_t > 0.0:
		var p := 1.0 - roll_t / ROLL_DUR
		target_eye = 1.6 - 0.8 * sin(PI * p)
		cam_roll = -roll_sign * TAU * _ease(p)
	elif slide_t > 0.0:
		target_eye = 0.8
		cam_roll = 0.07
	elif wallrun_t > 0.0:
		var right := Vector3(1, 0, 0).rotated(Vector3.UP, yaw)
		cam_roll = -0.16 * signf(wall_n.dot(right))
	eye += (target_eye - eye) * minf(1.0, delta * (40.0 if roll_t > 0.0 else 14.0))
	var moving := is_on_floor() and wish.length() > 0.1 and slide_t <= 0.0
	if moving:
		bob += delta * 12.0
	game.shake = maxf(0.0, game.shake - delta * 2.5)
	head.position.y = eye + (sin(bob) * 0.04 if moving else 0.0)
	head.rotation.x = pitch
	cam.rotation.z = lerp_angle(cam.rotation.z, cam_roll, 1.0 if roll_t > 0.0 else minf(1.0, delta * 10.0))
	cam.h_offset = randf_range(-0.1, 0.1) * game.shake
	cam.v_offset = randf_range(-0.1, 0.1) * game.shake
	var fov_t := 90.0 if roll_t > 0.0 else (88.0 if slide_t > 0.0 or wallrun_t > 0.0 else 80.0)
	if game.skill_t > 0.0:
		fov_t += 6.0
	cam.fov += (fov_t - cam.fov) * minf(1.0, delta * 10.0)
	var p: float = 1.0 - reload_t / W.reload if reload_t > 0.0 else -1.0
	for G in guns:
		G.kick = maxf(0.0, G.kick - delta * 8.0)
		if G.fm_t > 0.0:
			G.fm_t -= delta
			if G.fm_t <= 0.0:
				G.fm.visible = false
		var ra := _animate_reload(G, p) if p >= 0.0 else { "y": 0.0, "rx": 0.0, "rz": 0.0 }
		var strafe: float = intent.move.x
		G.g.position = Vector3(G.bx + cos(bob * 0.5) * 0.01 - sway.x * 0.5, -0.2 + absf(sin(bob * 0.5)) * 0.012 - G.kick * 0.02 + ra.y + sway.y * 0.5, -0.45 + G.kick * 0.06)
		G.g.rotation = Vector3(G.kick * 0.15 + ra.rx + sway.y, sway.x * 1.5, ra.rz - strafe * 0.05)
	flash.light_energy = maxf(0.0, flash.light_energy - delta * 40.0)

static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# ---------- Rechargements spectaculaires ----------
func _animate_reload(G: Dictionary, p: float) -> Dictionary:
	var tilt := _ease(p / 0.12) * (1.0 - _ease((p - 0.85) / 0.15))
	var o := { "y": -0.04 * tilt, "rx": 0.25 * tilt, "rz": 0.45 * tilt * G.side }
	match W.model:
		"sawed":
			# Brise-porte : on casse l'arme, les douilles sautent, on la referme d'un coup sec
			var open := _ease((p - 0.05) / 0.2) * (1.0 - _ease((p - 0.75) / 0.1))
			o.rx += 0.35 * open
			if G.extra:
				G.extra.transform = G.extra_home
				G.extra.rotation.x = -0.75 * open
			if p > 0.25 and not G.ejected:
				_eject(G)
			_mag_back(G, p, 0.45, 0.7, o)
			if p > 0.8 and not reload_fx.has("snap"):
				reload_fx.snap = true
				game.sfx.play("pump")
		"revolver":
			# Verdict : le barillet bascule et tourne, le chargeur rapide tombe, un coup de poignet referme
			var tilt2 := _ease((p - 0.05) / 0.2) * (1.0 - _ease((p - 0.8) / 0.12))
			o.rz += 0.8 * tilt2 * G.side
			if G.extra:
				G.extra.transform = G.extra_home
				G.extra.position.x = 0.05 * tilt2
				G.extra.rotation.z = TAU * 2.0 * _ease((p - 0.15) / 0.65)
			if p > 0.25 and not G.ejected:
				_eject(G)
			_mag_back(G, p, 0.5, 0.75, o)
		"rifle":
			# le fusil fait un tour complet et expulse le chargeur en haut du mouvement
			o.rx += -TAU * _ease((p - 0.12) / 0.4)
			if p > 0.3 and not G.ejected:
				_eject(G)
			_mag_back(G, p, 0.58, 0.8, o)
		"shotgun":
			# spin-cock : grand tour vers l'avant, la cartouchière part, puis on arme la pompe
			var s := _ease((p - 0.08) / 0.45)
			o.rx += TAU * s
			o.y += 0.06 * sin(PI * s)
			if p > 0.25 and not G.ejected:
				_eject(G)
			_mag_back(G, p, 0.55, 0.75, o)
			if G.extra:
				G.extra.transform = G.extra_home
				G.extra.position.z += 0.09 * sin(PI * _ease((p - 0.8) / 0.14))
			if p > 0.8 and not reload_fx.has("pump"):
				reload_fx.pump = true
				game.sfx.play("pump")
		_:
			# uzis : double salto, les deux chargeurs partent sur les côtés
			var s := _ease((p - 0.06) / 0.44)
			o.rx += -2.0 * TAU * s
			o.y += 0.08 * sin(PI * s)
			o.rz *= 1.4
			if p > 0.22 and not G.ejected:
				_eject(G)
			_mag_back(G, p, 0.55, 0.78, o)
	return o

func _mag_back(G: Dictionary, p: float, a: float, b: float, o: Dictionary) -> void:
	if p < a:
		return
	G.mag.visible = true
	var pos: Vector3 = G.mag_home
	pos.y -= 0.3 * (1.0 - _ease((p - a) / (b - a)))
	G.mag.position = pos
	if p >= b and not G.back:
		G.back = true
		game.sfx.play("click")
		o.y += 0.03

func _eject(G: Dictionary) -> void:
	G.ejected = true
	G.mag.visible = false
	var t := ThrownMag.new()
	t.game = game
	var mi := MeshInstance3D.new()
	mi.mesh = G.mag.mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2b3440")
	m.emission_enabled = true
	m.emission = Color("ffc23d")
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	t.mat = m
	t.add_child(mi)
	game.world.add_child(t)
	t.global_transform = G.mag.global_transform
	t.scale = Vector3.ONE * 1.6
	var fwd := Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, yaw)
	t.vel = fwd * 5.0 + right * G.side * (1.6 if W.get("dual", false) else 0.6) + Vector3(0, 6.5, 0) + Vector3(velocity.x, 0, velocity.z) * 0.6
	t.spin = Vector3(8.0 + randf() * 6.0, 3.0, 5.0)
	thrown.append(t)
	game.sfx.play("spin")

func flying_mags() -> Array:
	thrown = thrown.filter(func(t): return is_instance_valid(t) and t.state != "dead" and t.state != "gone")
	return thrown.filter(func(t): return t.state == "fly")

# ---------- Tir ----------
func shoot() -> void:
	if ammo <= 0:
		start_reload()
		return
	var surge: bool = game.skill_t > 0.0
	if not surge:
		ammo -= 1
	fire_cd = W.rate / (1.25 if surge else 1.0) / (1.3 if wallrun_t > 0.0 and game.tree.has("w_j3") else 1.0)
	shot_count += 1
	var G: Dictionary = guns[shot_count % guns.size()]
	G.kick = 1.0
	G.fm.rotation.z = randf() * TAU
	_eject_casing(G)
	G.fm.visible = true
	G.fm_t = 0.04
	flash.position = G.g.position + G.muzzle
	flash.light_energy = 3.0
	game.shake = maxf(game.shake, W.kick * 4.0)
	pitch = minf(1.5, pitch + W.kick)
	game.sfx.play(W.sound)
	var origin := cam.global_position
	var basis := cam.global_transform.basis
	var muzzle: Vector3 = G.g.to_global(G.muzzle)
	var last_shot: bool = game.up.last_shots > 0 and ammo < game.up.last_shots
	var dmg_mul: float = (2.0 if last_shot else 1.0) * game.dmg_bonus()
	var ram: bool = slide_t > 0.0 and game.tree.has("w_b4")
	if ram:
		dmg_mul *= 1.5
	var spread: float = W.spread
	if air and W.has("air_precise"):
		spread *= W.air_precise
	if air and game.tree.has("w_j1"):
		spread = 0.0
		dmg_mul *= 1.2
	if W.has("recoil"):
		# Brise-porte : le tir propulse à l'opposé de la visée (vise le sol pour décoller)
		var push: Vector3 = basis.z * W.recoil * game.up.get("recoil_mult", 1.0)
		if is_on_floor() and push.y < 3.0:
			push *= 0.35
		velocity += push
		if push.y > 0.0:
			velocity.y = maxf(velocity.y, push.y)
		recoil_t = 0.45
	if surge:
		dmg_mul *= 1.5
	if game.up.air_dmg > 0 and air:
		dmg_mul *= 1.0 + 0.5 * game.up.air_dmg
	# pompe + recul propulsif : tirer en l'air te projette en arrière
	if game.up.recoil_jump > 0 and not is_on_floor():
		velocity += basis.z * 9.0 * game.up.recoil_jump
		velocity.y = maxf(velocity.y, 5.0)
	var space := get_world_3d().direct_space_state
	var hit_any := false
	var mags := flying_mags()
	for i in W.pellets:
		var dir := (basis * Vector3(randf_range(-spread, spread), randf_range(-spread, spread), -1.0)).normalized()
		var end := origin + dir * 60.0
		var exclude: Array[RID] = [get_rid()]
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 120.0, 1 | 2, exclude)
		var r := space.intersect_ray(q)
		var first_d: float = origin.distance_to(r.position) if r else 120.0
		# chargeur en vol sur la trajectoire ?
		var mag_hit = null
		for t in mags:
			if t.state != "fly":
				continue
			var to: Vector3 = t.global_position - origin
			var along := to.dot(dir)
			if along > 0.0 and along < first_d and to.length_squared() - along * along < 0.36:
				mag_hit = t
				break
		if mag_hit:
			end = mag_hit.global_position
			game.launch_mag(mag_hit, origin, dir)
			hit_any = true
		else:
			var struck := 0
			while r and struck <= game.up.pierce:
				var en = r.collider
				if not (en is CharacterBody3D and en.get("alive") != null):
					end = r.position
					game.burst(end, Color("6a7784"), 3, 3.0)
					break
				struck += 1
				end = r.position
				var head_hit: bool = r.position.y > en.global_position.y + en.T.h * 0.8
				var dmg: float = W.dmg * dmg_mul * (game.up.crit if head_hit else 1.0)
				var ctx := { "src": "gun", "head": head_hit, "from": origin }
				if head_hit and game.tree.has("w_v1"):
					ammo = mini(W.mag, ammo + 1)
				if head_hit and W.has("execute") and not en.is_boss:
					# Verdict : un tir à la tête achève un ennemi affaibli
					var seuil: float = 0.4 if game.tree.has("w_v3") else W.execute
					if en.hp - dmg <= en.max_hp * seuil and en.reform_t <= 0.0:
						dmg = en.hp + 1.0
						ctx.exec = true
						if game.tree.has("w_v2"):
							ammo = mini(W.mag, ammo + 1)
						game.add_style("EXÉCUTION", 30, true)
				game.damage_enemy(en, dmg, r.position, ctx)
				if ram:
					game.knockback(en, dir, 4.0)
				hit_count += 1
				if game.up.ricochet > 0 and randf() < 0.3 * game.up.ricochet:
					game.ricochet(en, r.position, dmg * 0.6)
				elif game.tree.has("w_j2") and hit_count % 10 == 0:
					game.ricochet(en, r.position, dmg)
				if air and game.tree.has("w_j4"):
					game.ricochet(en, r.position, dmg * 0.7)
				hit_any = true
				exclude.append(en.get_rid())
				q = PhysicsRayQueryParameters3D.create(origin, origin + dir * 120.0, 1 | 2, exclude)
				r = space.intersect_ray(q)
		if i < 3:
			game.tracer(muzzle, end, Color("ff5a36") if last_shot else Color("ffd28a"))
	if hit_any:
		game.hud.hitmark()
		game.sfx.play("hit")
	if ammo == 0:
		start_reload()
