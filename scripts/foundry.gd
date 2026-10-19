# Arène de la zone 2 : la fonderie. Halle d'acier fermée, presses hydrauliques pour le wall run,
# silos et quais surélevés, îlot de coulée au centre, socles des bras mécaniques.
# Le décor reste froid (acier bleu-gris, lumières cyan et blanches) : l'orange est réservé au danger
# (métal en fusion, flaques, coulée) et aux ennemis.
# Phase 2 du boss : la coulée. Le métal en fusion inonde le sol par vagues, il faut rester en hauteur.
extends "res://scripts/arena.gd"

const MOLTEN := Color("ff7a1a")
const STEEL := Color("3a4352")
const SAFE := Color("3fd0c9")

var embers: CPUParticles3D
var flood: MeshInstance3D
var flood_mat: ShaderMaterial
var flood_state := "off"   # off, warn, rise, on, fall, rest
var flood_t := 0.0
var _plate_tex: ImageTexture
var _wall_tex: ImageTexture

func _ready() -> void:
	phase2_text = "La coulée inonde la halle"
	_rng.seed = 21
	_plate_tex = _plate_texture()
	_wall_tex = _wall_texture()
	_build_floor()
	_build_hall()
	_build_interior()
	_build_overhead()
	_build_lights()
	_build_embers()
	_build_flood()

# ---------- Textures procédurales ----------
func _plate_texture() -> ImageTexture:
	# tôles striées avec rivets
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color("2e3644"))
	for y in 128:
		for x in 128:
			if (x + y) % 8 < 2:
				img.set_pixel(x, y, Color("3a4352"))
	for i in 128:
		for w in 2:
			img.set_pixel(i, w, Color("161b22"))
			img.set_pixel(w, i, Color("161b22"))
	for c in [Vector2i(6, 6), Vector2i(121, 6), Vector2i(6, 121), Vector2i(121, 121), Vector2i(64, 6), Vector2i(6, 64)]:
		img.fill_rect(Rect2i(c.x - 1, c.y - 1, 3, 3), Color("6a7890"))
	return ImageTexture.create_from_image(img)

func _wall_texture() -> ImageTexture:
	# bardage ondulé vertical, avec une bande de fenêtres hautes froides
	var img := Image.create(64, 256, false, Image.FORMAT_RGB8)
	for x in 64:
		var k := 0.75 + 0.25 * sin(x / 64.0 * TAU * 4.0)
		for y in 256:
			img.set_pixel(x, y, Color("2b3340") * k)
	for x in range(4, 60, 14):
		img.fill_rect(Rect2i(x, 20, 10, 26), Color("6f8fb8"))
	return ImageTexture.create_from_image(img)

# ---------- Matériaux ----------
func _steel(c := STEEL, metal := 0.6, rough := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m

func _molten(energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = MOLTEN
	m.emission_enabled = true
	m.emission = MOLTEN
	m.emission_energy_multiplier = energy
	return m

func _stencil(parent: Node3D, text: String, pos: Vector3, rot_y: float, size: float, c: Color) -> void:
	for side in [0.0, PI]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 160
		l.pixel_size = size
		l.modulate = Color(c.r * 1.6, c.g * 1.6, c.b * 1.6)
		l.outline_size = 0
		l.shaded = false
		l.double_sided = false
		l.rotation.y = rot_y + side
		var off := Vector3(0, 0, 0.42).rotated(Vector3.UP, rot_y + side)
		l.position = pos + off
		parent.add_child(l)

# ---------- Sol ----------
func _build_floor() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _plate_tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.25
	m.metallic = 0.55
	m.roughness = 0.5
	_box(Vector3(0, -0.5, 0), Vector3(HALF * 2, 1, HALF * 2), m)
	# allées de sécurité cyan
	var lane := _neon(SAFE, 1.4)
	for v in [-26.0, 26.0]:
		_box(Vector3(0, 0.01, v), Vector3(HALF * 2 - 4, 0.02, 0.18), lane, false)
		_box(Vector3(v, 0.01, 0), Vector3(0.18, 0.02, HALF * 2 - 4), lane, false)
	# chevrons de danger autour de l'îlot central
	var chev := _neon(Color("4f7cff"), 1.2)
	for i in 8:
		var a := i / 8.0 * TAU
		var b := _box(Vector3(cos(a) * 8.0, 0.01, sin(a) * 8.0), Vector3(2.2, 0.02, 0.25), chev, false)
		b.rotation.y = -a

# ---------- Halle ----------
func _build_hall() -> void:
	var wm := StandardMaterial3D.new()
	wm.albedo_texture = _wall_tex
	wm.emission_enabled = true
	wm.emission_texture = _wall_tex
	wm.emission_energy_multiplier = 0.25
	wm.uv1_triplanar = true
	wm.uv1_world_triplanar = true
	wm.uv1_scale = Vector3.ONE * (1.0 / 16.0)
	wm.metallic = 0.5
	wm.roughness = 0.55
	var h := 24.0
	for w in [[Vector3(0, h / 2, -HALF - 2), Vector3(HALF * 2 + 8, h, 4)], [Vector3(0, h / 2, HALF + 2), Vector3(HALF * 2 + 8, h, 4)],
			[Vector3(-HALF - 2, h / 2, 0), Vector3(4, h, HALF * 2)], [Vector3(HALF + 2, h / 2, 0), Vector3(4, h, HALF * 2)]]:
		_box(w[0], w[1], wm)
	# toit sombre, sans collision (on reste sous les poutres)
	_box(Vector3(0, h + 0.5, 0), Vector3(HALF * 2 + 8, 1, HALF * 2 + 8), _steel(Color("0d1015"), 0.2, 0.9), false)
	# piliers plats sur les murs (ne cassent pas le wall run) et bandes cyan
	var pillar := _steel(Color("4a5568"), 0.7, 0.35)
	var band := _neon(SAFE, 1.8)
	for i in range(-36, 37, 12):
		for f in [[Vector3(i, h / 2, -HALF + 0.08), Vector3(1.2, h, 0.16)], [Vector3(i, h / 2, HALF - 0.08), Vector3(1.2, h, 0.16)],
				[Vector3(-HALF + 0.08, h / 2, i), Vector3(0.16, h, 1.2)], [Vector3(HALF - 0.08, h / 2, i), Vector3(0.16, h, 1.2)]]:
			_box(f[0], f[1], pillar, false)
	for f in [[Vector3(0, 9.0, -HALF + 0.1), Vector3(HALF * 2, 0.15, 0.1)], [Vector3(0, 9.0, HALF - 0.1), Vector3(HALF * 2, 0.15, 0.1)],
			[Vector3(-HALF + 0.1, 9.0, 0), Vector3(0.1, 0.15, HALF * 2)], [Vector3(HALF - 0.1, 9.0, 0), Vector3(0.1, 0.15, HALF * 2)]]:
		_box(f[0], f[1], band, false)
	# gueules des hauts-fourneaux sur le mur nord : la seule lueur chaude du décor, au loin
	for x in [-24.0, 0.0, 24.0]:
		_box(Vector3(x, 5.0, -HALF + 0.15), Vector3(7.0, 5.0, 0.2), _molten(2.2), false)
		_box(Vector3(x, 7.8, -HALF + 0.4), Vector3(8.4, 0.6, 0.6), pillar, false)
		for k in 5:
			_box(Vector3(x - 2.8 + k * 1.4, 5.0, -HALF + 0.35), Vector3(0.25, 5.0, 0.2), _steel(Color("14181f")), false)
		var o := OmniLight3D.new()
		o.light_color = Color("ff8a3d")
		o.light_energy = 2.0
		o.omni_range = 14.0
		o.position = Vector3(x, 4.0, -HALF + 3.0)
		add_child(o)
	# grosses conduites horizontales
	var pipe := _steel(Color("566175"), 0.8, 0.3)
	for z in [-HALF + 1.2, HALF - 1.2]:
		var p := _cyl(Vector3(0, 14.0, z), 0.7, HALF * 2, pipe, false)
		p.rotation.z = PI / 2
	for x in [-HALF + 1.2, HALF - 1.2]:
		var p := _cyl(Vector3(x, 15.5, 0), 0.55, HALF * 2, pipe, false)
		p.rotation.x = PI / 2
	_stencil(self, "FONDERIE 02", Vector3(0, 12.0, HALF - 0.6), PI, 0.02, SAFE)
	_bounds()

# ---------- Intérieur ----------
func _build_interior() -> void:
	var steel := _steel()
	var dark := _steel(Color("252c37"), 0.5, 0.6)
	# silos aux quatre coins : refuges hauts pendant la coulée, avec un jump pad devant
	var i := 0
	for c in [Vector2(-30, -30), Vector2(30, -30), Vector2(-30, 30), Vector2(30, 30)]:
		_cyl(Vector3(c.x, 3.5, c.y), 3.4, 7.0, steel)
		for y in [1.5, 4.0, 6.5]:
			_cyl(Vector3(c.x, y, c.y), 3.45, 0.18, dark, false)
		_cyl(Vector3(c.x, 7.04, c.y), 3.5, 0.1, _neon(SAFE, 2.2), false)
		perches.append(Vector3(c.x, 7.0, c.y))
		var pad_pos := Vector3(c.x * 0.8, 0.0, c.y * 0.8)
		_add_pad(pad_pos, (Vector3(c.x, 0, c.y) - pad_pos).normalized() * 5.0, 19.0)
		i += 1
	# presses hydrauliques : grands murs d'acier pour le wall run
	for pr in [[Vector3(0, 0, -21), 0.0, "LIGNE 02"], [Vector3(0, 0, 21), PI, "DANGER"], [Vector3(-17, 0, 0), PI / 2, "PRESSE A"], [Vector3(17, 0, 0), -PI / 2, "PRESSE B"]]:
		_press(pr[0], pr[1], pr[2])
	# quais de chargement surélevés avec rampe
	for s in [-1.0, 1.0]:
		_box(Vector3(s * 31, 1.75, 0), Vector3(8, 3.5, 12), steel)
		_box(Vector3(s * 27.0, 3.55, 0), Vector3(0.12, 0.1, 12), _neon(SAFE, 2.0), false)
		var ramp := _box(Vector3(s * 23.0, 1.75, 0), Vector3(8.9, 0.4, 6), dark)
		ramp.rotation.z = -s * atan2(3.5, 8.0)
		_add_pad(Vector3(s * 31, 3.5, 4.5), Vector3.ZERO, 16.0)
	# îlot de coulée central, assez bas pour y sauter
	_box(Vector3(0, 0.6, 0), Vector3(10, 1.2, 10), dark)
	for e in [[Vector3(0, 1.21, -5), Vector3(10, 0.03, 0.15)], [Vector3(0, 1.21, 5), Vector3(10, 0.03, 0.15)],
			[Vector3(-5, 1.21, 0), Vector3(0.15, 0.03, 10)], [Vector3(5, 1.21, 0), Vector3(0.15, 0.03, 10)]]:
		_box(e[0], e[1], _neon(SAFE, 2.0), false)
	# lingots empilés : couverts
	for c in [Vector3(16, 0, -30), Vector3(-16, 0, 30), Vector3(-30, 0, -14), Vector3(30, 0, 14)]:
		_box(c + Vector3(0, 0.55, 0), Vector3(3.2, 1.1, 1.6), _steel(Color("5c6678"), 0.85, 0.3))
		_box(c + Vector3(0, 1.4, 0), Vector3(2.4, 0.6, 1.2), _steel(Color("4a5466"), 0.85, 0.3))
	# socles des bras mécaniques
	for a in [Vector3(-12, 0, -30), Vector3(12, 0, 30), Vector3(-30, 0, 12), Vector3(30, 0, -12)]:
		anchors.append(a)
		_cyl(a + Vector3(0, 0.05, 0), 1.4, 0.1, _neon(Color("4f7cff"), 1.5), false)

func _press(pos: Vector3, rot_y: float, text: String) -> void:
	var holder := StaticBody3D.new()
	holder.position = pos + Vector3(0, 4.0, 0)
	holder.rotation.y = rot_y
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(16, 8, 0.8)
	col.shape = shape
	holder.add_child(col)
	add_child(holder)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(16, 8, 0.8)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _plate_tex
	m.albedo_color = Color("8090a8")
	m.uv1_scale = Vector3(4, 2, 1)
	m.metallic = 0.7
	m.roughness = 0.35
	mi.material_override = m
	holder.add_child(mi)
	# vérins au-dessus, cadre cyan, marquage au pochoir
	var pist := _steel(Color("9aa8bd"), 0.9, 0.2)
	for x in [-5.0, 5.0]:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.4; cm.bottom_radius = 0.4; cm.height = 4.0
		c.mesh = cm
		c.material_override = pist
		c.position = Vector3(x, 6.0, 0)
		holder.add_child(c)
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new(); tb.size = Vector3(16.6, 0.8, 1.4)
	top.mesh = tb
	top.material_override = _steel(Color("2b323e"))
	top.position = Vector3(0, 8.4, 0)
	holder.add_child(top)
	for y in [-3.9, 3.9]:
		var e := MeshInstance3D.new()
		var eb := BoxMesh.new(); eb.size = Vector3(16.05, 0.12, 0.85)
		e.mesh = eb
		e.material_override = _neon(SAFE, 2.2, true)
		e.position = Vector3(0, y, 0)
		holder.add_child(e)
	_stencil(holder, text, Vector3(0, 0.4, 0), 0.0, 0.009, Color("cfe3ff"))

# ---------- Pont roulant et éclairage ----------
func _build_overhead() -> void:
	var beam := _steel(Color("2f3744"), 0.6, 0.5)
	for x in [-14.0, 14.0]:
		_box(Vector3(x, 18.0, 0), Vector3(1.0, 1.2, HALF * 2), beam, false)
	_box(Vector3(0, 17.2, -6), Vector3(30, 1.0, 2.0), _steel(Color("4f7cff"), 0.4, 0.5), false)
	_box(Vector3(0, 16.0, -6), Vector3(3, 1.4, 2.6), beam, false)
	_box(Vector3(0, 12.5, -6), Vector3(0.08, 6.0, 0.08), beam, false)
	_box(Vector3(0, 9.4, -6), Vector3(1.0, 0.6, 0.3), _steel(Color("9aa8bd"), 0.9, 0.2), false)

func _build_lights() -> void:
	var lamp := _steel(Color("1a1f28"))
	var spots := [Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20), Vector3(0, 0, -30), Vector3(0, 0, 30), Vector3(-32, 0, 0), Vector3(32, 0, 0)]
	for s in spots:
		_box(s + Vector3(0, 19.0, 0), Vector3(0.06, 4.0, 0.06), lamp, false)
		_box(s + Vector3(0, 16.9, 0), Vector3(1.6, 0.25, 1.6), lamp, false)
		_box(s + Vector3(0, 16.75, 0), Vector3(1.3, 0.05, 1.3), _neon(Color("dfeeff"), 4.0), false)
		var o := OmniLight3D.new()
		o.light_color = Color("cfe3ff")
		o.light_energy = 2.4
		o.omni_range = 22.0
		o.position = s + Vector3(0, 15.5, 0)
		add_child(o)
	var core := OmniLight3D.new()
	core.light_color = SAFE
	core.light_energy = 1.2
	core.omni_range = 14.0
	core.position = Vector3(0, 3.0, 0)
	add_child(core)

func _build_embers() -> void:
	# escarbilles qui montent : de petites touches chaudes autour du joueur
	embers = CPUParticles3D.new()
	embers.amount = 90
	embers.lifetime = 3.0
	embers.local_coords = false
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(24, 0.5, 24)
	embers.direction = Vector3(0.1, 1, 0)
	embers.spread = 20.0
	embers.gravity = Vector3(0, 0.6, 0)
	embers.initial_velocity_min = 1.0
	embers.initial_velocity_max = 2.5
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("ffb36b")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = m
	embers.mesh = qm
	add_child(embers)

func follow(p: Vector3) -> void:
	embers.global_position = Vector3(p.x, 0.5, p.z)

# ---------- Phase 2 du boss : la coulée ----------
func _build_flood() -> void:
	flood = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(HALF * 2, HALF * 2)
	flood.mesh = pm
	# métal en fusion sombre avec une croûte et des veines lumineuses : chaud sans aveugler,
	# les ennemis et le HUD restent lisibles par-dessus
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float glow = 1.0;
void fragment() {
	vec2 uv = UV * 26.0;
	float t = TIME * 0.35;
	float n = sin(uv.x * 1.3 + t) * sin(uv.y * 1.1 - t * 0.7) + 0.5 * sin((uv.x + uv.y) * 2.3 + t * 1.3);
	float vein = 1.0 - smoothstep(0.0, 0.14, abs(n));
	vec3 crust = vec3(0.10, 0.025, 0.01);
	vec3 hot = vec3(1.0, 0.42, 0.06) * 1.5 * glow;
	ALBEDO = mix(crust, hot, vein);
}
"""
	flood_mat = ShaderMaterial.new()
	flood_mat.shader = sh
	flood.material_override = flood_mat
	flood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flood.position.y = -0.6
	flood.visible = false
	add_child(flood)

func collapse() -> void:
	if collapsed:
		return
	collapsed = true
	_flood_set("warn", 2.5)

func calm() -> void:
	# boss vaincu : le métal se retire
	if flood_state in ["warn", "rise", "on"]:
		_flood_set("fall", 1.2)
	collapsed = false

func reset() -> void:
	collapsed = false
	flood_state = "off"
	flood.visible = false
	flood.position.y = -0.6

func flooding() -> bool:
	return flood_state in ["on", "rise"] and flood.position.y > 0.0

func _flood_set(s: String, t: float) -> void:
	flood_state = s
	flood_t = t

func tick(delta: float) -> void:
	if flood_state == "off":
		return
	flood_t -= delta
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	match flood_state:
		"warn":
			# le sol rougeoie avant la vague : il faut monter
			flood.visible = true
			flood.position.y = -0.05
			flood_mat.set_shader_parameter("glow", 0.3 + pulse * 0.9)
			if flood_t <= 0.0:
				_flood_set("rise", 1.0)
		"rise":
			flood.position.y = lerpf(-0.05, 0.35, 1.0 - flood_t)
			flood_mat.set_shader_parameter("glow", 1.0)
			if flood_t <= 0.0:
				_flood_set("on", 5.5)
		"on":
			flood.position.y = 0.35 + sin(Time.get_ticks_msec() * 0.003) * 0.04
			if flood_t <= 0.0:
				_flood_set("fall", 1.2)
		"fall":
			flood.position.y = lerpf(-0.6, 0.35, flood_t / 1.2)
			if flood_t <= 0.0:
				flood.visible = false
				if collapsed:
					_flood_set("rest", 7.0)
				else:
					flood_state = "off"
		"rest":
			if flood_t <= 0.0:
				_flood_set("warn", 2.5)

func flood_warning() -> bool:
	return flood_state == "warn"

func hazard_at(p: Vector3, _on_floor: bool) -> float:
	# dans le métal en fusion : seules les surfaces hautes (îlot, quais, silos, rampes hautes) protègent
	if flooding() and p.y < flood.position.y + 0.25:
		return 30.0
	return 0.0
