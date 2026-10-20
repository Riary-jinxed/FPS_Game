# Kit de Nyx, la Coureuse : Overdrive, grenade Tremplin, Crocs (lames qui reviennent), Harpon (grappin),
# et les effets de son arbre (préfixe ny_). L'Essaim est une arme à balles normale (trait move_tight).
extends "res://scripts/kit.gd"

var blades: Array = []      # lames en vol { node, pos, vel, state, t, hit }
var anchor := {}            # carreau accroché { pos, en, node }
var pulling := 0.0          # temps de traction restant
var tramps: Array = []      # tremplins posés par la grenade { pad, life }
var air_t := 0.0
var ghost_used := false
var trail_t := 0.0
var volley := 0
var slowmo_t := 0.0

func reset() -> void:
	active = 0.0
	for b in blades:
		if is_instance_valid(b.node):
			b.node.queue_free()
	blades.clear()
	_drop_anchor()
	for t in tramps:
		_remove_tramp(t)
	tramps.clear()
	air_t = 0.0
	slowmo_t = 0.0

func _exit_tree() -> void:
	reset()

func wave_dmg(base: float, per: float) -> float:
	return (base + per * game.wave) * (1.0 + Data.ZONE_HP * game.zone_idx)

# ---------- Overdrive ----------
func custom_skill() -> bool:
	return true

func activate() -> void:
	active = skill_time()
	if has("ny_si1"):
		var c: Vector3 = p.global_position + Vector3(0, 1, 0)
		game.shockwave(c, Color("5effc8"), 7.0)
		for e in _near(c, 7.0):
			game.damage_enemy(e, wave_dmg(30.0, 4.0), e.center(), { "src": "boom" })
			game.knockback(e, e.global_position - c, 4.0)
			if is_instance_valid(e) and e.alive:
				e.stun(1.5)

func tick(delta: float) -> void:
	if active > 0.0:
		if not (has("ny_sv4") and not p.is_on_floor()):
			active -= delta
		if active <= 0.0:
			active = 0.0
			game.hud.add_feed("FIN D'OVERDRIVE")
		elif has("ny_sv3"):
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.2
				for e in _near(p.global_position + Vector3(0, 1, 0), 2.4):
					game.damage_enemy(e, wave_dmg(10.0, 1.0), e.center(), { "src": "boom" })
					game.tracer(p.global_position + Vector3(0, 1, 0), e.center(), Color("5effc8"))
	if has("ny_sv1") and active <= 0.0 and p.wallrun_t > 0.0:
		p.skill = minf(100.0, p.skill + 6.0 * delta * game.up.skill_gain)
	# temps en l'air : Fantôme, Courant d'air
	if p.air:
		air_t += delta
		if has("ny_ve4") and air_t > 3.0 and not ghost_used:
			ghost_used = true
			p.iframes = maxf(p.iframes, 1.0)
			game.hud.add_feed("FANTÔME", true)
		if has("ny_vf1"):
			p.hp = minf(game.up.max_hp, p.hp + 2.0 * delta)
	else:
		air_t = 0.0
		ghost_used = false
	if has("ny_vf4") and p.hp < game.up.max_hp * 0.3:
		p.hp = minf(game.up.max_hp, p.hp + 5.0 * delta)
	if slowmo_t > 0.0:
		slowmo_t -= delta
		game.enemy_slow = 0.5 if slowmo_t > 0.0 else 1.0
	_head_bounce()
	_update_blades(delta)
	_update_anchor(delta)
	_update_tramps(delta)

# ---------- Armes ----------
func throws_mags() -> bool:
	return false

func can_reload() -> bool:
	return p.W.get("mode", "") != "blade"

func fire() -> bool:
	match p.W.mode:
		"blade":
			if p.ammo <= 0:
				return true
			p.ammo -= 1
			p.fire_cd = p.W.rate
			_throw_blade()
			return true
		"bolt":
			if p.ammo <= 0:
				p.start_reload()
				return true
			p.ammo -= 1
			p.fire_cd = p.W.rate
			_fire_bolt()
			if p.ammo <= 0:
				p.start_reload()
			return true
	return false

func alt_fire() -> bool:
	if p.W.get("mode", "") != "bolt":
		return false
	if anchor.is_empty():
		game.sfx.play("deny")
		return true
	pulling = 1.2
	game.sfx.play("dash")
	return true

func shot_mult() -> float:
	return 1.4 if active > 0.0 and p.air else 1.0

func dmg_mult(en, _ctx: Dictionary) -> float:
	return 1.35 if has("ny_h4") and en.tag_t > 0.0 else 1.0

func spread_mult() -> float:
	return 0.0 if has("ny_e2") and p.slide_t > 0.0 else 1.0

func rate_mult() -> float:
	if has("ny_e3") and p.W.id == "essaim":
		return 1.0 + 0.35 * clampf(_speed() / 16.0, 0.0, 1.0)
	return 1.0

func on_gun_hit(en, dmg: float, _ctx: Dictionary) -> void:
	_on_hit(en, dmg)

func on_shot() -> void:
	if has("ny_e4") and p.air and p.W.id == "essaim":
		volley += 1
		if volley % 5 == 0:
			# Volée : le tir est doublé
			var r := _aim_ray(80.0)
			if r and r.collider.get("alive") != null:
				game.damage_enemy(r.collider, p.W.dmg * game.dmg_bonus() * shot_mult(), r.position, { "src": "gun" })
				game.tracer(p.eye_position() + Vector3(0, -0.15, 0), r.position, Color("5effc8"))

func _on_hit(en, dmg: float) -> void:
	if not is_instance_valid(en):
		return
	if has("ny_wt1") and p.air and en.alive:
		en.bleed(dmg * 0.4 / 3.0, 3.0)
	if has("ny_vf2") and _speed() > 8.0:
		p.hp = minf(game.up.max_hp, p.hp + 0.6)

func on_kill(en, _c: Vector3, _ctx: Dictionary, aerial: bool) -> void:
	if aerial and has("ny_wt2") and p.W.get("mode", "") != "blade":
		p.ammo = mini(p.W.mag, p.ammo + maxi(1, p.W.mag / 4))
	if aerial and has("ny_sv2") and active > 0.0:
		active += 0.5
	if anchor.get("en") == en:
		_drop_anchor()

# ---- Crocs ----
func _throw_blade() -> void:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.36, 0.08, 0.5)
	mi.mesh = pm
	mi.material_override = game._unshaded(Color("5effc8"), 3.5)
	game.world.add_child(mi)
	var fwd: Vector3 = -p.cam.global_transform.basis.z
	var pos: Vector3 = p.eye_position() + fwd * 0.5 + Vector3(0, -0.2, 0)
	mi.global_position = pos
	var b := { "node": mi, "pos": pos, "vel": fwd * 38.0, "state": "out", "t": 0.0, "hit": {}, "angle": randf() * TAU }
	if has("ny_c4"):
		b.state = "orbit"
	blades.append(b)
	game.sfx.play("spin")

func _update_blades(delta: float) -> void:
	var home: Vector3 = p.global_position + Vector3(0, 1.1, 0)
	for b in blades.duplicate():
		if not is_instance_valid(b.node):
			blades.erase(b)
			continue
		b.t += delta
		var prev: Vector3 = b.pos
		match b.state:
			"orbit":
				# Tourbillon : la lame tourne autour de Nyx avant de partir
				b.angle += 12.0 * delta
				b.pos = home + Vector3(cos(b.angle), 0, sin(b.angle)) * 1.9
				_blade_hits(b, prev, 1.1)
				if b.t > 0.55:
					b.state = "out"
					b.t = 0.0
					b.hit = {}
					b.vel = -p.cam.global_transform.basis.z * 38.0
			"out":
				b.pos += b.vel * delta
				if game.ray_world(prev, b.pos) or b.t > 0.5:
					_blade_back(b)
				elif _blade_hits(b, prev, 0.9):
					_blade_back(b)
			"back":
				var to: Vector3 = home - b.pos
				if to.length() < 1.3:
					p.ammo = mini(p.W.mag if p.W.get("mode", "") == "blade" else 99, p.ammo + 1)
					b.node.queue_free()
					blades.erase(b)
					continue
				b.pos += to.normalized() * minf(48.0 * delta, to.length())
				if has("ny_c2"):
					_blade_hits(b, prev, 0.9)
		b.node.global_position = b.pos
		b.node.rotation.y += 25.0 * delta

func _blade_back(b: Dictionary) -> void:
	b.state = "back"
	b.hit = {}

func _blade_hits(b: Dictionary, a: Vector3, r: float) -> bool:
	# vrai si une lame a tué : elle revient tout de suite
	var killed := false
	for e in game.enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or b.hit.has(e):
			continue
		var c: Vector3 = e.center()
		var seg: Vector3 = b.pos - a
		var t := clampf((c - a).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		if (a + seg * t).distance_to(c) < r + e.T.r:
			b.hit[e] = true
			var dmg: float = p.W.dmg * game.dmg_bonus() * shot_mult() if p.W.id == "crocs" else wave_dmg(30.0, 3.0)
			game.damage_enemy(e, dmg, c, { "src": "gun", "from": a })
			_on_hit(e, dmg)
			game.hud.hitmark()
			game.sfx.play("hit")
			if is_instance_valid(e) and e.alive:
				if has("ny_c3"):
					e.slow(2.0, 0.45)
			else:
				killed = true
	return killed

# ---- Harpon ----
func _range() -> float:
	return 60.0 if has("ny_mw3") else 40.0

func _aim_ray(dist: float) -> Dictionary:
	var o: Vector3 = p.eye_position()
	var dir: Vector3 = -p.cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * dist, 1 | 2, [p.get_rid()])
	return p.get_world_3d().direct_space_state.intersect_ray(q)

func _fire_bolt() -> void:
	game.sfx.play(p.W.sound)
	game.shake = maxf(game.shake, 0.25)
	p.pitch = minf(1.5, p.pitch + p.W.kick)
	var r := _aim_ray(_range())
	var o: Vector3 = p.eye_position() + Vector3(0, -0.15, 0)
	if not r:
		game.tracer(o, o - p.cam.global_transform.basis.z * _range(), Color("5effc8"))
		return
	_drop_anchor()
	game.tracer(o, r.position, Color("5effc8"))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.06, 0.06, 0.6)
	mi.mesh = bm
	mi.material_override = game._unshaded(Color("5effc8"), 3.0)
	game.world.add_child(mi)
	mi.global_position = r.position
	mi.look_at(r.position + (r.position - o).normalized(), Vector3.UP if absf((r.position - o).normalized().y) < 0.99 else Vector3.RIGHT)
	var en = r.collider if r.collider.get("alive") != null else null
	anchor = { "pos": r.position, "en": en, "node": mi, "life": 6.0 }
	if en:
		anchor.off = r.position - en.global_position
		en.tag_t = 6.0
		var dmg: float = p.W.dmg * game.dmg_bonus() * shot_mult()
		var head_hit: bool = r.position.y > en.global_position.y + en.T.h * 0.8
		if head_hit:
			dmg *= game.up.crit
		game.damage_enemy(en, dmg, r.position, { "src": "gun", "head": head_hit, "from": o })
		_on_hit(en, dmg)
		game.hud.hitmark()
		game.sfx.play("hit")
		if has("ny_h3"):
			var n := 0
			for e in _near(r.position, 7.0):
				if e == en or n >= 2:
					continue
				n += 1
				game.tracer(r.position, e.center(), Color("bffcff"))
				game.damage_enemy(e, wave_dmg(30.0, 3.0), e.center(), { "src": "boom" })
				e.stun(0.5)
		if not is_instance_valid(en) or not en.alive:
			_drop_anchor()

func _drop_anchor() -> void:
	if anchor.has("node") and is_instance_valid(anchor.node):
		anchor.node.queue_free()
	anchor = {}
	pulling = 0.0

func _update_anchor(delta: float) -> void:
	if anchor.is_empty():
		return
	anchor.life -= delta
	if anchor.en != null:
		if not is_instance_valid(anchor.en) or not anchor.en.alive:
			_drop_anchor()
			return
		anchor.pos = anchor.en.global_position + anchor.off
		anchor.node.global_position = anchor.pos
	if pulling > 0.0:
		pulling -= delta
		var from: Vector3 = p.global_position + Vector3(0, 1.0, 0)
		var to: Vector3 = anchor.pos - from
		game.tracer(p.eye_position() + Vector3(0.2, -0.25, 0), anchor.pos, Color("5effc8"))
		if to.length() < 2.2 or pulling <= 0.0:
			if anchor.en != null and to.length() < 2.6:
				if has("ny_h2"):
					game.damage_enemy(anchor.en, wave_dmg(90.0, 8.0), anchor.en.center(), { "src": "boom" })
					game.add_style("ABORDAGE", 40, true)
				p.velocity = Vector3(p.velocity.x * 0.3, 7.0, p.velocity.z * 0.3)
			_drop_anchor()
			return
		p.velocity = to.normalized() * (36.0 if has("ny_mw3") else 28.0)
		p.jumps = 1
	elif anchor.life <= 0.0:
		_drop_anchor()

# ---------- Tremplin ----------
func custom_grenade() -> bool:
	return true

func gren_max_bonus() -> int:
	return 1 if has("ny_g1") else 0

func gren_rate_mult() -> float:
	return 1.25 if has("ny_st1") else 1.0

func grenade_blast(pos: Vector3, _scale: float) -> void:
	var G: Dictionary = game.grenade()
	var r: float = G.radius * (1.35 if has("ny_g3") else 1.0)
	game.shockwave(pos, Color(G.color), r)
	game.burst(pos, Color(G.color), 24, 10.0)
	game.sfx.play("boom")
	var hits := 0
	for e in _near(pos, r):
		game.damage_enemy(e, wave_dmg(G.dmg, 5.0), e.center(), { "src": "boom" })
		if is_instance_valid(e) and e.alive:
			e.stun(3.0 if has("ny_g3") else 2.0)
		hits += 1
	if hits > 0:
		game.add_style("SONNÉS" if hits > 1 else "SONNÉ", 15.0 * hits)
	# tremplin posé au sol sous l'impact
	var ground := Vector3(pos.x, 0.0, pos.z)
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -30, 0), 1)
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		ground = hit.position
	game.city._add_pad(ground, Vector3.ZERO, 24.0, Color("5effc8"))
	var pad: Dictionary = game.city.pads[-1]
	pad.temp = true
	if has("ny_g4"):
		pad.on_launch = func(): _catapult(ground)
	tramps.append({ "pad": pad, "life": 10.0 if has("ny_g2") else 6.0 })

func _catapult(at: Vector3) -> void:
	game.shockwave(at + Vector3(0, 0.5, 0), Color("5effc8"), 5.0)
	for e in _near(at + Vector3(0, 1, 0), 5.0):
		game.damage_enemy(e, wave_dmg(60.0, 5.0), e.center(), { "src": "boom" })
	game.add_style("CATAPULTE", 30)

func _update_tramps(delta: float) -> void:
	for t in tramps.duplicate():
		t.life -= delta
		if t.life < 1.5 and is_instance_valid(t.pad.node):
			t.pad.node.visible = int(t.life * 8.0) % 2 == 0
		if t.life <= 0.0:
			_remove_tramp(t)
			tramps.erase(t)

func _remove_tramp(t: Dictionary) -> void:
	if is_instance_valid(game.city):
		game.city.pads.erase(t.pad)
	for k in ["node", "ring"]:
		if is_instance_valid(t.pad[k]):
			t.pad[k].queue_free()

# ---------- Arbre ----------
func apply_node(id: String) -> void:
	var W: Dictionary = p.W
	match id:
		"ny_e1":
			if W.id == "essaim":
				W.mag = roundi(W.mag * 1.3); p.ammo = W.mag
		"ny_c1":
			if W.id == "crocs":
				W.mag += 2; p.ammo += 2
		"ny_h1":
			if W.id == "harpon":
				W.mag = 2; p.ammo = 2
		"ny_st1": game.up.skill_gain *= 1.25
		"ny_st2": game.up.skill_time += 2.0
		"ny_vt1": game.up.max_hp += 20.0; p.hp += 20.0
		"ny_mt1": game.up.wallrun *= 1.5

# ---------- Survie ----------
func hurt_mult(_d: float) -> float:
	if has("ny_vt2"):
		return 1.0 - 0.3 * clampf(_speed() / 16.0, 0.0, 1.0)
	return 1.0

func on_dodge() -> void:
	if has("ny_ve1"):
		slowmo_t = 1.5
		game.enemy_slow = 0.5
		game.hud.add_feed("ESQUIVE PARFAITE", true)

func hidden_from(dist: float) -> bool:
	return has("ny_ve3") and dist > 20.0

# ---------- Mouvement ----------
func on_roll() -> bool:
	if has("ny_ve2"):
		p.hp = minf(game.up.max_hp, p.hp + 5.0)
	if has("ny_ma2") and not p.is_on_floor():
		# dash aérien : garde l'altitude
		var f: Vector3 = p.move_input()
		if f.length() < 0.1:
			f = Vector3(0, 0, -1).rotated(Vector3.UP, p.yaw)
		f = f.normalized()
		p.velocity = Vector3(f.x * 24.0, maxf(p.velocity.y, 1.5), f.z * 24.0)
		p.iframes = 0.3
		p.dodged = false
		game.sfx.play("dash")
		game.add_style("DASH", 10)
		return true
	return false

func on_jump(_air: bool) -> void:
	if has("ny_si2") and active > 0.0:
		var c: Vector3 = p.global_position + Vector3(0, 1, 0)
		var best = null
		var bd := 18.0
		for e in game.enemies:
			if is_instance_valid(e) and e.alive and e.center().distance_to(c) < bd:
				bd = e.center().distance_to(c)
				best = e
		if best:
			game.tracer(c, best.center(), Color("5effc8"))
			game.damage_enemy(best, wave_dmg(30.0, 3.0), best.center(), { "src": "gun" })

func on_wall_jump() -> void:
	if has("ny_vf3"):
		game.shield = minf(20.0, game.shield + 10.0)

func on_land(fall_speed: float) -> void:
	var c: Vector3 = p.global_position + Vector3(0, 0.5, 0)
	if has("ny_si4") and active > 0.0 and fall_speed > 6.0:
		# Comète
		game.shockwave(c, Color("5effc8"), 5.0)
		game.sfx.play("boom")
		game.shake = maxf(game.shake, 0.4)
		for e in _near(c, 5.0):
			game.damage_enemy(e, wave_dmg(70.0, 6.0), e.center(), { "src": "boom" })
			if is_instance_valid(e) and e.alive:
				e.stun(1.0)
	elif has("ny_si3") and fall_speed > 13.0:
		game.shockwave(c, Color("5effc8"), 3.0)
		for e in _near(c, 3.0):
			game.damage_enemy(e, wave_dmg(40.0, 4.0), e.center(), { "src": "boom" })

func _head_bounce() -> void:
	if not has("ny_ma3") or p.velocity.y > -3.0:
		return
	var feet: Vector3 = p.global_position
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var top: float = e.global_position.y + e.T.h
		if absf(feet.y - top) < 0.5 and Vector2(feet.x - e.global_position.x, feet.z - e.global_position.z).length() < e.T.r + 0.5:
			p.velocity.y = 12.0
			p.jumps = 1
			game.damage_enemy(e, wave_dmg(45.0, 5.0), e.center(), { "src": "boom" })
			game.add_style("REBOND", 30, true)
			game.sfx.play("pad")
			return

func gravity_mult(hold: bool) -> float:
	if has("ny_ma4") and hold and p.velocity.y < 0.0:
		return 0.3
	return 1.0

func wallrun_infinite() -> bool:
	return active > 0.0 or has("ny_mw4")

func wall_boost() -> bool:
	return has("ny_mw1")

func walljump_bonus() -> Vector2:
	return Vector2(1.25 if has("ny_mw2") else 1.0, 2.5 if has("ny_mt2") else 0.0)

func speed_mult() -> float:
	return 1.3 if has("ny_vf4") and p.hp < game.up.max_hp * 0.3 else 1.0

func extra_jumps() -> int:
	return (1 if active > 0.0 else 0) + (1 if has("ny_ma1") else 0)

# ---------- Outils ----------
func _speed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()

func _near(c: Vector3, r: float) -> Array:
	return game.enemies.filter(func(e): return is_instance_valid(e) and e.alive and e.center().distance_to(c) < r + e.T.r)
