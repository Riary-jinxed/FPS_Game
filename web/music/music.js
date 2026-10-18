/* Horde Breaker : lecteur de musique.
   Charge les pistes depuis music/, boucle, fondu enchaîné entre les phases du jeu.
   Zones : la zone 1 lit music/<fichier>, la zone N lit music/zoneN/<fichier>,
   et reprend la piste de la zone 1 si celle de la zone manque.
   Une piste absente est ignorée sans erreur, donc on peut ajouter les fichiers au fur et à mesure.

   API :
     Music.play('menu' | 'wave' | 'boss' | 'boss2' | 'augment' | 'over')
     Music.setZone(n)        (1, 2, 3… ; prend effet à la prochaine piste)
     Music.setVolume(0..1)   Music.duck(true|false) (pause : baisse le volume)   Music.toggleMute()
*/
(function () {
  const DIR = 'music/';
  const TRACKS = {
    menu:    ['menu.mp3'],
    wave:    ['wave_1.mp3', 'wave_2.mp3', 'wave_3.mp3'], // tourne d'une vague à l'autre
    boss:    ['boss.mp3'],
    boss2:   ['boss_phase2.mp3', 'boss.mp3'],            // phase 2 : repli sur boss.mp3 si absent
    augment: ['augment.mp3'],
    over:    ['gameover.mp3'],
  };
  const SHARED = { menu: true, over: true }; // communs à toutes les zones
  const FADE = 1.2; // secondes

  let volume = 0.6, muted = false, ducked = false, zone = 1;
  let current = null, currentKey = null, waveIdx = 0;
  const cache = {};
  try { const v = localStorage.getItem('hb-music-vol'); if (v !== null) volume = +v; muted = localStorage.getItem('hb-music-mute') === '1'; } catch (e) {}

  function el(path) {
    if (cache[path] !== undefined) return cache[path];
    const a = new Audio(DIR + path);
    a.loop = !/gameover/.test(path);
    a.preload = 'auto';
    a.volume = 0;
    // Fichier absent : on l'oublie et on relance la phase, qui prendra le candidat suivant.
    a.addEventListener('error', () => {
      cache[path] = null;
      if (current === a) { current = null; const k = currentKey; currentKey = null; play(k); }
    });
    return (cache[path] = a);
  }
  function target() { return muted ? 0 : volume * (ducked ? 0.35 : 1); }
  function fade(a, to, done) {
    const from = a.volume, t0 = performance.now();
    clearInterval(a._fade);
    a._fade = setInterval(() => {
      const k = Math.min(1, (performance.now() - t0) / (FADE * 1000));
      a.volume = Math.max(0, Math.min(1, from + (to - from) * k));
      if (k >= 1) { clearInterval(a._fade); if (done) done(); }
    }, 30);
  }
  function candidates(key) {
    let list = TRACKS[key] || [];
    if (key === 'wave') { const s = waveIdx % list.length; list = list.slice(s).concat(list.slice(0, s)); }
    const out = [];
    for (const f of list) {
      if (zone > 1 && !SHARED[key]) out.push('zone' + zone + '/' + f);
      out.push(f);
    }
    return out;
  }

  function play(key) {
    if (!key || key === currentKey) return; // même phase : on garde la piste (y compris pendant une vague)
    const path = candidates(key).find(p => el(p));
    if (key === 'wave') waveIdx++;
    currentKey = key;
    const next = path ? el(path) : null;
    const prev = current;
    if (prev && prev !== next) fade(prev, 0, () => prev.pause());
    current = next;
    if (!next) return;
    if (next !== prev) { next.currentTime = 0; next.volume = 0; }
    const p = next.play(); if (p && p.catch) p.catch(() => {}); // bloqué tant qu'il n'y a pas eu de clic
    fade(next, target());
  }

  // Les navigateurs bloquent l'audio avant un geste : on relance au premier clic / touche.
  function unlock() { if (current && current.paused) { const p = current.play(); if (p && p.catch) p.catch(() => {}); } }
  addEventListener('pointerdown', unlock); addEventListener('keydown', unlock);

  function save() { try { localStorage.setItem('hb-music-vol', volume); localStorage.setItem('hb-music-mute', muted ? '1' : '0'); } catch (e) {} }
  window.Music = {
    play,
    setZone(n) { n = Math.max(1, n | 0); if (n !== zone) { zone = n; waveIdx = 0; } },
    setVolume(v) { volume = Math.max(0, Math.min(1, v)); save(); if (current) fade(current, target()); },
    duck(on) { ducked = !!on; if (current) fade(current, target()); },
    toggleMute() { muted = !muted; save(); if (current) fade(current, target()); return muted; },
    get key() { return currentKey; },
    get zone() { return zone; },
  };
})();
