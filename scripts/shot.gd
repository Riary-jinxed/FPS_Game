# Projectile ennemi. La roulade le traverse (et compte comme une esquive).
extends Node3D

var game
var vel := Vector3.ZERO
var dmg := 10.0
var radius := 0.25
var life := 5.0
var dodged := false
var color := Color.WHITE

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	add_child(mi)

func _physics_process(delta: float) -> void:
	if game.state != "play":
		return
	var from := global_position
	var to: Vector3 = from + vel * delta * game.enemy_slow
	life -= delta * game.enemy_slow
	var p = game.player
	var pp: Vector3 = p.global_position
	var near: bool = absf(to.x - pp.x) < 0.5 + radius and absf(to.z - pp.z) < 0.5 + radius and to.y > pp.y - radius and to.y < pp.y + 1.8 + radius
	var hit := false
	if near and not dodged:
		hit = game.hurt_player(dmg)
		if not hit:
			dodged = true
	if game.state != "play":
		return
	if hit or life <= 0.0 or to.y < 0.0 or game.ray_world(from, to):
		if not hit:
			game.burst(to, color, 4, 3.0)
		queue_free()
		return
	global_position = to
