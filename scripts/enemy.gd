# Ennemi de base et boss. Le corps est une boîte de collision (calque 2), le visuel est construit en code.
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
var B := {}
var phase2 := false
var ability_cd := 4.0
var alive := true
var hop_seed := 0.0
var visual: Node3D
var mat: StandardMaterial3D
var ring: MeshInstance3D

func setup(g, tname: String, t: Dictionary, mult: float, boss_def := {}) -> void:
	game = g
	type_name = tname
	T = t
	hp = t.hp * mult
	max_hp = hp
	speed = t.speed
	shoot_cd = 1.0 + randf() * 2.0
	hop_seed = randf() * 10.0
	if not boss_def.is_empty():
		is_boss = true
		B = boss_def
		spawn_t = 1.0
		shoot_cd = 2.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(T.r * 1.6, T.h, T.r * 1.6)
	col.shape = shape
	col.position.y = T.h * 0.5
	add_child(col)
	visual = Node3D.new()
	add_child(visual)
	mat = StandardMaterial3D.new()
	mat.albedo_color = T.color
	mat.emission_enabled = true
	mat.emission = T.color
	mat.emission_energy_multiplier = 0.15
	_box(Vector3(T.r * 1.6, T.h * 0.7, T.r * 1.2), Vector3(0, T.h * 0.45, 0), mat)
	_box(Vector3(T.r * 1.1, T.h * 0.28, T.r * 1.1), Vector3(0, T.h * 0.92, 0), mat)
	var eye := StandardMaterial3D.new()
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.albedo_color = Color.WHITE
	_box(Vector3(T.r * 0.8, T.h * 0.05, 0.02), Vector3(0, T.h * 0.94, -T.r * 0.56), eye)
	if is_boss:
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = T.r * 1.4 - 0.08
		tm.outer_radius = T.r * 1.4 + 0.08
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = T.color
		ring.material_override = rm
		ring.position.y = 0.2
		visual.add_child(ring)
	visual.scale = Vector3.ONE * 0.05

func _box(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	visual.add_child(mi)

func center() -> Vector3:
	return global_position + Vector3(0, T.h * 0.5, 0)

func _physics_process(delta: float) -> void:
	if not alive or game.state != "play":
		return
	if spawn_t > 0.0:
		spawn_t -= delta
		visual.scale = Vector3.ONE * clampf(1.0 - maxf(spawn_t, 0.0) * (1.0 if is_boss else 2.0), 0.05, 1.0)
		return
	visual.scale = Vector3.ONE
	var p = game.player
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	visual.rotation.y = atan2(-dir.x, -dir.z)
	var spd := speed
	if T.get("ranged", false) and dist < 16.0:
		spd = -speed * 0.6 if dist < 10.0 else 0.0
	if is_boss:
		_boss_ai(dist, delta)
	if dist > T.r + 0.6 or spd < 0.0:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = -0.5 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	if not is_boss:
		visual.position.y = absf(sin(game.gt * 12.0 * speed / 6.0 + hop_seed)) * 0.12
	# contact
	atk_cd -= delta
	if dist < T.r + 0.8 and absf(p.global_position.y - global_position.y) < T.h and atk_cd <= 0.0:
		game.hurt_player(T.dmg)
		atk_cd = 0.8
	if game.state != "play":
		return
	if T.get("ranged", false):
		shoot_cd -= delta
		if shoot_cd <= 0.0 and dist < 30.0:
			var from := global_position + Vector3(0, T.h * 0.9, 0)
			game.fire_shot(from, (p.eye_position() - from).normalized(), 16.0, T.dmg, Color("7dff9a"), 0.2)
			shoot_cd = 2.0 + randf() * 1.5
			game.sfx.play("orb")
	if flash_t > 0.0:
		flash_t -= delta
		mat.emission_energy_multiplier = 2.0
	else:
		mat.emission_energy_multiplier = 0.15

func _boss_ai(dist: float, delta: float) -> void:
	ring.rotation.y += delta * 2.0
	if not phase2 and hp < max_hp / 2.0:
		phase2 = true
		speed *= 1.35
		game.music.play("boss2")
		game.hud.banner("Phase 2", B.name + " enrage")
		game.sfx.play("boss")
	ability_cd -= delta
	shoot_cd -= delta
	var p = game.player
	var from := global_position + Vector3(0, T.h * 0.85, 0)
	if shoot_cd <= 0.0:
		var aim: Vector3 = (p.eye_position() - from).normalized()
		var n := 5 if phase2 else 3
		for k in n:
			game.fire_shot(from, aim.rotated(Vector3.UP, (k - (n - 1) / 2.0) * 0.12), 20.0, 12.0, T.color, 0.35)
		shoot_cd = 1.1 if phase2 else 1.8
		game.sfx.play("orb")
	if ability_cd <= 0.0:
		match B.pattern:
			"slam":
				# onde de choc au sol puis bond vers le joueur
				for k in 24:
					var a := k / 24.0 * TAU
					game.fire_shot(Vector3(global_position.x, 0.5, global_position.z), Vector3(cos(a), 0, sin(a)), 13.0, 18.0, Color("ff5a36"), 0.4)
				var hop: Vector3 = (p.global_position - global_position) * 0.35
				hop.y = 0.0
				global_position += hop
				game.shake = 0.8
				game.sfx.play("boss")
			"summon":
				for k in (8 if phase2 else 5):
					game.to_spawn.append("runner")
				game.spawn_timer = 0.0
				for k in 12:
					var a := k / 12.0 * TAU
					game.fire_shot(from, Vector3(cos(a), 0.05, sin(a)).normalized(), 14.0, 10.0, Color("3fd0c9"), 0.3)
			_:
				# pluie de projectiles autour du joueur
				for k in (14 if phase2 else 9):
					var src := Vector3(p.global_position.x + randf_range(-5, 5), 18.0 + randf() * 6.0, p.global_position.z + randf_range(-5, 5))
					game.fire_shot(src, Vector3.DOWN, 10.0 + randf() * 4.0, 15.0, Color("ffc23d"), 0.45)
		ability_cd = 4.0 if phase2 else 6.5
