# Chargeur éjecté pendant un rechargement. Touché en vol, il fonce sur un ennemi et explose.
extends Node3D

var game
var vel := Vector3.ZERO
var spin := Vector3(10, 3, 5)
var state := "fly" # fly, homing, dead
var life := 4.0
var target = null
var dir := Vector3.FORWARD
var mat: StandardMaterial3D

func _physics_process(delta: float) -> void:
	if game.state != "play":
		return
	life -= delta
	match state:
		"fly":
			vel.y -= 7.0 * delta
			var from := global_position
			var to := from + vel * delta
			if to.y < 0.08 or life <= 0.0 or game.ray_world(from, to):
				# retombé : simple débris qui disparaît
				state = "dead"
				mat.emission_energy_multiplier = 0.0
				global_position.y = maxf(0.08, to.y)
				get_tree().create_timer(1.0).timeout.connect(queue_free)
				return
			global_position = to
			rotate_x(spin.x * delta)
			rotate_z(spin.z * delta)
		"homing":
			var d := dir
			var valid: bool = target != null and is_instance_valid(target) and target.alive
			if valid:
				d = (target.center() - global_position).normalized()
			var from := global_position
			var to := from + d * 42.0 * delta
			rotate_x(30.0 * delta)
			if randf() < 0.6:
				game.burst(from, Color("ffc23d"), 1, 1.5)
			var close: bool = valid and to.distance_to(target.center()) < target.T.r + 0.8
			global_position = to
			if close or life <= 0.0 or to.y < 0.1 or game.ray_world(from, to):
				game.explode_mag(self)

func launch(t, d: Vector3) -> void:
	state = "homing"
	life = 2.5
	target = t
	dir = d
	mat.emission_energy_multiplier = 4.0
