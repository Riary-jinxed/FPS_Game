# Horde Breaker : flux d'un run (zones de 10 rounds enchaînées), style, économie, XP, arbre, Surcharge, augments.
extends Node3D

const Data = preload("res://scripts/data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ShotScript = preload("res://scripts/shot.gd")
const ThrownMag = preload("res://scripts/thrown_mag.gd")
const HudScript = preload("res://scripts/hud.gd")
const MusicScript = preload("res://scripts/music.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const KitBase = preload("res://scripts/kit.gd")
const ARENAS := { "city": preload("res://scripts/city.gd"), "foundry": preload("res://scripts/foundry.gd") }
var SAVE := "user://save.cfg"   # les tests utilisent leur propre fichier

var state := "menu" # menu, play, between, paused, over, victory
var player
var hud
var music
var sfx
var city                 # arène de la zone en cours (city.gd, foundry.gd...)
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
var kit                     # kit du perso joué (compétence, grenade, armes spéciales, arbre)
var chosen := "jumeaux"
var best := 0
var best_wave := 0
# méta-progression (sauvegardée entre les runs)
var unlocked := ["kade"]     # persos débloqués
var mastery := {}            # XP de maîtrise par perso
var datas := 0               # Données : monnaie gardée entre les runs
var boom_kills := 0          # kills par explosion au total (succès Démolition)
var unlock_all := false      # mode test : tout est débloqué
var run_xp := 0
var meta_msg := ""
var run_bosses := 0
var _boom_frame := -1
var _boom_n := 0
var pickups: Array = []
var bonus_t := 12.0
var gren_charges := 1           # grenades prêtes
var gren_prog := 0.0            # recharge de la prochaine grenade (0 à 1)
var grenades: Array = []        # grenades en vol { node, vel, life }
var route_trace := false             # prochaine prime sur un point haut de l'arène
var zone_idx := 0
var start_zone := 0
var hazards: Array = []   # flaques de métal { pos, r, life, dps, delay, node, warn }
var rings: Array = []     # ondes de coulée { c, r, spd, max, dmg, delay, hit, node }
var hazard_tick := 0.0
var flood_warned := false
var env: Environment
var sky_mat: ProceduralSkyMaterial
var moon: DirectionalLight3D

# économie et progression du run
var credits := 0
var xp := 0
var level := 1
var points := 0
var tree := {}
var shield := 0.0          # Survie > Bouclier
var calm_t := 0.0          # temps depuis le dernier coup reçu
var armor_t := 0.0         # Survie > Armure d'exécuteur
var second_wind := false   # Survie > Second souffle, déjà utilisé ce round
var surge_hits := {}       # Compétence > Exécution : ennemis touchés pendant Surcharge
var surge_kills := 0       # Compétence > Écho
var tempest_t := 0.0       # Compétence > Tempête : fenêtre de relance gratuite
var slide_hit := {}        # Déplacement > Fauchage / Bolide : ennemis déjà percutés par cette glissade
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
	_load_arena()
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
	_make_kit()
	hud = HudScript.new(); add_child(hud)
	hud.weapon_picked.connect(start_with)
	hud.augment_picked.connect(pick_augment)
	hud.shop_buy.connect(buy)
	hud.tree_pick.connect(pick_tree)
	hud.continue_pressed.connect(next_between)
	hud.resume_pressed.connect(resume)
	hud.retry_pressed.connect(func(): start_with(chosen))
	hud.menu_pressed.connect(to_menu)
	hud.zone_picked.connect(pick_zone)
	hud.char_picked.connect(pick_character)
	if "--autotest" in OS.get_cmdline_user_args() or "--showcase" in OS.get_cmdline_user_args() or "--routes" in OS.get_cmdline_user_args() or "--chars" in OS.get_cmdline_user_args():
		SAVE = "user://save_test.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	hud.unlock_all_toggled.connect(toggle_unlock_all)
	_load_save()
	to_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zone="):
			pick_zone(clampi(int(a.substr(7)) - 1, 0, Data.ZONES.size() - 1))
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()
	elif "--showcase" in OS.get_cmdline_user_args():
		_showcase()
	elif "--routes" in OS.get_cmdline_user_args():
		_routes_only()
	elif "--chars" in OS.get_cmdline_user_args():
		_chars_only()

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
	add.call("skill", [KEY_E, KEY_F], -1, [JOY_BUTTON_Y], [])
	# clic droit : tir secondaire de l'arme quand elle en a un (Harpon, Glu, Mouche), sinon la compétence
	add.call("alt", [], MOUSE_BUTTON_RIGHT, [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	add.call("fire", [], MOUSE_BUTTON_LEFT, [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	add.call("grenade", [KEY_G], MOUSE_BUTTON_MIDDLE, [JOY_BUTTON_RIGHT_SHOULDER], [])
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
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky_mat = sm
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
	moon = DirectionalLight3D.new()
	moon.light_color = Color("9fb4ff")
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-60, 35, 0)
	add_child(moon)

func _apply_zone_env() -> void:
	var E: Dictionary = zone().env
	sky_mat.sky_top_color = E.sky_top
	sky_mat.sky_horizon_color = E.sky_horizon
	sky_mat.ground_horizon_color = E.sky_horizon
	env.fog_light_color = E.fog
	env.fog_density = E.fog_density
	env.ambient_light_color = E.ambient
	env.ambient_light_energy = E.get("ambient_energy", 0.55)
	moon.light_color = E.moon

func _load_arena() -> void:
	# chaque zone a son arène : on remplace l'ancienne
	var want = ARENAS[zone().arena]
	if city != null and city.get_script() == want:
		city.reset()
	else:
		if city != null:
			remove_child(city)
			city.queue_free()
		city = want.new()
		add_child(city)
	_apply_zone_env()

func pick_zone(i: int) -> void:
	start_zone = i
	if state == "menu":
		zone_idx = i
		_load_arena()
		_save()
		to_menu()

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		best = cfg.get_value("game", "best", 0)
		best_wave = cfg.get_value("game", "best_wave", 0)
		unlocked = cfg.get_value("meta", "unlocked", ["kade"])
		mastery = cfg.get_value("meta", "mastery", {})
		datas = cfg.get_value("meta", "datas", 0)
		boom_kills = cfg.get_value("meta", "boom_kills", 0)
		unlock_all = cfg.get_value("meta", "unlock_all", false)
		var ch: String = cfg.get_value("game", "character", "kade")
		if Data.CHARACTERS.has(ch) and char_open(ch):
			character = ch
		var c: String = cfg.get_value("game", "weapon", "jumeaux")
		if c in Data.CHARACTERS[character].weapons and weapon_open(c):
			chosen = c
		else:
			chosen = Data.CHARACTERS[character].weapons[0]
		start_zone = clampi(cfg.get_value("game", "zone", 0), 0, Data.ZONES.size() - 1)
		zone_idx = start_zone
		_load_arena()

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.set_value("game", "best_wave", best_wave)
	cfg.set_value("game", "weapon", chosen)
	cfg.set_value("game", "character", character)
	cfg.set_value("meta", "unlocked", unlocked)
	cfg.set_value("meta", "mastery", mastery)
	cfg.set_value("meta", "datas", datas)
	cfg.set_value("meta", "boom_kills", boom_kills)
	cfg.set_value("meta", "unlock_all", unlock_all)
	cfg.set_value("game", "zone", start_zone)
	cfg.save(SAVE)

func _make_kit() -> void:
	if kit:
		kit.queue_free()
	var path: String = Data.CHARACTERS[character].kit
	kit = (load(path) if path != "" else KitBase).new()
	kit.game = self
	kit.p = player
	add_child(kit)

# ---------- Méta-progression : persos, maîtrise, Données ----------
func char_open(id: String) -> bool:
	return unlock_all or id in unlocked

func mastery_of(id: String) -> int:
	return Data.mastery_level(mastery.get(id, 0))

func weapon_open(wid: String) -> bool:
	for cid in Data.CHARACTERS:
		var list: Array = Data.CHARACTERS[cid].weapons
		var i := list.find(wid)
		if i >= 0:
			return unlock_all or mastery_of(cid) >= Data.WEAPON_MASTERY[i]
	return true

func unlock_char(id: String, why: String) -> void:
	if id in unlocked or not Data.CHARACTERS.has(id):
		return
	unlocked.append(id)
	_save()
	hud.banner(Data.CHARACTERS[id].name + " débloquée" if id != "brack" else "Brack débloqué", why)
	sfx.play("level")

func pick_character(id: String) -> void:
	if state != "menu":
		return
	if not char_open(id):
		if id == "iris" and datas >= Data.IRIS_PRICE:
			datas -= Data.IRIS_PRICE
			unlock_char("iris", "Palier du Terminal acheté")
		else:
			sfx.play("deny")
			return
	character = id
	chosen = Data.CHARACTERS[id].weapons[0]
	_save()
	to_menu()

func toggle_unlock_all() -> void:
	unlock_all = not unlock_all
	if not char_open(character):
		character = "kade"
	if not weapon_open(chosen) or not chosen in Data.CHARACTERS[character].weapons:
		chosen = Data.CHARACTERS[character].weapons[0]
	_save()
	to_menu()

func _menu_chars() -> Array:
	var out := []
	for id in Data.CHARACTER_ORDER:
		var C: Dictionary = Data.CHARACTERS[id]
		var lock := ""
		if not char_open(id):
			lock = C.unlock
			if id == "iris":
				lock += " · %d / %d Données" % [datas, Data.IRIS_PRICE]
		out.append({ "id": id, "name": C.name, "title": C.title, "skill": C.skill, "lock": lock, "mastery": mastery_of(id) })
	return out

func _menu_weapons() -> Array:
	var out := []
	var list: Array = Data.CHARACTERS[character].weapons
	for i in list.size():
		var w: Dictionary = Data.WEAPONS[list[i]]
		out.append({ "id": w.id, "w": w, "lock": "" if weapon_open(w.id) else "Maîtrise %d" % Data.WEAPON_MASTERY[i] })
	return out

func _meta_text() -> String:
	return "Maîtrise de %s : niveau %d · Données : %d" % [Data.CHARACTERS[character].name, mastery_of(character), datas]

func _end_run_meta() -> String:
	# maîtrise du perso, Données gagnées, déblocages
	var before := mastery_of(character)
	mastery[character] = mastery.get(character, 0) + run_xp
	var gain := score / 100 + 40 * run_bosses
	datas += gain
	var msg := "+%d Données" % gain
	var after := mastery_of(character)
	if after > before:
		msg += " · maîtrise de %s niveau %d" % [Data.CHARACTERS[character].name, after]
		var list: Array = Data.CHARACTERS[character].weapons
		for i in list.size():
			if before < Data.WEAPON_MASTERY[i] and after >= Data.WEAPON_MASTERY[i]:
				msg += " · %s débloquée" % Data.WEAPONS[list[i]].name
	run_xp = 0
	run_bosses = 0
	return msg

func zone() -> Dictionary:
	return Data.ZONES[zone_idx]

# ---------- Flux de partie ----------
func to_menu() -> void:
	state = "menu"
	_set_slow(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_cam.current = true
	hud.show_menu(Data.CHARACTERS[character], _menu_chars(), _menu_weapons(), chosen, best, best_wave, Data.ZONES, start_zone, _meta_text(), unlock_all)
	music.play("menu")

func start_with(id: String) -> void:
	if not weapon_open(id):
		sfx.play("deny")
		return
	if not id in Data.CHARACTERS[character].weapons:
		# arme d'un autre perso (test auto, vitrine) : on prend son perso
		for cid in Data.CHARACTERS:
			if id in Data.CHARACTERS[cid].weapons:
				character = cid
	chosen = id
	_save()
	reset_game()
	begin()

func reset_game() -> void:
	for c in world.get_children():
		c.queue_free()
	enemies.clear()
	pickups.clear()
	bonus_t = 12.0
	gren_charges = 1
	gren_prog = 0.0
	grenades.clear()
	boss = null
	up = Data.BASE_UP.duplicate()
	taken = {}
	tree = {}
	shield = 0.0; calm_t = 0.0; armor_t = 0.0; second_wind = false
	surge_hits = {}; surge_kills = 0; tempest_t = 0.0; slide_hit = {}
	between = []
	weapon_level = 1
	credits = 0; xp = 0; level = 1; points = 0
	run_xp = 0; run_bosses = 0
	skill_t = 0.0
	_set_slow(false)
	glitch_t = 0.0
	player.reset(Data.WEAPONS[chosen])
	_make_kit()
	var CH: Dictionary = Data.CHARACTERS[character]
	up.max_hp = CH.hp
	up.speed = CH.speed
	player.hp = up.max_hp
	wave = 0; cleared = 0; score = 0; kills = 0; to_spawn = []; intermission = 1.5
	style = 0.0; chain = 0; best_rank = 0; recent_kills = []
	zone_idx = start_zone
	_clear_hazards()
	_load_arena()
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
	meta_msg = _end_run_meta()
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
	hud.show_over(wave, kills, Data.RANKS[best_rank][0], score, level, meta_msg)

func victory() -> void:
	state = "victory"
	music.play("victory")
	_end_run()
	hud.show_victory(zone().name, kills, Data.RANKS[best_rank][0], score, level, credits, meta_msg)

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
			if state == "menu" and i < Data.CHARACTERS[character].weapons.size():
				start_with(Data.CHARACTERS[character].weapons[i])
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
	second_wind = false
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

func spawn_pos(min_dist := 18.0, fly := false, radius := 0.9, height := 2.2) -> Vector3:
	# position libre : jamais dans le décor (murs de pub, tours, plateformes), jamais au-dessus de la fosse
	var p := Vector3.ZERO
	var best := Vector3.ZERO
	var found := false
	for tries in 40:
		var a := randf() * TAU
		var d := 14.0 + randf() * 23.0
		p = Vector3(clampf(cos(a) * d, -36.0, 36.0), 0.05, clampf(sin(a) * d, -36.0, 36.0))
		if fly:
			p.y = 5.0 + randf() * 3.0
		if not is_free(p, radius, height) or (not fly and city.over_pit(p)):
			continue
		best = p
		found = true
		if p.distance_to(player.global_position) >= min_dist:
			return p
	if found:
		return best
	return Vector3(0, p.y, -24) if not city.over_pit(Vector3(0, 0, -24)) else Vector3(0, p.y, -34)

func is_free(p: Vector3, radius := 0.9, height := 2.2) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = radius + 0.25
	shape.height = maxf(height, shape.radius * 2.0 + 0.1)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	# le bas de la capsule reste 0.25 au-dessus du sol pour ne pas compter la dalle
	q.transform = Transform3D(Basis(), p + Vector3(0, shape.height / 2.0 + 0.25, 0))
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _free_slot(type: String, slots: Array, max_n: int) -> Variant:
	# poste libre pour un ennemi fixe (sniper sur un toit, bras mécanique sur un socle)
	var used := []
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.type_name == type:
			used.append(e.get_meta("slot"))
	if used.size() >= max_n:
		return null
	var free := []
	for i in slots.size():
		if not i in used:
			free.append(i)
	return null if free.is_empty() else free[randi() % free.size()]

func spawn_enemy(type: String, mult: float) -> void:
	var slot = null
	var slots: Array = []
	if type == "sniper":
		slots = city.perches
		slot = _free_slot(type, slots, Data.MAX_SNIPERS)
		if slot == null:
			type = "spitter"
	elif type == "arm":
		slots = city.anchors
		slot = _free_slot(type, slots, Data.MAX_ARMS)
		if slot == null:
			type = "furnace"
	var e = EnemyScript.new()
	var t: Dictionary = Data.ENEMIES[type].duplicate()
	e.setup(self, type, t, mult * (1.0 + Data.ZONE_HP * zone_idx))
	e.speed = t.speed * (0.9 + randf() * 0.25) * minf(1.3, 1.0 + wave * 0.02)
	world.add_child(e)
	if slot != null:
		e.set_meta("slot", slot)
		e.global_position = slots[slot] + Vector3(0, 0.05, 0)
		e.facing = randf() * TAU
		e.arm_angle = randf() * TAU
	else:
		e.global_position = spawn_pos(18.0, t.get("fly", false), t.r, t.h)
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
	if wave >= Data.BOSS_ROUND and zone_idx + 1 >= Data.ZONES.size():
		victory()
		return
	between = []
	# un augment offert après chaque boss (mini-boss et boss de zone)
	if wave == Data.MINIBOSS_ROUND or wave >= Data.BOSS_ROUND:
		between.append("augment")
	if wave in Data.SHOP_ROUNDS:
		between.append("shop")
	between.append("tree")
	if wave >= Data.BOSS_ROUND:
		between.append("zone")
	next_between()

func next_zone() -> void:
	# zone suivante : nouvelle arène, les rounds repartent de 1, le build et les crédits restent
	zone_idx += 1
	for c in world.get_children():
		c.queue_free()
	enemies.clear()
	pickups.clear()
	_clear_hazards()
	boss = null
	_load_arena()
	wave = 0; cleared = 0; to_spawn = []; intermission = 3.0
	player.global_position = Vector3(0, 0.1, 16)
	player.velocity = Vector3.ZERO
	player.hp = up.max_hp
	music.set_zone(zone_idx + 1)
	begin()
	hud.banner("Zone %d" % (zone_idx + 1), zone().name)
	sfx.play("level")

func next_between() -> void:
	# enchaîne les écrans de fin de round : augment offert, shop, arbre (s'il reste des points)
	while not between.is_empty():
		var s: String = between.pop_front()
		if s == "tree" and points <= 0:
			continue
		if s == "zone":
			next_zone()
			return
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
			_end_surge()
	kit.tick(delta)
	tempest_t = maxf(0.0, tempest_t - delta)
	armor_t = maxf(0.0, armor_t - delta)
	calm_t += delta
	if tree.has("v_s1") and calm_t > 4.0:
		shield = minf(25.0, shield + 12.0 * delta)
	_slide_hits()
	if glitch_t > 0.0:
		glitch_t -= delta
	_update_pads(delta)
	city.tick(delta)
	_update_hazards(delta)
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
	_update_bonus(delta)
	_update_grenades(delta)
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
			if pad.has("on_launch"):
				pad.on_launch.call()
			sfx.play("pad")
			var tw: Tween = pad.ring.create_tween()
			tw.tween_property(pad.ring, "scale", Vector3.ONE * 1.8, 0.15)
			tw.tween_property(pad.ring, "scale", Vector3.ONE, 0.25)
			return

func _update_bonus(delta: float) -> void:
	# une prime sur un point haut (passerelle, puits) toutes les ~18 s : le mouvement rapporte
	bonus_t -= delta
	if bonus_t > 0.0 or city.bonus_spots.is_empty():
		return
	bonus_t = randf_range(15.0, 21.0)
	if pickups.filter(func(pk): return pk.kind == "bonus").size() >= 2:
		return
	var spots: Array = city.bonus_spots.filter(func(s): return pickups.all(func(pk): return Vector2(pk.node.position.x - s.x, pk.node.position.z - s.z).length() > 2.0))
	if spots.is_empty():
		return
	var s: Vector3 = spots[randi() % spots.size()]
	_drop_pickup(s, "bonus", s.y)
	hud.add_feed("PRIME EN HAUTEUR", true)

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
				"bonus":
					credits += 30
					player.hp = minf(up.max_hp, player.hp + 20.0)
					add_style("PRIME", 120.0, true)
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
	var sk := { "pct": 100.0 * skill_t / (Data.CHARACTERS[character].skill_time + up.skill_time) if skill_t > 0.0 else player.skill, "txt": skill_txt, "ready": player.skill >= 100.0 or skill_t > 0.0 }
	if kit.custom_skill():
		sk = kit.skill_hud()
	hud.update_hud({
		"hp": str(maxi(0, ceili(player.hp))) + (" +%d" % roundi(shield) if shield >= 1.0 else ""), "hp_pct": 100.0 * player.hp / up.max_hp,
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
		"skill_pct": sk.pct, "skill_txt": sk.txt, "skill_ready": sk.ready,
		"gren_txt": "%s  %s%s  · G" % [grenade().name.to_upper(), "● ".repeat(gren_charges), "○ ".repeat(gren_max() - gren_charges)],
		"gren_pct": 100.0 if gren_charges >= gren_max() else 100.0 * gren_prog, "gren_ready": gren_charges > 0,
		"gren_rate": "×%.1f" % gren_rate(),
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
	enemy_slow = (0.4 if tree.has("s_r1") else 0.55) if on else 1.0
	if not on:
		skill_t = 0.0
	if hud:
		hud.set_surge(on)

func _end_surge() -> void:
	var was_free := tempest_t < 0.0
	_set_slow(false)
	if tree.has("s_r4"):
		# Exécution : tous les ennemis touchés pendant Surcharge prennent un gros coup
		for e in surge_hits.keys():
			if is_instance_valid(e) and e.alive:
				shockwave(e.center(), Color("3fd0c9"), 2.0)
				damage_enemy(e, (60.0 + 8.0 * wave) * (1.0 + Data.ZONE_HP * zone_idx), e.center(), { "src": "boom" })
	surge_hits = {}
	if tree.has("s_d3") and surge_kills >= 5:
		player.skill = maxf(player.skill, 50.0)
		hud.add_feed("ÉCHO · 50 %", true)
	if tree.has("s_d4") and not was_free:
		tempest_t = 10.0

func _slide_hits() -> void:
	# Fauchage : la glissade renverse les petits ennemis. Bolide : après une roulade, elle blesse tout.
	var ram: bool = player.recoil_t > 0.0 and tree.has("w_b2")
	if player.slide_t <= 0.0 and not ram:
		slide_hit = {}
		return
	var bolide: bool = (tree.has("m_g4") and player.bolide and player.slide_t > 0.0) or ram
	var pp: Vector3 = player.global_position
	for e in enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or slide_hit.has(e):
			continue
		var d := Vector2(e.global_position.x - pp.x, e.global_position.z - pp.z).length()
		if d > e.T.r + 1.2 or absf(e.global_position.y - pp.y) > 1.5:
			continue
		if bolide:
			slide_hit[e] = true
			damage_enemy(e, (55.0 + 6.0 * wave) * (1.0 + Data.ZONE_HP * zone_idx), e.center(), { "src": "boom" })
		elif tree.has("m_g2") and not e.is_boss and Data.ENEMIES.get(e.type_name, {}).get("hp", 999.0) <= 40.0:
			slide_hit[e] = true
			damage_enemy(e, 40.0, e.center(), { "src": "boom" })
			knockback(e, Vector3(e.global_position.x - pp.x, 0, e.global_position.z - pp.z), 3.0)

func knockback(e, dir: Vector3, dist: float) -> void:
	if not is_instance_valid(e) or not e.alive or e.is_boss or dir.length() < 0.01:
		return
	var to: Vector3 = e.global_position + dir.normalized() * dist
	if is_free(to, e.T.r, e.T.h) and not city.over_pit(to):
		e.global_position = to

func activate_skill() -> void:
	if state != "play" or skill_t > 0.0:
		return
	if kit.custom_skill():
		if kit.active > 0.0:
			return
		if player.skill < 100.0:
			sfx.play("deny")
			return
		player.skill = 0.0
		sfx.play("skill")
		hud.flash(Data.CHARACTERS[character].color, 0.8)
		hud.add_feed(Data.CHARACTERS[character].skill.to_upper(), true)
		shake = maxf(shake, 0.4)
		kit.activate()
		return
	var free := tempest_t > 0.0
	if player.skill < 100.0 and not free:
		sfx.play("deny")
		return
	if free:
		# Tempête : la relance gratuite ne marche qu'une fois
		tempest_t = 0.0
		hud.add_feed("TEMPÊTE", true)
	else:
		player.skill = 0.0
	surge_hits = {}
	surge_kills = 0
	skill_t = Data.CHARACTERS[character].skill_time + up.skill_time
	_set_slow(true)
	player.ammo = player.W.mag
	player.reload_t = 0.0
	sfx.play("skill")
	hud.flash(Color("3fd0c9"), 0.8)
	hud.add_feed("SURCHARGE", true)
	shake = maxf(shake, 0.4)
	if tree.has("s_d1"):
		var c: Vector3 = player.global_position + Vector3(0, 1, 0)
		shockwave(c, Color("3fd0c9"), 9.0)
		for e in enemies.duplicate():
			if is_instance_valid(e) and e.alive and e.center().distance_to(c) < 9.0:
				damage_enemy(e, 50.0 + 6.0 * wave, e.center(), { "src": "boom" })

# ---------- Grenade (consommable du perso) ----------
func grenade() -> Dictionary:
	return Data.CHARACTERS[character].grenade

func gren_max() -> int:
	return (2 if tree.has("s_g1") else 1) + kit.gren_max_bonus()

func gren_rate() -> float:
	# recharge plus rapide avec une bonne note de style : ×1 en D, ×2 en S, ×2,5 en SSS
	return (1.0 + 0.25 * rank_idx()) * (1.25 if tree.has("s_t1") else 1.0) * kit.gren_rate_mult()

func throw_grenade() -> void:
	if state != "play":
		return
	if gren_charges <= 0:
		sfx.play("deny")
		return
	gren_charges -= 1
	var G := grenade()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.32
	mi.mesh = sm
	mi.material_override = _unshaded(Color(G.color), 4.0)
	world.add_child(mi)
	var fwd: Vector3 = -player.head.global_transform.basis.z
	mi.global_position = player.eye_position() + fwd * 0.6
	var v: Vector3 = fwd * 24.0 + Vector3(0, 3.5, 0) + player.velocity * 0.4
	grenades.append({ "node": mi, "vel": v, "life": 2.5 })
	sfx.play("dash")

func _update_grenades(delta: float) -> void:
	if gren_charges < gren_max():
		gren_prog += delta * gren_rate() / grenade().cd
		if gren_prog >= 1.0:
			gren_charges += 1
			gren_prog = 0.0
			sfx.play("ping")
	else:
		gren_prog = 0.0
	var space := get_world_3d().direct_space_state
	for g in grenades.duplicate():
		var n: Node3D = g.node
		g.vel.y -= 22.0 * delta
		g.life -= delta
		var a := n.global_position
		var b: Vector3 = a + g.vel * delta
		var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 2)
		var hit := space.intersect_ray(q)
		if hit or g.life <= 0.0:
			var p: Vector3 = hit.position + hit.normal * 0.2 if hit else a
			grenades.erase(g)
			n.queue_free()
			_grenade_blast(p, 1.0)
		else:
			n.global_position = b

func _grenade_blast(p: Vector3, scale: float) -> void:
	if kit.custom_grenade():
		kit.grenade_blast(p, scale)
		return
	var G := grenade()
	var r: float = G.radius * (1.4 if tree.has("s_g2") else 1.0) * scale
	var col := Color(G.color)
	shockwave(p, col, r)
	burst(p, col, int(30 * scale), 13.0)
	sfx.play("boom")
	shake = maxf(shake, 0.7 * scale)
	var dmg: float = (G.dmg + 9.0 * wave) * scale
	var hits := 0
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.alive and e.center().distance_to(p) < r + e.T.r:
			var away: Vector3 = e.global_position - p
			damage_enemy(e, dmg * 1.5 if e.is_boss else dmg, e.center(), { "src": "boom" })
			knockback(e, Vector3(away.x, 0, away.z), 3.0 * scale)
			hits += 1
	if hits > 0 and scale >= 1.0:
		add_style("IMPULSION" if hits < 3 else "IMPULSION ×%d" % hits, 20.0 * hits)
	# grenade jump : le souffle propulse le joueur, sans le blesser
	var pc: Vector3 = player.global_position + Vector3(0, 0.9, 0)
	if scale >= 1.0 and pc.distance_to(p) < r * 0.9:
		var push := pc - p
		push.y = 0.0
		var hv := push.normalized() * 7.0 if push.length() > 0.2 else Vector3.ZERO
		player.velocity = Vector3(player.velocity.x + hv.x, maxf(player.velocity.y, 0.0) + 13.0, player.velocity.z + hv.z)
		player.jumps = 1
		add_style("ENVOL", 25.0)
	if tree.has("s_g4") and scale >= 1.0:
		# Fragmentation : 5 éclats qui retombent autour et explosent à leur tour
		for k in 5:
			var a := k * TAU / 5.0 + randf() * 0.4
			var to := p + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.8, 1.3)
			to.y = maxf(0.3, p.y - 0.5)
			get_tree().create_timer(0.3 + k * 0.06, false).timeout.connect(func(): _grenade_blast(to, 0.45))

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
			kit.on_dodge()
		return false
	if kit.on_hurt_check(d):
		return false
	d *= kit.hurt_mult(d)
	if tree.has("s_r2") and skill_t > Data.CHARACTERS[character].skill_time + up.skill_time - 1.0:
		return false
	if tree.has("v_r3") and player.roll_grace > 0.0:
		d *= 0.5
	if armor_t > 0.0:
		d *= 0.5
	calm_t = 0.0
	if shield > 0.0:
		var absorbed := minf(shield, d)
		shield -= absorbed
		d -= absorbed
		if d <= 0.0:
			sfx.play("click")
			return true
	if tree.has("v_s4") and not second_wind and player.hp - d <= 0.0:
		# Second souffle : une fois par round, on survit au coup fatal
		second_wind = true
		player.hp = 1.0
		player.iframes = 1.0
		hud.banner("Second souffle", "")
		sfx.play("level")
		return true
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
	hud.banner("Phase 2", city.phase2_text)
	city.collapse()

func damage_enemy(en, dmg: float, at: Vector3, ctx := {}) -> void:
	if not is_instance_valid(en) or not en.alive:
		return
	if en.reform_t > 0.0:
		# golem en train de se reformer : les tirs ricochent
		burst(at, Color("9aa8bd"), 2, 3.0)
		return
	if ctx.get("src", "") == "gun" and ctx.has("from") and en.blocks(ctx.from):
		# bouclier frontal : il faut le contourner, passer au-dessus ou le faire exploser
		dmg *= 0.1
		burst(at, Color("bffcff"), 2, 3.0)
		if shield_ping <= 0.0:
			shield_ping = 0.15
			sfx.play("click")
	if skill_t > 0.0:
		surge_hits[en] = true
	dmg *= kit.dmg_mult(en, ctx)
	en.hp -= dmg
	en.flash_t = 0.08
	if not ctx.get("quiet", false):
		burst(at, en.T.color, 4 if en.is_boss else 3, 4.0)
	if en.hp <= 0.0:
		kill_enemy(en, ctx)

func kill_enemy(en, ctx: Dictionary) -> void:
	if not en.alive:
		return
	if en.T.get("reform", false) and not en.reformed:
		# golem de scories : il s'effondre puis se reforme une fois
		en.start_reform()
		burst(en.center(), en.T.color, 14, 7.0)
		add_style("BRISÉ", 15)
		sfx.play("boom")
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
	var m4: float = 1.5 if tree.has("m_a4") else 1.0
	if player.wallrun_t > 0.0: add_style("KILL MURAL", 50 * m4, true)
	elif aerial: add_style("KILL AÉRIEN", 45 * m4, true)
	if aerial and tree.has("m_a4"):
		player.roll_cd = 0.0
	_tree_on_kill(en, c, ctx, aerial)
	kit.on_kill(en, c, ctx, aerial)
	if player.roll_t > 0.0 or player.roll_grace > 0.0: add_style("ROULADE MORTELLE", 40, true)
	if player.slide_t > 0.0: add_style("GLISSADE", 40, true)
	match src:
		"mag": add_style("JONGLEUR", 35)
		"ric": add_style("RICOCHET", 25)
		"boom": add_style("RÉACTION EN CHAÎNE", 20)
		"fall": add_style("CHUTE", 30)
	if skill_t > 0.0:
		surge_kills += 1
		if tree.has("s_r3"):
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
	if src in ["boom", "mag", "dot"]:
		boom_kills += 1
		var f := Engine.get_physics_frames()
		_boom_n = _boom_n + 1 if f == _boom_frame else 1
		_boom_frame = f
		if (_boom_n >= Data.BRACK_BLAST or boom_kills >= Data.BRACK_TOTAL) and not "brack" in unlocked:
			unlock_char("brack", "Succès Démolition")
	if en.is_boss:
		run_bosses += 1
		if not en.is_mini and zone_idx >= 1:
			unlock_char("nyx", "Boss de la Fonderie vaincu")
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
			city.calm()
			_clear_hazards()
			to_spawn.clear()
			for o in enemies.duplicate():
				if is_instance_valid(o) and o.alive:
					o.reformed = true
					kill_enemy(o, { "src": "boom" })
	elif randf() < 0.07:
		_drop_pickup(c)

func _tree_on_kill(en, c: Vector3, ctx: Dictionary, aerial: bool) -> void:
	var close: bool = c.distance_to(player.global_position + Vector3(0, 1, 0)) < 4.0
	var leech := 2.0 if tree.has("v_r4") and player.hp < up.max_hp * 0.25 else 1.0
	if close and tree.has("w_t1"):
		player.ammo = player.W.mag
		player.reload_t = 0.0
	if close and tree.has("w_b3"):
		player.ammo = mini(player.W.mag, player.ammo + 1)
	if close and tree.has("v_r2"):
		player.hp = minf(up.max_hp, player.hp + 4.0 * leech)
	if aerial and tree.has("s_g3"):
		gren_prog += 2.0 / grenade().cd
	if aerial and tree.has("v_t2"):
		player.hp = minf(up.max_hp, player.hp + 5.0 * leech)
	if ctx.get("head", false) and tree.has("v_s2"):
		armor_t = 2.0
	if ctx.get("exec", false) and tree.has("w_v4"):
		# Sentence : l'exécution fait exploser la cible
		shockwave(c, Color("3fd0c9"), 4.0)
		burst(c, Color("3fd0c9"), 20, 10.0)
		sfx.play("boom")
		for o in enemies.duplicate():
			if is_instance_valid(o) and o.alive and o != en and o.center().distance_to(c) < 4.0:
				damage_enemy(o, 50.0 + 6.0 * wave, o.center(), { "src": "boom" })

func dmg_bonus() -> float:
	# bonus de dégâts de l'arbre, lu par player.shoot
	var m := 1.0
	if tree.has("v_r1") and player.hp < up.max_hp * 0.5:
		m *= 1.25
	if tree.has("v_r4") and player.hp < up.max_hp * 0.25:
		m *= 1.4
	return m

func gain_xp(n: int) -> void:
	xp += n
	run_xp += n
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
	if tree.has("s_d2") and skill_t > 0.0:
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

# ---------- Dangers au sol (fonderie) ----------
func add_puddle(pos: Vector3, r: float, life: float, dps: float, delay := 0.0) -> void:
	# flaque de métal en fusion, précédée d'un cercle d'alerte quand elle tombe du ciel
	var ground := Vector3(pos.x, 0.0, pos.z)
	var q := PhysicsRayQueryParameters3D.create(Vector3(pos.x, pos.y + 1.0, pos.z), Vector3(pos.x, pos.y - 30.0, pos.z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		ground = hit.position
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = 0.06
	mi.mesh = cm
	var m := _unshaded(Color("ff7a1a"), 3.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = ground + Vector3(0, 0.04, 0)
	if delay > 0.0:
		m.albedo_color = Color(1.0, 0.48, 0.1, 0.25)
		mi.scale = Vector3(1, 0.3, 1)
	hazards.append({ "pos": ground, "r": r, "life": life, "dps": dps, "delay": delay, "node": mi, "mat": m })

func add_ring(center: Vector3, spd: float, max_r: float, dmg: float, delay := 0.0) -> void:
	# onde de coulée qui s'étend au sol : il faut sauter par-dessus
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.82; tm.outer_radius = 1.0; tm.rings = 48
	mi.mesh = tm
	mi.material_override = _unshaded(Color("ff7a1a"), 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = delay <= 0.0
	world.add_child(mi)
	mi.global_position = Vector3(center.x, 0.25, center.z)
	rings.append({ "c": Vector3(center.x, 0.0, center.z), "r": 1.0, "spd": spd, "max": max_r, "dmg": dmg, "delay": delay, "hit": false, "node": mi })

func _clear_hazards() -> void:
	for h in hazards + rings:
		if is_instance_valid(h.node):
			h.node.queue_free()
	hazards.clear()
	rings.clear()
	flood_warned = false

func _update_hazards(delta: float) -> void:
	var d := delta * enemy_slow
	var pp: Vector3 = player.global_position
	var dps := 0.0
	for h in hazards.duplicate():
		if h.delay > 0.0:
			h.delay -= d
			h.mat.albedo_color.a = 0.25 + 0.3 * sin(gt * 20.0) * sin(gt * 20.0)
			if h.delay <= 0.0:
				h.node.scale = Vector3.ONE
				h.mat.albedo_color = Color(1.0, 0.48, 0.1, 0.95)
				burst(h.pos + Vector3(0, 0.3, 0), Color("ff7a1a"), 8, 5.0)
			continue
		h.life -= d
		if h.life < 1.0:
			h.mat.albedo_color.a = maxf(0.0, h.life) * 0.95
		if h.life <= 0.0:
			h.node.queue_free()
			hazards.erase(h)
			continue
		if Vector2(pp.x - h.pos.x, pp.z - h.pos.z).length() < h.r and pp.y - h.pos.y < 0.6:
			dps = maxf(dps, h.dps)
	for g in rings.duplicate():
		if g.delay > 0.0:
			g.delay -= d
			g.node.visible = g.delay <= 0.0
			continue
		g.r += g.spd * d
		g.node.scale = Vector3(g.r, 1.0, g.r)
		var hd := Vector2(pp.x - g.c.x, pp.z - g.c.z).length()
		if not g.hit and absf(hd - g.r) < 0.8 and pp.y < 0.9:
			g.hit = true
			hurt_player(g.dmg)
		if g.r >= g.max:
			g.node.queue_free()
			rings.erase(g)
	dps = maxf(dps, city.hazard_at(pp, player.is_on_floor()))
	var warn: bool = city.has_method("flood_warning") and city.flood_warning()
	if warn and not flood_warned:
		hud.banner("La coulée arrive", "Monte en hauteur")
		sfx.play("charge")
	flood_warned = warn
	hazard_tick -= delta
	if dps > 0.0 and hazard_tick <= 0.0:
		hazard_tick = 0.3
		hurt_player(dps * 0.3, true)

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

func _drop_pickup(pos: Vector3, kind := "", ground := -100.0) -> void:
	if kind == "":
		var r := randf()
		kind = "hp" if r < 0.5 else ("cr" if r < 0.8 else "ammo")
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.5, 0.5, 0.5)
	mi.mesh = pm
	var col := { "hp": Color("3fd0c9"), "cr": Color("ffc23d"), "ammo": Color("ff4fa3"), "bonus": Color("ffe14f") }
	mi.material_override = _unshaded(col[kind], 3.0)
	world.add_child(mi)
	var y := maxf(0.0, pos.y - 0.6) if pos.y < 9.5 else 9.0
	if ground > -100.0:
		y = ground
	var life := 15.0
	if kind == "bonus":
		mi.scale = Vector3.ONE * 1.6
		life = 14.0
	mi.global_position = Vector3(pos.x, y + 0.8, pos.z)
	pickups.append({ "node": mi, "kind": kind, "life": life, "y": y })

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
		"barrel": W.spread *= 0.7
		"trigger": W.rate /= 1.12
		"bolt": W.reload *= 0.8
		"ext": W.mag = roundi(W.mag * 1.25); player.ammo = W.mag
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
		"j_drum": W.mag = roundi(W.mag * 1.4); player.ammo = W.mag
		"j_rate": W.rate /= 1.2
		"b_pellets": W.pellets += 4
		"b_kick": up.recoil_mult = up.get("recoil_mult", 1.0) * 1.3
		"v_dmg": W.dmg *= 1.25
		"v_speed": W.reload *= 0.7

# ---------- Shop (après les rounds 3, 6 et 9) ----------
func open_shop() -> void:
	music.play("shop")
	shop_offers = []
	var n_taken := 0
	for id in taken:
		n_taken += taken[id]
	for a in _roll_augments(2):
		shop_offers.append({ "kind": "aug", "id": a.id, "name": a.name, "desc": a.desc, "tag": player.W.name if a.has("weapon") else "Augment · " + a.tag, "price": Data.AUG_PRICE + 15 * n_taken, "data": a })
	var others: Array = Data.GENERICS.filter(func(g): return g != player.W.id)
	if not others.is_empty():
		var gid: String = others[randi() % others.size()]
		var GW: Dictionary = Data.WEAPONS[gid]
		shop_offers.append({ "kind": "weapon", "id": gid, "name": GW.name, "desc": GW.blurb + " Remplace ton arme actuelle (augments communs gardés).", "tag": "Arme générique", "price": Data.WEAPON_PRICE + 40 * zone_idx })
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
		"weapon":
			_swap_weapon(o.id)
		"upgrade":
			weapon_level += 1
			W.dmg *= 1.15
			W.mag = roundi(W.mag * 1.1)
			player.ammo = W.mag
		"heal":
			player.hp = minf(up.max_hp, player.hp + (40.0 if o.id == "heal_s" else up.max_hp))
	_refresh_shop()

func _swap_weapon(id: String) -> void:
	# nouvelle arme : on repart de ses stats, puis on réapplique le niveau d'arme et les augments
	# communs ou propres à cette arme (ceux d'une autre arme sont perdus)
	var W: Dictionary = Data.WEAPONS[id].duplicate(true)
	player.set_weapon(W)
	for k in weapon_level - 1:
		W.dmg *= 1.15
		W.mag = roundi(W.mag * 1.1)
	for a in Data.AUGMENTS:
		if not taken.has(a.id) or (a.has("weapon") and a.weapon != id):
			continue
		if a.id in ["speed", "roll", "slide", "jump", "hp", "leech", "regen", "boom", "greed", "juggle", "show"]:
			continue # effets sur le perso, déjà appliqués
		for k in taken[a.id]:
			apply_augment(a.id)
	player.ammo = W.mag
	hud.banner(W.name, "Nouvelle arme")

# ---------- Arbre de compétences ----------
func open_tree() -> void:
	music.play("augment")
	hud.show_tree(Data.CHARACTERS[character], Data.TREE[character], Data.tree_nodes(character), tree, points, level, player.W.id)

func can_take(id: String) -> bool:
	for n in Data.tree_nodes(character):
		if n.id == id:
			# les sous-branches d'arme ne servent qu'avec cette arme
			if n.weapon != "" and n.weapon != player.W.id:
				return false
			return not tree.has(id) and (n.req == "" or tree.has(n.req))
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
		"w_t2": up.mag_boom += 0.4
		"w_b1": W.mag += 1; player.ammo = W.mag
		"s_t1": up.skill_gain *= 1.25
		"s_t2": up.skill_time += 2.0
		"v_t1": up.max_hp += 25.0; player.hp += 25.0
		"v_s1": shield = 25.0
		"v_s3": up.regen += 1.0
		"m_t1": up.wallrun *= 1.5
		"m_t2": up.roll_cd *= 0.8
		"m_g1": up.speed *= 1.08
	kit.apply_node(id)
	# les autres nœuds sont lus directement dans tree (main.gd et player.gd) ou par le kit du perso
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
			e.reformed = true
			kill_enemy(e, {})

func _advance_to(w: int, tag: String) -> void:
	# nettoie les rounds jusqu'à atteindre le round w
	var guard := 0
	while wave < w and guard < 20:
		guard += 1
		_clear_round()
		await _wait(0.3)
		await _drain_between("%s%d" % [tag, wave])
		await _wait(2.6)
		if wave < w and wave >= 6 and wave <= 9:
			print("[z2] wave=%d mix=%s" % [wave, ", ".join(enemies.map(func(e): return e.type_name))])

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
				for n in Data.tree_nodes(character):
					if points > 0 and can_take(n.id):
						pick_tree(n.id)
				print("[%s] tree=%s" % [tag, tree.keys()])
				if state == "between" and screen == "tree":
					next_between()
		await _wait(0.2)

func _showcase() -> void:
	# captures des armes, puis des ennemis et des boss figés devant la caméra
	await _wait(1.0)
	for w in (Data.WEAPON_ORDER + Data.GENERICS if zone_idx == 0 else ["verdict"]):
		start_with(w)
		_clear_round()
		player.global_position = Vector3(-30, 0.1, 10)
		player.yaw = -PI / 2
		await _wait(0.4)
		await _shot("gun_" + w)
	start_with("verdict")
	await _wait(0.2)
	_clear_round()
	wave = 1; cleared = 1; intermission = 999.0
	if zone().arena == "foundry":
		await _route_shots(Vector3(-14, 7.0, 38.5), Vector3(21, 4, 18), Vector3(20.3, 5.0, 11.0), PI, 0.45)
	else:
		await _route_shots(Vector3(-16.5, 8.5, -14), Vector3(0, 5, -33), Vector3(10.0, 7.5, 30.3), -PI / 2, -0.45)
	_clear_round()
	player.hp = 1e9
	enemy_slow = 0.0
	player.global_position = Vector3(0, 0.1, 17)
	player.yaw = 0.0
	player.pitch = 0.02
	var types := ["grunt", "runner", "brute", "spitter", "shield", "hacker", "sniper", "drone", "pub"]
	if zone().arena == "foundry":
		types = ["grunt", "runner", "furnace", "golem", "brute", "shield", "spitter", "drone", "arm"]
	for i in types.size():
		spawn_enemy(types[i], 1.0)
		var e = enemies[-1]
		e.spawn_t = 0.0
		e.arm_angle = -PI / 2.0
		e.global_position = Vector3(-10.0 + i * 2.5, 2.2 if Data.ENEMIES[types[i]].get("fly", false) else 0.05, 9.0)
		if types[i] == "arm":
			e.global_position = Vector3(10.0, 0.05, 4.0)
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
	# écran de l'arbre en flocon, avec quelques nœuds pris
	for id in ["w_t1", "w_t2", "w_v1", "s_t1", "s_t2", "s_d1", "s_g1", "v_t1", "m_t1", "m_t2", "m_a1", "m_a2"]:
		tree[id] = true
	state = "between"; screen = "tree"; points = 4; level = 12
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	open_tree()
	await _wait(0.3)
	await _shot("tree")
	get_tree().quit()

func _route_shots(view: Vector3, target: Vector3, run_from: Vector3, run_yaw: float, turn: float) -> void:
	# vue d'ensemble des parcours (avec des primes posées), puis un wall run sur panneau en cours
	for s in city.bonus_spots:
		_drop_pickup(s, "bonus", s.y)
	player.global_position = view
	player.velocity = Vector3.ZERO
	var d := target - (view + Vector3(0, 1.6, 0))
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	player.forced_intent = { "move": Vector2.ZERO, "look": Vector2.ZERO, "jump": false, "roll": false, "slide": false, "reload": false, "skill": false, "fire": false }
	await _wait(0.6)
	await _shot("routes")
	player.global_position = run_from
	player.yaw = run_yaw
	player.pitch = 0.05
	player.velocity = Vector3(0, 0, -12).rotated(Vector3.UP, run_yaw) + Vector3(0, 6.0, 0)
	player.forced_intent = { "move": Vector2(0, -1), "look": Vector2.ZERO, "jump": false, "roll": false, "slide": false, "reload": false, "skill": false, "fire": false }
	await _wait(0.35)
	player.yaw = run_yaw + turn
	player.pitch = -0.2
	await _wait(0.1)
	await _shot("wallrun_panel")
	player.forced_intent = {}
	for pk in pickups:
		pk.node.queue_free()
	pickups.clear()

func _check_spawns(tag: String) -> void:
	# aucune position d'apparition dans le décor ; l'ancien tirage au hasard en donnait
	var bad := 0
	var old_bad := 0
	for i in 400:
		var p := spawn_pos(18.0, false, 0.9, 2.4)
		if not is_free(p, 0.9, 2.4):
			bad += 1
		var a := randf() * TAU
		var d := 26.0 + randf() * 11.0
		if not is_free(Vector3(clampf(cos(a) * d, -37.0, 37.0), 0.05, clampf(sin(a) * d, -37.0, 37.0)), 0.9, 2.4):
			old_bad += 1
	print("[%s] spawns in scenery=%d / 400 (old method: %d / 400)" % [tag, bad, old_bad])

func _zone2_test() -> void:
	await _wait(1.0)
	print("[z2] zone=%d name=%s arena=%s state=%s wave=%d level=%d credits=%d" % [zone_idx, zone().name, city.get_script().resource_path.get_file(), state, wave, level, credits])
	_check_spawns("z2")
	await _wait(3.0)
	await _shot("z2_round1")
	print("[z2] wave=%d enemies=%s" % [wave, ", ".join(enemies.map(func(e): return e.type_name))])
	_clear_round()
	await _wait(0.2)
	intermission = 999.0
	await _route_test("z2", Vector3(6, 0, -34), Vector3(20.3, 5.0, 11.0), PI, Vector3(0, 0, 30.5), Vector3(0, 0, -1))
	_clear_round()
	# bras mécanique : le joueur est sur sa trajectoire, il doit être touché
	spawn_enemy("arm", 1.0)
	var arm = enemies[-1]
	arm.spawn_t = 0.0
	var anc: Vector3 = arm.global_position
	player.global_position = anc + Vector3(4.0, 0.1, 0)
	player.velocity = Vector3.ZERO
	var hp0: float = player.hp
	await _wait(5.0)
	print("[z2] arm on anchor=%s hit=%s" % [city.anchors.has(anc - Vector3(0, 0.05, 0)), player.hp < hp0])
	_clear_round()
	# ouvrier-fournaise : il sème des flaques
	spawn_enemy("furnace", 1.0)
	var fw = enemies[-1]
	fw.spawn_t = 0.0
	fw.ability_cd = 0.0
	player.global_position = Vector3(0, 1.3, 0)
	await _wait(1.0)
	print("[z2] puddles=%d" % hazards.size())
	if hazards.size() > 0:
		var pz: Vector3 = hazards[0].pos
		hp0 = player.hp
		player.global_position = pz + Vector3(0, 0.1, 0)
		await _wait(0.8)
		print("[z2] puddle burns=%s" % (player.hp < hp0))
	_clear_round()
	_clear_hazards()
	# golem : se reforme une fois
	spawn_enemy("golem", 1.0)
	var gol = enemies[-1]
	gol.spawn_t = 0.0
	kill_enemy(gol, {})
	print("[z2] golem after 1st kill alive=%s reformed=%s" % [gol.alive, gol.reformed])
	await _wait(2.0)
	kill_enemy(gol, {})
	print("[z2] golem after 2nd kill alive=%s" % gol.alive)
	intermission = 0.5
	await _advance_to(5, "z2r")
	await _wait(1.0)
	print("[z2] now wave=%d boss=%s" % [wave, boss.T.name if boss else "-"])
	if boss:
		player.global_position = Vector3(0, 1.3, 8)
		await _wait(6.0)
		await _shot("z2_miniboss")
		boss.hp = boss.max_hp * 0.4
		await _wait(0.3)
		print("[z2] miniboss phase2=%s hazards=%d rings=%d" % [boss.phase2, hazards.size(), rings.size()])
	await _advance_to(8, "z2r")
	await _wait(1.5)
	await _shot("z2_round8")
	await _advance_to(10, "z2r")
	await _wait(3.0)
	print("[z2] wave=%d boss=%s" % [wave, boss.T.name if boss else "-"])
	if boss:
		player.global_position = Vector3(0, 1.3, 14)
		player.yaw = 0.0
		player.pitch = 0.1
		await _wait(2.0)
		await _shot("z2_boss")
		boss.hp = boss.max_hp * 0.45
		await _wait(0.5)
		print("[z2] boss phase2=%s collapsed=%s" % [boss.phase2, city.collapsed])
		# attendre la coulée : au sol on brûle, sur l'îlot central on est à l'abri
		player.global_position = Vector3(10, 0.1, 10)
		var guard := 0
		while not city.flooding() and guard < 400:
			guard += 1
			await get_tree().physics_frame
		await _wait(0.6)
		hp0 = player.hp
		await _wait(0.8)
		print("[z2] flood on=%s ground burns=%s" % [city.flooding(), player.hp < hp0])
		await _shot("z2_flood")
		player.global_position = Vector3(0, 1.4, 0)
		player.velocity = Vector3.ZERO
		await _wait(0.3)
		hp0 = player.hp
		_clear_hazards()
		rings.clear()
		await _wait(0.8)
		print("[z2] on island safe=%s y=%.2f" % [player.hp >= hp0, player.global_position.y])
		kill_enemy(boss, {})
		await _wait(0.5)

func _tree_test() -> void:
	# quelques effets de l'arbre, sur une partie neuve au Verdict
	start_with("verdict")
	await _wait(1.0)
	_clear_round()
	intermission = 999.0
	for id in ["v_t1", "v_t2", "v_s1", "v_s2", "v_s3", "v_s4", "w_t1", "w_t2", "w_v1", "w_v2", "m_t1", "m_t2", "m_a1", "m_a2"]:
		state = "between"; screen = "tree"; points = 1
		pick_tree(id)
	state = "play"
	print("[tree] owned=%d max_hp=%d shield=%d" % [tree.size(), int(up.max_hp), int(shield)])
	print("[tree] can take Jumeaux node with Verdict=%s" % can_take("w_j1"))
	player.hp = 50.0
	hurt_player(20.0, true)
	print("[tree] shield absorbs: hp=%d shield=%d" % [int(player.hp), int(shield)])
	hurt_player(500.0, true)
	print("[tree] second wind: hp=%d state=%s" % [int(player.hp), state])
	spawn_enemy("grunt", 1.0)
	var g = enemies[-1]
	g.spawn_t = 0.0
	g.global_position = Vector3(0, 0.05, 8)
	player.global_position = Vector3(0, 0.1, 14)
	player.yaw = 0.0
	await _wait(0.3)
	g.hp = g.max_hp * 0.35
	var d: Vector3 = g.global_position + Vector3(0, g.T.h * 0.9, 0) - player.eye_position()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	player.rotation.y = player.yaw
	player.head.rotation.x = player.pitch
	await get_tree().physics_frame
	var ammo0: int = player.ammo
	player.fire_cd = 0.0
	player.W.spread = 0.0
	player.shoot()
	print("[tree] execution: alive=%s ammo %d -> %d" % [g.alive, ammo0, player.ammo])
	player.global_position = Vector3(0, 12, 20)
	player.velocity = Vector3.ZERO
	player.forced_intent = { "move": Vector2.ZERO, "look": Vector2.ZERO, "jump": false, "jump_hold": true, "roll": false, "slide": false, "reload": false, "skill": false, "fire": false }
	await _wait(1.0)
	print("[tree] glide vy=%.1f" % player.velocity.y)
	player.forced_intent = {}
	state = "between"; screen = "tree"; points = 3
	open_tree()
	await _wait(0.3)
	await _shot("tree")

func _nearest_pad(p: Vector3) -> Dictionary:
	var best: Dictionary = city.pads[0]
	for pad in city.pads:
		if pad.pos.distance_to(p) < best.pos.distance_to(p):
			best = pad
	return best

func _grenade_test() -> void:
	# grenade : dégâts + recul sur un ennemi, grenade jump, recharge plus rapide avec une haute note
	_clear_round()
	intermission = 999.0
	player.forced_intent = { "move": Vector2.ZERO, "look": Vector2.ZERO, "jump": false, "roll": false, "slide": false, "reload": false, "skill": false, "fire": false }
	player.global_position = Vector3(0, 0.1, 16)
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = -0.15
	spawn_enemy("brute", 1.0)
	var e = enemies[-1]
	e.spawn_t = 0.0
	e.global_position = Vector3(0, 0.05, 8)
	spawn_enemy("brute", 1.0)          # témoin loin du joueur : le round ne se termine pas pendant le test
	enemies[-1].spawn_t = 0.0
	enemies[-1].global_position = Vector3(-34, 0.05, -34)
	enemy_slow = 0.0
	await _wait(0.3)
	var hp0: float = e.hp
	var z0: float = e.global_position.z
	gren_charges = 1
	throw_grenade()
	await _wait(0.8)
	print("[gren] hit dmg=%.0f pushed=%.1f charges=%d" % [hp0 - e.hp, z0 - e.global_position.z, gren_charges])
	# grenade jump : on la lance à ses pieds
	await _wait(0.5)
	player.pitch = -1.45
	player.head.rotation.x = player.pitch
	await get_tree().physics_frame
	gren_charges = 1
	var y0: float = player.global_position.y
	throw_grenade()
	var top := y0
	for k in 60:
		await get_tree().physics_frame
		top = maxf(top, player.global_position.y)
	print("[gren] grenade jump height=%.2f" % (top - y0))
	# recharge : D contre S
	gren_charges = 0; gren_prog = 0.0
	style = 0.0
	var r_low := gren_rate()
	style = Data.RANKS[4][1]
	print("[gren] recharge D=%.1fs S=%.1fs" % [grenade().cd / r_low, grenade().cd / gren_rate()])
	style = 0.0
	gren_charges = 1
	player.pitch = 0.0
	player.forced_intent = {}
	enemy_slow = 1.0
	_clear_round()
	intermission = 1.0

func _target(type: String, at: Vector3):
	spawn_enemy(type, 1.0)
	var e = enemies[-1]
	e.spawn_t = 0.0
	e.global_position = at
	return e

func _aim_at(p: Vector3) -> void:
	var d: Vector3 = p - player.eye_position()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	player.rotation.y = player.yaw
	player.head.rotation.x = player.pitch

func _chars_only() -> void:
	# test rapide des persos débloquables, sans faire tout le run
	print("AUTOTEST start")
	unlock_all = true
	if OS.get_environment("HB_SHOTS") != "":
		Engine.max_physics_steps_per_frame = 40
		to_menu()
		await _wait(0.5)
		await _shot("menu_persos")
		for w in Data.CHARACTERS.nyx.weapons:
			start_with(w)
			_clear_round()
			player.global_position = Vector3(-30, 0.1, 10)
			player.yaw = -PI / 2
			await _wait(0.4)
			await _shot("gun_" + w)
	start_with("jumeaux")
	await _wait(1.0)
	await _nyx_test()
	print("AUTOTEST done")
	get_tree().quit()

func _nyx_test() -> void:
	# Nyx : Overdrive, Tremplin, Crocs, Harpon et quelques nœuds de l'arbre
	pick_zone(0)
	start_with("essaim")
	await _wait(1.0)
	print("[nyx] char=%s kit=%s hp=%.0f weapon=%s" % [character, kit.get_script().resource_path.get_file(), player.hp, player.W.name])
	player.hp = 1e9; up.max_hp = 1e9
	_clear_round()
	intermission = 999.0
	var idle := { "move": Vector2.ZERO, "look": Vector2.ZERO, "jump": false, "roll": false, "slide": false, "reload": false, "skill": false, "fire": false }
	player.forced_intent = idle
	var witness = _target("brute", Vector3(-34, 0.05, -34))
	enemy_slow = 0.0
	# Overdrive
	player.skill = 100.0
	activate_skill()
	print("[nyx] overdrive active=%.1f extra_jumps=%d wallrun_inf=%s" % [kit.active, kit.extra_jumps(), kit.wallrun_infinite()])
	kit.active = 0.0
	# Tremplin : étourdit et pose un pad
	player.global_position = Vector3(0, 0.1, 16)
	var g1 = _target("brute", Vector3(0, 0.05, 8))
	await _wait(0.2)
	var pads0: int = city.pads.size()
	_aim_at(g1.center())
	gren_charges = 1
	throw_grenade()
	await _wait(0.6)
	print("[nyx] tremplin pads %d -> %d stunned=%s" % [pads0, city.pads.size(), is_instance_valid(g1) and g1.alive and g1.stun_t > 0.0])
	var tp: Dictionary = city.pads[-1]
	player.global_position = tp.pos + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	var top := 0.0
	for k in 120:
		await get_tree().physics_frame
		top = maxf(top, player.global_position.y)
	print("[nyx] tremplin height=%.1f" % top)
	_clear_round()
	witness = _target("brute", Vector3(-34, 0.05, -34))
	# Crocs : la lame part, touche et revient
	start_with("crocs")
	await _wait(0.5)
	player.hp = 1e9; up.max_hp = 1e9
	_clear_round(); intermission = 999.0
	witness = _target("brute", Vector3(-34, 0.05, -34))
	player.forced_intent = idle
	enemy_slow = 0.0
	player.global_position = Vector3(0, 0.1, 16)
	var b1 = _target("brute", Vector3(0, 0.05, 6))
	await _wait(0.2)
	_aim_at(b1.center())
	var hp0: float = b1.hp
	player.fire_cd = 0.0
	player.shoot()
	var ammo_out: int = player.ammo
	await _wait(1.2)
	print("[nyx] crocs dmg=%.0f ammo %d -> %d (mag %d)" % [hp0 - b1.hp, ammo_out, player.ammo, player.W.mag])
	_clear_round()
	# Harpon : carreau dans un ennemi puis traction
	start_with("harpon")
	await _wait(0.5)
	player.hp = 1e9; up.max_hp = 1e9
	_clear_round(); intermission = 999.0
	witness = _target("brute", Vector3(-34, 0.05, -34))
	player.forced_intent = idle
	enemy_slow = 0.0
	player.global_position = Vector3(0, 0.1, 16)
	var b2 = _target("brute", Vector3(0, 0.05, -2))
	await _wait(0.2)
	_aim_at(b2.center())
	hp0 = b2.hp
	player.fire_cd = 0.0
	player.shoot()
	var d0: float = player.global_position.distance_to(b2.global_position)
	print("[nyx] harpon dmg=%.0f anchored=%s tagged=%s" % [hp0 - b2.hp, not kit.anchor.is_empty(), b2.tag_t > 0.0])
	var alt := idle.duplicate(); alt.alt = true
	player.forced_intent = alt
	await get_tree().physics_frame
	player.forced_intent = idle
	await _wait(0.6)
	print("[nyx] pull dist %.1f -> %.1f" % [d0, player.global_position.distance_to(b2.global_position)])
	# arbre : quelques nœuds
	state = "between"; screen = "tree"; points = 6
	for id in ["ny_wt1", "ny_wt2", "ny_h1", "ny_mt1", "ny_mt2", "ny_ma1"]:
		pick_tree(id)
	print("[nyx] tree=%s harpon mag=%d jumps=%d" % [str(tree.keys()), player.W.mag, up.jumps + kit.extra_jumps()])
	if OS.get_environment("HB_SHOTS") != "":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		open_tree()
		await _wait(0.3)
		await _shot("nyx_tree")
	state = "play"; screen = ""
	enemy_slow = 1.0
	player.forced_intent = {}
	_clear_round()

func _route_test(tag: String, pad_at: Vector3, run_from: Vector3, run_yaw: float, shaft_mid: Vector3, shaft_n: Vector3) -> void:
	# parcours : jump pad vers la passerelle, wall run sur un panneau, montée d'un puits en wall jumps
	var idle := { "move": Vector2.ZERO, "look": Vector2.ZERO, "jump": false, "roll": false, "slide": false, "reload": false, "skill": false, "fire": false }
	var pad := _nearest_pad(pad_at)
	player.forced_intent = idle
	player.global_position = pad.pos + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _wait(2.0)
	print("[%s] route pad -> y=%.2f floor=%s pos=%s" % [tag, player.global_position.y, player.is_on_floor(), str(player.global_position.snapped(Vector3.ONE * 0.1))])
	if run_from != Vector3.ZERO:
		player.global_position = run_from
		player.yaw = run_yaw
		player.rotation.y = run_yaw
		player.velocity = Vector3(0, 0, -12).rotated(Vector3.UP, run_yaw) + Vector3(0, 6.0, 0)
		var fwd := idle.duplicate(); fwd.move = Vector2(0, -1)
		player.forced_intent = fwd
		var best := 0.0
		for k in 90:
			await get_tree().physics_frame
			best = maxf(best, player.wallrun_t)
			if route_trace and k % 6 == 0:
				print("  run k=%d pos=%s wr=%.2f boost=%s vy=%.1f" % [k, str(player.global_position.snapped(Vector3.ONE * 0.1)), player.wallrun_t, player.wall_boost, player.velocity.y])
		await _wait(0.8)
		print("[%s] route panel wallrun=%s end=%s floor=%s" % [tag, best > 0.0, str(player.global_position.snapped(Vector3.ONE * 0.1)), player.is_on_floor()])
		await _shot(tag + "_panel")
	# puits : on rebondit d'un mur à l'autre
	player.forced_intent = idle
	player.global_position = shaft_mid + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _wait(0.4)
	player.velocity = shaft_n * 6.0 + Vector3(0, 9.0, 0)
	var top := 0.0
	var bounces := 0
	for k in 300:
		await get_tree().physics_frame
		top = maxf(top, player.global_position.y)
		if route_trace and k % 6 == 0:
			print("  shaft k=%d pos=%s vy=%.1f" % [k, str(player.global_position.snapped(Vector3.ONE * 0.1)), player.velocity.y])
		if player.wallrun_cd <= 0.0 and not player.is_on_floor() and player._near_wall() != Vector3.ZERO and player.velocity.y < 3.0:
			player.jump()
			bounces += 1
			if bounces > 8:
				break
		if player.is_on_floor() and player.global_position.y > 5.0:
			break
	await _wait(0.6)
	print("[%s] route shaft bounces=%d top=%.2f end_y=%.2f floor=%s" % [tag, bounces, top, player.global_position.y, player.is_on_floor()])
	player.forced_intent = {}

func _routes_only() -> void:
	# test rapide des parcours des deux arènes
	await _wait(1.0)
	route_trace = true
	for z in 2:
		pick_zone(z)
		start_with(Data.WEAPON_ORDER[0])
		await _wait(1.0)
		player.hp = 1e9
		up.max_hp = 1e9
		_clear_round()
		intermission = 999.0
		if z == 0:
			await _route_test("z1", Vector3(0, 0, 27), Vector3(10.0, 7.5, 30.3), -PI / 2, Vector3(-22, 0, -14), Vector3(-1, 0, 0))
		else:
			await _route_test("z2", Vector3(6, 0, -34), Vector3(20.3, 5.0, 11.0), PI, Vector3(0, 0, 30.5), Vector3(0, 0, -1))
	pick_zone(0)
	get_tree().quit()

func _autotest() -> void:
	print("AUTOTEST start")
	if OS.get_environment("HB_SHOTS") != "":
		Engine.max_physics_steps_per_frame = 40
	await _wait(1.5)
	pick_zone(0)
	print("[meta] fresh: chars=%s nyx_open=%s brise_porte_open=%s verdict_open=%s" % [str(unlocked), char_open("nyx"), weapon_open("brise_porte"), weapon_open("verdict")])
	await _shot("menu")
	var wid: String = Data.WEAPON_ORDER[0]
	start_with(wid)
	await _wait(2.5)
	player.hp = 1e9
	up.max_hp = 1e9
	print("[run] wave=%d enemies=%d" % [wave, enemies.size()])
	_check_spawns("z1")
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
	await _route_test("z1", Vector3(0, 0, 27), Vector3(10.0, 7.5, 30.3), -PI / 2, Vector3(-22, 0, -14), Vector3(-1, 0, 0))
	await _grenade_test()
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
	player.yaw = 0.0
	player.pitch = 0.0
	player.ammo = 2
	player.reload_t = 0.0
	player.start_reload()
	var mags: Array = []
	for k in int((player.W.reload + 0.2) * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		mags = player.flying_mags()
		if mags.size() > 0 and mags[0].vel.y < 0.0:
			break
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
	print("[run] after zone 1 boss state=%s screen=%s between=%s" % [state, screen, str(between)])
	await _drain_between("z1end")
	await _zone2_test()
	print("[run] state=%s level=%d credits=%d score=%d" % [state, level, credits, score])
	print("[meta] after run: chars=%s mastery=%s datas=%d msg=%s brise_porte_open=%s" % [str(unlocked), str(mastery), datas, meta_msg, weapon_open("brise_porte")])
	unlock_all = true
	print("[run] tree points spent=%d nodes=%s" % [tree.size(), ", ".join(tree.keys())])
	await _shot("victory")
	await _tree_test()
	# les deux autres armes : départ, tir, mort
	for w2 in Data.WEAPON_ORDER.slice(1):
		start_with(w2)
		await _wait(2.0)
		for k in 6:
			player.shoot()
			player.fire_cd = 0.0
		print("[%s] ammo=%d wave=%d" % [w2, player.ammo, wave])
		if player.W.has("recoil"):
			# viser le sol et tirer : le recul fait décoller
			player.global_position = Vector3(0, 0.1, 16)
			player.velocity = Vector3.ZERO
			await _wait(0.3)
			player.pitch = -1.45
			player.head.rotation.x = player.pitch
			await get_tree().physics_frame
			player.ammo = 2
			player.fire_cd = 0.0
			player.shoot()
			await _wait(0.35)
			print("[%s] recoil jump y=%.2f" % [w2, player.global_position.y])
		player.hp = 1.0
		player.iframes = 0.0
		hurt_player(10)
		print("[%s] state after death=%s" % [w2, state])
		await _wait(0.3)
	await _shot("over")
	await _nyx_test()
	print("AUTOTEST done")
	get_tree().quit()
