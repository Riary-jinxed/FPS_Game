# Données du jeu : armes, ennemis, boss, rangs de style, augments.
# Tout l'équilibrage se règle ici.
extends RefCounted

const WAVES_PER_ZONE := 10 # 7 zones de 10 rounds (mini boss round 5, boss de zone round 10)

const WEAPONS := {
	"rifle": {
		"id": "rifle", "name": "Fusil d'assaut", "mag": 30, "rate": 0.085, "dmg": 22.0, "pellets": 1,
		"spread": 0.012, "reload": 1.0, "kick": 0.012, "sound": "rifle", "color": Color("3fd0c9"),
		"blurb": "Précis et régulier. Récompense les tirs à la tête.",
		"stats": [["Dégâts", "Moyens"], ["Cadence", "Rapide"], ["Portée", "Longue"]],
	},
	"shotgun": {
		"id": "shotgun", "name": "Fusil à pompe", "mag": 6, "rate": 0.6, "dmg": 16.0, "pellets": 9,
		"spread": 0.07, "reload": 1.1, "kick": 0.05, "sound": "shotgun", "color": Color("ffc23d"),
		"blurb": "Dévastateur au contact. Parfait pour les kills aériens.",
		"stats": [["Dégâts", "Énormes"], ["Cadence", "Lente"], ["Portée", "Courte"]],
	},
	"uzi": {
		"id": "uzi", "name": "Double uzi", "mag": 50, "rate": 0.045, "dmg": 11.0, "pellets": 1,
		"spread": 0.035, "reload": 0.9, "kick": 0.006, "sound": "uzi", "color": Color("ff4fa3"),
		"blurb": "Un uzi dans chaque main. Une pluie de balles, un reload en double.",
		"stats": [["Dégâts", "Faibles"], ["Cadence", "Folle"], ["Portée", "Moyenne"]],
	},
}
const WEAPON_ORDER := ["rifle", "shotgun", "uzi"]

const ENEMIES := {
	"grunt":   { "hp": 24.0,  "speed": 6.5, "dmg": 10.0, "r": 0.5, "h": 1.6, "color": Color("c0392b"), "score": 100 },
	"runner":  { "hp": 14.0,  "speed": 11.0, "dmg": 7.0, "r": 0.4, "h": 1.1, "color": Color("ffc23d"), "score": 150 },
	"brute":   { "hp": 130.0, "speed": 4.0, "dmg": 25.0, "r": 0.9, "h": 2.4, "color": Color("8e44ad"), "score": 300 },
	"spitter": { "hp": 30.0,  "speed": 4.5, "dmg": 8.0, "r": 0.5, "h": 1.8, "color": Color("27ae60"), "score": 200, "ranged": true },
}

const BOSSES := [
	{ "name": "Le Colosse", "color": Color("ff5a36"), "hp": 2600.0, "speed": 4.2, "r": 2.0, "h": 5.0, "pattern": "slam" },
	{ "name": "La Nuée", "color": Color("3fd0c9"), "hp": 3200.0, "speed": 5.5, "r": 1.6, "h": 4.0, "pattern": "summon" },
	{ "name": "L'Ardent", "color": Color("ffc23d"), "hp": 3800.0, "speed": 3.8, "r": 1.8, "h": 4.5, "pattern": "barrage" },
]

# [nom, style minimum, multiplicateur de score]
const RANKS := [["D", 0, 1.0], ["C", 80, 1.2], ["B", 200, 1.5], ["A", 380, 1.8], ["S", 620, 2.2], ["SS", 900, 2.6], ["SSS", 1250, 3.0]]

const BASE_UP := {
	"speed": 1.0, "max_hp": 100.0, "lifesteal": 0.0, "roll_cd": 1.0, "jumps": 2, "pierce": 0, "crit": 2.0,
	"explode": 0, "regen": 0.0, "last_shots": 0, "recoil_jump": 0, "ricochet": 0, "air_dmg": 0,
	"slide_boost": 1.0, "style_mult": 1.0, "mag_boom": 1.0,
}

# "weapon" vide = augment commun. L'effet de chaque id est appliqué dans main.gd (apply_augment).
const AUGMENTS := [
	{ "id": "dmg", "name": "Munitions lourdes", "desc": "+20 % de dégâts", "tag": "Arme" },
	{ "id": "mag", "name": "Chargeur étendu", "desc": "+30 % de capacité du chargeur", "tag": "Arme" },
	{ "id": "reload", "name": "Mains rapides", "desc": "Recharge 20 % plus vite", "tag": "Arme", "max": 3 },
	{ "id": "juggle", "name": "Jongleur", "desc": "Les chargeurs tirés en vol explosent 50 % plus fort", "tag": "Style", "max": 3 },
	{ "id": "show", "name": "Showman", "desc": "+25 % de points de style", "tag": "Style", "max": 3 },
	{ "id": "speed", "name": "Semelles légères", "desc": "+10 % de vitesse de déplacement", "tag": "Mobilité", "max": 4 },
	{ "id": "roll", "name": "Roulade éclair", "desc": "La roulade se recharge 25 % plus vite", "tag": "Mobilité", "max": 3 },
	{ "id": "slide", "name": "Glissade turbo", "desc": "Glissade 25 % plus rapide", "tag": "Mobilité", "max": 2 },
	{ "id": "jump", "name": "Triple saut", "desc": "Un saut supplémentaire en l'air", "tag": "Mobilité", "max": 2 },
	{ "id": "hp", "name": "Blindage", "desc": "+25 santé max et soin complet", "tag": "Survie" },
	{ "id": "leech", "name": "Vampirisme", "desc": "+3 santé à chaque ennemi tué", "tag": "Survie" },
	{ "id": "regen", "name": "Nanites", "desc": "Régénère 1,5 santé par seconde", "tag": "Survie" },
	{ "id": "boom", "name": "Charges instables", "desc": "Les ennemis explosent en mourant et blessent leurs voisins", "tag": "Chaos" },
	{ "id": "r_pierce", "weapon": "rifle", "name": "Balles perforantes", "desc": "Les balles traversent un ennemi de plus", "max": 3 },
	{ "id": "r_lynx", "weapon": "rifle", "name": "Œil de lynx", "desc": "Tirs à la tête : +100 % de dégâts en plus", "max": 3 },
	{ "id": "r_last", "weapon": "rifle", "name": "Dernières balles", "desc": "Les 5 dernières balles du chargeur font double dégâts", "max": 2 },
	{ "id": "r_steady", "weapon": "rifle", "name": "Visée stable", "desc": "Dispersion et recul réduits de moitié", "max": 1 },
	{ "id": "s_pellets", "weapon": "shotgun", "name": "Chevrotine", "desc": "+3 plombs par tir", "max": 3 },
	{ "id": "s_choke", "weapon": "shotgun", "name": "Choke serré", "desc": "Dispersion réduite de 30 %, portée accrue", "max": 2 },
	{ "id": "s_blast", "weapon": "shotgun", "name": "Recul propulsif", "desc": "Tirer en l'air te projette en arrière : un rocket jump au pompe", "max": 2 },
	{ "id": "s_pump", "weapon": "shotgun", "name": "Pompe nerveuse", "desc": "+25 % de cadence de tir", "max": 3 },
	{ "id": "u_ric", "weapon": "uzi", "name": "Ricochet", "desc": "30 % de chances qu'une balle rebondisse sur un ennemi proche", "max": 3 },
	{ "id": "u_drum", "weapon": "uzi", "name": "Chargeurs tambour", "desc": "+50 % de balles par chargeur", "max": 2 },
	{ "id": "u_air", "weapon": "uzi", "name": "Pluie de plomb", "desc": "+50 % de dégâts quand tu es en l'air", "max": 2 },
	{ "id": "u_frenzy", "weapon": "uzi", "name": "Frénésie", "desc": "+20 % de cadence de tir", "max": 3 },
]
