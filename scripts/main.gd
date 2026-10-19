# Horde Breaker : flux d'un run (zone 1, 10 rounds), style, économie, XP, arbre, Surcharge, augments.
extends Node3D

const Data = preload("res://scripts/data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ShotScript = preload("res://scripts/shot.gd")
const ThrownMag = preload("res://scripts/thrown_mag.gd")
const HudScript = preload("res://scripts/hud.gd")
const MusicScript = preload("res://scripts/music.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const CityScript = preload("res://scripts/city.gd")
const SAVE := "user://save.cfg"

var state := "menu" # menu, play, between, paused, over, victory
var player
var hud
var music
var sfx
var city
var world: Node3D        # objets temporaires (ennemis, tirs, effets)
var menu_cam: Camera3D

var enemies: Array = []
var boss = null
var to_spawn: Array = []
var spawn_timer := 0.0
var intermission := 0.0
var wave := 0
var cleared := 0
var score := 0
var kills := 0
var taken := {}
var up := {}
var character := "kade"
var chosen := "rifle"
var best := 0
var best_wave := 0
var pickups: Array = []
var zone_idx := 0

# économie et progression du run
var credits := 0
var xp := 0
var level := 1
var points := 0
var tree := {}
var mods := {}
var weapon_level := 1
var between: Array = []
var screen := ""
var aug_choices: Array = []
var shop_offers: Array = []

# Surcharge et effets globaux
var skill_t := 0.0
var enemy_slow := 1.0
var glitch_t := 0.0
var pad_cd := 0.0
var fall_cd := 0.0

var style := 0.0
var style_idle := 0.0
var chain := 0
var chain_t := 0.0
var best_rank := 0
var recent_kills: Array = []
var gt := 0.0
var shake := 0.0
var hitstop_end := 0
var shield_ping := 0.0

# ---------- Mise en place ----------
func _ready() -> void:
	randomize()
	_setup_input()
	_build_environment()
	city = CityScript.new()
	add_child(city)
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
	hud.shop_buy.connect(buy)
	hud.tree_pick.connect(pick_tree)
	hud.continue_pressed.connect(next_between)
	hud.resume_pressed.connect(resume)
	hud.retry_pressed.connect(func(): start_with(chosen))
	hud.menu_pressed.connect(to_menu)
	_load_save()
	to_menu()
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()
	elif "--showcase" in OS.get_cmdline_user_args():
		_showcase()

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
	add.call("skill", [KEY_E, KEY_F], MOUSE_BUTTON_RIGHT, [JOY_BUTTON_Y], [])
	add.call("fire", [], MOUSE_BUTTON_LEFT, [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	add.call("pause", [KEY_ESCAPE, KEY_P], -1, [JOY_BUTTON_START], [])
	add.call("mute", [KEY_M], -1, [], [])
	add.call("pick_1", [KEY_1], -1, [], [])
	add.call("pick_2", [KEY_2], -1, [], [])
	add.call("pick_3", [KEY_3], -1, [], [])
	add.call("pick_4", [KEY_4], -1, [], [])
	add.call("pick_5", [KEY_5], -1, [], [])
	add.call("pick_6", [KEY_6], -1, [], [])
	add.call("confirm", [KEY_ENTER, KEY_KP_ENTER], -1, [JOY_BUTTON_A], [])

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("07051a")
	sm.sky_horizon_color = Color("3a1450")
	sm.ground_bottom_color = Color("05040c")
	sm.ground_horizon_color = Color("3a1450")
	sm.sun_angle_max = 0.0
	sm.sky_energy_multiplier = 1.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a4a78")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color("2a1240")
	env.fog_density = 0.012
	env.fog_sky_affect = 0.6
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("9fb4ff")
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-60, 35, 0)
	add_child(moon)

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		best = cfg.get_value("game", "best", 0)
		best_wave = cfg.get_value("game", "best_wave", 0)
		var c: String = cfg.get_value("game", "weapon", "rifle")
		if Data.WEAPONS.has(c):
			chosen = c

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.set_value("game", "best_wave", best_wave)
	cfg.set_value("game", "weapon", chosen)
	cfg.save(SAVE)

func zone() -> Dictionary:
	return Data.ZONES[zone_idx]

# ---------- Flux de partie ----------
func to_menu() -> void:
	state = "menu"
	_set_slow(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_cam.current = true
	hud.show_menu(Data.CHARACTERS[character], Data.WEAPONS, chosen, best, best_wave)
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
	tree = {}
	mods = {}
	between = []
	weapon_level = 1
	credits = 0; xp = 0; level = 1; points = 0
	skill_t = 0.0
	_set_slow(false)
	glitch_t = 0.0
	player.reset(Data.WEAPONS[chosen])
	wave = 0; cleared = 0; score = 0; kills = 0; to_spawn = []; intermission = 1.5
	style = 0.0; chain = 0; best_rank = 0; recent_kills = []
	city.reset()
	music.set_zone(zone_idx + 1)

func begin() -> void:
	state = "play"
	screen = ""
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

func _end_run() -> void:
	player.hp = maxf(player.hp, 0.0)
	_set_slow(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	best_wave = maxi(best_wave, cleared)
	if score > best:
		best = score
	_save()

func game_over() -> void:
	state = "over"
	player.hp = 0.0
	music.play("over")
	_end_run()
	hud.show_over(wave, kills, Data.RANKS[best_rank][0], score, level)

func victory() -> void:
	state = "victory"
	music.play("victory")
	_end_run()
	hud.show_victory(zone().name, kills, Data.RANKS[best_rank][0], score, level, credits)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		hud.set_mute(music.toggle_mute())
	elif event.is_action_pressed("pause"):
		if state == "play":
			pause_game()
		elif state == "paused":
			resume()
	for i in 6:
		if event.is_action_pressed("pick_%d" % (i + 1)):
			if state == "menu" and i < Data.WEAPON_ORDER.size():
				start_with(Data.WEAPON_ORDER[i])
			elif state == "between" and screen == "augment":
				pick_augment(i)
			elif state == "between" and screen == "shop":
				buy(i)
	if event.is_action_pressed("confirm") and state == "between" and screen in ["shop", "tree"]:
		next_between()

func _notification(what: int) -> void:
	# fenêtre qui perd le focus : pause automatique
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play" and not "--autotest" in OS.get_cmdline_user_args():
		pause_game()

# ---------- Rounds ----------
func _round_def(w: int) -> Dictionary:
	var rounds: Array = zone().rounds
	return rounds[clampi(w - 1, 0, rounds.size() - 1)]

func _pick(mix: Dictionary) -> String:
	var total := 0.0
	for k in mix:
		total += mix[k]
	var r := randf() * total
	for k in mix:
		r -= mix[k]
		if r <= 0.0:
			return k
	return mix.keys()[0]

func _wave_composition(w: int) -> Array:
	var R := _round_def(w)
	var list := []
	for i in R.n:
		var t := _pick(R.mix)
		if t == "pub":
			# les drones pub arrivent en essaim
			for k in 4:
				list.append("pub")
		else:
			list.append(t)
	list.shuffle()
	return list

func start_wave() -> void:
	wave += 1
	music.set_zone(zone_idx + 1)
	var R := _round_def(wave)
	to_spawn = _wave_composition(wave)
	spawn_timer = 0.5
	match R.get("special", ""):
		"miniboss":
			music.play("miniboss")
			_spawn_boss(zone().miniboss, true)
			spawn_timer = 5.0
		"boss":
			music.play("boss")
			_spawn_boss(zone().boss, false)
			spawn_timer = 7.0
		_:
			music.play("wave")
			hud.banner("Round %d" % wave, "%s · %d ennemis" % [zone().name, to_spawn.size()])

func spawn_pos(min_dist := 18.0, fly := false) -> Vector3:
	var p := Vector3.ZERO
	for tries in 12:
		var a := randf() * TAU
		var d := 26.0 + randf() * 11.0
		p = Vector3(clampf(cos(a) * d, -37.0, 37.0), 0.05, clampf(sin(a) * d, -37.0, 37.0))
		if p.distance_to(player.global_position) >= min_dist:
			break
	if fly:
		p.y = 5.0 + randf() * 3.0
	return p

func _free_perch() -> Variant:
	var used := []
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.type_name == "sniper":
			used.append(e.get_meta("perch"))
	if used.size() >= Data.MAX_SNIPERS:
		return null
	var free := []
	for i in city.perches.size():
		if not i in used:
			free.append(i)
	return null if free.is_empty() else free[randi() % free.size()]

func spawn_enemy(type: String, mult: float) -> void:
	var perch = null
	if type == "sniper":
		perch = _free_perch()
		if perch == null:
			type = "spitter"
	var e = EnemyScript.new()
	var t: Dictionary = Data.ENEMIES[type].duplicate()
	e.setup(self, type, t, mult)
	e.speed = t.speed * (0.9 + randf() * 0.25) * minf(1.3, 1.0 + wave * 0.02)
	world.add_child(e)
	if perch != null:
		e.set_meta("perch", perch)
		e.global_position = city.perches[perch] + Vector3(0, 0.05, 0)
	else:
		e.global_position = spawn_pos(18.0, t.get("fly", false))
	enemies.append(e)

func _spawn_boss(b: Dictionary, mini: bool) -> void:
	var t := { "name": b.name, "ai": "boss", "hp": b.hp, "speed": b.speed, "dmg": 30.0, "r": b.r, "h": b.h, "color": b.color, "score": b.score, "cr": b.cr, "xp": b.xp }
	var def := b.duplicate()
	def.mini = mini
	var e = EnemyScript.new()
	e.setup(self, "boss", t, 1.0, def)
	world.add_child(e)
	e.global_position = Vector3(0, 0.05, -24)
	enemies.append(e)
	boss = e
	hud.show_boss(b.name)
	hud.banner(("Mini-boss : " if mini else "Boss de zone : ") + b.name, "Round %d" % wave)
	sfx.play("boss")

func _on_round_clear() -> void:
	cleared = wave
	var bonus := 20 + 5 * wave + 10 * rank_idx()
	credits += bonus
	hud.add_feed("ROUND NETTOYÉ +%d ¤" % bonus, true)
	if wave >= Data.BOSS_ROUND:
		victory()
		return
	between = []
	if wave == Data.MINIBOSS_ROUND:
		between.append("augment")
	if wave in Data.SHOP_ROUNDS:
		between.append("shop")
	between.append("tree")
	next_between()

func next_between() -> void:
	# enchaîne les écrans de fin de round : augment offert, shop, arbre (s'il reste des points)
	while not between.is_empty():
		var s: String = between.pop_front()
		if s == "tree" and points <= 0:
			continue
		state = "between"
		screen = s
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		match s:
			"augment": open_augments()
			"shop": open_shop()
			"tree": open_tree()
		return
	if state == "between":
		intermission = 2.0
		begin()

# ---------- Boucle ----------
func _process(delta: float) -> void:
	if hitstop_end > 0 and Time.get_ticks_msec() >= hitstop_end:
		hitstop_end = 0
		Engine.time_scale = 1.0
	if state == "menu":
		var t := Time.get_ticks_msec() * 0.00006
		menu_cam.position = Vector3(sin(t) * 30.0, 9.0, cos(t) * 30.0)
		menu_cam.look_at(Vector3(0, 4, 0))
		city.follow(menu_cam.global_position)
		return
	city.follow(player.global_position)
	if state != "play":
		return
	gt += delta
	shield_ping -= delta
	fall_cd -= delta
	if chain_t > 0.0:
		chain_t -= delta
		if chain_t <= 0.0:
			chain = 0
	style_idle += delta
	if style_idle > 1.5:
		style = maxf(0.0, style - (15.0 + style * 0.12) * delta)
	if skill_t > 0.0:
		skill_t -= delta
		if skill_t <= 0.0:
			_set_slow(false)
	if glitch_t > 0.0:
		glitch_t -= delta
	_update_pads(delta)
	enemies = enemies.filter(func(e): return is_instance_valid(e) and e.alive)
	if enemies.is_empty() and to_spawn.is_empty():
		if wave > cleared:
			_on_round_clear()
			return
		if intermission <= 0.0:
			intermission = 1.5
		intermission -= delta
		if intermission <= 0.0:
			start_wave()
	elif not to_spawn.is_empty():
		spawn_timer -= delta * enemy_slow
		if spawn_timer <= 0.0:
			var batch := mini(to_spawn.size(), 1 + int(wave / 3))
			var mult := 1.0 + maxf(0.0, wave - 3) * 0.08 # pas de bonus de PV sur les 3 premiers rounds
			for i in batch:
				spawn_enemy(to_spawn.pop_back(), mult)
			spawn_timer = maxf(0.3, 1.1 - wave * 0.05)
	_update_pickups(delta)
	_update_hud()

func _update_pads(delta: float) -> void:
	pad_cd -= delta
	if pad_cd > 0.0:
		return
	var pp: Vector3 = player.global_position
	for pad in city.pads:
		var d := Vector2(pp.x - pad.pos.x, pp.z - pad.pos.z).length()
		if d < 1.3 and absf(pp.y - pad.pos.y) < 0.7:
			player.launch(pad.push + Vector3(0, pad.power, 0))
			pad_cd = 0.5
			sfx.play("pad")
			var tw: Tween = pad.ring.create_tween()
			tw.tween_property(pad.ring, "scale", Vector3.ONE * 1.8, 0.15)
			tw.tween_property(pad.ring, "scale", Vector3.ONE, 0.25)
			return

func _update_pickups(delta: float) -> void:
	for pk in pickups.duplicate():
		if not is_instance_valid(pk.node):
			pickups.erase(pk)
			continue
		pk.node.rotation.y += delta * 3.0
		pk.node.position.y = pk.y + 0.8 + sin(gt * 4.0) * 0.15
		pk.life -= delta
		var near: bool = Vector2(pk.node.position.x - player.global_position.x, pk.node.position.z - player.global_position.z).length() < 1.3 and absf(player.global_position.y - pk.y) < 2.5
		if near:
			match pk.kind:
				"hp": player.hp = minf(up.max_hp, player.hp + 25.0)
				"cr": credits += 15
				_: player.ammo = player.W.mag
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
	var skill_txt := "SURCHARGE  %d %%" % int(player.skill)
	if skill_t > 0.0:
		skill_txt = "SURCHARGE ACTIVE"
	elif player.skill >= 100.0:
		skill_txt = "SURCHARGE PRÊTE · E"
	hud.update_hud({
		"hp": maxi(0, ceili(player.hp)), "hp_pct": 100.0 * player.hp / up.max_hp,
		"roll_pct": 100.0 * (1.0 - player.roll_cd / up.roll_cd),
		"score": score, "rank": R[0], "style_pct": style_pct, "chain": chain_txt,
		"zone": "Zone %d · %s" % [zone_idx + 1, zone().name], "wave": "%d / %d" % [wave, Data.BOSS_ROUND],
		"remain": "%d ennemi%s" % [left, "s" if left > 1 else ""],
		"wname": w.name + (" · niv. %d" % weapon_level if weapon_level > 1 else ""),
		"ammo": "··" if player.reload_t > 0.0 else ("∞" if skill_t > 0.0 else "%d / %d" % [player.ammo, w.mag]),
		"reserve": "Rechargement" if player.reload_t > 0.0 else ("R pour recharger" if player.ammo == 0 else " "),
		"reload_pct": 100.0 * (1.0 - player.reload_t / w.reload) if player.reload_t > 0.0 else -1.0,
		"mag_flying": player.flying_mags().size() > 0,
		"boss_pct": 100.0 * boss.hp / boss.max_hp if boss != null and is_instance_valid(boss) and boss.alive else -1.0,
		"credits": credits, "level": level, "xp_pct": 100.0 * xp / Data.xp_for_level(level), "points": points,
		"skill_pct": 100.0 * skill_t / (Data.CHARACTERS[character].skill_time + up.skill_time) if skill_t > 0.0 else player.skill,
		"skill_txt": skill_txt, "skill_ready": player.skill >= 100.0 or skill_t > 0.0,
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
	var gain: float = pts * up.style_mult
	style = minf(1600.0, style + gain)
	style_idle = 0.0
	chain += 1
	chain_t = 3.0
	# le combo charge la compétence
	if skill_t <= 0.0:
		player.skill = minf(100.0, player.skill + gain * 0.2 * up.skill_gain)
	var r := rank_idx()
	best_rank = maxi(best_rank, r)
	if r > before:
		hud.rank_pop()
		sfx.play("style")
	if label != "":
		hud.add_feed("%s +%d" % [label, roundi(gain)], big)

func hitstop(seconds: float) -> void:
	# arrêt sur image bref sur les gros moments (tir de chargeur, boss abattu)
	Engine.time_scale = 0.15
	hitstop_end = Time.get_ticks_msec() + int(seconds * 1000.0)

# ---------- Surcharge ----------
func _set_slow(on: bool) -> void:
	enemy_slow = 0.55 if on else 1.0
	if not on:
		skill_t = 0.0
	if hud:
		hud.set_surge(on)

func activate_skill() -> void:
	if state != "play" or skill_t > 0.0:
		return
	if player.skill < 100.0:
		sfx.play("deny")
		return
	player.skill = 0.0
	skill_t = Data.CHARACTERS[character].skill_time + up.skill_time
	_set_slow(true)
	player.ammo = player.W.mag
	player.reload_t = 0.0
	sfx.play("skill")
	hud.flash(Color("3fd0c9"), 0.8)
	hud.add_feed("SURCHARGE", true)
	shake = maxf(shake, 0.4)
	if tree.has("s3"):
		var c: Vector3 = player.global_position + Vector3(0, 1, 0)
		shockwave(c, Color("3fd0c9"), 9.0)
		for e in enemies.duplicate():
			if is_instance_valid(e) and e.alive and e.center().distance_to(c) < 9.0:
				damage_enemy(e, 50.0 + 6.0 * wave, e.center(), { "src": "boom" })

# ---------- Combat ----------
func hurt_player(d: float, unavoidable := false) -> bool:
	if state != "play":
		return false
	if player.iframes > 0.0 and not unavoidable:
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

func player_fell() -> void:
	# chute dans la fosse : dégâts et retour sur la terre ferme
	if fall_cd > 0.0:
		return
	fall_cd = 0.5
	var p: Vector3 = player.global_position
	var flat := Vector3(p.x, 0, p.z)
	if flat.length() < 0.5:
		flat = Vector3(0, 0, 1)
	player.global_position = flat.normalized() * (city.PLAZA + 4.0) + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	hurt_player(15.0, true)

func hacker_glitch(t: float) -> void:
	glitch_t = maxf(glitch_t, t)
	hud.glitch(t)
	sfx.play("glitch")

func boss_phase2(en) -> void:
	sfx.play("boss")
	shake = 0.8
	if en.is_mini:
		hud.banner("Phase 2", en.T.name + " s'énerve")
		return
	music.play("boss2")
	hud.banner("Phase 2", "La dalle s'effondre")
	city.collapse()

func damage_enemy(en, dmg: float, at: Vector3, ctx := {}) -> void:
	if not is_instance_valid(en) or not en.alive:
		return
	if ctx.get("src", "") == "gun" and ctx.has("from") and en.blocks(ctx.from):
		# bouclier frontal : il faut le contourner, passer au-dessus ou le faire exploser
		dmg *= 0.1
		burst(at, Color("bffcff"), 2, 3.0)
		if shield_ping <= 0.0:
			shield_ping = 0.15
			sfx.play("click")
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
	var src: String = ctx.get("src", "")
	# figures de style
	add_style("", 12)
	if ctx.get("head", false): add_style("TÊTE", 20)
	var aerial: bool = player.air
	var m4: float = 1.5 if tree.has("m4") else 1.0
	if player.wallrun_t > 0.0: add_style("KILL MURAL", 50 * m4, true)
	elif aerial: add_style("KILL AÉRIEN", 45 * m4, true)
	if aerial and tree.has("m4"):
		player.roll_cd = 0.0
	if player.roll_t > 0.0 or player.roll_grace > 0.0: add_style("ROULADE MORTELLE", 40, true)
	if player.slide_t > 0.0: add_style("GLISSADE", 40, true)
	match src:
		"mag": add_style("JONGLEUR", 35)
		"ric": add_style("RICOCHET", 25)
		"boom": add_style("RÉACTION EN CHAÎNE", 20)
		"fall": add_style("CHUTE", 30)
	if skill_t > 0.0 and tree.has("s4"):
		skill_t += 0.5
	recent_kills = recent_kills.filter(func(t): return gt - t < 0.6)
	recent_kills.append(gt)
	if recent_kills.size() == 3: add_style("MULTI-KILL", 70, true)
	if recent_kills.size() == 6: add_style("MASSACRE", 150, true)
	var r := rank_idx()
	score += roundi(en.T.score * Data.RANKS[r][2])
	# crédits (bonus selon le combo) et XP
	credits += roundi(en.T.get("cr", 0) * (1.0 + 0.15 * r) * up.credit_mult)
	gain_xp(en.T.get("xp", 0))
	sfx.play("kill")
	if up.lifesteal > 0.0:
		player.hp = minf(up.max_hp, player.hp + up.lifesteal)
	if en.type_name == "pub" or (up.explode > 0 and not en.is_boss):
		var power: float = 30.0 if en.type_name == "pub" else 14.0 * up.explode
		burst(c, Color("ff8a3d"), 18, 10.0)
		for o in enemies.duplicate():
			if is_instance_valid(o) and o.alive and o != en and o.center().distance_to(c) < 3.5:
				damage_enemy(o, power, o.center(), { "src": "boom" })
	if en.is_boss:
		boss = null
		shake = 1.0
		hitstop(0.4)
		add_style("BOSS ABATTU", 300, true)
		hud.banner(("Mini-boss" if en.is_mini else "Boss") + " vaincu", "+%d points" % en.T.score)
		for k in 4:
			_drop_pickup(c + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), "cr")
		player.hp = minf(up.max_hp, player.hp + 40.0)
		if not en.is_mini:
			# le boss de zone emporte ses renforts avec lui
			to_spawn.clear()
			for o in enemies.duplicate():
				if is_instance_valid(o) and o.alive:
					kill_enemy(o, { "src": "boom" })
	elif randf() < 0.07:
		_drop_pickup(c)

func gain_xp(n: int) -> void:
	xp += n
	while xp >= Data.xp_for_level(level):
		xp -= Data.xp_for_level(level)
		level += 1
		points += 1
		sfx.play("level")
		hud.add_feed("NIVEAU %d · +1 POINT" % level, true)

func kamikaze_blast(en) -> void:
	if not en.alive:
		return
	en.alive = false
	var c: Vector3 = en.center()
	shockwave(c, en.T.color, 3.0)
	burst(c, en.T.color, 16, 8.0)
	sfx.play("boom")
	en.queue_free()
	if c.distance_to(player.global_position + Vector3(0, 1, 0)) < 3.0:
		hurt_player(en.T.dmg)

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

func _best_target(origin: Vector3, dir: Vector3, skip: Array) -> Variant:
	var best_e = null
	var bs := 0.6
	for e in enemies:
		if not is_instance_valid(e) or not e.alive or e in skip:
			continue
		var to: Vector3 = e.center() - origin
		var d := to.length()
		if d > 60.0:
			continue
		var s := to.normalized().dot(dir) - d * 0.002
		if s > bs:
			bs = s
			best_e = e
	return best_e

func launch_mag(t, origin: Vector3, dir: Vector3) -> void:
	# le chargeur part comme une roquette vers l'ennemi le plus proche du viseur
	var target = _best_target(origin, dir, [])
	t.launch(target, dir)
	if tree.has("w4"):
		# Pluie d'acier : deux éclats partent vers d'autres ennemis
		var skip := [target]
		for k in 2:
			var other = null
			var bd := 40.0
			for e in enemies:
				if is_instance_valid(e) and e.alive and not e in skip and e.center().distance_to(t.global_position) < bd:
					bd = e.center().distance_to(t.global_position)
					other = e
			var shard := ThrownMag.new()
			shard.game = self
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.06, 0.18, 0.08)
			mi.mesh = bm
			var m := StandardMaterial3D.new()
			m.emission_enabled = true
			m.emission = Color("ffc23d")
			shard.mat = m
			mi.material_override = m
			shard.add_child(mi)
			world.add_child(shard)
			shard.global_position = t.global_position
			shard.launch(other, dir.rotated(Vector3.UP, (k - 0.5) * 0.8))
			skip.append(other)
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
	bm.material = _unshaded(color, 4.0)
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
	mi.material_override = _unshaded(color, 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = (a + b) / 2.0
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.06, false).timeout.connect(mi.queue_free)

func _drop_pickup(pos: Vector3, kind := "") -> void:
	if kind == "":
		var r := randf()
		kind = "hp" if r < 0.5 else ("cr" if r < 0.8 else "ammo")
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.5, 0.5, 0.5)
	mi.mesh = pm
	var col := { "hp": Color("3fd0c9"), "cr": Color("ffc23d"), "ammo": Color("ff4fa3") }
	mi.material_override = _unshaded(col[kind], 3.0)
	world.add_child(mi)
	var y := maxf(0.0, pos.y - 0.6) if pos.y < 9.5 else 9.0
	mi.global_position = Vector3(pos.x, y + 0.8, pos.z)
	pickups.append({ "node": mi, "kind": kind, "life": 15.0, "y": y })

# ---------- Augments (offerts après chaque boss) ----------
func _roll_augments(n: int) -> Array:
	var w_id: String = player.W.id
	var ok := func(a): return (not a.has("weapon") or a.weapon == w_id) and (not a.has("max") or taken.get(a.id, 0) < a.max)
	var specific := Data.AUGMENTS.filter(func(a): return a.has("weapon") and ok.call(a))
	var common := Data.AUGMENTS.filter(func(a): return not a.has("weapon") and ok.call(a))
	specific.shuffle()
	var out := []
	# au moins une carte propre à l'arme, quand il en reste
	if not specific.is_empty():
		out.append(specific.pop_back())
	var rest := specific + common
	rest.shuffle()
	while out.size() < n and not rest.is_empty():
		out.append(rest.pop_back())
	out.shuffle()
	return out

func _owned_text() -> String:
	var owned := []
	for id in taken:
		for a in Data.AUGMENTS:
			if a.id == id:
				owned.append(a.name + (" ×%d" % taken[id] if taken[id] > 1 else ""))
	return ("Tes augments : " + ", ".join(owned)) if owned.size() > 0 else "Choisis ton premier augment."

func open_augments() -> void:
	music.play("augment")
	aug_choices = _roll_augments(3)
	hud.show_augments(aug_choices, taken, "Augment offert · boss vaincu", player.W.name, _owned_text())

func pick_augment(i: int) -> void:
	if state != "between" or screen != "augment" or i >= aug_choices.size():
		return
	var a: Dictionary = aug_choices[i]
	_take_augment(a)
	hud.banner(a.name, a.desc)
	next_between()

func _take_augment(a: Dictionary) -> void:
	apply_augment(a.id)
	taken[a.id] = taken.get(a.id, 0) + 1
	sfx.play("pickup")

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
		"greed": up.credit_mult += 0.3
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

# ---------- Shop (après les rounds 3, 6 et 9) ----------
func open_shop() -> void:
	music.play("shop")
	shop_offers = []
	var n_taken := 0
	for id in taken:
		n_taken += taken[id]
	for a in _roll_augments(2):
		shop_offers.append({ "kind": "aug", "id": a.id, "name": a.name, "desc": a.desc, "tag": player.W.name if a.has("weapon") else "Augment · " + a.tag, "price": Data.AUG_PRICE + 15 * n_taken, "data": a })
	var free_mods := Data.MODS.filter(func(m): return not mods.has(m.id))
	if not free_mods.is_empty():
		var m: Dictionary = free_mods[randi() % free_mods.size()]
		shop_offers.append({ "kind": "mod", "id": m.id, "name": m.name, "desc": m.desc, "tag": "Mod d'arme", "price": m.price })
	shop_offers.append({ "kind": "upgrade", "id": "upgrade", "name": "%s niv. %d" % [player.W.name, weapon_level + 1], "desc": "+15 % de dégâts, +10 % de balles par chargeur", "tag": "Arme supérieure", "price": Data.UPGRADE_PRICE + 80 * (weapon_level - 1) })
	for h in Data.HEALS:
		shop_offers.append({ "kind": "heal", "id": h.id, "name": h.name, "desc": h.desc, "tag": "Soin", "price": h.price })
	_refresh_shop()

func _refresh_shop() -> void:
	hud.show_shop(shop_offers, credits, maxi(0, ceili(player.hp)), int(up.max_hp), "Round %d nettoyé · prochain shop au round %d" % [wave, _next_shop()])

func _next_shop() -> int:
	for r in Data.SHOP_ROUNDS:
		if r > wave:
			return r
	return Data.SHOP_ROUNDS[0]

func buy(i: int) -> void:
	if state != "between" or screen != "shop" or i >= shop_offers.size():
		return
	var o: Dictionary = shop_offers[i]
	if o.get("sold", false) or credits < o.price:
		sfx.play("deny")
		return
	if o.kind == "heal" and player.hp >= up.max_hp:
		sfx.play("deny")
		return
	credits -= o.price
	o.sold = true
	sfx.play("buy")
	var W: Dictionary = player.W
	match o.kind:
		"aug": _take_augment(o.data)
		"mod":
			mods[o.id] = true
			match o.id:
				"mod_barrel": W.spread *= 0.7
				"mod_trigger": W.rate /= 1.12
				"mod_bolt": W.reload *= 0.8
				"mod_ext": W.mag = roundi(W.mag * 1.25); player.ammo = W.mag
		"upgrade":
			weapon_level += 1
			W.dmg *= 1.15
			W.mag = roundi(W.mag * 1.1)
			player.ammo = W.mag
		"heal":
			player.hp = minf(up.max_hp, player.hp + (40.0 if o.id == "heal_s" else up.max_hp))
	_refresh_shop()

# ---------- Arbre de compétences ----------
func open_tree() -> void:
	music.play("augment")
	hud.show_tree(Data.CHARACTERS[character], Data.TREE[character], tree, points, level)

func can_take(id: String) -> bool:
	for br in Data.TREE[character]:
		var prev := ""
		for n in br.nodes:
			if n.id == id:
				return not tree.has(id) and (prev == "" or tree.has(prev))
			prev = n.id
	return false

func pick_tree(id: String) -> void:
	if state != "between" or screen != "tree" or points <= 0 or not can_take(id):
		sfx.play("deny")
		return
	points -= 1
	tree[id] = true
	sfx.play("level")
	var W: Dictionary = player.W
	match id:
		"s1": up.skill_gain *= 1.25
		"s2": up.skill_time += 2.0
		"w1": W.dmg *= 1.12
		"w2": W.reload *= 0.85
		"w3": up.mag_boom += 0.4
		"m1": up.wallrun *= 1.5
		"m2": up.roll_cd *= 0.8
		"m3": up.speed *= 1.08; up.slide_boost *= 1.15
	# s3, s4, w4, m4 : effets lus directement dans tree
	if points <= 0:
		next_between()
	else:
		open_tree()

# ---------- Test automatique (godot --path . -- --autotest) ----------
func _wait(s: float) -> void:
	# compte en pas de physique : le test garde le même rythme de jeu même quand le rendu rame
	for i in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame

func _shot(name: String) -> void:
	var dir := OS.get_environment("HB_SHOTS")
	if dir != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")

func _clear_round() -> void:
	to_spawn.clear()
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.alive:
			kill_enemy(e, {})

func _drain_between(tag: String) -> void:
	# passe les écrans de fin de round en achetant / choisissant le premier choix
	var guard := 0
	while state == "between" and guard < 12:
		guard += 1
		print("[%s] screen=%s credits=%d points=%d" % [tag, screen, credits, points])
		await _shot("%s_%s" % [tag, screen])
		match screen:
			"augment":
				pick_augment(0)
			"shop":
				for i in shop_offers.size():
					buy(i)
				print("[%s] bought=%s" % [tag, ", ".join(shop_offers.filter(func(o): return o.get("sold", false)).map(func(o): return o.id))])
				next_between()
			"tree":
				for br in Data.TREE[character]:
					for n in br.nodes:
						if points > 0 and can_take(n.id):
							pick_tree(n.id)
				print("[%s] tree=%s" % [tag, tree.keys()])
				if state == "between" and screen == "tree":
					next_between()
		await _wait(0.2)

func _showcase() -> void:
	# captures des armes, puis des ennemis et des boss figés devant la caméra
	await _wait(1.0)
	for w in Data.WEAPON_ORDER:
		start_with(w)
		_clear_round()
		player.global_position = Vector3(-30, 0.1, 10)
		player.yaw = -PI / 2
		await _wait(0.4)
		await _shot("gun_" + w)
	start_with("rifle")
	await _wait(0.2)
	_clear_round()
	wave = 1; cleared = 1; intermission = 999.0
	player.hp = 1e9
	enemy_slow = 0.0
	player.global_position = Vector3(0, 0.1, 17)
	player.yaw = 0.0
	player.pitch = 0.02
	var types := ["grunt", "runner", "brute", "spitter", "shield", "hacker", "sniper", "drone", "pub"]
	for i in types.size():
		spawn_enemy(types[i], 1.0)
		var e = enemies[-1]
		e.spawn_t = 0.0
		e.global_position = Vector3(-10.0 + i * 2.5, 2.2 if Data.ENEMIES[types[i]].get("fly", false) else 0.05, 9.0)
	await _wait(0.6)
	await _shot("lineup")
	_clear_round()
	await _wait(0.3)
	enemy_slow = 0.0
	_spawn_boss(zone().miniboss, true)
	boss.spawn_t = 0.0
	boss.global_position = Vector3(-6, 0.05, 2)
	_spawn_boss(zone().boss, false)
	boss.spawn_t = 0.0
	boss.global_position = Vector3(6, 0.05, -2)
	await _wait(0.6)
	await _shot("bosses")
	city.collapse()
	await _wait(5.0)
	player.global_position = Vector3(0, 0.1, 18)
	player.velocity = Vector3(0, 12, 0)
	player.pitch = -0.6
	await _wait(0.5)
	await _wait(0.1)
	await _shot("collapse")
	get_tree().quit()

func _autotest() -> void:
	print("AUTOTEST start")
	if OS.get_environment("HB_SHOTS") != "":
		Engine.max_physics_steps_per_frame = 40
	await _wait(1.5)
	await _shot("menu")
	var wid: String = Data.WEAPON_ORDER[0]
	start_with(wid)
	await _wait(2.5)
	player.hp = 1e9
	up.max_hp = 1e9
	print("[run] wave=%d enemies=%d" % [wave, enemies.size()])
	await _shot("round1")
	for k in 10:
		player.shoot()
		player.fire_cd = 0.0
	print("[run] ammo after 10 shots=%d" % player.ammo)
	# wall run sur la façade ouest
	player.global_position = Vector3(-39.0, 3.0, -10.0)
	player.yaw = PI
	player.pitch = 0.0
	player.velocity = Vector3(-1.0, 2.0, 11.0)
	player.forced_intent = { "move": Vector2(0, -1), "look": Vector2.ZERO, "jump": false, "roll": false, "slide": false, "reload": false, "skill": false, "fire": false }
	await _wait(0.2)
	print("[run] wallrun_t=%.2f on_wall=%s y=%.2f" % [player.wallrun_t, player.is_on_wall(), player.global_position.y])
	await _shot("wallrun")
	player.jump()
	print("[run] wall jump vel=%s" % str(player.velocity))
	player.forced_intent = {}
	await _wait(1.0)
	# jump pad
	var pad: Dictionary = city.pads[0]
	player.global_position = pad.pos + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _wait(0.6)
	print("[run] after pad y=%.2f" % player.global_position.y)
	await _wait(1.5)
	# Surcharge
	player.skill = 100.0
	activate_skill()
	print("[run] skill_t=%.1f slow=%.2f" % [skill_t, enemy_slow])
	await _wait(0.3)
	await _shot("surge")
	# rechargement + chargeur
	player.global_position = Vector3(0, 0.1, 16)
	_set_slow(false)
	player.ammo = 2
	player.reload_t = 0.0
	player.start_reload()
	await _wait(player.W.reload + 0.1)
	var mags: Array = player.flying_mags()
	print("[run] flying mags=%d" % mags.size())
	if mags.size() > 0:
		var d: Vector3 = mags[0].global_position - player.eye_position()
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		player.rotation.y = player.yaw
		player.head.rotation.x = player.pitch
		await get_tree().physics_frame
		player.fire_cd = 0.0
		player.shoot()
		print("[run] mag state=%s style=%d" % [mags[0].state, style])
	# rounds 1 à 4, avec le shop du round 3
	credits = 2000
	for r in 4:
		_clear_round()
		await _wait(0.3)
		await _drain_between("r%d" % wave)
		await _wait(2.6)
		print("[run] now wave=%d state=%s enemies=%d" % [wave, state, enemies.size() + to_spawn.size()])
	# round 5 : mini-boss
	await _wait(1.5)
	print("[run] miniboss=%s name=%s" % [boss != null, boss.T.name if boss else "-"])
	for e in enemies:
		if is_instance_valid(e) and e.type_name == "sniper":
			print("[run] sniper on perch y=%.1f" % e.global_position.y)
	if boss:
		player.global_position = Vector3(0, 0.1, 10)
		await _wait(1.0)
		await _shot("miniboss")
		hacker_glitch(2.0)
		await _wait(0.2)
		await _shot("glitch")
		boss.hp = boss.max_hp * 0.4
		await _wait(0.3)
		print("[run] miniboss phase2=%s" % boss.phase2)
	_clear_round()
	await _wait(0.3)
	await _drain_between("r5")
	# rounds 6 à 9
	for r in 4:
		await _wait(2.6)
		print("[run] wave=%d mix=%s" % [wave, ", ".join(enemies.map(func(e): return e.type_name))])
		if wave == 6:
			await _wait(2.0)
			await _shot("round6")
		_clear_round()
		await _wait(0.3)
		await _drain_between("r%d" % wave)
	# round 10 : boss de zone
	await _wait(3.0)
	print("[run] wave=%d boss=%s" % [wave, boss.T.name if boss else "-"])
	if boss:
		player.global_position = Vector3(0, 0.1, 22)
		player.yaw = 0.0
		player.pitch = 0.1
		await _wait(2.0)
		await _shot("boss")
		boss.hp = boss.max_hp * 0.45
		await _wait(3.5)
		print("[run] boss phase2=%s music=%s collapsed=%s tiles=%d" % [boss.phase2, music.current_key, city.collapsed, city.tiles.filter(func(t): return is_instance_valid(t)).size()])
		await _shot("collapse")
		kill_enemy(boss, {})
		await _wait(0.5)
	print("[run] state=%s level=%d credits=%d score=%d" % [state, level, credits, score])
	await _shot("victory")
	# les deux autres armes : départ, tir, mort
	for w2 in Data.WEAPON_ORDER.slice(1):
		start_with(w2)
		await _wait(2.0)
		for k in 6:
			player.shoot()
			player.fire_cd = 0.0
		print("[%s] ammo=%d wave=%d" % [w2, player.ammo, wave])
		player.hp = 1.0
		player.iframes = 0.0
		hurt_player(10)
		print("[%s] state after death=%s" % [w2, state])
		await _wait(0.3)
	await _shot("over")
	print("AUTOTEST done")
	get_tree().quit()
