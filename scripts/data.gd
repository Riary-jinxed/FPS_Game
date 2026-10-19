# Données du jeu : personnages, armes, ennemis, rounds, boss, shop, arbre de compétences, augments.
# Tout l'équilibrage se règle ici.
extends RefCounted

const WAVES_PER_ZONE := 10 # 7 zones de 10 rounds (mini boss round 5, boss de zone round 10)
const SHOP_ROUNDS := [3, 6, 9]
const MINIBOSS_ROUND := 5
const BOSS_ROUND := 10

# ---------- Personnages ----------
# Chaque perso a sa compétence (chargée par le combo), sa liste d'armes et son arbre.
const CHARACTERS := {
	"kade": {
		"id": "kade", "name": "Kade", "title": "Lame du Syndicat",
		"blurb": "Ancien nettoyeur de la ville-système. Vit pour l'élan et les kills en l'air.",
		"skill": "Surcharge", "skill_desc": "Le temps ralentit autour de toi : munitions infinies, +50 % de dégâts, +25 % de cadence.",
		"weapons": ["rifle", "shotgun", "uzi"],
		"skill_time": 6.0,
	},
}
const CHARACTER_ORDER := ["kade"]

# L'arbre se remplit avec les points de niveau, entre deux rounds. 3 branches, le dernier nœud est la version améliorée.
const TREE := {
	"kade": [
		{ "branch": "Surcharge", "nodes": [
			{ "id": "s1", "name": "Batterie", "desc": "La jauge de Surcharge se remplit 25 % plus vite" },
			{ "id": "s2", "name": "Prolongation", "desc": "Surcharge dure 2 s de plus" },
			{ "id": "s3", "name": "Onde de choc", "desc": "Activer Surcharge souffle et blesse les ennemis proches" },
			{ "id": "s4", "name": "Surcharge+", "desc": "Chaque kill en Surcharge la prolonge de 0,5 s", "ult": true },
		] },
		{ "branch": "Armes", "nodes": [
			{ "id": "w1", "name": "Calibre", "desc": "+12 % de dégâts" },
			{ "id": "w2", "name": "Doigts agiles", "desc": "Recharge 15 % plus vite" },
			{ "id": "w3", "name": "Chargeur piégé", "desc": "Les chargeurs tirés en vol explosent 40 % plus fort" },
			{ "id": "w4", "name": "Pluie d'acier", "desc": "Un chargeur touché se divise en 3 et frappe 3 ennemis", "ult": true },
		] },
		{ "branch": "Mobilité", "nodes": [
			{ "id": "m1", "name": "Coureur de murs", "desc": "Le wall run dure 50 % plus longtemps" },
			{ "id": "m2", "name": "Réflexes", "desc": "La roulade se recharge 20 % plus vite" },
			{ "id": "m3", "name": "Élan", "desc": "+8 % de vitesse, glissade plus puissante" },
			{ "id": "m4", "name": "Danse murale", "desc": "Un kill en l'air ou sur un mur recharge la roulade et rapporte +50 % de style", "ult": true },
		] },
	],
}

# ---------- Armes ----------
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

# ---------- Déplacement ----------
# Réglages du mouvement : accélération forte, freinage doux et élan conservé en l'air.
const MOVE := {
	"speed": 12.0, "accel": 16.0, "friction": 5.0, "air_accel": 7.0, "air_drag": 0.15,
	"gravity": 22.0, "jump": 9.5, "air_jump": 8.5, "bhop_keep": 0.97,
}

# ---------- Ennemis ----------
# Couleurs chaudes et saturées (rouge, orange, ambre, magenta, lime) : le décor est froid pour qu'ils ressortent.
# ai : walk (corps à corps), ranged (tir et garde ses distances), drone (vole et tire), kamikaze (vole et explose),
# sniper (laser depuis les toits), hacker (brouille le HUD et se téléporte). shield : bouclier frontal.
# cr : crédits gagnés, xp : expérience.
const ENEMIES := {
	"grunt":   { "name": "Grunt", "ai": "walk", "hp": 24.0, "speed": 6.5, "dmg": 10.0, "r": 0.5, "h": 1.6, "color": Color("ff3b30"), "score": 100, "cr": 4, "xp": 10 },
	"runner":  { "name": "Runner", "ai": "walk", "hp": 14.0, "speed": 11.0, "dmg": 7.0, "r": 0.4, "h": 1.1, "color": Color("ffb000"), "score": 150, "cr": 5, "xp": 12 },
	"brute":   { "name": "Brute", "ai": "walk", "hp": 130.0, "speed": 4.0, "dmg": 25.0, "r": 0.9, "h": 2.4, "color": Color("ff6b1a"), "score": 300, "cr": 14, "xp": 35 },
	"spitter": { "name": "Spitter", "ai": "ranged", "hp": 30.0, "speed": 4.5, "dmg": 8.0, "r": 0.5, "h": 1.8, "color": Color("c6ff1a"), "score": 200, "cr": 7, "xp": 18 },
	"drone":   { "name": "Drone", "ai": "drone", "hp": 20.0, "speed": 8.0, "dmg": 7.0, "r": 0.5, "h": 0.6, "color": Color("ff4060"), "score": 180, "cr": 6, "xp": 15, "fly": true },
	"shield":  { "name": "Bouclier", "ai": "walk", "hp": 60.0, "speed": 5.0, "dmg": 14.0, "r": 0.6, "h": 1.9, "color": Color("ffd23f"), "score": 250, "cr": 10, "xp": 25, "shield": true },
	"hacker":  { "name": "Hacker", "ai": "hacker", "hp": 34.0, "speed": 6.0, "dmg": 6.0, "r": 0.45, "h": 1.7, "color": Color("ff3cf0"), "score": 280, "cr": 12, "xp": 28 },
	"sniper":  { "name": "Sniper", "ai": "sniper", "hp": 40.0, "speed": 0.0, "dmg": 26.0, "r": 0.5, "h": 1.9, "color": Color("ff1f3d"), "score": 320, "cr": 14, "xp": 30 },
	"pub":     { "name": "Drone pub", "ai": "kamikaze", "hp": 8.0, "speed": 13.0, "dmg": 12.0, "r": 0.35, "h": 0.5, "color": Color("ff8a3d"), "score": 60, "cr": 2, "xp": 5, "fly": true },
}

# ---------- Zones ----------
# Chaque round : nombre d'ennemis et poids de chaque type. "miniboss" / "boss" : round de boss avec une escorte.
const ZONES := [
	{
		"name": "Ville néon", "rounds": [
			{ "n": 10, "mix": { "grunt": 1.0 } },
			{ "n": 14, "mix": { "grunt": 0.65, "runner": 0.35 } },
			{ "n": 18, "mix": { "grunt": 0.45, "runner": 0.25, "drone": 0.3 } },
			{ "n": 22, "mix": { "grunt": 0.35, "runner": 0.2, "shield": 0.2, "spitter": 0.25 } },
			{ "n": 12, "mix": { "grunt": 0.5, "runner": 0.3, "pub": 0.2 }, "special": "miniboss" },
			{ "n": 26, "mix": { "grunt": 0.3, "runner": 0.2, "shield": 0.15, "hacker": 0.12, "drone": 0.13, "sniper": 0.1 } },
			{ "n": 30, "mix": { "grunt": 0.25, "runner": 0.2, "shield": 0.12, "hacker": 0.1, "spitter": 0.1, "sniper": 0.08, "pub": 0.15 } },
			{ "n": 34, "mix": { "grunt": 0.25, "runner": 0.2, "brute": 0.07, "shield": 0.12, "hacker": 0.08, "drone": 0.1, "sniper": 0.08, "pub": 0.1 } },
			{ "n": 38, "mix": { "grunt": 0.2, "runner": 0.2, "brute": 0.08, "shield": 0.12, "hacker": 0.1, "drone": 0.1, "spitter": 0.08, "sniper": 0.07, "pub": 0.05 } },
			{ "n": 14, "mix": { "grunt": 0.4, "runner": 0.4, "drone": 0.2 }, "special": "boss" },
		],
		"miniboss": { "name": "Le Brouilleur", "color": Color("ff3cf0"), "hp": 1500.0, "speed": 5.0, "r": 1.3, "h": 4.0, "pattern": "glitch", "score": 3000, "cr": 80, "xp": 150 },
		"boss": { "name": "Titan Néon", "color": Color("ff3b30"), "hp": 4600.0, "speed": 4.0, "r": 2.2, "h": 6.0, "pattern": "titan", "score": 8000, "cr": 150, "xp": 300 },
	},
]
const MAX_SNIPERS := 3

# [nom, style minimum, multiplicateur de score]
const RANKS := [["D", 0, 1.0], ["C", 80, 1.2], ["B", 200, 1.5], ["A", 380, 1.8], ["S", 620, 2.2], ["SS", 900, 2.6], ["SSS", 1250, 3.0]]

const BASE_UP := {
	"speed": 1.0, "max_hp": 100.0, "lifesteal": 0.0, "roll_cd": 1.0, "jumps": 2, "pierce": 0, "crit": 2.0,
	"explode": 0, "regen": 0.0, "last_shots": 0, "recoil_jump": 0, "ricochet": 0, "air_dmg": 0,
	"slide_boost": 1.0, "style_mult": 1.0, "mag_boom": 1.0, "wallrun": 1.0, "skill_gain": 1.0, "skill_time": 0.0, "credit_mult": 1.0,
}

# ---------- XP ----------
static func xp_for_level(lvl: int) -> int:
	return 80 + 50 * (lvl - 1)

# ---------- Shop ----------
const MODS := [
	{ "id": "mod_barrel", "name": "Canon long", "desc": "Dispersion réduite de 30 %", "price": 90 },
	{ "id": "mod_trigger", "name": "Détente sèche", "desc": "+12 % de cadence de tir", "price": 110 },
	{ "id": "mod_bolt", "name": "Culasse rapide", "desc": "Recharge 20 % plus vite", "price": 90 },
	{ "id": "mod_ext", "name": "Grande capacité", "desc": "+25 % de balles par chargeur", "price": 100 },
]
const HEALS := [
	{ "id": "heal_s", "name": "Stim", "desc": "+40 santé", "price": 45 },
	{ "id": "heal_l", "name": "Soin complet", "desc": "Santé au maximum", "price": 100 },
]
const AUG_PRICE := 110
const UPGRADE_PRICE := 140

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
	{ "id": "greed", "name": "Prime de combo", "desc": "+30 % de crédits gagnés", "tag": "Économie", "max": 2 },
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
