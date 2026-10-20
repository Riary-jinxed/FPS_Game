# Kit d'Iris, la Hackeuse : Piratage (les ennemis du cône se battent pour toi), grenade Brouilleur,
# Aiguille (rail chargé qui traverse), Mouche (drones-tourelles), Patch (marquage qui se propage),
# et les effets de son arbre (préfixe ir_).
extends "res://scripts/kit.gd"

const VIOLET := Color("c77dff")
const HACK := Color("ff9cf2")

var hacked := {}            # ennemis piratés { en: true }
var tags := {}              # repères au-dessus des marqués et des piratés { en: MeshInstance3D }
var drones: Array = []      # { node, pos, post (Vector3 ou null = suit Iris), cd, life }
var next_drone := 0
var charge := 0.0           # charge de l'Aiguille (0 à 1)
var charging := false
var decoy := {}             # leurre { node, pos, life }
var ghost_t := 0.0
var shot_guard_t := 0.0     # Pare-feu total
var history: Array = []     # positions des 3 dernières secondes (Sauvegarde)
var hist_t := 0.0
var save_zone := -1
var tag_mats := {}

func reset() -> void:
	active = 0.0
	for e in tags:
		if is_instance_valid(tags[e]):
			tags[e].queue_free()
	tags.clear()
	hacked.clear()
	for d in drones:
		if is_instance_valid(d.node):
			d.node.queue_free()
	drones.clear()
	_drop_decoy()
	charge = 0.0
	charging = false
	ghost_t = 0.0
	shot_guard_t = 0.0
	history.clear()
	save_zone = -1

func _exit_tree() -> void:
	reset()

func wave_dmg(base: float, per: float) -> float:
	return (base + per * game.wave) * (1.0 + Data.ZONE_HP * game.zone_idx)

# ---------- Piratage ----------
func custom_skill() -> bool:
	return true

func skill_time() -> float:
	return Data.CHARACTERS.iris.skill_time + (3.0 if has("ir_sc1") else 0.0)

func activate() -> void:
	var t := skill_time()
	active = t
	var o: Vector3 = p.eye_position()
	var fwd: Vector3 = -p.cam.global_transform.basis.z
	var half: float = deg_to_rad(55.0 if has("ir_st2") else 35.0)
	var n := 0
	var root = null
	var root_a := 0.3
	for e in game.enemies.duplicate():
		if not is_instance_valid(e) or not e.alive:
			continue
		var to: Vector3 = e.center() - o
		var ang := fwd.angle_to(to)
		var in_cone: bool = to.length() < 26.0 and ang < half and not game.ray_world(o, e.center())
		if in_cone and ang < root_a and not (e.is_boss and not e.is_mini):
			root_a = ang
			root = e
		if in_cone or (has("ir_sc4") and e.mark_t > 0.0):
			if _hack(e, t):
				n += 1
				game.tracer(o + Vector3(0, -0.2, 0), e.center(), HACK)
			elif has("ir_sk3"):
				e.slow(6.0, 0.5)
	if has("ir_sk4") and root != null:
		# Root : piraté jusqu'à sa mort, même un élite
		root.hack_t = 9999.0
		hacked[root] = true
		game.hud.add_feed("ROOT : " + root.T.get("name", root.type_name).to_upper(), true)
	if has("ir_vf4"):
		shot_guard_t = 3.0
	game.hud.add_feed("PIRATÉS ×%d" % n if n > 1 else ("PIRATÉ" if n == 1 else "AUCUNE CIBLE"), n > 0)
	if n > 0:
		game.add_style("PIRATAGE", 15.0 * n)

func _hack(e, t: float) -> bool:
	# les boss résistent, les élites aussi sauf Root
	if not is_instance_valid(e) or not e.alive or e.is_boss:
		return false
	e.hack_t = maxf(e.hack_t, t)
	hacked[e] = true
	return true

func hacked_ai(e, d: float) -> void:
	# un piraté attaque l'ennemi non piraté le plus proche
	var best = null
	var bd := 30.0
	for o in game.enemies:
		if o == e or not is_instance_valid(o) or not o.alive or o.hack_t > 0.0:
			continue
		var dd: float = o.global_position.distance_to(e.global_position)
		if dd < bd:
			bd = dd
			best = o
	if best == null:
		e._move(Vector3.ZERO, 0.0)
		return
	var dir: Vector3 = best.global_position - e.global_position
	dir.y = 0.0
	var ranged: bool = e.T.ai == "ranged"
	var reach: float = 12.0 if ranged else e.T.r + best.T.r + 0.8
	e._move(dir.normalized(), e.speed if bd > reach else 0.0)
	if dir.length() > 0.1:
		e.rotation.y = atan2(-dir.x, -dir.z)
	e.atk_cd -= d
	if bd <= reach + 0.3 and e.atk_cd <= 0.0:
		e.atk_cd = 0.9
		var dmg := wave_dmg(14.0, 2.0) * (2.0 if e.T.r >= 0.8 else 1.0) * (1.5 if has("ir_sk1") else 1.0)
		if ranged:
			game.tracer(e.center(), best.center(), HACK)
		game.damage_enemy(best, dmg, best.center(), { "src": "hack" })

func hack_end(e) -> void:
	hacked.erase(e)
	if has("ir_sc3") and is_instance_valid(e) and e.alive:
		# Autodestruction
		var c: Vector3 = e.center()
		game.shockwave(c, HACK, 4.0)
		game.sfx.play("boom")
		for o in _near(c, 4.0):
			game.damage_enemy(o, wave_dmg(50.0, 6.0) if o != e else 99999.0, o.center(), { "src": "boom" })

func tick(delta: float) -> void:
	if active > 0.0:
		active = maxf(0.0, active - delta)
	shot_guard_t = maxf(0.0, shot_guard_t - delta)
	ghost_t = maxf(0.0, ghost_t - delta)
	for e in hacked.keys():
		if not is_instance_valid(e) or not e.alive or e.hack_t <= 0.0:
			hacked.erase(e)
	if has("ir_vs1") and hacked.size() > 0:
		p.hp = minf(game.up.max_hp, p.hp + 2.0 * delta)
	if has("ir_vt2") and drones.size() > 0:
		game.shield = minf(20.0, game.shield + 8.0 * delta)
	# Sauvegarde : positions des 3 dernières secondes
	hist_t -= delta
	if hist_t <= 0.0:
		hist_t = 0.25
		if p.is_on_floor():
			history.append(p.global_position)
			if history.size() > 12:
				history.pop_front()
	_update_rail(delta)
	_update_drones(delta)
	_update_decoy(delta)
	_update_tags()

# ---------- Armes ----------
func throws_mags() -> bool:
	return false

func can_reload() -> bool:
	return p.W.get("mode", "") != "drone"

func fire() -> bool:
	match p.W.mode:
		"rail":
			# la charge se gère dans _update_rail, le tir part au relâchement
			if p.ammo <= 0:
				p.start_reload()
			return true
		"drone":
			p.fire_cd = p.W.rate
			_send_drone()
			return true
	return false

func alt_fire() -> bool:
	if p.W.get("mode", "") != "drone":
		return false
	if drones.is_empty():
		game.sfx.play("deny")
		return true
	for d in drones:
		if d.life > 900.0:
			d.post = null
	game.sfx.play("ping")
	return true

func dmg_mult(en, _ctx: Dictionary) -> float:
	return 1.25 if has("ir_wt1") and en.mark_t > 0.0 else 1.0

func on_gun_hit(en, _dmg: float, ctx: Dictionary) -> void:
	if not is_instance_valid(en):
		return
	if has("ir_wt2") and en.mark_t > 0.0 and p.W.get("mode", "") == "" and not ctx.get("drone", false):
		p.ammo = mini(p.W.mag, p.ammo + 1)
	if p.W.id == "patch" and en.alive:
		_mark(en)

func _mark(e) -> void:
	if is_instance_valid(e) and e.alive:
		e.mark_t = maxf(e.mark_t, 8.0 if has("ir_p1") else 5.0)

func on_kill(en, c: Vector3, ctx: Dictionary, _aerial: bool) -> void:
	if en.mark_t > 0.0:
		if has("ir_vs2"):
			p.hp = minf(game.up.max_hp, p.hp + 4.0)
		# le marquage passe aux voisins
		if has("ir_p4"):
			for o in _near(c, 10.0):
				_mark(o)
				game.tracer(c, o.center(), VIOLET)
		else:
			var n := 2 if has("ir_p2") else 1
			for o in _closest(c, 8.0, n, [en]):
				_mark(o)
				game.tracer(c, o.center(), VIOLET)
	if ctx.get("src", "") == "hack" and has("ir_sk2"):
		p.hp = minf(game.up.max_hp, p.hp + 5.0)
	if hacked.has(en):
		hacked.erase(en)
		if has("ir_sc2"):
			for o in _closest(c, 10.0, 1, [en]):
				if _hack(o, maxf(3.0, en.hack_t if en.hack_t < 900.0 else 3.0)):
					game.tracer(c, o.center(), HACK)
	if ctx.get("drone", false) and has("ir_m4"):
		# Colonie : un drone temporaire
		var temp := drones.filter(func(d): return d.life < 900.0)
		if temp.size() < 4:
			_spawn_drone(c + Vector3(0, 2.0, 0), c + Vector3(0, 2.0, 0), 6.0)

# ---- Aiguille ----
func _charge_time() -> float:
	return 0.4 if has("ir_a1") else 0.8

func _update_rail(delta: float) -> void:
	if p.W.get("mode", "") != "rail":
		charging = false
		charge = 0.0
		return
	var hold: bool = p.intent.get("fire", false) and p.ammo > 0 and p.reload_t <= 0.0 and p.fire_cd <= 0.0 and game.state == "play"
	if hold:
		if not charging:
			charging = true
			game.sfx.play("charge")
		var was := charge
		charge = minf(1.0, charge + delta / _charge_time())
		if was < 1.0 and charge >= 1.0:
			game.sfx.play("ping")
		for G in p.guns:
			if G.extra:
				G.extra.scale = Vector3.ONE * (1.0 + 0.6 * charge)
	elif charging:
		charging = false
		_fire_rail(charge)
		charge = 0.0
		for G in p.guns:
			if G.extra:
				G.extra.scale = Vector3.ONE

func _fire_rail(c: float) -> void:
	p.ammo -= 1
	p.fire_cd = p.W.rate
	game.sfx.play(p.W.sound)
	game.shake = maxf(game.shake, 0.2 + 0.4 * c)
	p.pitch = minf(1.5, p.pitch + p.W.kick * (1.0 + c))
	var full: bool = c >= 1.0
	var o: Vector3 = p.eye_position()
	var dir: Vector3 = -p.cam.global_transform.basis.z
	var reach := 100.0
	if not (full and has("ir_a3")):
		var q := PhysicsRayQueryParameters3D.create(o, o + dir * reach, 1)
		var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			reach = o.distance_to(hit.position)
	var dmg: float = p.W.dmg * game.dmg_bonus() * shot_mult() * (1.0 + 2.0 * c)
	var line := []
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var to: Vector3 = e.center() - o
		var along := to.dot(dir)
		if along < 0.0 or along > reach:
			continue
		if (to - dir * along).length() < e.T.r + 0.35:
			line.append({ "e": e, "d": along })
	line.sort_custom(func(a, b): return a.d < b.d)
	game.tracer(o + Vector3(0, -0.15, 0), o + dir * reach, VIOLET if not full else Color.WHITE)
	var refund := false
	for k in line.size():
		var e = line[k].e
		if not is_instance_valid(e) or not e.alive:
			continue
		var at: Vector3 = o + dir * line[k].d
		if e.mark_t > 0.0 and has("ir_wt2"):
			refund = true
		game.damage_enemy(e, dmg, at, { "src": "gun" })
		game.hud.hitmark()
		if has("ir_a4"):
			_hack(e, 3.0)
		if k == line.size() - 1 and full and has("ir_a2"):
			game.shockwave(at, VIOLET, 3.5)
			game.sfx.play("boom")
			for o2 in _near(at, 3.5):
				game.damage_enemy(o2, dmg * 0.6, o2.center(), { "src": "boom" })
	if line.size() >= 3:
		game.add_style("ENFILADE ×%d" % line.size(), 15.0 * line.size())
	if refund:
		p.ammo = mini(p.W.mag, p.ammo + 1)
	if p.ammo <= 0:
		p.start_reload()

# ---- Mouche ----
func _max_drones() -> int:
	return 2 if has("ir_m1") else 1

func _send_drone() -> void:
	var o: Vector3 = p.eye_position()
	var dir: Vector3 = -p.cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * 50.0, 1 | 2, [p.get_rid()])
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	var post: Vector3 = (hit.position + hit.normal * 0.6 if hit else o + dir * 50.0) + Vector3(0, 1.6, 0)
	var own := drones.filter(func(d): return d.life > 900.0)
	if own.size() < _max_drones():
		_spawn_drone(p.eye_position() + Vector3(0, 0.3, 0), post, 9999.0)
	else:
		next_drone = (next_drone + 1) % own.size()
		own[next_drone].post = post
	game.sfx.play("dash")

func _spawn_drone(at: Vector3, post, life: float) -> void:
	var root := Node3D.new()
	game.world.add_child(root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.36, 0.12, 0.36)
	body.mesh = bm
	body.material_override = game._unshaded(Color("3a3050"), 1.0)
	root.add_child(body)
	for x in [-0.24, 0.24]:
		for z in [-0.24, 0.24]:
			var r := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.12; cm.bottom_radius = 0.12; cm.height = 0.02
			r.mesh = cm
			r.material_override = game._unshaded(VIOLET, 2.5)
			r.position = Vector3(x, 0.07, z)
			root.add_child(r)
	var eye := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.07; sm.height = 0.14
	eye.mesh = sm
	eye.material_override = game._unshaded(Color.WHITE, 4.0)
	eye.position = Vector3(0, -0.06, -0.18)
	root.add_child(eye)
	root.global_position = at
	drones.append({ "node": root, "pos": at, "post": post, "cd": 0.0, "life": life })

func _update_drones(delta: float) -> void:
	if p.W.get("mode", "") != "drone":
		for d in drones:
			if is_instance_valid(d.node):
				d.node.queue_free()
		drones.clear()
		return
	var k := 0
	for d in drones.duplicate():
		d.life -= delta
		if d.life <= 0.0 or not is_instance_valid(d.node):
			if is_instance_valid(d.node):
				d.node.queue_free()
			drones.erase(d)
			continue
		var target: Vector3
		if d.post != null:
			target = d.post
		else:
			var side := Vector3(0.9 if k % 2 == 0 else -0.9, 0.5, 0.3).rotated(Vector3.UP, p.yaw)
			target = p.eye_position() + side
		k += 1
		var to: Vector3 = target - d.pos
		d.pos += to * minf(1.0, delta * (10.0 if d.post == null else 5.0))
		d.node.global_position = d.pos + Vector3(0, sin(game.gt * 4.0 + k) * 0.06, 0)
		d.node.rotation.y += delta * 2.0
		if d.post == null and not has("ir_m3"):
			continue
		d.cd -= delta
		if d.cd > 0.0:
			continue
		var best = null
		var bd := 22.0
		for e in game.enemies:
			if is_instance_valid(e) and e.alive and e.hack_t <= 0.0:
				var dd: float = e.center().distance_to(d.pos)
				if dd < bd and not game.ray_world(d.pos, e.center()):
					bd = dd
					best = e
		if best:
			d.cd = 0.35
			var dmg: float = Data.WEAPONS.mouche.dmg * game.dmg_bonus() * (1.6 if has("ir_m2") else 1.0)
			game.tracer(d.pos, best.center(), VIOLET)
			game.damage_enemy(best, dmg, best.center(), { "src": "gun", "drone": true, "quiet": true })
			if has("ir_m2") and is_instance_valid(best) and best.alive:
				best.slow(1.0, 0.5)

# ---------- Brouilleur ----------
func custom_grenade() -> bool:
	return true

func gren_max_bonus() -> int:
	return 1 if has("ir_g1") else 0

func gren_rate_mult() -> float:
	return 1.25 if has("ir_st1") else 1.0

func grenade_blast(pos: Vector3, _scale: float) -> void:
	var G: Dictionary = game.grenade()
	var r: float = G.radius * (1.4 if has("ir_g3") else 1.0)
	game.shockwave(pos, VIOLET, r)
	game.burst(pos, VIOLET, 24, 10.0)
	game.sfx.play("glitch")
	var hits := 0
	for e in _near(pos, r):
		game.damage_enemy(e, wave_dmg(G.dmg, 3.0), e.center(), { "src": "boom" })
		if not is_instance_valid(e) or not e.alive:
			continue
		_mark(e)
		e.jam_t = maxf(e.jam_t, 5.0 if has("ir_g2") else 3.0)
		if has("ir_g4"):
			_hack(e, 3.0)
		hits += 1
	if hits > 0:
		game.add_style("BROUILLÉS" if hits > 1 else "BROUILLÉ", 12.0 * hits)

# ---------- Arbre ----------
func apply_node(id: String) -> void:
	match id:
		"ir_st1": game.up.skill_gain *= 1.25
		"ir_vt1": game.up.max_hp += 25.0; p.hp += 25.0
		"ir_vt2": game.shield = maxf(game.shield, 20.0)
		"ir_mt1": game.up.wallrun *= 1.5
		"ir_mt2": game.up.roll_cd *= 0.8

# ---------- Survie ----------
func hurt_mult(_d: float) -> float:
	return 0.75 if has("ir_vs3") and p.intent.get("fire", false) else 1.0

func on_hurt_check(d: float) -> bool:
	if has("ir_vs4") and save_zone != game.zone_idx and p.hp - d * hurt_mult(d) <= 0.0 and history.size() > 0:
		# Sauvegarde : retour 3 s en arrière
		save_zone = game.zone_idx
		p.global_position = history[0] + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.hp = game.up.max_hp * 0.5
		p.iframes = 1.0
		game.hud.banner("Sauvegarde restaurée", "")
		game.sfx.play("glitch")
		return true
	return false

func on_shot_near(s, dist: float) -> void:
	if has("ir_vf1") and dist < 6.0 and not s.has_meta("slowed"):
		s.set_meta("slowed", true)
		s.vel *= 0.35

func blocks_shot() -> bool:
	return shot_guard_t > 0.0

func reflect_shot(_s) -> bool:
	if has("ir_vf3") and game.shield > 0.0:
		game.shield = maxf(0.0, game.shield - 4.0)
		game.sfx.play("click")
		return true
	return false

func hidden_from(dist: float) -> bool:
	return ghost_t > 0.0 or (has("ir_vf2") and dist > 18.0)

func decoy_pos():
	return decoy.pos + Vector3(0, 1.2, 0) if not decoy.is_empty() else null

# ---------- Mouvement ----------
func on_roll() -> bool:
	if has("ir_ml1"):
		_drop_decoy()
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new(); cm.radius = 0.35; cm.height = 1.8
		mi.mesh = cm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.45)
		mi.material_override = m
		game.world.add_child(mi)
		mi.global_position = p.global_position + Vector3(0, 0.9, 0)
		decoy = { "node": mi, "pos": p.global_position, "life": 4.0 }
	if has("ir_ml4"):
		ghost_t = 2.0
	if not has("ir_mp1"):
		return false
	var dest = null
	if has("ir_mp4"):
		var e = _aimed_marked()
		if e:
			var away: Vector3 = e.global_position - p.global_position
			away.y = 0.0
			dest = e.global_position + away.normalized() * (e.T.r + 1.3)
			game.add_style("SAUT RÉSEAU", 30, true)
	if dest == null and has("ir_mp3") and p.intent.move.y > 0.5:
		var own := drones.filter(func(d): return d.post != null)
		if own.size() > 0:
			dest = own[0].pos + Vector3(0, -1.0, 0)
	if dest == null:
		var f: Vector3 = p.move_input()
		if f.length() < 0.1:
			f = Vector3(0, 0, -1).rotated(Vector3.UP, p.yaw)
		f.y = 0.0
		f = f.normalized()
		var dist: float = 10.0 if has("ir_mp2") else 6.0
		var c: Vector3 = p.global_position + Vector3(0, 0.9, 0)
		var q := PhysicsRayQueryParameters3D.create(c, c + f * dist, 1)
		var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			dist = maxf(0.0, c.distance_to(hit.position) - 0.6)
		dest = p.global_position + f * dist
	game.tracer(p.global_position + Vector3(0, 1, 0), dest + Vector3(0, 1, 0), VIOLET)
	game.burst(p.global_position + Vector3(0, 1, 0), VIOLET, 10, 5.0)
	p.global_position = dest
	p.iframes = maxf(p.iframes, 0.25)
	p.dodged = false
	game.sfx.play("glitch")
	return true

func _aimed_marked():
	var o: Vector3 = p.eye_position()
	var fwd: Vector3 = -p.cam.global_transform.basis.z
	var best = null
	var ba := deg_to_rad(12.0)
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive or e.mark_t <= 0.0:
			continue
		var to: Vector3 = e.center() - o
		if to.length() > 35.0:
			continue
		var a := fwd.angle_to(to)
		if a < ba:
			ba = a
			best = e
	return best

func _update_decoy(delta: float) -> void:
	if decoy.is_empty():
		return
	decoy.life -= delta
	decoy.node.visible = decoy.life > 1.0 or int(decoy.life * 10.0) % 2 == 0
	if has("ir_ml3"):
		for e in _near(decoy.pos + Vector3(0, 1, 0), 6.0):
			e.slow(0.3, 0.5)
	if decoy.life <= 0.0:
		if has("ir_ml2"):
			var c: Vector3 = decoy.pos + Vector3(0, 1, 0)
			game.shockwave(c, VIOLET, 4.0)
			game.sfx.play("boom")
			for e in _near(c, 4.0):
				game.damage_enemy(e, wave_dmg(60.0, 6.0), e.center(), { "src": "boom" })
		_drop_decoy()

func _drop_decoy() -> void:
	if decoy.has("node") and is_instance_valid(decoy.node):
		decoy.node.queue_free()
	decoy = {}

# ---------- Repères ----------
func _update_tags() -> void:
	for e in tags.keys():
		if not is_instance_valid(e) or not e.alive or (e.mark_t <= 0.0 and e.hack_t <= 0.0):
			if is_instance_valid(tags[e]):
				tags[e].queue_free()
			tags.erase(e)
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive or (e.mark_t <= 0.0 and e.hack_t <= 0.0):
			continue
		var t: MeshInstance3D = tags.get(e)
		if t == null:
			t = MeshInstance3D.new()
			var pm := PrismMesh.new(); pm.size = Vector3(0.3, 0.3, 0.05)
			t.mesh = pm
			t.rotation.z = PI
			game.world.add_child(t)
			tags[e] = t
		var key := ("h" if e.hack_t > 0.0 else "m") + ("x" if has("ir_p3") else "")
		if not tag_mats.has(key):
			var m: StandardMaterial3D = game._unshaded(HACK if key.begins_with("h") else VIOLET, 3.0)
			m.no_depth_test = key.ends_with("x")
			tag_mats[key] = m
		t.material_override = tag_mats[key]
		t.global_position = e.global_position + Vector3(0, e.T.h + 0.5, 0)
		t.rotation.y = game.gt * 3.0

# ---------- Outils ----------
func _closest(c: Vector3, r: float, n: int, skip: Array) -> Array:
	var list := _near(c, r).filter(func(e): return not e in skip)
	list.sort_custom(func(a, b): return a.center().distance_to(c) < b.center().distance_to(c))
	return list.slice(0, n)

func _near(c: Vector3, r: float) -> Array:
	return game.enemies.filter(func(e): return is_instance_valid(e) and e.alive and e.center().distance_to(c) < r + e.T.r)
