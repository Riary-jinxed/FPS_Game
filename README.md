# Horde Breaker (Godot 4)

Port Godot du prototype web. Tout est construit en code (pas d'assets externes).

## Lancer
1. Installer Godot 4.3 ou plus récent (version standard, pas .NET).
2. Godot > Importer > choisir `project.godot` dans ce dossier.
3. F5 pour jouer.

## Contrôles
ZQSD / WASD bouger · souris viser / tirer · Espace sauter (double saut) · Shift roulade (invincible) · C glissade · R recharger (puis tire sur le chargeur en vol) · P / Échap pause · M musique.
Manette : sticks, A saut, LB roulade, B glissade, X recharger, RT tirer.

## Structure
- `scripts/data.gd` : tout l'équilibrage (armes, ennemis, boss, augments, rangs de style).
- `scripts/main.gd` : arène, vagues, style/combo, dégâts, augments, effets.
- `scripts/player.gd` : mouvement, armes, tir, rechargements et chargeurs éjectés.
- `scripts/enemy.gd`, `shot.gd`, `thrown_mag.gd` : ennemis/boss, projectiles, chargeur lancé.
- `scripts/hud.gd` : HUD et menus. `sfx.gd` sons synthétisés. `music.gd` musique.

## Musique
Déposer les mp3 Suno dans `music/` avec les mêmes noms que la version web
(voir `../fps-game/music/README.md`), avec des sous-dossiers `zone1/`, `zone2/`… par zone (5 vagues par zone).

## Test auto
`godot --headless --path . -- --autotest` joue une partie scriptée avec les 3 armes et affiche le résultat dans la console.
