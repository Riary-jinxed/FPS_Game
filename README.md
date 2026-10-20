# Horde Breaker (Godot 4)

FPS nerveux en vagues. Cette version contient les **zones 1 (ville néon) et 2 (fonderie)**, enchaînées dans le même run : 10 rounds par zone, un mini-boss au round 5, le boss de zone au round 10. Le menu permet aussi de démarrer directement en zone 2.
Tout est construit en code (pas d'assets externes). Direction du jeu : `fps-game/DIRECTION.md` dans les fichiers du projet.

## Lancer
1. Installer Godot 4.3 ou plus récent (version standard, pas .NET).
2. Godot > Importer > choisir `project.godot` dans ce dossier.
3. F5 pour jouer. Le rendu Forward+ (par défaut) active les reflets du sol mouillé et l'occlusion ambiante.

## Contenu
- **Run** : zones de 10 rounds courts. Shop après les rounds 3, 6 et 9. Un augment offert après chaque boss. Le boss de zone vaincu ouvre la zone suivante avec le même build.
- **Persos** (choix au menu) : chacun a sa compétence (touche E ou F, chargée par le combo), sa grenade, 3 armes uniques et son propre arbre de 48 nœuds.
  - **Kade**, compétence **Surcharge** : ralenti des ennemis, munitions infinies, +50 % de dégâts. Disponible dès le début.
  - **Nyx**, la Coureuse (90 PV, plus rapide), compétence **Overdrive** : wall run illimité, triple saut, tirs en l'air +40 %. Grenade **Tremplin** : étourdit et laisse un tremplin temporaire qui propulse très haut. Armes : **Essaim** (SMG dont la dispersion se resserre quand tu cours), **Crocs** (lames qui traversent et reviennent, sans rechargement), **Harpon** (arbalète, le carreau s'accroche ; clic droit pour te tracter). Débloquée en battant le boss de la zone 2.
  - **Brack**, le Démolisseur (140 PV, plus lent), compétence **Frappe orbitale** : marque une zone à la visée, écrasée 1,5 s plus tard. Grenade **Grappe** : grosse charge qui se divise en 4 petites bombes. Armes : **Tambour** (lance-grenades à rebond, 6 coups), **Moulin** (minigun dont la cadence monte, mais qui ralentit Brack), **Glu** (mines collantes, clic droit pour tout faire sauter). Ses explosions le blessent un peu (nœud *Démineur* pour l'éviter) ; dans l'arbre, la roulade devient une charge d'épaule. Débloqué par le succès *Démolition* : 15 ennemis tués d'une seule explosion, ou 500 kills par explosion au total.
  - Iris arrive ensuite (débloquée par un palier acheté en Données).
- **Méta-progression** (sauvegardée) : chaque perso commence avec sa 1re arme unique ; la 2e se débloque en maîtrise 2 et la 3e en maîtrise 4 (la maîtrise monte avec l'XP gagnée en jouant le perso). Chaque run rapporte des **Données** (score / 100, +40 par boss). Le bouton **Mode test** du menu débloque tout, pour essayer les persos et les armes.
- **Grenade** (consommable propre à chaque perso, touche G ou molette) : elle se recharge avec le temps, plus vite avec une bonne note de style (15 s en D, 7,5 s en S, 6 s en SSS). Celle de Kade, **Impulsion**, explose à l'impact, repousse les ennemis et te propulse si tu es dans le souffle (grenade jump d'environ 3,5 m). Sous-branche *Impulsion* de l'arbre (Compétence) : 2 charges, rayon +40 %, kills en l'air qui avancent la recharge, et la pointe *Fragmentation*.
- **Armes uniques de Kade** : **Jumeaux**, deux pistolets à tir rapide, précis et plus forts en l'air ; **Brise-porte**, canon scié à 2 cartouches dont le recul propulse (tire vers le sol pour sauter plus haut) ; **Verdict**, revolver lourd qui exécute les ennemis sous 30 % de PV. Les armes génériques (fusil, pompe, uzi) s'achètent au shop pendant le run.
- **Économie** : les kills rapportent des crédits (¤), plus avec un bon rang de style. Le shop vend des augments, une arme générique, une montée de niveau d'arme et des soins (les mods à comportement arrivent plus tard).
- **XP et arbre en flocon** : l'XP du run donne un point par niveau (environ 22 sur un run complet), à placer entre deux rounds. Chaque arbre a 48 nœuds : 4 branches (Armes, Compétence, Survie, Déplacement), un tronc de 2 nœuds puis des sous-branches terminées par une pointe. Les sous-branches d'arme ne servent qu'avec l'arme correspondante. Arbre de Nyx : Essaim, Crocs, Harpon / Vitesse, Impact, Tremplin / Esquive, Flux / Air, Murs. Arbre de Brack : Tambour, Moulin, Glu / Précision, Saturation, Grappe / Blindage, Carnage / Charge, Souffle.
- **Mobilité** : double saut, roulade, glissade, **wall run** (saute contre un mur et avance) et **wall jump** (saute pendant le wall run, ou contre un mur tout proche), jump pads vers les toits.
- **Parcours dans les arènes** : panneaux de wall run à chevrons (ils font monter pendant la course), puits de wall jumps entre un panneau et un pilier, passerelles en hauteur. Des **primes** (+30 ¤, +20 PV, style) apparaissent régulièrement sur ces points hauts. Ville : passerelles nord et sud (jump pad violet), panneaux qui mènent aux tours, deux puits. Fonderie : passerelles le long des murs (refuges pendant la coulée, trou central à franchir en wall run), chaînes de plaques suspendues, un puits.
- **Ennemis** : grunt, runner, brute, spitter, drone, bouclier (à contourner ou à prendre par au-dessus), et ceux de la ville néon : hacker (brouille le HUD puis se téléporte), sniper laser sur les toits (roule pour esquiver le tir), essaim de drones pub kamikazes.
- **Boss** : *Le Brouilleur* (round 5, hacker géant) et *Titan Néon* (round 10). En phase 2, le Titan effondre la dalle centrale et fait sortir des murs de la fosse.
- **Zone 2, la fonderie** : halle d'acier avec presses (wall run), silos, quais et îlot central. Ennemis propres : ouvrier-fournaise (laisse des flaques de métal en fusion), bras mécanique fixe (balaie à hauteur de jambes, saute par-dessus), golem de scories (se reforme une fois). Mini-boss *Le Contremaître* (pluie de métal, renforts, onde de coulée) et boss *Haut-Fourneau* : ondes à sauter, et en phase 2 la coulée inonde la halle par vagues, il faut rester en hauteur.

## Contrôles
ZQSD / WASD bouger · souris viser / tirer · Espace sauter, double saut, wall jump · Shift roulade (invincible) · C glissade · R recharger (puis tire sur le chargeur en vol) · clic droit tir secondaire (Harpon : se tracter) · E ou F compétence · G ou molette grenade · P / Échap pause · M musique · 1 à 6 et Entrée dans le shop.
Manette : A saut, LB roulade, B glissade, X recharger, Y compétence, RT tirer, LT tir secondaire.

## Structure
- `scripts/data.gd` : tout l'équilibrage (perso, arbre, armes, ennemis, rounds de la zone, boss, shop, augments).
- `scripts/main.gd` : flux du run, rounds, style/combo, économie, XP, arbre, Surcharge, augments, effets.
- `scripts/arena.gd` : base commune des arènes. `city.gd` : ville néon (zone 1). `foundry.gd` : fonderie (zone 2).
- `scripts/kit.gd` : base des kits de perso (compétence, grenade, armes à mode spécial, effets de l'arbre). `scripts/kits/nyx.gd`, `brack.gd` : kits de Nyx et de Brack. `scripts/data_chars.gd` : arbres des persos débloquables.
- `scripts/player.gd` : entrées (`read_input`) séparées de la logique (`simulate`), mouvement, wall run, armes, rechargements.
- `scripts/enemy.gd` : comportements des ennemis et patterns des boss.
- `scripts/shot.gd`, `thrown_mag.gd` : projectiles et chargeur lancé.
- `scripts/hud.gd` : HUD et écrans (menu, shop, arbre, augment, pause, game over, victoire). `sfx.gd` sons synthétisés. `music.gd` musique.

## Musique
Déposer les mp3 Suno dans `music/` avec les mêmes noms que la version web (voir `web/music/README.md`).
Nouvelles pistes optionnelles : `miniboss.mp3` (sinon `boss.mp3`), `shop.mp3` et `victory.mp3` (sinon `augment.mp3`).

## Test auto
`godot --headless --path . -- --autotest` joue un run scripté des zones 1 et 2 (spawns hors du décor, wall run, parcours, jump pad, Surcharge, shop, arbre, mini-boss et boss en 2 phases, bras mécanique, flaques, golem, coulée, victoire), teste des effets de l'arbre puis les deux autres armes, et affiche le résultat dans la console. `-- --showcase --zone=2` prend des captures de la zone 2. `-- --chars` teste seulement les persos débloquables (Nyx : Overdrive, Tremplin, Crocs, Harpon, arbre ; Brack : Tambour, Moulin, Glu, Frappe orbitale, Grappe, charge, succès Démolition). `-- --routes` teste seulement les parcours des deux arènes (jump pad, panneau, puits).
