# Horde Breaker : arène, vagues, style, augments et flux de partie.
extends Node3D

const Data = preload("res://scripts/data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ShotScript = preload("res://scripts/shot.gd")
const HudScript = preload("res://scripts/hud.gd")
const MusicScript = preload("res://scripts/music.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const ARENA := 40.0
const SAVE := "user://save.cfg"

var state := "menu" # menu, play, augment, paused, over
var player
var hud
var music
var sfx
var world: Node3D        # objets temporaires (ennemis, tirs, effets)
var menu_cam: Camera3D

var enemies: Array = []
var boss = null
var to_spawn: Array = []
var spawn_timer := 0.0
var intermission := 0.0
var wave := 0
var score := 0
var kills := 0
var aug_wave := 0
var aug_choices: Array = []
var taken := {}
var up := {}
var chosen := "rifle"
var best := 0
var pickups: Array = []

var style := 0.0
var style_idle := 0.0
var chain := 0
var chain_t := 0.0
var best_rank := 0
var recent_kills: Array = []
var gt := 0.0
var shake := 0.0
var hitstop_end := 0

# ---------- Mise en place ----------
func _ready() -> void:
	randomize()
	_setup_input()
	_build_environment()
	_build_arena()
	world = Node3D.new()
	add_child(world)
	sfx = SfxScript.new(); add_child(sfx)
	music = MusicScript.new(); add_child(music)
	menu_cam = Camera3D.new(); menu_cam.fov = 70.0
	add_child(menu_cam)
	player = PlayerScript.new()
	player.game = self
	add_child(player)
	up = Data.BASE_UP.duplicate()
	player.reset(Data.WEAPONS[chosen])
	hud = HudScript.new(); add_child(hud)
	hud.weapon_picked.connect(start_with)
	hud.augment_picked.connect(pick_augment)
	hud.resume_pressed.connect(resume)
	hud.retry_pressed.connect(func(): start_with(chosen))
	hud.menu_pressed.connect(to_menu)
	_load_save()
	to_menu()
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()

func _setup_input() -> void:
	var add := func(action: String, keys: Array, mouse: int, buttons: Array, axes: Array):
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for k in keys:
			var e := InputEventKey.new(); e.physical_keycode = k; InputMap.action_add_event(action, e)
		if mouse >= 0:
			var m := InputEventMouseButton.new(); m.button_index = mouse; InputMap.action_add_event(action, m)
		for b in buttons:
			var j := InputEventJoypadButton.new(); j.button_index = b; InputMap.action_add_event(action, j)
		for a in axes:
			var j := InputEventJoypadMotion.new(); j.axis = a[0]; j.axis_value = a[1]; InputMap.action_add_event(action, j)
	# touches physiques : W/A sur QWERTY = Z/Q sur AZERTY
	add.call("move_forward", [KEY_W, KEY_UP], -1, [], [[JOY_AXIS_LEFT_Y, -1.0]])
	add.call("move_back", [KEY_S, KEY_DOWN], -1, [], [[JOY_AXIS_LEFT_Y, 1.0]])
	add.call("move_left", [KEY_A, KEY_LEFT], -1, [], [[JOY_AXIS_LEFT_X, -1.0]])
	add.call("move_right", [KEY_D, KEY_RIGHT], -1, [], [[JOY_AXIS_LEFT_X, 1.0]])
	add.call("jump", [KEY_SPACE], -1, [JOY_BUTTON_A], [])
	add.call("roll", [KEY_SHIFT], -1, [JOY_BUTTON_LEFT_SHOULDER], [])
	add.call("slide", [KEY_C, KEY_CTRL], -1, [JOY_BUTTON_B], [])
	add.call("reload", [KEY_R], -1, [JOY_BUTTON_X], [])
	add.call("fire", [], MOUSE_BUTTON_LEFT, [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	add.call("pause", [KEY_ESCAPE, KEY_P], -1, [JOY_BUTTON_START], [])
	add.call("mute", [KEY_M], -1, [], [])
	add.call("pick_1", [KEY_1], -1, [], [])
	add.call("pick_2", [KEY_2], -1, [], [])
	add.call("pick_3", [KEY_3], -1, [], [])

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07090d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a6e80")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color("07090d")
	env.fog_density = 0.018
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe2c8")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)
	for l in [[-30, -30, Color("ff5a36")], [30, 30, Color("3fd0c9")], [-30, 30, Color("3fd0c9")], [30, -30, Color("ff5a36")]]:
		var o := OmniLight3D.new()
		o.light_color = l[2]
		o.light_energy = 2.0
		o.omni_range = 40.0
		o.position = Vector3(l[0], 6, l[1])
		add_child(o)

func _grid_texture() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color("12161c"))
	for i in range(0, 256, 32):
		for j in 256:
			for w in 2:
				img.set_pixel(clampi(i + w, 0, 255), j, Color("1f2a33"))
				img.set_pixel(j, clampi(i + w, 0, 255), Color("1f2a33"))
	return ImageTexture.create_from_image(img)

func _add_box(x: float, z: float, w: float, d: float, h: float, trim := true) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(x, h / 2.0, z)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(w, h, d)
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(w, h, d)
	mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = Color("2a3440")
	mi.material_override = m
	body.add_child(mi)
	if trim:
		var t := MeshInstance3D.new()
		var tb := BoxMesh.new(); tb.size = Vector3(w + 0.02, 0.12, d + 0.02)
		t.mesh = tb
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color("ff5a36")
		tm.emission_enabled = true; tm.emission = Color("ff5a36"); tm.emission_energy_multiplier = 1.5
		t.material_override = tm
		t.position.y = h / 2.0 - 0.3
		body.add_child(t)
	add_child(body)

func _build_arena() -> void:
	# sol
	var floor_body := StaticBody3D.new()
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new(); fs.size = Vector3(ARENA * 2, 1, ARENA * 2)
	fc.shape = fs; fc.position.y = -0.5
	floor_body.add_child(fc)
	var fm := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(ARENA * 2, ARENA * 2)
	fm.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _grid_texture()
	mat.uv1_scale = Vector3(20, 20, 1)
	fm.material_override = mat
	floor_body.add_child(fm)
	add_child(floor_body)
	# murs, piliers et couverts (même plan que le prototype web)
	_add_box(0, -ARENA, ARENA * 2, 1, 8, false)
	_add_box(0, ARENA, ARENA * 2, 1, 8, false)
	_add_box(-ARENA, 0, 1, ARENA * 2, 8, false)
	_add_box(ARENA, 0, 1, ARENA * 2, 8, false)
	for p in [[-14, -14], [14, -14], [-14, 14], [14, 14]]:
		_add_box(p[0], p[1], 3, 3, 7)
	var i := 0
	for p in [[0, -22], [0, 22], [-22, 0], [22, 0]]:
		_add_box(p[0], p[1], 8 if i < 2 else 1.5, 1.5 if i < 2 else 8, 1.6)
		i += 1
	for p in [[-26, -26], [26, 26], [-26, 26], [26, -26]]:
		_add_box(p[0], p[1], 5, 5, 2.4)
	_add_box(0, 0, 4, 4, 1.2)

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		best = cfg.get_value("game", "best", 0)
		var c: String = cfg.get_value("game", "weapon", "rifle")
		if Data.WEAPONS.has(c):
			chosen = c

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.set_value("game", "weapon", chosen)
	cfg.save(SAVE)

# ---------- Flux de partie ----------
func to_menu() -> void:
	state = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_cam.current = true
	hud.show_menu(Data.WEAPONS, Data.WEAPON_ORDER, chosen, best)
	music.play("menu")

func start_with(id: String) -> void:
	chosen = id
	_save()
	reset_game()
	begin()

func reset_game() -> void:
	for c in world.get_children():
		c.queue_free()
	enemies.clear()
	pickups.clear()
	boss = null
	up = Data.BASE_UP.duplicate()
	taken = {}
	aug_wave = 0
	player.reset(Data.WEAPONS[chosen])
	wave = 0; score = 0; kills = 0; to_spawn = []; intermission = 1.5
	style = 0.0; chain = 0; best_rank = 0; recent_kills = []
	music.set_zone(1)

func begin() -> void:
	state = "play"
	player.cam.current = true
	hud.show_screen("none")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func pause_game() -> void:
	if state != "play":
		return
	state = "paused"
	music.duck(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_screen("pause")

func resume() -> void:
	music.duck(false)
	begin()

func game_over() -> void:
	state = "over"
	player.hp = 0.0
	music.play("over")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if score > best:
		best = score
		_save()
	hud.show_over(wave, kills, Data.RANKS[best_rank][0], score)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		hud.set_mute(music.toggle_mute())
	elif event.is_action_pressed("pause"):
		if state == "play":
			pause_game()
		elif state == "paused":
			resume()
	for i in 3:
		if event.is_action_pressed("pick_%d" % (i + 1)):
			if state == "menu":
				start_with(Data.WEAPON_ORDER[i])
			elif state == "augment":
				pick_augment(i)

func _notification(what: int) -> void:
	# fenêtre qui perd le focus : pause automatique
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play" and not "--autotest" in OS.get_cmdline_user_args():
		pause_game()

# ---------- Vagues ----------
func _wave_composition(w: int) -> Array:
	var n := roundi(6 + w * 3.2 + pow(w, 1.35))
	var list := []
	for i in n:
		var r := randf()
		if w >= 6 and r < minf(0.12, 0.03 + w * 0.006): list.append("brute")
		elif w >= 3 and r < 0.32: list.append("runner")
		elif w >= 4 and r < 0.45: list.append("spitter")
		else: list.append("grunt")
	return list

func start_wave() -> void:
	wave += 1
	music.set_zone(int((wave - 1) / Data.WAVES_PER_ZONE) + 1)
	if wave % 5 == 0:
		music.play("boss")
		_spawn_boss()
		to_spawn = _wave_composition(int(wave / 2)).slice(0, 6 + wave)
		spawn_timer = 6.0
	else:
		to_spawn = _wave_composition(wave)
		spawn_timer = 0.5
		music.play("wave")
		hud.banner("Vague %d" % wave, "%d ennemis" % to_spawn.size())

func _spawn_pos(min_dist := 18.0) -> Vector3:
	var p := Vector3.ZERO
	for tries in 10:
		var a := randf() * TAU
		var d := 30.0 + randf() * 7.0
		p = Vector3(clampf(cos(a) * d, -ARENA + 2, ARENA - 2), 0.05, clampf(sin(a) * d, -ARENA + 2, ARENA - 2))
		if p.distance_to(player.global_position) >= min_dist:
			break
	return p

func spawn_enemy(type: String, mult: float) -> void:
	var e = EnemyScript.new()
	var t: Dictionary = Data.ENEMIES[type].duplicate()
	e.setup(self, type, t, mult)
	e.speed = t.speed * (0.9 + randf() * 0.25) * minf(1.35, 1.0 + wave * 0.015)
	world.add_child(e)
	e.global_position = _spawn_pos()
	enemies.append(e)

func _spawn_boss() -> void:
	var idx := int(wave / 5 - 1) % Data.BOSSES.size()
	var cycle := int((wave / 5 - 1) / Data.BOSSES.size())
	var b: Dictionary = Data.BOSSES[idx]
	var t := { "hp": b.hp * (1.0 + cycle * 0.8), "speed": b.speed, "dmg": 30.0, "r": b.r, "h": b.h, "color": b.color, "score": 5000 * (cycle + 1) }
	var e = EnemyScript.new()
	e.setup(self, "boss", t, 1.0, b)
	world.add_child(e)
	e.global_position = Vector3(0, 0.05, -30)
	enemies.append(e)
	boss = e
	hud.show_boss(b.name + (" +%d" % cycle if cycle > 0 else ""))
	hud.banner("Boss : " + b.name, "vague %d" % wave)
	sfx.play("boss")

# ---------- Boucle ----------
func _process(delta: float) -> void:
	if hitstop_end > 0 and Time.get_ticks_msec() >= hitstop_end:
		hitstop_end = 0
		Engine.time_scale = 1.0
	if state == "menu":
		var t := Time.get_ticks_msec() * 0.0001
		menu_cam.position = Vector3(sin(t) * 24.0, 7.0, cos(t) * 24.0)
		menu_cam.look_at(Vector3(0, 1, 0))
		return
	if state != "play":
		return
	gt += delta
	if chain_t > 0.0:
		chain_t -= delta
		if chain_t <= 0.0:
			chain = 0
	style_idle += delta
	if style_idle > 1.5:
		style = maxf(0.0, style - (15.0 + style * 0.12) * delta)
	enemies = enemies.filter(func(e): return is_instance_valid(e) and e.alive)
	if enemies.is_empty() and to_spawn.is_empty():
		if wave > 0 and aug_wave < wave:
			open_augments()
			return
		if intermission <= 0.0:
			intermission = 1.5
		intermission -= delta
		if intermission <= 0.0:
			start_wave()
	elif not to_spawn.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var batch := mini(to_spawn.size(), 1 + int(wave / 3))
			var mult := 1.0 + maxf(0.0, wave - 3) * 0.08 # pas de bonus de PV sur les 3 premières vagues
			for i in batch:
				spawn_enemy(to_spawn.pop_back(), mult)
			spawn_timer = maxf(0.25, 1.1 - wave * 0.04)
	_update_pickups(delta)
	_update_hud()

func _update_pickups(delta: float) -> void:
	for pk in pickups.duplicate():
		if not is_instance_valid(pk.node):
			pickups.erase(pk)
			continue
		pk.node.rotation.y += delta * 3.0
		pk.node.position.y = 0.8 + sin(gt * 4.0) * 0.15
		pk.life -= delta
		var near: bool = Vector2(pk.node.position.x - player.global_position.x, pk.node.position.z - player.global_position.z).length() < 1.3 and player.global_position.y < 2.5
		if near:
			if pk.kind == "hp":
				player.hp = minf(up.max_hp, player.hp + 25.0)
			else:
				player.ammo = player.W.mag
			sfx.play("pickup")
		if near or pk.life <= 0.0:
			pk.node.queue_free()
			pickups.erase(pk)

func _update_hud() -> void:
	var r := rank_idx()
	var R: Array = Data.RANKS[r]
	var style_pct := 100.0
	if r + 1 < Data.RANKS.size():
		style_pct = 100.0 * (style - R[1]) / (Data.RANKS[r + 1][1] - R[1])
	var chain_txt := " "
	if chain > 1:
		chain_txt = "COMBO ×%d  ·  SCORE ×%s" % [chain, str(R[2])]
	elif R[2] > 1.0:
		chain_txt = "SCORE ×%s" % str(R[2])
	var left := enemies.size() + to_spawn.size()
	var w: Dictionary = player.W
	hud.update_hud({
		"hp": maxi(0, ceili(player.hp)), "hp_pct": 100.0 * player.hp / up.max_hp,
		"roll_pct": 100.0 * (1.0 - player.roll_cd / up.roll_cd),
		"score": score, "rank": R[0], "style_pct": style_pct, "chain": chain_txt,
		"wave": wave, "remain": "%d ennemi%s" % [left, "s" if left > 1 else ""],
		"wname": w.name, "ammo": "··" if player.reload_t > 0.0 else "%d / %d" % [player.ammo, w.mag],
		"reserve": "Rechargement" if player.reload_t > 0.0 else ("R pour recharger" if player.ammo == 0 else " "),
		"reload_pct": 100.0 * (1.0 - player.reload_t / w.reload) if player.reload_t > 0.0 else -1.0,
		"mag_flying": player.flying_mags().size() > 0,
		"boss_pct": 100.0 * boss.hp / boss.max_hp if boss != null and is_instance_valid(boss) and boss.alive else -1.0,
	})

# ---------- Style ----------
func rank_idx() -> int:
	var r := 0
	for i in Data.RANKS.size():
		if style >= Data.RANKS[i][1]:
			r = i
	return r

func add_style(label: String, pts: float, big := false) -> void:
	var before := rank_idx()
	style = minf(1600.0, style + pts * up.style_mult)
	style_idle = 0.0
	chain += 1
	chain_t = 3.0
	var r := rank_idx()
	best_rank = maxi(best_rank, r)
	if r > before:
		hud.rank_pop()
		sfx.play("style")
	if label != "":
		hud.add_feed("%s +%d" % [label, roundi(pts * up.style_mult)], big)

func hitstop(seconds: float) -> void:
	# arrêt sur image bref sur les gros moments (tir de chargeur, boss abattu)
	Engine.time_scale = 0.15
	hitstop_end = Time.get_ticks_msec() + int(seconds * 1000.0)

# ---------- Combat ----------
func hurt_player(d: float) -> bool:
	if state != "play":
		return false
	if player.iframes > 0.0:
		if not player.dodged:
			player.dodged = true
			add_style("ESQUIVE", 60, true)
			sfx.play("dodge")
			hud.flash(Color("3fd0c9"), 0.5)
		return false
	player.hp -= d
	shake = maxf(shake, 0.35)
	style *= 0.55
	chain = 0
	chain_t = 0.0
	hud.flash(Color(1.0, 0.16, 0.08), 0.9)
	sfx.play("hurt")
	if player.hp <= 0.0:
		game_over()
	return true

func damage_enemy(en, dmg: float, at: Vector3, ctx := {}) -> void:
	if not is_instance_valid(en) or not en.alive:
		return
	en.hp -= dmg
	en.flash_t = 0.08
	burst(at, en.T.color, 4 if en.is_boss else 3, 4.0)
	if en.hp <= 0.0:
		kill_enemy(en, ctx)

func kill_enemy(en, ctx: Dictionary) -> void:
	if not en.alive:
		return
	en.alive = false
	var c: Vector3 = en.center()
	burst(c, en.T.color, 60 if en.is_boss else 14, 14.0 if en.is_boss else 7.0)
	en.queue_free()
	kills += 1
	# figures de style
	add_style("", 12)
	if ctx.get("head", false): add_style("TÊTE", 20)
	if player.air: add_style("KILL AÉRIEN", 45, true)
	if player.roll_t > 0.0 or player.roll_grace > 0.0: add_style("ROULADE MORTELLE", 40, true)
	if player.slide_t > 0.0: add_style("GLISSADE", 40, true)
	match ctx.get("src", ""):
		"mag": add_style("JONGLEUR", 35)
		"ric": add_style("RICOCHET", 25)
		"boom": add_style("RÉACTION EN CHAÎNE", 20)
	recent_kills = recent_kills.filter(func(t): return gt - t < 0.6)
	recent_kills.append(gt)
	if recent_kills.size() == 3: add_style("MULTI-KILL", 70, true)
	if recent_kills.size() == 6: add_style("MASSACRE", 150, true)
	score += roundi(en.T.score * Data.RANKS[rank_idx()][2])
	sfx.play("kill")
	if up.lifesteal > 0.0:
		player.hp = minf(up.max_hp, player.hp + up.lifesteal)
	if up.explode > 0 and not en.is_boss:
		burst(c, Color("ff8a3d"), 18, 10.0)
		for o in enemies.duplicate():
			if is_instance_valid(o) and o.alive and o != en and Vector2(o.global_position.x - c.x, o.global_position.z - c.z).length() < 3.5:
				damage_enemy(o, 14.0 * up.explode, o.center(), { "src": "boom" })
	if en.is_boss:
		boss = null
		shake = 1.0
		hitstop(0.4)
		add_style("BOSS ABATTU", 300, true)
		hud.banner("Boss vaincu", "+%d points" % en.T.score)
		for k in 4:
			_drop_pickup(c + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
		player.hp = minf(up.max_hp, player.hp + 40.0)
	elif randf() < 0.07:
		_drop_pickup(c)

func ricochet(from, at: Vector3, dmg: float) -> void:
	var best_e = null
	var bd := 8.0
	for e in enemies:
		if e == from or not is_instance_valid(e) or not e.alive:
			continue
		var d: float = e.global_position.distance_to(from.global_position)
		if d < bd:
			bd = d
			best_e = e
	if best_e == null:
		return
	tracer(at, best_e.center(), Color("ff4fa3"))
	damage_enemy(best_e, dmg, best_e.center(), { "src": "ric" })

func launch_mag(t, origin: Vector3, dir: Vector3) -> void:
	# le chargeur part comme une roquette vers l'ennemi le plus proche du viseur
	var best_e = null
	var bs := 0.6
	for e in enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var to: Vector3 = e.center() - origin
		var d := to.length()
		if d > 60.0:
			continue
		var s := to.normalized().dot(dir) - d * 0.002
		if s > bs:
			bs = s
			best_e = e
	t.launch(best_e, dir)
	hitstop(0.12)
	sfx.play("ping")
	add_style("TIR DE CHARGEUR", 120, true)

func explode_mag(t) -> void:
	var p: Vector3 = t.global_position
	t.state = "gone"
	t.queue_free()
	shockwave(p, Color("ffc23d"), 4.5)
	burst(p, Color("ffc23d"), 24, 12.0)
	sfx.play("boom")
	shake = maxf(shake, 0.6)
	var dmg: float = (60.0 + 8.0 * wave) * up.mag_boom
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.alive and e.center().distance_to(p) < 4.5 + e.T.r:
			damage_enemy(e, dmg * 1.5 if e.is_boss else dmg, e.center(), { "src": "mag" })

func fire_shot(from: Vector3, dir: Vector3, speed: float, dmg: float, color: Color, size := 0.25) -> void:
	var s = ShotScript.new()
	s.game = self
	s.vel = dir * speed
	s.dmg = dmg
	s.radius = size
	s.color = color
	world.add_child(s)
	s.global_position = from

func ray_world(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ---------- Effets ----------
func _unshaded(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func burst(pos: Vector3, color: Color, n := 10, spd := 6.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(1, n)
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = spd * 0.3
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -18, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var bm := BoxMesh.new(); bm.size = Vector3.ONE * 0.12
	bm.material = _unshaded(color)
	p.mesh = bm
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

func shockwave(pos: Vector3, color: Color, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0
	mi.mesh = sm
	var m := _unshaded(color, 3.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.6
	mi.material_override = m
	world.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.35)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)

func tracer(a: Vector3, b: Vector3, color: Color) -> void:
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.015, 0.015, len)
	mi.mesh = bm
	mi.material_override = _unshaded(color, 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = (a + b) / 2.0
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.06, false).timeout.connect(mi.queue_free)

func _drop_pickup(pos: Vector3) -> void:
	var kind := "hp" if randf() < 0.7 else "ammo"
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.5, 0.5, 0.5)
	mi.mesh = pm
	mi.material_override = _unshaded(Color("3fd0c9") if kind == "hp" else Color("ffc23d"))
	world.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.8, pos.z)
	pickups.append({ "node": mi, "kind": kind, "life": 15.0 })

# ---------- Augments ----------
func open_augments() -> void:
	state = "augment"
	music.play("augment")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var w_id: String = player.W.id
	var ok := func(a): return (not a.has("weapon") or a.weapon == w_id) and (not a.has("max") or taken.get(a.id, 0) < a.max)
	var specific := Data.AUGMENTS.filter(func(a): return a.has("weapon") and ok.call(a))
	var common := Data.AUGMENTS.filter(func(a): return not a.has("weapon") and ok.call(a))
	specific.shuffle()
	aug_choices = []
	# au moins une carte propre à l'arme, quand il en reste
	if not specific.is_empty():
		aug_choices.append(specific.pop_back())
	var rest := specific + common
	rest.shuffle()
	while aug_choices.size() < 3 and not rest.is_empty():
		aug_choices.append(rest.pop_back())
	aug_choices.shuffle()
	var owned := []
	for id in taken:
		for a in Data.AUGMENTS:
			if a.id == id:
				owned.append(a.name + (" ×%d" % taken[id] if taken[id] > 1 else ""))
	hud.show_augments(aug_choices, taken, wave, player.W.name, ("Tes augments : " + ", ".join(owned)) if owned.size() > 0 else "Choisis ton premier augment.")

func pick_augment(i: int) -> void:
	if state != "augment" or i >= aug_choices.size():
		return
	var a: Dictionary = aug_choices[i]
	apply_augment(a.id)
	taken[a.id] = taken.get(a.id, 0) + 1
	sfx.play("pickup")
	aug_wave = wave
	intermission = 1.5
	begin()
	hud.banner(a.name, a.desc)

func apply_augment(id: String) -> void:
	var W: Dictionary = player.W
	match id:
		"dmg": W.dmg *= 1.2
		"mag": W.mag = roundi(W.mag * 1.3); player.ammo = W.mag
		"reload": W.reload *= 0.8
		"juggle": up.mag_boom += 0.5
		"show": up.style_mult += 0.25
		"speed": up.speed *= 1.1
		"roll": up.roll_cd *= 0.75
		"slide": up.slide_boost *= 1.25
		"jump": up.jumps += 1
		"hp": up.max_hp += 25.0; player.hp = up.max_hp
		"leech": up.lifesteal += 3.0
		"regen": up.regen += 1.5
		"boom": up.explode += 1
		"r_pierce": up.pierce += 1
		"r_lynx": up.crit += 1.0
		"r_last": up.last_shots += 5
		"r_steady": W.spread *= 0.5; W.kick *= 0.5
		"s_pellets": W.pellets += 3
		"s_choke": W.spread *= 0.7
		"s_blast": up.recoil_jump += 1
		"s_pump": W.rate /= 1.25
		"u_ric": up.ricochet += 1
		"u_drum": W.mag = roundi(W.mag * 1.5); player.ammo = W.mag
		"u_air": up.air_dmg += 1
		"u_frenzy": W.rate /= 1.2

# ---------- Test automatique (godot --path . -- --autotest) ----------
func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _shot(name: String) -> void:
	var dir := OS.get_environment("HB_SHOTS")
	if dir != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")

func _autotest() -> void:
	print("AUTOTEST start")
	await _wait(1.0)
	await _shot("menu")
	for wid in Data.WEAPON_ORDER:
		start_with(wid)
		await _wait(2.5)
		print("[%s] wave=%d enemies=%d" % [wid, wave, enemies.size()])
		player.hp = 1e9
		# tir
		for k in 10:
			player.shoot()
			player.fire_cd = 0.0
		print("[%s] ammo after 10 shots=%d reloading=%s" % [wid, player.ammo, player.reload_t > 0.0])
		# glissade + roulade + esquive
		player.velocity = Vector3(0, 0, -10)
		player.slide()
		print("[%s] slide_t=%.2f" % [wid, player.slide_t])
		await _wait(0.2)
		await _shot("slide_" + wid)
		player.roll_cd = 0.0
		player.roll()
		await _wait(0.1)
		await _shot("roll_" + wid)
		print("[%s] dodge -> hurt returned %s, style=%d" % [wid, hurt_player(10), style])
		await _wait(0.6)
		# rechargement + tir sur le chargeur
		player.ammo = 2
		player.reload_t = 0.0
		player.start_reload()
		await _wait(W_reload_wait(wid))
		await _shot("reload_" + wid)
		await _wait(player.W.reload)
		var mags: Array = player.flying_mags()
		print("[%s] flying mags=%d reload_done=%s" % [wid, mags.size(), player.reload_t <= 0.0])
		if mags.size() > 0:
			var d: Vector3 = mags[0].global_position - player.eye_position()
			player.yaw = atan2(-d.x, -d.z)
			player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			player.rotation.y = player.yaw
			player.head.rotation.x = player.pitch
			await get_tree().physics_frame
			# l'ennemi le plus proche se rapproche pour le test
			if enemies.size() > 0:
				enemies[0].global_position = player.global_position + Vector3(0, 0, -8).rotated(Vector3.UP, player.yaw)
			player.fire_cd = 0.0
			player.shoot()
			print("[%s] mag state after shot=%s style=%d" % [wid, mags[0].state, style])
			await _wait(0.05)
			await _shot("magshot_" + wid)
		await _wait(1.0)
		# vider la vague pour voir l'écran d'augments
		to_spawn.clear()
		for e in enemies.duplicate():
			kill_enemy(e, {})
		await _wait(0.5)
		print("[%s] state=%s choices=%s" % [wid, state, ", ".join(aug_choices.map(func(a): return a.id))])
		await _shot("augment_" + wid)
		pick_augment(0)
		print("[%s] taken=%s state=%s score=%d rank=%s" % [wid, taken, state, score, Data.RANKS[best_rank][0]])
		# boss : on saute à la vague 5
		aug_wave = 4
		wave = 4
		for e in enemies.duplicate():
			kill_enemy(e, {})
		to_spawn.clear()
		await _wait(2.5)
		print("[%s] wave=%d boss=%s" % [wid, wave, boss != null])
		if boss:
			await _wait(1.5)
			await _shot("boss_" + wid)
			boss.hp = boss.max_hp * 0.4
			await _wait(0.5)
			print("[%s] boss phase2=%s music=%s" % [wid, boss.phase2, music.current_key])
			kill_enemy(boss, {})
		player.hp = 1.0
		player.iframes = 0.0
		hurt_player(10)
		print("[%s] state after death=%s" % [wid, state])
		await _wait(0.3)
		await _shot("over_" + wid)
	print("AUTOTEST done")
	get_tree().quit()

func W_reload_wait(wid: String) -> float:
	return 0.35 if wid != "uzi" else 0.3
