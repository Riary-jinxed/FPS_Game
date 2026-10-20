# Kit de Brack, le Démolisseur : Frappe orbitale, grenade Grappe, Tambour (grenades à rebond),
# Moulin (minigun qui monte en cadence), Glu (mines collantes), charge d'épaule, et les effets de son
# arbre (préfixe br_). Ses explosions le blessent un peu, sauf avec Démineur.
extends "res://scripts/kit.gd"

const ORANGE := Color("ff8a3d")
const SMALL_R := 0.62       # rayon max d'un « petit » ennemi que le Colosse écrase

var bombs: Array = []       # projectiles { node, pos, vel, kind, life, r, dmg, ... }
var strikes: Array = []     # frappes en attente { pos, en, t, r, dmg, node, beam }
var zones: Array = []       # zones au sol { pos, r, t, kind, node }
var spin := 0.0             # montée en cadence du Moulin (0 à 1)
var charge_t := 0.0
var charge_dir := Vector3.ZERO
var charge_hit := {}
var still_t := 0.0
var regen_t := 0.0
var crush_cd := 0.0
var ray_tick := 0.0
var rempart_t := 0.0
var rempart_kills := 0
var rempart_used := false
var last_wave := -1

func reset() -> void:
	active = 0.0
	for list in [bombs, strikes, zones]:
		for b in list:
			for k in ["node", "beam"]:
				if b.has(k) and is_instance_valid(b[k]):
					b[k].queue_free()
		list.clear()
	spin = 0.0
	charge_t = 0.0
	rempart_t = 0.0
	rempart_used = false

func _exit_tree() -> void:
	reset()

func wave_dmg(base: float, per: float) -> float:
	return (base + per * game.wave) * (1.0 + Data.ZONE_HP * game.zone_idx)

# ---------- Frappe orbitale ----------
func custom_skill() -> bool:
	return true

func activate() -> void:
	var aim := _aim_point()
	if has("br_sp4"):
		# Rayon continu : laser orbital piloté à la visée
		active = 4.0
		ray_tick = 0.0
		return
	var delay: float = 0.5 if has("br_sp1") else 1.5
	var r: float = 7.0 * (1.3 if has("br_st2") else 1.0)
	var dmg := wave_dmg(160.0, 16.0)
	var en = aim.en if has("br_sp2") else null
	if has("br_ss4"):
		# Tapis de bombes : 5 frappes en ligne dans la direction visée
		var fwd := Vector3(0, 0, -1).rotated(Vector3.UP, p.yaw)
		for k in 5:
			_add_strike(aim.pos + fwd * (k - 1) * r * 0.9, null, delay + 0.18 * k, r * 0.75, dmg * 0.8)
	else:
		_add_strike(aim.pos, en, delay, r, dmg)
		if has("br_ss1"):
			var a := randf() * TAU
			_add_strike(aim.pos + Vector3(cos(a), 0, sin(a)) * r * 0.8, null, delay + 0.4, r * 0.6, dmg * 0.6)
	game.sfx.play("ping")

func _add_strike(pos: Vector3, en, t: float, r: float, dmg: float) -> void:
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = 0.04
	ring.mesh = cm
	ring.material_override = _glass(Color(1.0, 0.3, 0.15), 0.35)
	game.world.add_child(ring)
	ring.global_position = _ground(pos) + Vector3(0, 0.06, 0)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.12, 60.0, 0.12)
	beam.mesh = bm
	beam.material_override = game._unshaded(Color(1.0, 0.35, 0.2), 3.0)
	game.world.add_child(beam)
	beam.global_position = ring.global_position + Vector3(0, 30.0, 0)
	strikes.append({ "pos": ring.global_position, "en": en, "t": t, "t0": t, "r": r, "dmg": dmg, "node": ring, "beam": beam })

func _update_strikes(delta: float) -> void:
	for s in strikes.duplicate():
		s.t -= delta
		if s.en != null and is_instance_valid(s.en) and s.en.alive:
			s.pos = _ground(s.en.global_position) + Vector3(0, 0.06, 0)
		s.node.global_position = s.pos
		s.beam.global_position = s.pos + Vector3(0, 30.0, 0)
		s.beam.visible = int(s.t * 12.0) % 2 == 0
		if has("br_sp3"):
			# Gravité : attire vers le centre avant l'impact
			for e in _near(s.pos, s.r * 1.8):
				if e.is_boss:
					continue
				var to: Vector3 = s.pos - e.global_position
				to.y = 0.0
				if to.length() > 0.6:
					e.global_position += to.normalized() * minf(7.0 * delta, to.length())
		if s.t <= 0.0:
			strikes.erase(s)
			s.node.queue_free()
			s.beam.queue_free()
			game.tracer(s.pos + Vector3(0, 60, 0), s.pos, Color(1.0, 0.6, 0.3))
			game.shake = maxf(game.shake, 0.9)
			_explode(s.pos + Vector3(0, 0.6, 0), s.r, s.dmg, { "strike": true })
			if has("br_ss2"):
				_add_zone(s.pos, s.r, 4.0, "burn")
			if has("br_vc3"):
				regen_t = 4.0

func _update_ray(delta: float) -> void:
	if active <= 0.0:
		return
	active -= delta
	ray_tick -= delta
	var aim := _aim_point()
	var at: Vector3 = _ground(aim.pos)
	if ray_tick <= 0.0:
		ray_tick = 0.08
		game.tracer(at + Vector3(randf_range(-0.3, 0.3), 60, randf_range(-0.3, 0.3)), at, Color(1.0, 0.45, 0.2))
		game.burst(at + Vector3(0, 0.3, 0), ORANGE, 3, 6.0)
		for e in _near(at + Vector3(0, 1, 0), 3.2):
			game.damage_enemy(e, wave_dmg(10.0, 1.2), e.center(), { "src": "boom", "quiet": true })
	if active <= 0.0:
		active = 0.0
		game.hud.add_feed("FIN DU RAYON")
		if has("br_vc3"):
			regen_t = 4.0

# ---------- Tick ----------
func tick(delta: float) -> void:
	if game.wave != last_wave:
		last_wave = game.wave
		rempart_used = false
	_update_ray(delta)
	_update_strikes(delta)
	_update_bombs(delta)
	_update_zones(delta)
	_update_spin(delta)
	# survie
	if Vector2(p.velocity.x, p.velocity.z).length() < 0.5 and p.is_on_floor():
		still_t += delta
	else:
		still_t = 0.0
	if has("br_vb1") and game.calm_t > 3.0:
		game.shield = minf(30.0, game.shield + 15.0 * delta)
	if has("br_vb3") and game.shield >= 29.5:
		p.hp = minf(game.up.max_hp, p.hp + 3.0 * delta)
	if regen_t > 0.0:
		regen_t -= delta
		p.hp = minf(game.up.max_hp, p.hp + 5.0 * delta)
	if rempart_t > 0.0:
		rempart_t -= delta
		p.iframes = maxf(p.iframes, 0.1)
		if rempart_t <= 0.0:
			if rempart_kills >= 10:
				p.hp = maxf(p.hp, game.up.max_hp * 0.5)
				game.hud.add_feed("REMPART TENU", true)
			else:
				game.hud.add_feed("REMPART TOMBÉ")
	crush_cd -= delta
	if has("br_vb4") and crush_cd <= 0.0:
		_crush()

# ---------- Armes ----------
func throws_mags() -> bool:
	return false

func fire() -> bool:
	match p.W.mode:
		"lob":
			if p.ammo <= 0:
				p.start_reload()
				return true
			p.ammo -= 1
			p.fire_cd = p.W.rate
			_launch(-p.cam.global_transform.basis.z)
			_kick()
			if p.ammo <= 0:
				p.start_reload()
			return true
		"mine":
			if p.ammo <= 0:
				p.start_reload()
				return true
			p.ammo -= 1
			p.fire_cd = p.W.rate
			_throw_mine()
			_kick()
			if p.ammo <= 0:
				p.start_reload()
			return true
	return false

func alt_fire() -> bool:
	match p.W.get("mode", ""):
		"mine":
			detonate_mines()
			return true
		"lob":
			if not has("br_t4"):
				return false
			# Barrage : tout le tambour en éventail
			if p.ammo <= 0 or p.reload_t > 0.0:
				game.sfx.play("deny")
				return true
			var n: int = p.ammo
			var fwd: Vector3 = -p.cam.global_transform.basis.z
			for k in n:
				var a := lerpf(-0.4, 0.4, float(k) / maxf(1.0, n - 1.0))
				_launch(fwd.rotated(Vector3.UP, a))
			p.ammo = 0
			_kick()
			game.add_style("BARRAGE", 20)
			p.start_reload()
			return true
	return false

func _kick() -> void:
	game.sfx.play(p.W.sound)
	game.shake = maxf(game.shake, 0.3)
	p.pitch = minf(1.5, p.pitch + p.W.kick)

func _blast_r() -> float:
	return p.W.get("blast", 3.5)

func _launch(dir: Vector3) -> void:
	var pos: Vector3 = p.eye_position() + dir * 0.6 + Vector3(0, -0.15, 0)
	var v: Vector3 = dir * 26.0 + Vector3(0, 3.0, 0) + p.velocity * 0.3
	_spawn("lob", pos, v, 0.13, { "life": 1.6, "r": _blast_r(), "dmg": p.W.dmg * game.dmg_bonus() * shot_mult() })

func _throw_mine() -> void:
	var dir: Vector3 = -p.cam.global_transform.basis.z
	var pos: Vector3 = p.eye_position() + dir * 0.6 + Vector3(0, -0.15, 0)
	_spawn("mine", pos, dir * 24.0 + Vector3(0, 2.0, 0) + p.velocity * 0.3, 0.16, { "r": _blast_r(), "dmg": p.W.dmg * game.dmg_bonus() * shot_mult() })
	var mines := bombs.filter(func(b): return b.kind == "mine")
	if mines.size() > 8:
		_pop(mines[0])

func detonate_mines() -> void:
	var mines := bombs.filter(func(b): return b.kind == "mine")
	if mines.is_empty():
		game.sfx.play("deny")
		return
	for b in mines:
		_pop(b)
	if mines.size() >= 3:
		game.add_style("CHAPELET", 10.0 * mines.size())

func _spawn(kind: String, pos: Vector3, vel: Vector3, size: float, extra := {}) -> Dictionary:
	var mi := MeshInstance3D.new()
	if kind == "mine":
		var cm := CylinderMesh.new(); cm.top_radius = size; cm.bottom_radius = size; cm.height = size * 0.6
		mi.mesh = cm
	else:
		var sm := SphereMesh.new(); sm.radius = size; sm.height = size * 2.0
		mi.mesh = sm
	mi.material_override = game._unshaded(ORANGE if kind != "bomblet" else Color("ffd23d"), 3.5)
	game.world.add_child(mi)
	mi.global_position = pos
	var b := { "node": mi, "pos": pos, "vel": vel, "kind": kind, "life": 9999.0, "r": 2.5, "dmg": 40.0,
		"stuck": false, "en": null, "off": Vector3.ZERO, "leapt": false, "chain": false, "small": false, "t": 0.0 }
	b.merge(extra, true)
	bombs.append(b)
	return b

func _update_bombs(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for b in bombs.duplicate():
		if not is_instance_valid(b.node):
			bombs.erase(b)
			continue
		b.t += delta
		b.life -= delta
		if b.life <= 0.0:
			_pop(b)
			continue
		if b.stuck:
			if b.en != null:
				if is_instance_valid(b.en) and b.en.alive:
					b.pos = b.en.global_position + b.off
				else:
					b.en = null
			elif has("br_l2") and not b.leapt:
				# Mines sauteuses : la mine bondit sur l'ennemi le plus proche
				var best = _nearest(b.pos, 6.0)
				if best:
					b.leapt = true
					game.tracer(b.pos, best.center(), ORANGE)
					b.en = best
					b.off = best.center() - best.global_position
					b.pos = best.center()
			b.node.global_position = b.pos
			b.node.visible = b.kind != "mine" or int(b.t * 4.0) % 2 == 0 or b.en != null
			continue
		b.vel.y -= 20.0 * delta
		var a: Vector3 = b.pos
		var to: Vector3 = a + b.vel * delta
		var hit_en = _hit_enemy(a, to, 0.25)
		if hit_en:
			if b.kind == "mine":
				b.stuck = true
				b.en = hit_en
				b.off = to - hit_en.global_position
				b.pos = to
				game.sfx.play("click")
			else:
				b.pos = to
				_pop(b)
			continue
		var q := PhysicsRayQueryParameters3D.create(a, to, 1)
		var hit := space.intersect_ray(q)
		if hit:
			if b.kind == "mine":
				b.stuck = true
				b.pos = hit.position + hit.normal * 0.05
				b.node.global_position = b.pos
				var n: Vector3 = hit.normal
				b.node.look_at(b.pos + n, Vector3.UP if absf(n.y) < 0.99 else Vector3.RIGHT)
				b.node.rotate_object_local(Vector3.RIGHT, PI / 2.0)
				game.sfx.play("click")
				continue
			b.pos = hit.position + hit.normal * 0.06
			b.vel = b.vel.bounce(hit.normal) * 0.55
			if b.kind == "lob" and has("br_t3") and not b.get("homed", false):
				# Aimantée : après un rebond, la grenade file vers l'ennemi le plus proche
				var e = _nearest(b.pos, 16.0)
				if e:
					b.homed = true
					b.vel = (e.center() - b.pos).normalized() * 22.0 + Vector3(0, 2.0, 0)
		else:
			b.pos = to
		b.node.global_position = b.pos

func _pop(b: Dictionary) -> void:
	if not bombs.has(b):
		return
	bombs.erase(b)
	if is_instance_valid(b.node):
		b.node.queue_free()
	_explode(b.pos, b.r, b.dmg, { "small": b.small, "chain": b.chain })
	match b.kind:
		"lob":
			if has("br_t2"):
				for k in 3:
					var a := k * TAU / 3.0 + randf() * 0.5
					_spawn("bomblet", b.pos + Vector3(0, 0.3, 0), Vector3(cos(a) * 5.0, 5.0, sin(a) * 5.0), 0.08,
						{ "life": 0.5 + k * 0.08, "r": 2.0, "dmg": b.dmg * 0.35, "small": true })
		"mine":
			if has("br_l3"):
				_add_zone(_ground(b.pos), b.r * 0.9, 4.0, "glue")
			if has("br_l4") and not b.small:
				for k in 2:
					var a := randf() * TAU
					_spawn("bomblet", b.pos + Vector3(0, 0.3, 0), Vector3(cos(a) * 4.0, 4.0, sin(a) * 4.0), 0.09,
						{ "life": 0.6 + k * 0.1, "r": b.r * 0.6, "dmg": b.dmg * 0.4, "small": true })

func _hit_enemy(a: Vector3, b: Vector3, r: float):
	var seg := b - a
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var c: Vector3 = e.center()
		var t := clampf((c - a).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		if (a + seg * t).distance_to(c) < r + e.T.r:
			return e
	return null

# ---- Moulin ----
func _firing_spin() -> bool:
	return p.W.get("spin", false) and p.intent.get("fire", false) and p.reload_t <= 0.0 and p.ammo > 0

func _update_spin(delta: float) -> void:
	if not p.W.get("spin", false):
		spin = 0.0
		return
	if _firing_spin():
		spin = minf(1.0, spin + delta / (0.6 if has("br_m1") else 1.2))
	else:
		spin = maxf(0.0, spin - delta * 1.5)
	for G in p.guns:
		if G.extra:
			G.extra.rotation.z += (2.0 + 40.0 * spin) * delta

func rate_mult() -> float:
	return 1.0 + 2.4 * spin if p.W.get("spin", false) else 1.0

func speed_mult() -> float:
	if _firing_spin():
		return 0.85 if has("br_m3") else 0.55
	return 1.0

func on_gun_hit(en, dmg: float, _ctx: Dictionary) -> void:
	if has("br_m2") and spin > 0.85 and is_instance_valid(en) and en.alive:
		en.bleed(dmg * 0.25, 2.0)

# ---------- Explosions ----------
func _explode(pos: Vector3, r: float, dmg: float, opts := {}) -> void:
	if has("br_wt1"):
		r *= 1.25
	var small: bool = opts.get("small", false)
	game.shockwave(pos, ORANGE, r)
	game.burst(pos, ORANGE, 10 if small else 24, 10.0)
	game.sfx.play("boom")
	game.shake = maxf(game.shake, 0.25 if small else 0.55)
	var hits := 0
	var killed := []
	for e in _near(pos, r):
		var away: Vector3 = e.global_position - pos
		game.damage_enemy(e, dmg, e.center(), { "src": "boom" })
		hits += 1
		if is_instance_valid(e) and e.alive:
			if not e.is_boss:
				game.knockback(e, Vector3(away.x, 0, away.z), 1.5 if small else 2.5)
		else:
			killed.append(e)
	if hits > 0:
		if has("br_vc1"):
			p.hp = minf(game.up.max_hp, p.hp + 1.5 * hits)
		if not small and hits >= 2:
			game.add_style("DÉMOLITION ×%d" % hits if hits >= 4 else "EXPLOSION ×%d" % hits, 12.0 * hits)
	if killed.size() >= 3 and has("br_vc2"):
		p.hp = minf(game.up.max_hp, p.hp + 15.0)
		game.hud.add_feed("FESTIN")
	if opts.get("chain", false):
		# Réaction en chaîne : chaque ennemi tué explose à son tour
		for e in killed:
			var c: Vector3 = e.center()
			game.get_tree().create_timer(0.15, false).timeout.connect(func(): _explode(c, 2.4, dmg * 0.7, { "small": true }))
	if opts.get("self_safe", false):
		return
	# le souffle touche aussi Brack : blessure légère, rocket jump, saut gratuit
	var pc: Vector3 = p.global_position + Vector3(0, 0.9, 0)
	var d := pc.distance_to(pos)
	if d < r:
		if not has("br_wt2"):
			_self_hurt((3.0 if small else 9.0) * (0.5 if has("br_ms1") else 1.0))
		if has("br_ms1") and not small:
			var push := pc - pos
			push.y = 0.0
			var hv := push.normalized() * 6.0 if push.length() > 0.2 else Vector3.ZERO
			p.velocity = Vector3(p.velocity.x + hv.x, maxf(p.velocity.y, 0.0) + 12.0, p.velocity.z + hv.z)
			game.add_style("ROCKET JUMP", 20)
	if has("br_ms4") and d < r * 1.5:
		p.jumps = 1

func _self_hurt(d: float) -> void:
	if p.iframes > 0.0 or game.state != "play":
		return
	if p.hp - d <= 0.0:
		game.hurt_player(d)
		return
	var absorbed := minf(game.shield, d)
	game.shield -= absorbed
	p.hp -= d - absorbed
	game.hud.flash(ORANGE, 0.35)

func _add_zone(pos: Vector3, r: float, t: float, kind: String) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = 0.05
	mi.mesh = cm
	mi.material_override = _glass(Color(1.0, 0.45, 0.1) if kind == "burn" else Color(0.6, 1.0, 0.35), 0.4)
	game.world.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	zones.append({ "pos": pos, "r": r, "t": t, "kind": kind, "node": mi, "tick": 0.0 })

func _update_zones(delta: float) -> void:
	for z in zones.duplicate():
		z.t -= delta
		z.tick -= delta
		if z.t <= 0.0:
			zones.erase(z)
			z.node.queue_free()
			continue
		if z.t < 1.0:
			z.node.visible = int(z.t * 8.0) % 2 == 0
		if z.tick <= 0.0:
			z.tick = 0.25
			for e in _near(z.pos + Vector3(0, 0.8, 0), z.r):
				if z.kind == "burn":
					game.damage_enemy(e, wave_dmg(6.0, 0.8), e.center(), { "src": "dot", "quiet": true })
				else:
					e.slow(0.4, 0.4)

func in_burn() -> bool:
	for z in zones:
		if z.kind == "burn" and Vector2(p.global_position.x - z.pos.x, p.global_position.z - z.pos.z).length() < z.r:
			return true
	return false

# ---------- Grappe ----------
func custom_grenade() -> bool:
	return true

func gren_max_bonus() -> int:
	return 1 if has("br_g1") else 0

func gren_rate_mult() -> float:
	return 1.25 if has("br_st1") else 1.0

func grenade_blast(pos: Vector3, _scale: float) -> void:
	var G: Dictionary = game.grenade()
	_explode(pos, G.radius, wave_dmg(G.dmg, 6.0))
	var n := 6 if has("br_g2") else 4
	var big: float = 1.35 if has("br_g3") else 1.0
	for k in n:
		var a := k * TAU / n + randf() * 0.4
		_spawn("bomblet", pos + Vector3(0, 0.4, 0), Vector3(cos(a) * 6.5, 6.0, sin(a) * 6.5), 0.1,
			{ "life": 0.55 + randf() * 0.25, "r": 2.6 * big, "dmg": wave_dmg(30.0, 4.0) * big, "small": true, "chain": has("br_g4") })
	game.add_style("GRAPPE", 10)

# ---------- Arbre ----------
func apply_node(id: String) -> void:
	var W: Dictionary = p.W
	match id:
		"br_t1":
			if W.id == "tambour":
				W.mag += 2; p.ammo += 2
		"br_l1":
			if W.id == "glu":
				W.mag += 2; p.ammo += 2
		"br_st1": game.up.skill_gain *= 1.25
		"br_vt1": game.up.max_hp += 40.0; p.hp += 40.0
		"br_vb1": game.shield = 30.0
		"br_vb4": p.hp += game.up.max_hp * 0.5; game.up.max_hp *= 1.5
		"br_mt1": game.up.speed *= 1.06

# ---------- Survie ----------
func hurt_mult(_d: float) -> float:
	var m := 1.0
	if has("br_vt2"):
		m *= 0.85
	if has("br_vb2") and still_t > 1.0:
		m *= 0.65
	if has("br_m4") and _firing_spin() and spin > 0.5:
		m *= 0.4
	if has("br_ss3") and in_burn():
		m *= 0.5
	return m

func on_hurt_check(d: float) -> bool:
	if rempart_t > 0.0:
		return true
	if has("br_vc4") and not rempart_used and p.hp - d * hurt_mult(d) <= 0.0:
		# Dernier rempart
		rempart_used = true
		rempart_t = 5.0
		rempart_kills = 0
		p.hp = 1.0
		game.hud.banner("Dernier rempart", "10 kills en 5 s")
		game.sfx.play("level")
		return true
	return false

func on_kill(_en, _c: Vector3, _ctx: Dictionary, _aerial: bool) -> void:
	if rempart_t > 0.0:
		rempart_kills += 1

func _crush() -> void:
	var c: Vector3 = p.global_position
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive or e.is_boss or e.T.r > SMALL_R:
			continue
		if absf(e.global_position.y - c.y) < 1.5 and Vector2(e.global_position.x - c.x, e.global_position.z - c.z).length() < e.T.r + 0.7:
			crush_cd = 0.3
			game.damage_enemy(e, wave_dmg(120.0, 12.0), e.center(), { "src": "gun" })
			game.add_style("ÉCRASÉ", 20)
			game.sfx.play("hit")
			return

# ---------- Mouvement : charge d'épaule ----------
func on_roll() -> bool:
	if not has("br_mt2"):
		return false
	var f: Vector3 = p.move_input()
	if f.length() < 0.1:
		f = Vector3(0, 0, -1).rotated(Vector3.UP, p.yaw)
	f.y = 0.0
	charge_dir = f.normalized()
	charge_t = 2.0 if has("br_mc4") else (0.68 if has("br_mc1") else 0.45)
	charge_hit = {}
	p.iframes = maxf(p.iframes, charge_t + 0.05)
	p.dodged = false
	game.sfx.play("dash")
	game.shake = maxf(game.shake, 0.3)
	return true

func move_override(delta: float) -> bool:
	if charge_t <= 0.0:
		return false
	charge_t -= delta
	p.velocity.x = charge_dir.x * 21.0
	p.velocity.z = charge_dir.z * 21.0
	p.iframes = maxf(p.iframes, 0.05)
	var c: Vector3 = p.global_position + Vector3(0, 0.9, 0)
	for e in _near(c, 1.6):
		if charge_hit.has(e):
			continue
		charge_hit[e] = true
		game.damage_enemy(e, wave_dmg(40.0, 5.0), e.center(), { "src": "charge" })
		game.sfx.play("hit")
		game.shake = maxf(game.shake, 0.45)
		if is_instance_valid(e) and e.alive:
			if not e.is_boss:
				game.knockback(e, charge_dir + (e.global_position - p.global_position).normalized() * 0.5, 4.0)
			if has("br_mc2"):
				e.stun(1.5)
			if not has("br_mc4") and (e.is_boss or e.T.r > SMALL_R):
				charge_t = 0.0   # un gros ennemi arrête la charge
		else:
			game.add_style("PERCUTÉ", 20)
			if has("br_mc3"):
				p.roll_cd = 0.0
	if p.is_on_wall() and charge_t < (1.95 if has("br_mc4") else 0.4):
		charge_t = 0.0
	if charge_t <= 0.0:
		p.velocity.x *= 0.3
		p.velocity.z *= 0.3
	return true

func on_land(fall_speed: float) -> void:
	if has("br_ms2") and fall_speed > 14.0:
		_explode(p.global_position + Vector3(0, 0.4, 0), 4.0, wave_dmg(50.0, 5.0), { "self_safe": true })

func on_wall_jump() -> void:
	if has("br_ms3"):
		_explode(p.global_position + Vector3(0, 1.0, 0), 3.5, wave_dmg(40.0, 4.0), { "self_safe": true })

# ---------- Outils ----------
func _aim_point() -> Dictionary:
	var o: Vector3 = p.eye_position()
	var dir: Vector3 = -p.cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * 80.0, 1 | 2, [p.get_rid()])
	var r: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	if r:
		var en = r.collider if r.collider.get("alive") != null else null
		return { "pos": r.position, "en": en }
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	return { "pos": p.global_position + flat * 25.0, "en": null }

func _ground(pos: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -40, 0), 1)
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3(pos.x, 0.0, pos.z)

func _glass(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _nearest(c: Vector3, r: float):
	var best = null
	var bd := r
	for e in game.enemies:
		if is_instance_valid(e) and e.alive and e.center().distance_to(c) < bd:
			bd = e.center().distance_to(c)
			best = e
	return best

func _near(c: Vector3, r: float) -> Array:
	return game.enemies.filter(func(e): return is_instance_valid(e) and e.alive and e.center().distance_to(c) < r + e.T.r)
