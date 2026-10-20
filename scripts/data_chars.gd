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

const BRACK_TREE := [
	{ "id": "w", "name": "Armes", "dir": Vector2(0, -1), "trunk": [
		{ "id": "br_wt1", "name": "Grosse charge", "desc": "Tes explosions ont +25 % de rayon" },
		{ "id": "br_wt2", "name": "Démineur", "desc": "Tes explosions ne blessent plus Brack" },
	], "subs": [
		{ "name": "Tambour", "weapon": "tambour", "nodes": [
			{ "id": "br_t1", "name": "Tambour long", "desc": "+2 grenades par tambour" },
			{ "id": "br_t2", "name": "Fragmentation", "desc": "Chaque grenade lâche 3 éclats qui explosent autour" },
			{ "id": "br_t3", "name": "Aimantée", "desc": "Après un rebond, la grenade file vers l'ennemi le plus proche" },
			{ "id": "br_t4", "name": "Barrage", "desc": "Clic droit : vide le tambour en éventail", "ult": true },
		] },
		{ "name": "Moulin", "weapon": "moulin", "nodes": [
			{ "id": "br_m1", "name": "Lancement rapide", "desc": "Le Moulin atteint sa pleine cadence 2 fois plus vite" },
			{ "id": "br_m2", "name": "Balles incendiaires", "desc": "À pleine cadence, les balles enflamment" },
			{ "id": "br_m3", "name": "Bien campé", "desc": "Le Moulin ralentit beaucoup moins Brack" },
			{ "id": "br_m4", "name": "Forteresse", "desc": "À pleine cadence, un bouclier frontal bloque 60 % des dégâts", "ult": true },
		] },
		{ "name": "Glu", "weapon": "glu", "nodes": [
			{ "id": "br_l1", "name": "Sac de mines", "desc": "+2 mines par chargeur" },
			{ "id": "br_l2", "name": "Mines sauteuses", "desc": "Une mine posée saute sur l'ennemi le plus proche (6 m) et s'y colle" },
			{ "id": "br_l3", "name": "Colle", "desc": "L'explosion laisse une flaque qui ralentit 4 s" },
			{ "id": "br_l4", "name": "Champ de mines", "desc": "Une mine qui explose en pose 2 petites", "ult": true },
		] },
	] },
	{ "id": "s", "name": "Compétence", "dir": Vector2(1, 0), "trunk": [
		{ "id": "br_st1", "name": "Liaison satellite", "desc": "La jauge de Frappe se remplit 25 % plus vite, et la grenade se recharge 25 % plus vite" },
		{ "id": "br_st2", "name": "Zone élargie", "desc": "La Frappe orbitale couvre une zone 30 % plus grande" },
	], "subs": [
		{ "name": "Précision", "nodes": [
			{ "id": "br_sp1", "name": "Délai court", "desc": "La Frappe tombe 0,5 s après le marquage au lieu de 1,5 s" },
			{ "id": "br_sp2", "name": "Balise", "desc": "Viser un ennemi lui colle le marqueur : la Frappe le suit" },
			{ "id": "br_sp3", "name": "Gravité", "desc": "Avant l'impact, la Frappe attire les ennemis vers son centre" },
			{ "id": "br_sp4", "name": "Rayon continu", "desc": "La Frappe devient un laser orbital que tu pilotes à la visée pendant 4 s", "ult": true },
		] },
		{ "name": "Saturation", "nodes": [
			{ "id": "br_ss1", "name": "Salve double", "desc": "Une 2e frappe, plus petite, tombe juste après" },
			{ "id": "br_ss2", "name": "Napalm", "desc": "La zone de frappe brûle pendant 4 s" },
			{ "id": "br_ss3", "name": "Abri", "desc": "Dans une zone qui brûle, Brack prend moitié moins de dégâts" },
			{ "id": "br_ss4", "name": "Tapis de bombes", "desc": "5 frappes tombent en ligne dans la direction visée", "ult": true },
		] },
		{ "name": "Grappe", "nodes": [
			{ "id": "br_g1", "name": "Double grappe", "desc": "2 charges de grenade" },
			{ "id": "br_g2", "name": "Grappe dense", "desc": "6 petites bombes au lieu de 4" },
			{ "id": "br_g3", "name": "Grosses bombes", "desc": "Les petites bombes ont +35 % de rayon et de dégâts" },
			{ "id": "br_g4", "name": "Réaction en chaîne", "desc": "Un ennemi tué par une petite bombe explose à son tour", "ult": true },
		] },
	] },
	{ "id": "v", "name": "Survie", "dir": Vector2(0, 1), "trunk": [
		{ "id": "br_vt1", "name": "Carrure", "desc": "+40 santé max" },
		{ "id": "br_vt2", "name": "Armure", "desc": "-15 % de dégâts reçus" },
	], "subs": [
		{ "name": "Blindage", "nodes": [
			{ "id": "br_vb1", "name": "Bouclier", "desc": "Bouclier de 30 qui se recharge après 3 s sans être touché" },
			{ "id": "br_vb2", "name": "Ancrage", "desc": "Immobile depuis 1 s : -35 % de dégâts" },
			{ "id": "br_vb3", "name": "Réparation", "desc": "Régénère 3 santé par seconde tant que le bouclier est plein" },
			{ "id": "br_vb4", "name": "Colosse", "desc": "Santé +50 %, et toucher un petit ennemi l'écrase", "ult": true },
		] },
		{ "name": "Carnage", "nodes": [
			{ "id": "br_vc1", "name": "Vol de vie explosif", "desc": "Chaque ennemi pris dans une de tes explosions rend 1,5 santé" },
			{ "id": "br_vc2", "name": "Festin", "desc": "3 kills ou plus d'un coup rendent 15 santé" },
			{ "id": "br_vc3", "name": "Ravitaillement", "desc": "Après une Frappe, régénère 20 santé en 4 s" },
			{ "id": "br_vc4", "name": "Dernier rempart", "desc": "À 0 santé : 5 s d'invulnérabilité, puis moitié de la santé rendue si tu fais 10 kills (1 fois par round)", "ult": true },
		] },
	] },
	{ "id": "m", "name": "Déplacement", "dir": Vector2(-1, 0), "trunk": [
		{ "id": "br_mt1", "name": "Pas lourd", "desc": "+6 % de vitesse" },
		{ "id": "br_mt2", "name": "Charge d'épaule", "desc": "La roulade devient une charge qui percute et repousse les ennemis" },
	], "subs": [
		{ "name": "Charge", "nodes": [
			{ "id": "br_mc1", "name": "Longue charge", "desc": "La charge va 50 % plus loin" },
			{ "id": "br_mc2", "name": "Renversement", "desc": "La charge étourdit les ennemis percutés 1,5 s" },
			{ "id": "br_mc3", "name": "Élan meurtrier", "desc": "Un kill pendant la charge la recharge aussitôt" },
			{ "id": "br_mc4", "name": "Locomotive", "desc": "La charge traverse tout et ne s'arrête qu'au mur (2 s max)", "ult": true },
		] },
		{ "name": "Souffle", "nodes": [
			{ "id": "br_ms1", "name": "Rocket jump", "desc": "Tes explosions proches te propulsent, et te blessent deux fois moins" },
			{ "id": "br_ms2", "name": "Atterrissage lourd", "desc": "Retomber de haut fait exploser le sol" },
			{ "id": "br_ms3", "name": "Saut mural explosif", "desc": "Un wall jump déclenche une explosion contre le mur" },
			{ "id": "br_ms4", "name": "Propulseur", "desc": "Chaque explosion proche te redonne un saut", "ult": true },
		] },
	] },
]

const IRIS_TREE := [
	{ "id": "w", "name": "Armes", "dir": Vector2(0, -1), "trunk": [
		{ "id": "ir_wt1", "name": "Ciblage", "desc": "Les ennemis marqués prennent +25 % de dégâts" },
		{ "id": "ir_wt2", "name": "Recyclage", "desc": "Toucher un ennemi marqué rend 1 munition" },
	], "subs": [
		{ "name": "Aiguille", "weapon": "aiguille", "nodes": [
			{ "id": "ir_a1", "name": "Condensateur", "desc": "L'Aiguille se charge 2 fois plus vite" },
			{ "id": "ir_a2", "name": "Surtension", "desc": "En pleine charge, la dernière cible traversée explose" },
			{ "id": "ir_a3", "name": "Perce-murs", "desc": "En pleine charge, le rail traverse les murs" },
			{ "id": "ir_a4", "name": "Ligne de code", "desc": "Chaque ennemi traversé est piraté 3 s", "ult": true },
		] },
		{ "name": "Mouche", "weapon": "mouche", "nodes": [
			{ "id": "ir_m1", "name": "Essaim", "desc": "2 drones au lieu d'un" },
			{ "id": "ir_m2", "name": "Drone lourd", "desc": "Les tirs du drone font +60 % de dégâts et ralentissent" },
			{ "id": "ir_m3", "name": "Escorte", "desc": "Le drone rappelé te suit partout, wall run compris, et tire aussi" },
			{ "id": "ir_m4", "name": "Colonie", "desc": "Chaque kill de drone crée un drone temporaire pour 6 s", "ult": true },
		] },
		{ "name": "Patch", "weapon": "patch", "nodes": [
			{ "id": "ir_p1", "name": "Persistance", "desc": "Le marquage dure 8 s au lieu de 5" },
			{ "id": "ir_p2", "name": "Rebond", "desc": "À la mort d'un marqué, le marquage saute sur 2 ennemis au lieu d'un" },
			{ "id": "ir_p3", "name": "Traceur", "desc": "Les marqués sont visibles à travers les murs" },
			{ "id": "ir_p4", "name": "Épidémie", "desc": "Un marqué qui meurt marque tous les ennemis à 10 m", "ult": true },
		] },
	] },
	{ "id": "s", "name": "Compétence", "dir": Vector2(1, 0), "trunk": [
		{ "id": "ir_st1", "name": "Accès root", "desc": "La jauge de Piratage se remplit 25 % plus vite, et la grenade se recharge 25 % plus vite" },
		{ "id": "ir_st2", "name": "Large bande", "desc": "Le cône de Piratage est plus large" },
	], "subs": [
		{ "name": "Contagion", "nodes": [
			{ "id": "ir_sc1", "name": "Bail long", "desc": "Le Piratage dure 3 s de plus" },
			{ "id": "ir_sc2", "name": "Ver", "desc": "Un piraté qui meurt pirate l'ennemi le plus proche" },
			{ "id": "ir_sc3", "name": "Autodestruction", "desc": "À la fin du Piratage, les piratés explosent" },
			{ "id": "ir_sc4", "name": "Réseau", "desc": "Le Piratage prend aussi tous les ennemis marqués, sur toute l'arène", "ult": true },
		] },
		{ "name": "Contrôle", "nodes": [
			{ "id": "ir_sk1", "name": "Overclock", "desc": "Les piratés font +50 % de dégâts" },
			{ "id": "ir_sk2", "name": "Dîme", "desc": "Chaque kill d'un piraté rend 5 santé à Iris" },
			{ "id": "ir_sk3", "name": "Bride", "desc": "Les boss pris dans le cône sont ralentis 6 s" },
			{ "id": "ir_sk4", "name": "Root", "desc": "L'ennemi le plus proche du viseur, même élite, reste piraté jusqu'à sa mort", "ult": true },
		] },
		{ "name": "Brouilleur", "nodes": [
			{ "id": "ir_g1", "name": "Double brouilleur", "desc": "2 charges de grenade" },
			{ "id": "ir_g2", "name": "Brouillage long", "desc": "Les tirs ennemis restent coupés 5 s au lieu de 3" },
			{ "id": "ir_g3", "name": "Grande onde", "desc": "Rayon du Brouilleur +40 %" },
			{ "id": "ir_g4", "name": "Prise de contrôle", "desc": "Le Brouilleur pirate 3 s les ennemis touchés", "ult": true },
		] },
	] },
	{ "id": "v", "name": "Survie", "dir": Vector2(0, 1), "trunk": [
		{ "id": "ir_vt1", "name": "Endurance", "desc": "+25 santé max" },
		{ "id": "ir_vt2", "name": "Bouclier de drone", "desc": "Bouclier de 20 qui se recharge tant qu'un drone est actif" },
	], "subs": [
		{ "name": "Pare-feu", "nodes": [
			{ "id": "ir_vf1", "name": "Ralentisseur", "desc": "Les projectiles ennemis à moins de 6 m ralentissent fortement" },
			{ "id": "ir_vf2", "name": "Brouillage", "desc": "Les tireurs à plus de 18 m ne te voient pas" },
			{ "id": "ir_vf3", "name": "Renvoi", "desc": "Tant que tu as du bouclier, les projectiles qui te touchent repartent vers les ennemis" },
			{ "id": "ir_vf4", "name": "Pare-feu total", "desc": "3 s d'immunité aux projectiles après un Piratage", "ult": true },
		] },
		{ "name": "Sauvegarde", "nodes": [
			{ "id": "ir_vs1", "name": "Lien vital", "desc": "Régénère 2 santé par seconde tant qu'un piraté est en vie" },
			{ "id": "ir_vs2", "name": "Extraction", "desc": "Tuer un ennemi marqué rend 4 santé" },
			{ "id": "ir_vs3", "name": "Concentration", "desc": "-25 % de dégâts tant que tu tires" },
			{ "id": "ir_vs4", "name": "Sauvegarde", "desc": "Une fois par zone, un coup fatal te ramène où tu étais il y a 3 s, avec la moitié de ta santé", "ult": true },
		] },
	] },
	{ "id": "m", "name": "Déplacement", "dir": Vector2(-1, 0), "trunk": [
		{ "id": "ir_mt1", "name": "Coureuse de murs", "desc": "Le wall run dure 50 % plus longtemps" },
		{ "id": "ir_mt2", "name": "Réflexes", "desc": "Roulade 20 % plus vite rechargée" },
	], "subs": [
		{ "name": "Téléport", "nodes": [
			{ "id": "ir_mp1", "name": "Blink", "desc": "La roulade devient un téléport court (6 m)" },
			{ "id": "ir_mp2", "name": "Longue portée", "desc": "Téléport de 10 m" },
			{ "id": "ir_mp3", "name": "Relais", "desc": "Roulade en reculant : téléport sur ton drone" },
			{ "id": "ir_mp4", "name": "Saut réseau", "desc": "Roulade en visant un ennemi marqué : téléport juste derrière lui", "ult": true },
		] },
		{ "name": "Leurre", "nodes": [
			{ "id": "ir_ml1", "name": "Hologramme", "desc": "La roulade laisse un leurre 4 s : les tireurs ne visent plus que lui" },
			{ "id": "ir_ml2", "name": "Leurre piégé", "desc": "Le leurre explose quand il disparaît" },
			{ "id": "ir_ml3", "name": "Appât", "desc": "Les ennemis près du leurre sont ralentis" },
			{ "id": "ir_ml4", "name": "Fantôme du réseau", "desc": "Après une roulade, les ennemis ne te voient plus pendant 2 s", "ult": true },
		] },
	] },
]
