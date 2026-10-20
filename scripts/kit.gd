# Kit d'un perso : sa compétence, sa grenade, ses armes à mode spécial et les effets de son arbre.
# Kade utilise ce kit de base (ses effets historiques sont codés dans main.gd et player.gd) ;
# Nyx, Brack et Iris ont leur kit dans scripts/kits/ et redéfinissent les fonctions utiles.
# Les valeurs par défaut sont neutres : un kit qui ne redéfinit rien ne change rien.
extends Node

const Data = preload("res://scripts/data.gd")

var game
var p                       # le joueur
var active := 0.0           # temps restant de la compétence du kit (0 = inactive)

func has(id: String) -> bool:
	return game.tree.has(id)

func reset() -> void:
	active = 0.0

# ---------- Compétence ----------
func custom_skill() -> bool:
	# false : compétence historique de Kade (Surcharge, dans main.gd)
	return false

func activate() -> void:
	pass

func skill_time() -> float:
	return Data.CHARACTERS[game.character].skill_time + game.up.skill_time

func skill_hud() -> Dictionary:
	var name: String = Data.CHARACTERS[game.character].skill.to_upper()
	if active > 0.0:
		return { "pct": 100.0 * active / skill_time(), "txt": name + " ACTIVE", "ready": true }
	return { "pct": p.skill, "txt": (name + " PRÊTE · E") if p.skill >= 100.0 else "%s  %d %%" % [name, int(p.skill)], "ready": p.skill >= 100.0 }

func tick(_delta: float) -> void:
	pass

# ---------- Grenade ----------
func custom_grenade() -> bool:
	return false

func grenade_blast(_pos: Vector3, _scale: float) -> void:
	pass

func gren_max_bonus() -> int:
	return 0

func gren_rate_mult() -> float:
	return 1.0

# ---------- Arbre ----------
func apply_node(_id: String) -> void:
	pass

# ---------- Combat ----------
func dmg_mult(_en, _ctx: Dictionary) -> float:
	# multiplicateur des dégâts que tu infliges à cet ennemi
	return 1.0

func shot_mult() -> float:
	# multiplicateur des dégâts de l'arme (lu au moment du tir)
	return 1.0

func spread_mult() -> float:
	return 1.0

func rate_mult() -> float:
	return 1.0

func on_gun_hit(_en, _dmg: float, _ctx: Dictionary) -> void:
	pass

func on_shot() -> void:
	pass

func on_kill(_en, _c: Vector3, _ctx: Dictionary, _aerial: bool) -> void:
	pass

func hurt_mult(_d: float) -> float:
	return 1.0

func on_hurt_check(_d: float) -> bool:
	# true : le coup est annulé
	return false

func fire() -> bool:
	# armes à mode spécial (lames, carreaux, mines...) : true si le kit a géré le tir
	return false

func alt_fire() -> bool:
	# tir secondaire de l'arme ; false = clic droit lance la compétence
	return false

func can_reload() -> bool:
	return true

func throws_mags() -> bool:
	# chargeurs lancés au rechargement : l'identité de Kade
	return true

# ---------- Mouvement ----------
func on_jump(_air: bool) -> void:
	pass

func on_wall_jump() -> void:
	pass

func on_land(_fall_speed: float) -> void:
	pass

func move_override(_delta: float) -> bool:
	# true : le kit pilote le mouvement ce pas-ci (charge d'épaule...)
	return false

func on_roll() -> bool:
	# true : le kit remplace la roulade
	return false

func on_dodge() -> void:
	pass

func gravity_mult(_hold: bool) -> float:
	return 1.0

func wallrun_infinite() -> bool:
	return false

func wall_boost() -> bool:
	return false

func walljump_bonus() -> Vector2:
	# x : multiplicateur de vitesse horizontale, y : vitesse verticale ajoutée
	return Vector2(1.0, 0.0)

func speed_mult() -> float:
	return 1.0

func extra_jumps() -> int:
	return 0

func hidden_from(_dist: float) -> bool:
	# true : les tireurs à cette distance ne voient pas le joueur
	return false
