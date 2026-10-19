# Arène de la zone 1 : place de la ville néon. Murs de buildings pour le wall run, tours de snipers,
# plateformes, jump pads, et une dalle centrale qui s'effondre pendant la phase 2 du boss.
# Palette du décor volontairement froide (cyan, bleu, violet) : les couleurs chaudes sont réservées
# aux ennemis et à leurs tirs, pour qu'ils ressortent du décor.
extends "res://scripts/arena.gd"

const TILE := 4.0
const PIT_Y := -10.0

var rise_walls: Array = []    # murs qui sortent du sol en phase 2
var rain: CPUParticles3D

var _win_tex: ImageTexture

func _ready() -> void:
	phase2_text = "La dalle s'effondre"
	_rng.seed = 7
	_win_tex = _window_texture()
	_build_floor()
	_build_perimeter()
	_build_skyline()
	_build_interior()
	_build_lamps()
	_build_rain()

# ---------- Textures procédurales ----------
func _window_texture() -> ImageTexture:
	var img := Image.create(128, 512, false, Image.FORMAT_RGB8)
	img.fill(Color("080a12"))
	var palette := [Color("c9d6ff"), Color("8fb0ff"), Color("9fd8ff"), Color("b9a6ff"), Color("6bfff0")]
	for row in 16:
		for col in 8:
			if _rng.randf() < 0.38:
				var c: Color = palette[_rng.randi() % palette.size()] * _rng.randf_range(0.35, 1.0)
				img.fill_rect(Rect2i(col * 16 + 3, row * 32 + 8, 10, 14), c)
			else:
				img.fill_rect(Rect2i(col * 16 + 3, row * 32 + 8, 10, 14), Color("10141f"))
	return ImageTexture.create_from_image(img)

func _ad_texture(a: Color, b: Color) -> ImageTexture:
	var img := Image.create(128, 64, false, Image.FORMAT_RGB8)
	for x in 128:
		var c := a.lerp(b, x / 127.0)
		for y in 64:
			var k := 1.0 if (y / 4) % 2 == 0 else 0.82
			img.set_pixel(x, y, c * k)
	return ImageTexture.create_from_image(img)

func _grate_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color("161a24"))
	for i in 64:
		for w in 2:
			img.set_pixel(i, w, Color("8a5cff"))
			img.set_pixel(w, i, Color("8a5cff"))
	for i in range(8, 64, 8):
		for j in 64:
			img.set_pixel(i, j, Color("0e1118"))
	return ImageTexture.create_from_image(img)

# ---------- Matériaux ----------
func _building_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2a3040")
	m.albedo_texture = _win_tex
	m.emission_enabled = true
	m.emission_texture = _win_tex
	m.emission_energy_multiplier = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * (1.0 / 12.8)
	m.roughness = 0.6
	m.metallic = 0.3
	return m

# ---------- Briques ----------
func _sign(pos: Vector3, rot_y: float, size: Vector2, text: String, color: Color, flicker := true) -> void:
	# panneau néon : cadre lumineux + texte
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	add_child(holder)
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(size.x, size.y, 0.15)
	back.mesh = bm
	back.material_override = _concrete(Color("0b0d14"))
	holder.add_child(back)
	var frame_m := _neon(color, 4.0, flicker)
	for e in [[Vector3(0, size.y / 2, 0.1), Vector3(size.x, 0.12, 0.08)], [Vector3(0, -size.y / 2, 0.1), Vector3(size.x, 0.12, 0.08)],
			[Vector3(size.x / 2, 0, 0.1), Vector3(0.12, size.y, 0.08)], [Vector3(-size.x / 2, 0, 0.1), Vector3(0.12, size.y, 0.08)]]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new(); b.size = e[1]
		mi.mesh = b
		mi.material_override = frame_m
		mi.position = e[0]
		holder.add_child(mi)
	var l := Label3D.new()
	l.text = text
	l.font_size = 160
	l.pixel_size = size.y / 260.0
	l.modulate = Color(color.r * 3.0, color.g * 3.0, color.b * 3.0)
	l.outline_modulate = Color(color.r, color.g, color.b, 0.6)
	l.outline_size = 24
	l.shaded = false
	l.double_sided = false
	l.position = Vector3(0, 0, 0.12)
	l.width = size.x / l.pixel_size
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	holder.add_child(l)

# ---------- Sol ----------
func _build_floor() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color("15181f")
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.seamless = true
	nt.width = 256; nt.height = 256
	asphalt.roughness_texture = nt
	asphalt.roughness = 1.0
	asphalt.metallic = 0.25
	asphalt.uv1_scale = Vector3(6, 6, 1)
	var w := HALF * 2.0
	var side := HALF - PLAZA
	for f in [[Vector3(0, -0.5, -(PLAZA + side / 2)), Vector3(w, 1, side)], [Vector3(0, -0.5, PLAZA + side / 2), Vector3(w, 1, side)],
			[Vector3(-(PLAZA + side / 2), -0.5, 0), Vector3(side, 1, PLAZA * 2)], [Vector3(PLAZA + side / 2, -0.5, 0), Vector3(side, 1, PLAZA * 2)]]:
		_box(f[0], f[1], asphalt)
	# marquages au sol
	var lane := _neon(Color("3fd0c9"), 1.6)
	for z in [-PLAZA - 0.4, PLAZA + 0.4]:
		_box(Vector3(0, 0.01, z), Vector3(PLAZA * 2 + 0.8, 0.02, 0.15), lane, false)
	for x in [-PLAZA - 0.4, PLAZA + 0.4]:
		_box(Vector3(x, 0.01, 0), Vector3(0.15, 0.02, PLAZA * 2 + 0.8), lane, false)
	var dash := _neon(Color("4f7cff"), 1.2)
	for i in range(-36, 37, 6):
		if absf(i) > PLAZA + 1:
			_box(Vector3(i, 0.01, 0), Vector3(3.0, 0.02, 0.2), dash, false)
			_box(Vector3(0, 0.01, i), Vector3(0.2, 0.02, 3.0), dash, false)
	_build_tiles()
	# fosse lumineuse sous la dalle
	var pit := StandardMaterial3D.new()
	pit.albedo_color = Color("8a5cff")
	pit.emission_enabled = true
	pit.emission = Color("8a5cff")
	pit.emission_energy_multiplier = 2.5
	_box(Vector3(0, PIT_Y, 0), Vector3(PLAZA * 2, 0.5, PLAZA * 2), pit, false)
	for s in [-1.0, 1.0]:
		_box(Vector3(0, PIT_Y / 2, s * PLAZA), Vector3(PLAZA * 2, -PIT_Y, 0.2), _concrete(Color("0d0f16")), false)
		_box(Vector3(s * PLAZA, PIT_Y / 2, 0), Vector3(0.2, -PIT_Y, PLAZA * 2), _concrete(Color("0d0f16")), false)

# ---------- Buildings ----------
func _build_perimeter() -> void:
	# une rangée continue de buildings : leurs façades forment les murs de l'arène (bons pour le wall run)
	var bmat := _building_mat()
	var words := ["NEO//CORP", "OPEN 24H", "SYSTÈME OK", "HORDE", "飲む", "BUY NOW", "ゲーム", "NOODLE", "ZONE 01", "CYBER BAR"]
	var colors := [Color("8a5cff"), Color("3fd0c9"), Color("4f7cff"), Color("6a4cff"), Color("4fc3ff"), Color("b98cff")]
	var k := 0
	for side in 4:
		var x := -HALF
		while x < HALF:
			var wdt := _rng.randf_range(8.0, 14.0)
			wdt = minf(wdt, HALF - x)
			var h := _rng.randf_range(14.0, 34.0)
			var depth := 12.0
			var c := x + wdt / 2.0
			var pos: Vector3
			var size: Vector3
			var face_rot := 0.0
			var face: Vector3
			match side:
				0:
					pos = Vector3(c, h / 2, -HALF - depth / 2); size = Vector3(wdt, h, depth); face_rot = 0.0; face = Vector3(c, 0, -HALF + 0.2)
				1:
					pos = Vector3(c, h / 2, HALF + depth / 2); size = Vector3(wdt, h, depth); face_rot = PI; face = Vector3(c, 0, HALF - 0.2)
				2:
					pos = Vector3(-HALF - depth / 2, h / 2, c); size = Vector3(depth, h, wdt); face_rot = PI / 2; face = Vector3(-HALF + 0.2, 0, c)
				_:
					pos = Vector3(HALF + depth / 2, h / 2, c); size = Vector3(depth, h, wdt); face_rot = -PI / 2; face = Vector3(HALF - 0.2, 0, c)
			_box(pos, size, bmat)
			# corniche lumineuse sur le toit
			var trim := _neon(colors[k % colors.size()], 2.2)
			_box(pos + Vector3(0, h / 2 + 0.1, 0), Vector3(size.x + 0.1, 0.2, size.z + 0.1), trim, false)
			# enseigne sur une façade sur deux
			if k % 2 == 0 and wdt > 9.0:
				_sign(face + Vector3(0, _rng.randf_range(6.0, minf(h - 3.0, 14.0)), 0), face_rot, Vector2(minf(wdt - 2.0, 8.0), 2.2), words[k % words.size()], colors[(k + 2) % colors.size()])
			# store de boutique au rez-de-chaussée
			_box(face + Vector3(0, 3.2, 0), (Vector3(wdt * 0.8, 0.12, 0.6) if side < 2 else Vector3(0.6, 0.12, wdt * 0.8)), _neon(colors[(k + 1) % colors.size()], 2.0, true), false)
			x += wdt
			k += 1
	_bounds()

func _build_skyline() -> void:
	# silhouettes lointaines, sans collision
	var bmat := _building_mat()
	bmat.emission_energy_multiplier = 0.9
	for i in 46:
		var a := i / 46.0 * TAU + _rng.randf() * 0.1
		var d := _rng.randf_range(70.0, 120.0)
		var w := _rng.randf_range(10.0, 22.0)
		var h := _rng.randf_range(35.0, 95.0)
		var p := Vector3(cos(a) * d, h / 2, sin(a) * d)
		_box(p, Vector3(w, h, w), bmat, false)
		if i % 3 == 0:
			_box(p + Vector3(0, h / 2 + 2.0, 0), Vector3(0.3, 4.0, 0.3), _neon(Color("8a5cff"), 5.0, true), false)

# ---------- Intérieur ----------
func _build_interior() -> void:
	var conc := _concrete()
	var colors := [Color("8a5cff"), Color("3fd0c9"), Color("4f7cff"), Color("6a4cff")]
	# tours de snipers aux quatre coins, avec un jump pad devant chacune
	var i := 0
	for c in [Vector2(-30, -30), Vector2(30, -30), Vector2(-30, 30), Vector2(30, 30)]:
		_box(Vector3(c.x, 4.5, c.y), Vector3(6, 9, 6), conc)
		_box(Vector3(c.x, 9.05, c.y), Vector3(6.1, 0.12, 6.1), _neon(colors[i], 2.5), false)
		for s in [-1.0, 1.0]:
			_box(Vector3(c.x + s * 3.05, 4.5, c.y), Vector3(0.08, 9.0, 0.3), _neon(colors[i], 2.0), false)
		perches.append(Vector3(c.x, 9.0, c.y))
		var pad_pos := Vector3(c.x * 0.78, 0.0, c.y * 0.78)
		_add_pad(pad_pos, (Vector3(c.x, 0, c.y) - pad_pos).normalized() * 6.0, 21.0)
		i += 1
	# panneaux publicitaires géants : murs de wall run
	var ads := [[Vector3(0, 0, -21), 0.0, "NEO//CORP", Color("8a5cff"), Color("3fd0c9")], [Vector3(0, 0, 21), PI, "UPGRADE YOU", Color("3fd0c9"), Color("6a4cff")],
			[Vector3(-17, 0, 0), PI / 2, "ゲーム", Color("4f7cff"), Color("8a5cff")], [Vector3(17, 0, 0), -PI / 2, "BUY NOW", Color("6a4cff"), Color("4fc3ff")]]
	for ad in ads:
		_ad_wall(ad[0], ad[1], ad[2], ad[3], ad[4])
	# plateformes surélevées avec rampe
	for s in [-1.0, 1.0]:
		_box(Vector3(s * 31, 1.75, 0), Vector3(8, 3.5, 12), conc)
		_box(Vector3(s * 27.0, 3.55, 0), Vector3(0.12, 0.1, 12), _neon(Color("3fd0c9"), 2.0), false)
		var ramp := _box(Vector3(s * 23.0, 1.75, 0), Vector3(8.9, 0.4, 6), conc)
		ramp.rotation.z = -s * atan2(3.5, 8.0)
		_add_pad(Vector3(s * 31, 3.5, 4.5), Vector3.ZERO, 16.0)
	# couverts
	for c in [Vector3(-16, 0, -30), Vector3(16, 0, 30), Vector3(-30, 0, 14), Vector3(30, 0, -14), Vector3(14, 0, -30), Vector3(-14, 0, 30)]:
		_box(c + Vector3(0, 0.7, 0), Vector3(3, 1.4, 1.5), _concrete(Color("2b3242")))
		_box(c + Vector3(0, 1.42, 0), Vector3(3.02, 0.06, 1.52), _neon(Color("4f7cff"), 1.5), false)
	# murs qui sortiront de la fosse pendant la phase 2 du boss
	for w in [[Vector3(0, 0, -7), Vector3(10, 6, 0.6)], [Vector3(0, 0, 7), Vector3(10, 6, 0.6)], [Vector3(-7, 0, 0), Vector3(0.6, 6, 10)], [Vector3(7, 0, 0), Vector3(0.6, 6, 10)]]:
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new(); shape.size = w[1]
		col.shape = shape
		body.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = w[1]
		mi.mesh = bm
		mi.material_override = _ad_material(Color("8a5cff"), Color("6a4cff"))
		body.add_child(mi)
		body.position = w[0] + Vector3(0, PIT_Y - 4.0, 0)
		body.set_meta("target", w[0] + Vector3(0, 3.5, 0))
		add_child(body)
		rise_walls.append(body)

func _ad_material(a: Color, b: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex := _ad_texture(a, b)
	m.albedo_texture = tex
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.3
	return m

func _ad_wall(pos: Vector3, rot_y: float, text: String, a: Color, b: Color) -> void:
	var holder := StaticBody3D.new()
	holder.position = pos + Vector3(0, 4.0, 0)
	holder.rotation.y = rot_y
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(16, 8, 0.6)
	col.shape = shape
	holder.add_child(col)
	add_child(holder)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(16, 8, 0.6)
	mi.mesh = bm
	mi.material_override = _ad_material(a, b)
	holder.add_child(mi)
	for z in [0.32, -0.32]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 200
		l.pixel_size = 0.013
		l.modulate = Color(1.5, 1.5, 1.5)
		l.outline_modulate = Color(0, 0, 0, 0.7)
		l.outline_size = 30
		l.shaded = false
		l.double_sided = false
		l.position = Vector3(0, 0.6, z)
		if z < 0.0:
			l.rotation.y = PI
		holder.add_child(l)
	# liseré lumineux
	var top := _box(pos + Vector3(0, 8.08, 0), Vector3(16.1, 0.12, 0.65), _neon(a, 3.0, true), false)
	top.rotation.y = rot_y

func _build_lamps() -> void:
	var pole := _concrete(Color("1a1f2a"))
	var spots := [Vector3(-36, 0, -16), Vector3(36, 0, 16), Vector3(-16, 0, 36), Vector3(16, 0, -36), Vector3(-36, 0, 22), Vector3(36, 0, -22), Vector3(22, 0, 36), Vector3(-22, 0, -36)]
	var colors := [Color("8a5cff"), Color("3fd0c9"), Color("4f7cff"), Color("6a4cff")]
	var i := 0
	for s in spots:
		_box(s + Vector3(0, 3.5, 0), Vector3(0.25, 7, 0.25), pole, true)
		var c: Color = colors[i % colors.size()]
		_box(s + Vector3(0, 7.1, 0), Vector3(0.9, 0.25, 0.9), _neon(c, 5.0), false)
		var o := OmniLight3D.new()
		o.light_color = c
		o.light_energy = 2.2
		o.omni_range = 16.0
		o.position = s + Vector3(0, 6.5, 0)
		add_child(o)
		i += 1
	# lumière de la fosse
	var pit_light := OmniLight3D.new()
	pit_light.light_color = Color("8a5cff")
	pit_light.light_energy = 1.5
	pit_light.omni_range = 20.0
	pit_light.position = Vector3(0, 2, 0)
	add_child(pit_light)

func _build_rain() -> void:
	rain = CPUParticles3D.new()
	rain.amount = 900
	rain.lifetime = 0.9
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(26, 1, 26)
	rain.direction = Vector3(0.08, -1, 0.03)
	rain.spread = 2.0
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 28.0
	rain.initial_velocity_max = 34.0
	rain.particle_flag_align_y = true
	var qm := QuadMesh.new()
	qm.size = Vector2(0.025, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.85, 1.0, 0.28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = m
	rain.mesh = qm
	rain.position = Vector3(0, 20, 0)
	add_child(rain)

func follow(p: Vector3) -> void:
	rain.global_position = Vector3(p.x, p.y + 20.0, p.z)

# ---------- Phase 2 du boss ----------
func collapse() -> void:
	if collapsed:
		return
	collapsed = true
	var order := tiles.duplicate()
	order.shuffle()
	var drop := order.slice(0, int(order.size() * 0.6))
	for t in drop:
		t.set_meta("drop", true)
		var m: StandardMaterial3D = t.get_meta("mat")
		var tw: Tween = t.create_tween()
		# alerte : la dalle clignote en rouge, puis tombe
		for k in 4:
			tw.tween_property(m, "emission_energy_multiplier", 4.0, 0.18)
			tw.tween_property(m, "emission_energy_multiplier", 0.6, 0.18)
		tw.tween_property(t, "position:y", PIT_Y - 6.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(t.queue_free)
	for w in rise_walls:
		var tw: Tween = w.create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(w, "position", w.get_meta("target"), 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func over_pit(p: Vector3) -> bool:
	# vrai si p est au-dessus d'une dalle tombée (ou en train de tomber)
	if not collapsed or absf(p.x) > PLAZA or absf(p.z) > PLAZA:
		return false
	for t in tiles:
		if is_instance_valid(t) and not t.has_meta("drop") and absf(t.position.x - p.x) <= TILE / 2.0 and absf(t.position.z - p.z) <= TILE / 2.0:
			return false
	return true

func reset() -> void:
	# remet la dalle en place pour une nouvelle partie
	if not collapsed:
		return
	collapsed = false
	for t in tiles:
		if is_instance_valid(t):
			t.queue_free()
	tiles.clear()
	for w in rise_walls:
		w.position = w.get_meta("target") + Vector3(0, PIT_Y - 7.5, 0)
	_build_tiles()

func _build_tiles() -> void:
	# dalle centrale en grilles
	var grate := StandardMaterial3D.new()
	grate.albedo_texture = _grate_texture()
	grate.emission_enabled = true
	grate.emission_texture = grate.albedo_texture
	grate.emission_energy_multiplier = 0.9
	grate.metallic = 0.6
	grate.roughness = 0.35
	var n := int(PLAZA * 2 / TILE)
	for i in n:
		for j in n:
			var m := grate.duplicate() as StandardMaterial3D
			var t := _box(Vector3(-PLAZA + TILE * (i + 0.5), -0.5, -PLAZA + TILE * (j + 0.5)), Vector3(TILE - 0.04, 1, TILE - 0.04), m)
			t.set_meta("mat", m)
			tiles.append(t)

