# Horde Breaker (Godot 4)

FPS nerveux en vagues. Cette version contient la **zone 1, la ville néon** : 10 rounds, un mini-boss au round 5, le boss de zone au round 10.
Tout est construit en code (pas d'assets externes). Direction du jeu : `fps-game/DIRECTION.md` dans les fichiers du projet.

## Lancer
1. Installer Godot 4.3 ou plus récent (version standard, pas .NET).
2. Godot > Importer > choisir `project.godot` dans ce dossier.
3. F5 pour jouer. Le rendu Forward+ (par défaut) active les reflets du sol mouillé et l'occlusion ambiante.

## Contenu de la zone 1
- **Run** : 10 rounds courts. Shop après les rounds 3, 6 et 9. Un augment offert après le mini-boss.
- **Personnage** : Kade, compétence **Surcharge** (touche E ou clic droit) chargée par le combo : ralenti des ennemis, munitions infinies, +50 % de dégâts.
- **Économie** : les kills rapportent des crédits (¤), plus avec un bon rang de style. Le shop vend des augments, des mods d'arme, une arme de niveau supérieur et des soins.
- **XP et arbre** : l'XP du run donne un point par niveau, à placer entre deux rounds dans l'arbre de Kade (Surcharge, Armes, Mobilité). Le 4e nœud de chaque branche est la version améliorée.
- **Mobilité** : double saut, roulade, glissade, **wall run** (saute contre un mur et avance) et **wall jump** (saute pendant le wall run), jump pads vers les toits.
- **Ennemis** : grunt, runner, brute, spitter, drone, bouclier (à contourner ou à prendre par au-dessus), et ceux de la ville néon : hacker (brouille le HUD puis se téléporte), sniper laser sur les toits (roule pour esquiver le tir), essaim de drones pub kamikazes.
- **Boss** : *Le Brouilleur* (round 5, hacker géant) et *Titan Néon* (round 10). En phase 2, le Titan effondre la dalle centrale et fait sortir des murs de la fosse.

## Contrôles
ZQSD / WASD bouger · souris viser / tirer · Espace sauter, double saut, wall jump · Shift roulade (invincible) · C glissade · R recharger (puis tire sur le chargeur en vol) · E ou clic droit compétence · P / Échap pause · M musique · 1 à 6 et Entrée dans le shop.
Manette : A saut, LB roulade, B glissade, X recharger, Y compétence, RT tirer.

## Structure
- `scripts/data.gd` : tout l'équilibrage (perso, arbre, armes, ennemis, rounds de la zone, boss, shop, augments).
- `scripts/main.gd` : flux du run, rounds, style/combo, économie, XP, arbre, Surcharge, augments, effets.
- `scripts/city.gd` : arène de la ville néon, effondrement de la phase 2.
- `scripts/player.gd` : entrées (`read_input`) séparées de la logique (`simulate`), mouvement, wall run, armes, rechargements.
- `scripts/enemy.gd` : comportements des ennemis et patterns des boss.
- `scripts/shot.gd`, `thrown_mag.gd` : projectiles et chargeur lancé.
- `scripts/hud.gd` : HUD et écrans (menu, shop, arbre, augment, pause, game over, victoire). `sfx.gd` sons synthétisés. `music.gd` musique.

## Musique
Déposer les mp3 Suno dans `music/` avec les mêmes noms que la version web (voir `web/music/README.md`).
Nouvelles pistes optionnelles : `miniboss.mp3` (sinon `boss.mp3`), `shop.mp3` et `victory.mp3` (sinon `augment.mp3`).

## Test auto
`godot --headless --path . -- --autotest` joue un run scripté de la zone 1 (wall run, jump pad, Surcharge, shop, arbre, mini-boss, boss en 2 phases, victoire) puis teste les deux autres armes, et affiche le résultat dans la console.
