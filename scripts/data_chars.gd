# Arbres en flocon des persos débloquables (Nyx, Brack, Iris), lus par data.gd (TREE).
# Même forme que celui de Kade : 4 branches, tronc de 2 nœuds, sous-branches de 3 nœuds et une pointe.
# Les effets sont appliqués par le kit du perso (scripts/kits/*.gd).

const NYX_TREE := [
	{ "id": "w", "name": "Armes", "dir": Vector2(0, -1), "trunk": [
		{ "id": "ny_wt1", "name": "Saignée", "desc": "Les tirs en l'air font saigner : +40 % des dégâts en 3 s" },
		{ "id": "ny_wt2", "name": "Ravitaillement", "desc": "Un kill en l'air rend un quart du chargeur" },
	], "subs": [
		{ "name": "Essaim", "weapon": "essaim", "nodes": [
			{ "id": "ny_e1", "name": "Chargeur de course", "desc": "+30 % de balles par chargeur" },
			{ "id": "ny_e2", "name": "Glissade stable", "desc": "Aucune dispersion pendant une glissade" },
			{ "id": "ny_e3", "name": "Emballement", "desc": "La cadence monte avec la vitesse, jusqu'à +35 %" },
			{ "id": "ny_e4", "name": "Volée", "desc": "En l'air, un tir sur 5 est doublé", "ult": true },
		] },
		{ "name": "Crocs", "weapon": "crocs", "nodes": [
			{ "id": "ny_c1", "name": "Meute", "desc": "+2 lames" },
			{ "id": "ny_c2", "name": "Aller-retour", "desc": "Les lames frappent aussi au retour" },
			{ "id": "ny_c3", "name": "Morsure froide", "desc": "Les lames ralentissent les ennemis touchés" },
			{ "id": "ny_c4", "name": "Tourbillon", "desc": "Les lames tournent autour de Nyx avant de partir", "ult": true },
		] },
		{ "name": "Harpon", "weapon": "harpon", "nodes": [
			{ "id": "ny_h1", "name": "Double carreau", "desc": "2 carreaux avant de recharger" },
			{ "id": "ny_h2", "name": "Abordage", "desc": "Se tracter sur un ennemi le frappe fort" },
			{ "id": "ny_h3", "name": "Carreau électrique", "desc": "Le carreau électrocute 2 ennemis proches" },
			{ "id": "ny_h4", "name": "Prédatrice", "desc": "Un ennemi harponné prend +35 % de dégâts de toutes tes armes", "ult": true },
		] },
	] },
	{ "id": "s", "name": "Compétence", "dir": Vector2(1, 0), "trunk": [
		{ "id": "ny_st1", "name": "Survoltée", "desc": "La jauge d'Overdrive se remplit 25 % plus vite, et la grenade se recharge 25 % plus vite" },
		{ "id": "ny_st2", "name": "Allonge", "desc": "Overdrive dure 2 s de plus" },
	], "subs": [
		{ "name": "Vitesse", "nodes": [
			{ "id": "ny_sv1", "name": "Dynamo", "desc": "La jauge se charge pendant le wall run" },
			{ "id": "ny_sv2", "name": "Relais", "desc": "Chaque kill en l'air prolonge Overdrive de 0,5 s" },
			{ "id": "ny_sv3", "name": "Traînée électrique", "desc": "En Overdrive, Nyx électrocute les ennemis qu'elle frôle" },
			{ "id": "ny_sv4", "name": "Infini", "desc": "Overdrive ne s'arrête pas tant que Nyx ne touche pas le sol", "ult": true },
		] },
		{ "name": "Impact", "nodes": [
			{ "id": "ny_si1", "name": "Démarrage", "desc": "Activer Overdrive projette et étourdit les ennemis proches" },
			{ "id": "ny_si2", "name": "Crocs volants", "desc": "En Overdrive, chaque saut lance une lame sur l'ennemi le plus proche" },
			{ "id": "ny_si3", "name": "Chute lourde", "desc": "Retomber de haut blesse les ennemis autour" },
			{ "id": "ny_si4", "name": "Comète", "desc": "En Overdrive, chaque atterrissage fait un impact de zone", "ult": true },
		] },
		{ "name": "Tremplin", "nodes": [
			{ "id": "ny_g1", "name": "Deux tremplins", "desc": "Deux grenades en réserve" },
			{ "id": "ny_g2", "name": "Tremplin durable", "desc": "Le tremplin reste 10 s au lieu de 6" },
			{ "id": "ny_g3", "name": "Sonnés", "desc": "Étourdissement plus long et plus large" },
			{ "id": "ny_g4", "name": "Catapulte", "desc": "Décoller du tremplin envoie une onde qui blesse autour", "ult": true },
		] },
	] },
	{ "id": "v", "name": "Survie", "dir": Vector2(0, 1), "trunk": [
		{ "id": "ny_vt1", "name": "Endurance", "desc": "+20 santé max" },
		{ "id": "ny_vt2", "name": "Vitesse = armure", "desc": "Plus Nyx va vite, moins elle prend de dégâts (jusqu'à -30 %)" },
	], "subs": [
		{ "name": "Esquive", "nodes": [
			{ "id": "ny_ve1", "name": "Esquive parfaite", "desc": "Esquiver un coup en roulade ralentit le temps 1,5 s" },
			{ "id": "ny_ve2", "name": "Roulade réparatrice", "desc": "Chaque roulade rend 5 santé" },
			{ "id": "ny_ve3", "name": "Mirage", "desc": "Les tireurs à plus de 20 m ne te voient pas" },
			{ "id": "ny_ve4", "name": "Fantôme", "desc": "Après 3 s en l'air, intouchable pendant 1 s", "ult": true },
		] },
		{ "name": "Flux", "nodes": [
			{ "id": "ny_vf1", "name": "Courant d'air", "desc": "Régénère 2 santé par seconde en l'air" },
			{ "id": "ny_vf2", "name": "Siphon", "desc": "Les tirs qui touchent en pleine course rendent un peu de santé" },
			{ "id": "ny_vf3", "name": "Rebond protecteur", "desc": "Un wall jump donne un bouclier de 10 (max 20)" },
			{ "id": "ny_vf4", "name": "Adrénaline", "desc": "Sous 30 % de vie : vitesse +30 % et forte régénération", "ult": true },
		] },
	] },
	{ "id": "m", "name": "Déplacement", "dir": Vector2(-1, 0), "trunk": [
		{ "id": "ny_mt1", "name": "Coureuse", "desc": "Le wall run dure 50 % plus longtemps" },
		{ "id": "ny_mt2", "name": "Saut de chat", "desc": "Les wall jumps vont plus haut" },
	], "subs": [
		{ "name": "Air", "nodes": [
			{ "id": "ny_ma1", "name": "Triple saut", "desc": "Un saut de plus en l'air" },
			{ "id": "ny_ma2", "name": "Dash aérien", "desc": "La roulade en l'air devient un dash qui garde l'altitude" },
			{ "id": "ny_ma3", "name": "Tremplin vivant", "desc": "Retomber sur un ennemi le blesse et te fait rebondir" },
			{ "id": "ny_ma4", "name": "Gravité zéro", "desc": "Chute très lente en gardant le saut, contrôle total en l'air", "ult": true },
		] },
		{ "name": "Murs", "nodes": [
			{ "id": "ny_mw1", "name": "Ascension", "desc": "Le wall run monte sur tous les murs, comme sur un panneau à chevrons" },
			{ "id": "ny_mw2", "name": "Sortie de mur", "desc": "+25 % de vitesse en sortant d'un wall jump" },
			{ "id": "ny_mw3", "name": "Long filin", "desc": "Le harpon porte plus loin et tracte plus vite" },
			{ "id": "ny_mw4", "name": "Funambule", "desc": "Wall run sans limite de durée", "ult": true },
		] },
	] },
]
