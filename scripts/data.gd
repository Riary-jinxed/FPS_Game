# Données du jeu : personnages, armes, ennemis, rounds, boss, shop, arbre de compétences, augments.
# Tout l'équilibrage se règle ici.
extends RefCounted

const DC = preload("res://scripts/data_chars.gd")

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
		"weapons": ["jumeaux", "brise_porte", "verdict"],
		"skill_time": 6.0, "hp": 100.0, "speed": 1.0, "kit": "", "color": Color("3fd0c9"),
		"unlock": "",
		# consommable : se recharge avec le temps, plus vite quand la note de style est haute
		"grenade": { "name": "Impulsion", "desc": "Grenade à impact : souffle les ennemis et te propulse si tu es dans l'explosion.",
			"cd": 15.0, "dmg": 80.0, "radius": 5.0, "color": "4fc3ff" },
	},
	"nyx": {
		"id": "nyx", "name": "Nyx", "title": "la Coureuse",
		"blurb": "Coursière de toits. Plus elle va vite, plus elle frappe fort, et elle déteste toucher le sol.",
		"skill": "Overdrive", "skill_desc": "Wall run illimité, triple saut et tirs en l'air +40 % de dégâts.",
		"weapons": ["essaim", "crocs", "harpon"],
		"skill_time": 7.0, "hp": 90.0, "speed": 1.06, "kit": "res://scripts/kits/nyx.gd", "color": Color("5effc8"),
		"unlock": "Bats le boss de la zone 2 (Fonderie)",
		"grenade": { "name": "Tremplin", "desc": "Étourdit à l'impact et laisse au sol un tremplin qui propulse très haut.",
			"cd": 15.0, "dmg": 40.0, "radius": 4.5, "color": "5effc8" },
	},
	"brack": {
		"id": "brack", "name": "Brack", "title": "le Démolisseur",
		"blurb": "Ex-démolisseur de chantier. Lent, increvable, et tout ce qu'il touche finit en cratère.",
		"skill": "Frappe orbitale", "skill_desc": "Marque une zone à la visée : elle est écrasée par une frappe 1,5 s plus tard.",
		"weapons": ["tambour", "moulin", "glu"],
		"skill_time": 4.0, "hp": 140.0, "speed": 0.9, "kit": "res://scripts/kits/brack.gd", "color": Color("ff8a3d"),
		"unlock": "Succès Démolition : 15 ennemis tués par une seule explosion, ou 500 kills par explosion",
		"grenade": { "name": "Grappe", "desc": "Grosse charge qui se divise en 4 petites bombes à l'impact.",
			"cd": 15.0, "dmg": 50.0, "radius": 3.5, "color": "ffa13d" },
	},
	"iris": {
		"id": "iris", "name": "Iris", "title": "la Hackeuse",
		"blurb": "Elle a écrit la moitié du code de la ville-système. L'autre moitié lui obéit quand même.",
		"skill": "Piratage", "skill_desc": "Les ennemis dans un cône devant toi se battent pour toi pendant 8 s.",
		"weapons": ["aiguille", "mouche", "patch"],
		"skill_time": 8.0, "hp": 100.0, "speed": 1.0, "kit": "res://scripts/kits/iris.gd", "color": Color("c77dff"),
		"unlock": "Palier du Terminal : 600 Données (clique sur Iris dans le menu pour l'acheter)",
		"grenade": { "name": "Brouilleur", "desc": "Impulsion qui marque les ennemis et coupe leurs tirs 3 s.",
			"cd": 15.0, "dmg": 25.0, "radius": 5.0, "color": "c77dff" },
	},
}
const CHARACTER_ORDER := ["kade", "nyx", "brack", "iris"]

# ---------- Maîtrise (méta-progression par perso) ----------
# La maîtrise monte avec l'XP gagnée en jouant le perso. Le perso commence avec sa 1re arme unique,
# la 2e arrive au niveau de maîtrise 2, la 3e au niveau 4.
const MASTERY_XP := 1800
const WEAPON_MASTERY := [1, 2, 4]
const IRIS_PRICE := 600      # palier du Terminal, en Données
const BRACK_BLAST := 15      # succès Démolition : ennemis tués par une seule explosion
const BRACK_TOTAL := 500     # ... ou kills par explosion au total

static func mastery_level(mxp: int) -> int:
	return mini(10, 1 + mxp / MASTERY_XP)

# Arbre en flocon : 4 branches (Armes en haut, Compétence à droite, Survie en bas, Déplacement à gauche).
# Chaque branche : un tronc de 2 nœuds, puis des sous-branches de 3 nœuds et une pointe (version améliorée).
# Armes : une sous-branche par arme unique du perso, active seulement avec cette arme.
# On avance depuis le centre ; un run complet donne environ 22 points, on ne remplit jamais tout.
# L'effet de chaque id est lu dans main.gd et player.gd (has_node).
const TREE := {
	"nyx": DC.NYX_TREE, "brack": DC.BRACK_TREE, "iris": DC.IRIS_TREE,
	"kade": [
		{ "id": "w", "name": "Armes", "dir": Vector2(0, -1), "trunk": [
			{ "id": "w_t1", "name": "Main lourde", "desc": "Un kill à bout portant recharge l'arme" },
			{ "id": "w_t2", "name": "Chargeur piégé", "desc": "Les chargeurs tirés en vol explosent 40 % plus fort" },
		], "subs": [
			{ "name": "Jumeaux", "weapon": "jumeaux", "nodes": [
				{ "id": "w_j1", "name": "Précision aérienne", "desc": "En l'air : aucune dispersion et +20 % de dégâts" },
				{ "id": "w_j2", "name": "Dixième balle", "desc": "Une balle sur 10 ricoche sur un autre ennemi" },
				{ "id": "w_j3", "name": "Tir alterné", "desc": "+30 % de cadence en wall run" },
				{ "id": "w_j4", "name": "Ballet", "desc": "En l'air, chaque balle qui touche frappe aussi un 2e ennemi", "ult": true },
			] },
			{ "name": "Brise-porte", "weapon": "brise_porte", "nodes": [
				{ "id": "w_b1", "name": "3e cartouche", "desc": "Une cartouche de plus (3 au lieu de 2)" },
				{ "id": "w_b2", "name": "Recul blessant", "desc": "Le recul propulsif blesse les ennemis sur ta trajectoire" },
				{ "id": "w_b3", "name": "Rechargement brutal", "desc": "Un kill à bout portant rend une cartouche" },
				{ "id": "w_b4", "name": "Bélier", "desc": "Tirer en glissade repousse les ennemis touchés et fait +50 % de dégâts", "ult": true },
			] },
			{ "name": "Verdict", "weapon": "verdict", "nodes": [
				{ "id": "w_v1", "name": "À la volée", "desc": "Un tir à la tête remet une balle dans le barillet" },
				{ "id": "w_v2", "name": "Exécution rentable", "desc": "Une exécution rend une balle" },
				{ "id": "w_v3", "name": "Sans appel", "desc": "Seuil d'exécution à 40 % de vie" },
				{ "id": "w_v4", "name": "Sentence", "desc": "Une exécution fait exploser la cible", "ult": true },
			] },
		] },
		{ "id": "s", "name": "Compétence", "dir": Vector2(1, 0), "trunk": [
			{ "id": "s_t1", "name": "Batterie", "desc": "La jauge de Surcharge se remplit 25 % plus vite, et la grenade se recharge 25 % plus vite" },
			{ "id": "s_t2", "name": "Prolongation", "desc": "Surcharge dure 2 s de plus" },
		], "subs": [
			{ "name": "Ralenti", "nodes": [
				{ "id": "s_r1", "name": "Temps mort", "desc": "Le ralenti de Surcharge est plus fort" },
				{ "id": "s_r2", "name": "Sang-froid", "desc": "Aucun dégât pendant la 1re seconde de Surcharge" },
				{ "id": "s_r3", "name": "Chasseur", "desc": "Chaque kill en Surcharge la prolonge de 0,5 s" },
				{ "id": "s_r4", "name": "Exécution", "desc": "À la fin de Surcharge, chaque ennemi touché pendant prend un gros coup", "ult": true },
			] },
			{ "name": "Déchaînement", "nodes": [
				{ "id": "s_d1", "name": "Onde de choc", "desc": "Activer Surcharge souffle et blesse les ennemis proches" },
				{ "id": "s_d2", "name": "Rafale de lames", "desc": "En Surcharge, un chargeur touché se divise en 3" },
				{ "id": "s_d3", "name": "Écho", "desc": "5 kills pendant Surcharge rendent la moitié de la jauge" },
				{ "id": "s_d4", "name": "Tempête", "desc": "Surcharge se relance gratuitement une fois dans les 10 s qui suivent", "ult": true },
			] },
			{ "name": "Impulsion", "nodes": [
				{ "id": "s_g1", "name": "Double charge", "desc": "Deux grenades en réserve" },
				{ "id": "s_g2", "name": "Gros souffle", "desc": "Rayon d'explosion +40 %" },
				{ "id": "s_g3", "name": "Main leste", "desc": "Chaque kill en l'air ou sur un mur avance la recharge de la grenade de 2 s" },
				{ "id": "s_g4", "name": "Fragmentation", "desc": "L'explosion projette 5 éclats qui explosent à leur tour", "ult": true },
			] },
		] },
		{ "id": "v", "name": "Survie", "dir": Vector2(0, 1), "trunk": [
			{ "id": "v_t1", "name": "Peau dure", "desc": "+25 santé max" },
			{ "id": "v_t2", "name": "Vol aérien", "desc": "+5 santé par kill en l'air" },
		], "subs": [
			{ "name": "Rage", "nodes": [
				{ "id": "v_r1", "name": "Dos au mur", "desc": "+25 % de dégâts sous 50 % de vie" },
				{ "id": "v_r2", "name": "Corps à corps", "desc": "+4 santé par kill à bout portant" },
				{ "id": "v_r3", "name": "Sortie de roulade", "desc": "Dégâts subis divisés par deux juste après une roulade" },
				{ "id": "v_r4", "name": "Increvable", "desc": "Sous 25 % de vie : +40 % de dégâts et vol de vie doublé", "ult": true },
			] },
			{ "name": "Sang-froid", "nodes": [
				{ "id": "v_s1", "name": "Bouclier", "desc": "Bouclier de 25 qui se recharge après 4 s sans dégâts" },
				{ "id": "v_s2", "name": "Armure d'exécuteur", "desc": "Un kill à la tête réduit les dégâts subis de 50 % pendant 2 s" },
				{ "id": "v_s3", "name": "Régénération", "desc": "Régénère 1 santé par seconde" },
				{ "id": "v_s4", "name": "Second souffle", "desc": "Une fois par round, survit à un coup fatal", "ult": true },
			] },
		] },
		{ "id": "m", "name": "Déplacement", "dir": Vector2(-1, 0), "trunk": [
			{ "id": "m_t1", "name": "Coureur de murs", "desc": "Le wall run dure 50 % plus longtemps" },
			{ "id": "m_t2", "name": "Réflexes", "desc": "La roulade se recharge 20 % plus vite" },
		], "subs": [
			{ "name": "Aérien", "nodes": [
				{ "id": "m_a1", "name": "Rebond", "desc": "Un saut de mur recharge la roulade" },
				{ "id": "m_a2", "name": "Planeur", "desc": "Maintenir le saut en chute fait planer" },
				{ "id": "m_a3", "name": "Ressorts", "desc": "Double saut 20 % plus haut" },
				{ "id": "m_a4", "name": "Danse murale", "desc": "Un kill en l'air ou sur un mur recharge la roulade et rapporte +50 % de style", "ult": true },
			] },
			{ "name": "Sol", "nodes": [
				{ "id": "m_g1", "name": "Élan", "desc": "+8 % de vitesse" },
				{ "id": "m_g2", "name": "Fauchage", "desc": "La glissade renverse et blesse les petits ennemis" },
				{ "id": "m_g3", "name": "Longue glissade", "desc": "Glissade 40 % plus longue" },
				{ "id": "m_g4", "name": "Bolide", "desc": "Une glissade juste après une roulade blesse tout sur son passage", "ult": true },
			] },
		] },
	],
}

# Liste à plat de l'arbre, avec le prérequis de chaque nœud : { id, name, desc, ult, req, branch, sub, weapon }
static func tree_nodes(char_id: String) -> Array:
	var out := []
	for br in TREE[char_id]:
		var prev := ""
		for n in br.trunk:
			var d: Dictionary = n.duplicate()
			d.req = prev; d.branch = br.id; d.sub = ""; d.weapon = ""
			out.append(d)
			prev = n.id
		var trunk_end := prev
		for sb in br.subs:
			prev = trunk_end
			for n in sb.nodes:
				var d: Dictionary = n.duplicate()
				d.req = prev; d.branch = br.id; d.sub = sb.name; d.weapon = sb.get("weapon", "")
				out.append(d)
				prev = n.id
	return out

# ---------- Armes ----------
# Armes uniques (une par perso au choix au départ) et génériques (communes, au shop pendant le run).
# model : modèle et animation de rechargement. Traits : dual (une arme dans chaque main),
# air_precise (dispersion réduite en l'air), recoil (le tir propulse à l'opposé de la visée),
# execute (un tir à la tête sur un ennemi affaibli l'achève, seuil en part de la vie).
const WEAPONS := {
	"jumeaux": {
		"id": "jumeaux", "name": "Jumeaux", "model": "pistols", "dual": true, "air_precise": 0.35,
		"mag": 24, "rate": 0.1, "dmg": 16.0, "pellets": 1, "spread": 0.02, "reload": 1.0, "kick": 0.01,
		"sound": "pistol", "color": Color("4fc3ff"), "unique": true,
		"blurb": "Pistolets jumelés à tir alterné. Très précis en l'air.",
		"stats": [["Dégâts", "Moyens"], ["Cadence", "Rapide"], ["En l'air", "Précis"]],
	},
	"brise_porte": {
		"id": "brise_porte", "name": "Brise-porte", "model": "sawed", "recoil": 11.0,
		"mag": 2, "rate": 0.26, "dmg": 18.0, "pellets": 12, "spread": 0.09, "reload": 0.95, "kick": 0.08,
		"sound": "blast", "color": Color("ff7a3d"), "unique": true,
		"blurb": "Pompe court à 2 coups. Le recul te propulse : vise le sol pour t'envoler.",
		"stats": [["Dégâts", "Énormes"], ["Coups", "2"], ["Recul", "Propulse"]],
	},
	"verdict": {
		"id": "verdict", "name": "Verdict", "model": "revolver", "execute": 0.3,
		"mag": 6, "rate": 0.42, "dmg": 75.0, "pellets": 1, "spread": 0.004, "reload": 1.5, "kick": 0.09,
		"sound": "revolver", "color": Color("d6b4ff"), "unique": true,
		"blurb": "Revolver lourd 6 coups. Un tir à la tête sur un ennemi sous 30 % de vie l'exécute.",
		"stats": [["Dégâts", "Lourds"], ["Cadence", "Lente"], ["Tête", "Exécute"]],
	},
	# --- Nyx ---
	# mode : blade (lames lancées qui reviennent, pas de rechargement), bolt (carreau qui s'accroche, tir
	# secondaire pour se tracter). move_tight : la dispersion se resserre avec la vitesse.
	"essaim": {
		"id": "essaim", "name": "Essaim", "model": "smg", "move_tight": 0.3,
		"mag": 40, "rate": 0.07, "dmg": 13.0, "pellets": 1, "spread": 0.06, "reload": 1.1, "kick": 0.008,
		"sound": "uzi", "color": Color("5effc8"), "unique": true,
		"blurb": "SMG lourd. La dispersion se resserre tant que tu cours.",
		"stats": [["Dégâts", "Moyens"], ["Cadence", "Rapide"], ["En course", "Précis"]],
	},
	"crocs": {
		"id": "crocs", "name": "Crocs", "model": "blades", "mode": "blade",
		"mag": 5, "rate": 0.2, "dmg": 34.0, "pellets": 1, "spread": 0.0, "reload": 0.0, "kick": 0.02,
		"sound": "spin", "color": Color("5effc8"), "unique": true,
		"blurb": "Lames de jet qui traversent et reviennent. Pas de rechargement : récupère-les.",
		"stats": [["Dégâts", "Forts"], ["Lames", "5"], ["Retour", "Sur kill"]],
	},
	"harpon": {
		"id": "harpon", "name": "Harpon", "model": "crossbow", "mode": "bolt", "alt": "Se tracter",
		"mag": 1, "rate": 0.3, "dmg": 80.0, "pellets": 1, "spread": 0.0, "reload": 0.8, "kick": 0.05,
		"sound": "revolver", "color": Color("5effc8"), "unique": true,
		"blurb": "Arbalète. Le carreau s'accroche ; clic droit pour te tracter vers la cible ou le mur.",
		"stats": [["Dégâts", "Lourds"], ["Carreau", "1"], ["Clic droit", "Grappin"]],
	},
	# Brack : lob (grenade à rebond), spin (minigun qui monte en cadence), mine (mines collantes, clic droit
	# pour les faire sauter). blast : rayon de l'explosion.
	"tambour": {
		"id": "tambour", "name": "Tambour", "model": "launcher", "mode": "lob", "blast": 3.6,
		"mag": 6, "rate": 0.5, "dmg": 70.0, "pellets": 1, "spread": 0.0, "reload": 1.6, "kick": 0.06,
		"sound": "shotgun", "color": Color("ff8a3d"), "unique": true,
		"blurb": "Lance-grenades à rebond, 6 coups. La grenade explose au contact d'un ennemi.",
		"stats": [["Dégâts", "Zone"], ["Coups", "6"], ["Rebonds", "Oui"]],
	},
	"moulin": {
		"id": "moulin", "name": "Moulin", "model": "minigun", "spin": true,
		"mag": 150, "rate": 0.12, "dmg": 12.0, "pellets": 1, "spread": 0.045, "reload": 2.2, "kick": 0.004,
		"sound": "uzi", "color": Color("ff8a3d"), "unique": true,
		"blurb": "Minigun. La cadence monte tant que tu tires, mais il ralentit Brack.",
		"stats": [["Cadence", "Monte"], ["Balles", "150"], ["Au tir", "Lent"]],
	},
	"glu": {
		"id": "glu", "name": "Glu", "model": "mines", "mode": "mine", "alt": "Faire sauter", "blast": 4.2,
		"mag": 4, "rate": 0.3, "dmg": 95.0, "pellets": 1, "spread": 0.0, "reload": 1.4, "kick": 0.03,
		"sound": "click", "color": Color("ff8a3d"), "unique": true,
		"blurb": "Lance-mines collantes. Elles collent aux murs et aux ennemis ; clic droit pour tout faire sauter.",
		"stats": [["Dégâts", "Énormes"], ["Mines", "4"], ["Clic droit", "Boum"]],
	},
	# Iris : rail (garde le tir pour charger, traverse les ennemis alignés), drone (drone-tourelle posé à la
	# visée, clic droit pour le rappeler). Patch marque les ennemis touchés.
	"aiguille": {
		"id": "aiguille", "name": "Aiguille", "model": "rail", "mode": "rail",
		"mag": 5, "rate": 0.3, "dmg": 60.0, "pellets": 1, "spread": 0.0, "reload": 1.5, "kick": 0.05,
		"sound": "revolver", "color": Color("c77dff"), "unique": true,
		"blurb": "Fusil à rail. Garde le tir enfoncé pour charger : le rail traverse tous les ennemis alignés.",
		"stats": [["Dégâts", "×3 chargé"], ["Charge", "0,8 s"], ["Traverse", "Tout"]],
	},
	"mouche": {
		"id": "mouche", "name": "Mouche", "model": "dronegun", "mode": "drone", "alt": "Rappeler",
		"mag": 1, "rate": 0.35, "dmg": 11.0, "pellets": 1, "spread": 0.0, "reload": 0.0, "kick": 0.02,
		"sound": "click", "color": Color("c77dff"), "unique": true,
		"blurb": "Envoie un drone-tourelle là où tu vises. Il tire seul ; clic droit pour le rappeler.",
		"stats": [["Drone", "1"], ["Tir", "Auto"], ["Clic droit", "Rappel"]],
	},
	"patch": {
		"id": "patch", "name": "Patch", "model": "virus",
		"mag": 14, "rate": 0.2, "dmg": 18.0, "pellets": 1, "spread": 0.008, "reload": 1.0, "kick": 0.015,
		"sound": "pistol", "color": Color("c77dff"), "unique": true,
		"blurb": "Pistolet virus. Les ennemis touchés sont marqués ; à leur mort, le marquage passe au voisin.",
		"stats": [["Dégâts", "Moyens"], ["Marque", "5 s"], ["Propagation", "Oui"]],
	},
	"rifle": {
		"id": "rifle", "name": "Fusil d'assaut", "model": "rifle", "mag": 30, "rate": 0.085, "dmg": 22.0, "pellets": 1,
		"spread": 0.012, "reload": 1.0, "kick": 0.012, "sound": "rifle", "color": Color("3fd0c9"),
		"blurb": "Précis et régulier. Récompense les tirs à la tête.",
		"stats": [["Dégâts", "Moyens"], ["Cadence", "Rapide"], ["Portée", "Longue"]],
	},
	"shotgun": {
		"id": "shotgun", "name": "Fusil à pompe", "model": "shotgun", "mag": 6, "rate": 0.6, "dmg": 16.0, "pellets": 9,
		"spread": 0.07, "reload": 1.1, "kick": 0.05, "sound": "shotgun", "color": Color("ffc23d"),
		"blurb": "Dévastateur au contact. Parfait pour les kills aériens.",
		"stats": [["Dégâts", "Énormes"], ["Cadence", "Lente"], ["Portée", "Courte"]],
	},
	"uzi": {
		"id": "uzi", "name": "Double uzi", "model": "uzi", "dual": true, "mag": 50, "rate": 0.045, "dmg": 11.0, "pellets": 1,
		"spread": 0.035, "reload": 0.9, "kick": 0.006, "sound": "uzi", "color": Color("ff4fa3"),
		"blurb": "Un uzi dans chaque main. Une pluie de balles, un reload en double.",
		"stats": [["Dégâts", "Faibles"], ["Cadence", "Folle"], ["Portée", "Moyenne"]],
	},
}
const WEAPON_ORDER := ["jumeaux", "brise_porte", "verdict"]
const GENERICS := ["rifle", "shotgun", "uzi"]
const WEAPON_PRICE := 160

# ---------- Déplacement ----------
# Réglages du mouvement : accélération forte, freinage doux et élan conservé en l'air.
const MOVE := {
	"speed": 12.0, "accel": 16.0, "friction": 5.0, "air_accel": 7.0, "air_drag": 0.15,
	"gravity": 22.0, "jump": 9.5, "air_jump": 8.5, "bhop_keep": 0.97,
}

# ---------- Ennemis ----------
# Couleurs chaudes et saturées (rouge, orange, ambre, magenta, lime) : le décor est froid pour qu'ils ressortent.
# ai : walk (corps à corps), ranged (tir et garde ses distances), drone (vole et tire), kamikaze (vole et explose),
# sniper (laser depuis les toits), hacker (brouille le HUD et se téléporte), furnace (laisse des flaques de métal en fusion),
# arm (bras fixe sur un socle qui balaie autour de lui, on saute par-dessus). shield : bouclier frontal. reform : se reforme une fois.
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
	# zone 2, la fonderie
	"furnace": { "name": "Ouvrier-fournaise", "ai": "furnace", "hp": 40.0, "speed": 5.5, "dmg": 12.0, "r": 0.6, "h": 1.8, "color": Color("ff8a3d"), "score": 220, "cr": 8, "xp": 20 },
	"arm":     { "name": "Bras mécanique", "ai": "arm", "hp": 80.0, "speed": 0.0, "dmg": 22.0, "r": 0.8, "h": 1.6, "color": Color("ff3cf0"), "score": 300, "cr": 13, "xp": 28, "reach": 6.5 },
	"golem":   { "name": "Golem de scories", "ai": "walk", "hp": 90.0, "speed": 4.2, "dmg": 20.0, "r": 0.8, "h": 2.1, "color": Color("ff3d7f"), "score": 340, "cr": 15, "xp": 32, "reform": true },
}
const MAX_ARMS := 2

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
		"arena": "city",
		"env": { "sky_top": Color("07051a"), "sky_horizon": Color("3a1450"), "fog": Color("2a1240"), "fog_density": 0.012, "ambient": Color("4a4a78"), "moon": Color("9fb4ff") },
	},
	{
		"name": "Fonderie", "rounds": [
			{ "n": 12, "mix": { "grunt": 0.6, "furnace": 0.4 } },
			{ "n": 16, "mix": { "grunt": 0.4, "runner": 0.3, "furnace": 0.3 } },
			{ "n": 20, "mix": { "grunt": 0.3, "runner": 0.2, "furnace": 0.25, "arm": 0.1, "drone": 0.15 } },
			{ "n": 24, "mix": { "grunt": 0.25, "runner": 0.2, "furnace": 0.2, "golem": 0.1, "shield": 0.15, "arm": 0.1 } },
			{ "n": 12, "mix": { "furnace": 0.5, "runner": 0.5 }, "special": "miniboss" },
			{ "n": 28, "mix": { "grunt": 0.2, "runner": 0.2, "furnace": 0.2, "golem": 0.12, "shield": 0.1, "arm": 0.08, "spitter": 0.1 } },
			{ "n": 32, "mix": { "grunt": 0.2, "runner": 0.2, "furnace": 0.18, "golem": 0.12, "drone": 0.12, "arm": 0.08, "spitter": 0.1 } },
			{ "n": 36, "mix": { "grunt": 0.18, "runner": 0.18, "brute": 0.08, "furnace": 0.16, "golem": 0.12, "shield": 0.1, "arm": 0.08, "drone": 0.1 } },
			{ "n": 40, "mix": { "grunt": 0.16, "runner": 0.18, "brute": 0.1, "furnace": 0.16, "golem": 0.14, "shield": 0.1, "arm": 0.06, "spitter": 0.1 } },
			{ "n": 14, "mix": { "furnace": 0.5, "golem": 0.2, "runner": 0.3 }, "special": "boss" },
		],
		"miniboss": { "name": "Le Contremaître", "color": Color("ff8a3d"), "hp": 2200.0, "speed": 5.0, "r": 1.4, "h": 4.2, "pattern": "foreman", "score": 4000, "cr": 100, "xp": 180 },
		"boss": { "name": "Haut-Fourneau", "color": Color("ff5a1f"), "hp": 6500.0, "speed": 3.2, "r": 2.6, "h": 6.5, "pattern": "forge", "score": 10000, "cr": 180, "xp": 360 },
		"arena": "foundry",
		"env": { "sky_top": Color("05070b"), "sky_horizon": Color("1a2230"), "fog": Color("1a2230"), "fog_density": 0.016, "ambient": Color("5a6680"), "ambient_energy": 0.9, "moon": Color("cfe3ff") },
	},
]
# PV des ennemis multipliés à chaque zone
const ZONE_HP := 0.35
const MAX_SNIPERS := 3

# [nom, style minimum, multiplicateur de score]
const RANKS := [["D", 0, 1.0], ["C", 80, 1.2], ["B", 200, 1.5], ["A", 380, 1.8], ["S", 620, 2.2], ["SS", 900, 2.6], ["SSS", 1250, 3.0]]

const BASE_UP := {
	"speed": 1.0, "max_hp": 100.0, "lifesteal": 0.0, "roll_cd": 1.0, "jumps": 2, "pierce": 0, "crit": 2.0,
	"explode": 0, "regen": 0.0, "last_shots": 0, "recoil_jump": 0, "ricochet": 0, "air_dmg": 0,
	"slide_boost": 1.0, "style_mult": 1.0, "mag_boom": 1.0, "wallrun": 1.0, "skill_gain": 1.0, "skill_time": 0.0, "credit_mult": 1.0, "recoil_mult": 1.0,
}

# ---------- XP ----------
# environ 5 points à la fin de la zone 1, 7 pour un run qui meurt en zone 2, 22 sur un run complet de 7 zones
static func xp_for_level(lvl: int) -> int:
	return 380 + 120 * (lvl - 1)

# ---------- Shop ----------
# Les mods à comportement (munition, mécanisme, déclencheur) arrivent au shop dans une prochaine passe.
const HEALS := [
	{ "id": "heal_s", "name": "Stim", "desc": "+40 santé", "price": 45 },
	{ "id": "heal_l", "name": "Soin complet", "desc": "Santé au maximum", "price": 100 },
]
const AUG_PRICE := 110
const UPGRADE_PRICE := 140

# Mods d'armes : un augment change un chiffre, un mod change un comportement. 3 emplacements par arme
# (Munition, Mécanisme, Déclencheur), un mod par emplacement, achetés au shop. hitscan : seulement pour
# les armes à balles ; weapon : mod propre à une arme unique. Effets dans main.gd (_mod_hit...) et player.gd.
const MOD_SLOTS := { "ammo": "Munition", "mech": "Mécanisme", "trig": "Déclencheur" }
const MOD_PRICE := 150
const MODS := [
	{ "id": "m_fire", "slot": "ammo", "name": "Incendiaire", "desc": "Les impacts enflamment l'ennemi et laissent des flammes au sol" },
	{ "id": "m_arc", "slot": "ammo", "name": "Arc", "desc": "À chaque impact, l'électricité saute sur 2 ennemis proches" },
	{ "id": "m_cryo", "slot": "ammo", "name": "Cryo", "desc": "Les impacts ralentissent ; au 3e impact rapproché, l'ennemi gèle 1,5 s" },
	{ "id": "m_frag", "slot": "ammo", "name": "Fragmentation", "desc": "Un kill à l'arme provoque une petite explosion" },
	{ "id": "m_burst", "slot": "mech", "name": "Rafale", "desc": "L'arme tire par rafales de 3 balles", "hitscan": true },
	{ "id": "m_charge", "slot": "mech", "name": "Charge", "desc": "Garde le tir enfoncé pour charger : le coup part au relâchement, jusqu'à ×3", "hitscan": true },
	{ "id": "m_bounce", "slot": "mech", "name": "Rebond", "desc": "Les balles ricochent une fois sur les murs", "hitscan": true },
	{ "id": "m_fan", "slot": "mech", "name": "Éventail", "desc": "Chaque tir part en éventail : 2 balles de plus sur les côtés", "hitscan": true },
	{ "id": "m_chain", "slot": "mech", "name": "Chaîne", "desc": "Clic droit tire l'ennemi harponné vers toi au lieu de te tracter", "weapon": "harpon" },
	{ "id": "m_shock", "slot": "trig", "name": "Recharge choc", "desc": "Recharger crée une onde qui repousse les ennemis proches" },
	{ "id": "m_last", "slot": "trig", "name": "Dernière balle", "desc": "La dernière balle du chargeur explose à l'impact", "hitscan": true },
	{ "id": "m_wall", "slot": "trig", "name": "Mur", "desc": "Les tirs pendant un wall run traversent tous les ennemis", "hitscan": true },
	{ "id": "m_roll", "slot": "trig", "name": "Roulade", "desc": "Après une roulade, le chargeur suivant est électrique et incendiaire" },
]

static func mod_ok(m: Dictionary, W: Dictionary) -> bool:
	# ce mod a-t-il un effet sur cette arme ?
	if m.has("weapon"):
		return W.id == m.weapon
	var mode: String = W.get("mode", "")
	if m.get("hitscan", false):
		return mode == ""
	if m.slot == "ammo" or m.id == "m_roll":
		return not mode in ["lob", "mine"]
	if m.id == "m_shock":
		return W.reload > 0.0 and not mode in ["blade", "drone"]
	return true

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
	{ "id": "barrel", "name": "Canon long", "desc": "Dispersion réduite de 30 %", "tag": "Arme", "max": 2 },
	{ "id": "trigger", "name": "Détente sèche", "desc": "+12 % de cadence de tir", "tag": "Arme", "max": 3 },
	{ "id": "bolt", "name": "Culasse rapide", "desc": "Recharge 20 % plus vite", "tag": "Arme", "max": 2 },
	{ "id": "ext", "name": "Grande capacité", "desc": "+25 % de balles par chargeur", "tag": "Arme", "max": 2 },
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
	{ "id": "j_drum", "weapon": "jumeaux", "name": "Chargeurs longs", "desc": "+40 % de balles par chargeur", "max": 2 },
	{ "id": "j_rate", "weapon": "jumeaux", "name": "Gâchettes jumelles", "desc": "+20 % de cadence de tir", "max": 3 },
	{ "id": "b_pellets", "weapon": "brise_porte", "name": "Chevrotine lourde", "desc": "+4 plombs par tir", "max": 3 },
	{ "id": "b_kick", "weapon": "brise_porte", "name": "Charge renforcée", "desc": "Le recul propulse 30 % plus fort", "max": 2 },
	{ "id": "v_dmg", "weapon": "verdict", "name": "Balles de plomb", "desc": "+25 % de dégâts", "max": 3 },
	{ "id": "v_speed", "weapon": "verdict", "name": "Chargeur rapide", "desc": "Recharge 30 % plus vite", "max": 2 },
	{ "id": "u_frenzy", "weapon": "uzi", "name": "Frénésie", "desc": "+20 % de cadence de tir", "max": 3 },
]
