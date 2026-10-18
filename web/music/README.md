# Musique de Horde Breaker

Ce fichier couvre la zone 1. Les autres zones sont dans [ZONES.md](ZONES.md).

Dépose tes exports Suno ici, en **.mp3**, avec exactement ces noms. Une piste manquante est simplement ignorée par le jeu.

| Fichier | Moment du jeu | Durée visée |
|---|---|---|
| `menu.mp3` | Écran titre | 1 min 30 à 2 min (boucle) |
| `wave_1.mp3`, `wave_2.mp3`, `wave_3.mp3` | Vagues normales (une piste différente à chaque vague) | 2 à 3 min (boucle) |
| `boss.mp3` | Vague de boss (toutes les 5 vagues) | 2 à 3 min (boucle) |
| `boss_phase2.mp3` | Boss sous 50 % de PV (optionnel) | 1 min 30 à 2 min (boucle) |
| `augment.mp3` | Écran de choix d'augment entre les vagues | 1 min (boucle) |
| `gameover.mp3` | Game over | 20 à 40 s (une fois) |

## Conseils Suno

- Coche **Instrumental**. Colle le bloc « Style » dans le champ *Style of Music*.
- Mets le bloc « Lyrics » dans le champ paroles, même en instrumental : les balises entre crochets guident la structure.
- Pour une boucle propre, coupe dans Suno (ou Audacity) entre deux temps forts, sans intro ni fade final. Les balises `[Intro]` sont volontairement courtes.
- Garde le même BPM pour toutes les pistes de combat (ici 140 à 150), ça rend les enchaînements naturels.
- Le mix Roboquest = synthwave/électro agressive + guitares djent, très rythmique. Le côté John Wick = darksynth industriel, basses saturées, ambiance néon nocturne. Les prompts mélangent les deux.

---

### menu.mp3
**Style**
```
dark synthwave, cinematic darksynth, slow build, 110 bpm, brooding analog bass, neon night city atmosphere, distant industrial percussion, reverb guitar swells, tension, john wick soundtrack vibe, instrumental
```
**Lyrics**
```
[Intro: low pulsing synth bass, rain ambience]
[Verse: slow heavy drums enter, dark arpeggio]
[Build: rising synth, gritty guitar swell]
[Hook: wide detuned lead, no drop]
[Outro: back to pulsing bass]
```

### wave_1.mp3 (début de run, énergique mais pas encore saturé)
**Style**
```
aggressive synthwave, cyberpunk electro, 145 bpm, driving four on the floor kick, distorted saw bass, punchy arpeggiated synth lead, djent guitar chugs, roboquest noisecream style, video game combat music, high energy, instrumental
```
**Lyrics**
```
[Intro: 4 bars drums and bass]
[Main Riff: synth lead and guitar chugs]
[Breakdown: half-time djent riff]
[Main Riff]
[Drop: full energy synth lead]
```

### wave_2.mp3 (plus sale, plus industriel)
**Style**
```
industrial darksynth, cyberpunk metal, 145 bpm, heavy distorted 8-string guitar riffs, gritty reese bass, pounding industrial drums, aggressive synth stabs, john wick club fight scene, relentless combat music, instrumental
```
**Lyrics**
```
[Intro: industrial percussion hit]
[Riff: chugging low guitar with synth stabs]
[Build: snare roll, rising noise]
[Drop: wall of guitars and saw bass]
[Riff]
```

### wave_3.mp3 (vagues avancées, la plus rapide)
**Style**
```
high octane electro metal, synthwave djent, 150 bpm, blast beat sections, screaming synth lead, polyrhythmic guitar riffs, sidechained distorted bass, chaotic arcade shooter energy, noisecream roboquest style, instrumental
```
**Lyrics**
```
[Intro: glitch riser]
[Verse: fast double kick, palm muted riff]
[Chorus: soaring synth lead over guitars]
[Breakdown: polyrhythmic djent, glitch fx]
[Chorus]
```

### boss.mp3
**Style**
```
epic boss battle, darksynth metal, 140 bpm, massive distorted guitars, choir pads, huge cinematic drums, menacing low brass synth, sub bass drops, roboquest boss fight energy, intense and heroic, instrumental
```
**Lyrics**
```
[Intro: ominous choir and sub drop]
[Riff: heavy half-time guitars, war drums]
[Build: rising choir, snare build]
[Drop: full speed synth lead and double kick]
[Bridge: menacing low synth, tension]
[Drop]
```

### boss_phase2.mp3 (le boss enrage)
**Style**
```
frantic boss phase two, extreme darksynth, 165 bpm, chaotic breakbeat drums, screaming distorted synth, tremolo guitars, alarm-like stabs, maximum intensity, rage, instrumental
```
**Lyrics**
```
[Intro: alarm stab, short riser]
[Main: frantic breakbeat with screaming lead]
[Break: two bars of silence then slam]
[Main]
```

### augment.mp3 (pause entre les vagues)
**Style**
```
chill dark synthwave, 90 bpm, warm analog pads, soft pulsing bass, lo-fi drum machine, calm before the storm, cyberpunk safehouse, slightly tense, instrumental
```
**Lyrics**
```
[Intro: soft pad]
[Loop: steady pulse, gentle arpeggio]
[Loop]
```

### gameover.mp3
**Style**
```
dark cinematic synth sting, slow, 70 bpm, deep detuned bass, mournful synth lead, reverb tail, defeat, short ending, instrumental
```
**Lyrics**
```
[Intro: heavy low hit]
[Melody: slow sad synth lead]
[End]
```

---

## Intégration dans le jeu (pour le fil qui gère index.html)

`music.js` est autonome. Il faut l'inclure et appeler `Music.play(...)` aux changements de phase :

```html
<script src="music/music.js"></script>
```

| Moment dans index.html | Appel |
|---|---|
| Chargement de la page, menu affiché | `Music.play('menu')` |
| `startWave()` vague normale | `Music.play('wave')` |
| `startWave()` quand `wave % 5 === 0` (spawn du boss) | `Music.play('boss')` |
| `bossAI`, quand `b.phase2` passe à true | `Music.play('boss2')` |
| Mort du boss (`if (en.boss)` dans le kill) | `Music.play('augment')` ou rien, l'écran d'augment suit |
| `openAugments()` | `Music.play('augment')` |
| `pauseGame()` / reprise | `Music.duck(true)` / `Music.duck(false)` |
| `gameOver()` | `Music.play('over')` |
| Changement de zone (avant `Music.play('wave')` de la 1re vague de la zone) | `Music.setZone(n)` |
| Nouvelle partie | `Music.setZone(1)` |
| Optionnel : touche M | `Music.toggleMute()` |

Le volume et le mute sont mémorisés dans le navigateur. Le jeu doit être servi depuis le dossier `fps-game/` pour que le chemin `music/` fonctionne.
