/* Mon Job Méca — logique de l'appli
   Fonctionne dans l'appli Windows (Electron, via window.jobmeca) et comme appli web (iPhone). */
(function () {
  'use strict';

  // ================= Profil d'Imad =================
  const PROFIL = {
    prenom: 'Imad',
    nom: 'Imad Eddine Hassainia',
    tel: '07 69 54 11 95',
    mail: 'imad.h33@icloud.com',
    ville: "Villenave-d'Ornon",
    permis: 'Permis B'
  };
  const ZONE = [
    ['Villenave-d\'Ornon', 'chez moi'], ['Bègles', '~3 km'], ['Cadaujac', '~6 km'], ['Bouliac', '~8 km'],
    ['Floirac', '~9 km'], ['Cenon', '~12 km'], ['Lormont', '~15 km'], ['Pessac', '~10 km'], ['Mérignac', '~15 km']
  ];

  // ================= Statuts =================
  const STATUTS = [
    ['a_traiter', 'À traiter'], ['a_postuler', 'À postuler'], ['postule', 'Postulé'], ['relance', 'Relancé'],
    ['entretien', 'Entretien'], ['refus', 'Refus'], ['ecartee', 'Écartée']
  ];
  const STATUTS_ENT = [['a_contacter', 'À contacter'], ['envoyee', 'Envoyée'], ['relancee', 'Relancée'], ['reponse', 'Réponse']];
  const ENVOYES = ['postule', 'relance', 'entretien', 'refus'];
  const LABEL = Object.fromEntries([...STATUTS, ...STATUTS_ENT]);

  // ================= Stockage local =================
  const KEY = 'job-meca-v1';
  const CACHE_KEY = 'job-meca-cache';
  function loadStore() {
    let s = {};
    try { s = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (_) { s = {}; }
    s.offres = s.offres || {};
    s.entreprises = s.entreprises || {};
    s.reglages = Object.assign({ urlMaj: '', theme: 'auto' }, s.reglages || {});
    return s;
  }
  let store = loadStore();
  function save() { localStorage.setItem(KEY, JSON.stringify(store)); }
  function suiviOffre(id) { return store.offres[id] || (store.offres[id] = { statut: 'a_traiter', dates: {} }); }
  function suiviEnt(id) { return store.entreprises[id] || (store.entreprises[id] = { statut: 'a_contacter', dates: {} }); }
  function statutOffre(id) { return (store.offres[id] && store.offres[id].statut) || 'a_traiter'; }
  function statutEnt(id) { return (store.entreprises[id] && store.entreprises[id].statut) || 'a_contacter'; }

  // ================= Données des offres =================
  let DATA = { maj: null, offres: [], entreprises: [] };
  let dataSource = '';
  const isApp = !!window.jobmeca;

  function normalize(d) {
    d = d || {};
    return {
      maj: d.maj || null,
      offres: Array.isArray(d.offres) ? d.offres.filter(o => o && o.id) : [],
      entreprises: Array.isArray(d.entreprises) ? d.entreprises.filter(e => e && e.id) : []
    };
  }

  async function loadData(manual) {
    const url = (store.reglages.urlMaj || window.JOBMECA_DEFAULT_URL || '').trim();
    let res = null, err = '';
    if (url) {
      if (isApp) {
        res = await window.jobmeca.telechargerOffres(url);
      } else {
        try {
          const r = await fetch(url + (url.includes('?') ? '&' : '?') + 't=' + Date.now(), { cache: 'no-store' });
          if (!r.ok) throw new Error('Réponse ' + r.status);
          res = { ok: true, data: await r.json(), source: url };
        } catch (e) { res = { ok: false, error: e.message }; }
      }
      if (!res.ok) { err = 'Mise à jour en ligne impossible (' + res.error + '). Données locales utilisées.'; res = null; }
    }
    if (!res) {
      if (isApp) {
        res = await window.jobmeca.lireOffres();
      } else {
        try {
          const r = await fetch('donnees/offres.json?t=' + Date.now(), { cache: 'no-store' });
          if (!r.ok) throw new Error('Réponse ' + r.status);
          res = { ok: true, data: await r.json(), source: 'donnees/offres.json' };
        } catch (e) { res = { ok: false, error: e.message }; }
      }
    }
    if (res && res.ok) {
      DATA = normalize(res.data);
      dataSource = res.source;
      try { localStorage.setItem(CACHE_KEY, JSON.stringify(DATA)); } catch (_) {}
    } else {
      try { DATA = normalize(JSON.parse(localStorage.getItem(CACHE_KEY) || '{}')); dataSource = 'mémoire'; } catch (_) {}
      err = err || ('Impossible de lire les offres : ' + ((res && res.error) || 'inconnu'));
    }
    if (err) toast(err, 5000);
    else if (manual) toast(DATA.offres.length + ' offres et ' + DATA.entreprises.length + ' entreprises chargées');
  }

  // ================= Outils =================
  const $ = (s, el = document) => el.querySelector(s);
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const today = () => new Date().toISOString().slice(0, 10);
  const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  const MOIS_L = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  function fmtDate(s) {
    if (!s) return '';
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
    if (!m) return String(s); // "À vérifier", "2026-11"… affiché tel quel
    return (+m[3]) + ' ' + MOIS[+m[2] - 1] + ' ' + m[1];
  }
  function fmtMaj(s) {
    if (!s) return 'date inconnue';
    const d = new Date(s);
    if (isNaN(d)) return String(s);
    return d.getDate() + ' ' + MOIS_L[d.getMonth()] + ' ' + d.getFullYear() + ' à ' + String(d.getHours()).padStart(2, '0') + 'h' + String(d.getMinutes()).padStart(2, '0');
  }
  function daysSince(s) {
    if (!s) return 0;
    const d = new Date(s + 'T12:00:00');
    return Math.floor((Date.now() - d.getTime()) / 86400000);
  }
  function pubInfo(o) {
    const v = String(o.publiee || '').trim();
    let m = /^(\d{4})-(\d{2})-(\d{2})/.exec(v);
    if (m) {
      const j = daysSince(m[0]);
      const txt = j <= 0 ? 'Publiée aujourd\'hui' : j === 1 ? 'Publiée hier' : j < 7 ? 'Publiée il y a ' + j + ' jours' : 'Publiée le ' + fmtDate(m[0]);
      return { txt, nouveau: j <= 2, connue: true, jours: j };
    }
    m = /^(\d{4})-(\d{2})$/.exec(v);
    if (m) return { txt: 'Publiée en ' + MOIS_L[+m[2] - 1] + ' ' + m[1], nouveau: false, connue: true, jours: 99 };
    return { txt: 'Date de publication inconnue', nouveau: false, connue: false, jours: 999 };
  }
  const km = v => (v === 0 || v) ? (v === 0 ? 'sur place' : v + ' km') : '';
  const prio = o => [1, 2, 3].includes(+o.prio) ? +o.prio : 3;
  const sortOffres = arr => arr.slice().sort((a, b) => prio(a) - prio(b) || (+a.km || 99) - (+b.km || 99));
  function lastDate(s) {
    if (!s || !s.dates) return '';
    return Object.values(s.dates).sort().pop() || '';
  }

  // Niveau d'expérience demandé, comparé au profil (débutant / ~1 an)
  function niveauXp(txt) {
    const t = (txt || '').toLowerCase();
    if (!t.trim()) return { cls: 'nc', label: 'Expérience' };
    if (/débutant|debutant|débuts|sans exp|aucune exp|première exp|premiere exp|cap suffisant|accepté|junior|formation/.test(t)) return { cls: 'ok', label: 'Bon pour toi' };
    if (/([3-9]|\d\d)\s*ans|confirmé|expérimenté|senior/.test(t)) return { cls: 'no', label: 'Expérience élevée' };
    if (/1 à 2 ans|1 an|un an|appréci|souhait|significative|à vérifier/.test(t)) return { cls: 'mid', label: 'Proche de ton profil' };
    if (/cap|bep|bac/.test(t) && !/\d\s*ans/.test(t)) return { cls: 'ok', label: 'Bon pour toi' };
    if (/2 ans/.test(t)) return { cls: 'mid', label: 'Proche de ton profil' };
    return { cls: 'nc', label: 'Expérience' };
  }

  // ================= Icônes =================
  const P = {
    home: '<path d="M3 11.5 12 4l9 7.5"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>',
    list: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9h10M7 13h10M7 17h6"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    building: '<path d="M3 21h18"/><path d="M5 21V8l7-4 7 4v13"/><path d="M9 21v-5h6v5"/><path d="M9 11h.01M15 11h.01"/>',
    track: '<path d="M4 6h16M4 12h10M4 18h6"/><circle cx="19" cy="17" r="3"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>',
    refresh: '<path d="M21 12a9 9 0 1 1-2.6-6.4"/><path d="M21 4v5h-5"/>',
    pin: '<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
    euro: '<path d="M18 7a7 7 0 1 0 0 10"/><path d="M4 10h10M4 14h10"/>',
    doc: '<path d="M14 3H6v18h12V7z"/><path d="M14 3v4h4"/><path d="M9 12h6M9 16h6"/>',
    ext: '<path d="M14 4h6v6"/><path d="M20 4 10 14"/><path d="M19 14v6H4V5h6"/>',
    pen: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m14 6 4 4"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    bell: '<path d="M6 16V11a6 6 0 1 1 12 0v5l2 2H4z"/><path d="M10 21h4"/>',
    check: '<path d="m5 12 5 5 9-10"/>',
    phone: '<path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2z"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>',
    car: '<path d="M5 16V11l2-5h10l2 5v5"/><path d="M3 16h18v3H3z"/><circle cx="7.5" cy="13" r=".5"/><circle cx="16.5" cy="13" r=".5"/>',
    wrench: '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.8-3.8a6 6 0 0 1-7.9 7.9l-6.9 6.9a2.1 2.1 0 0 1-3-3l6.9-6.9a6 6 0 0 1 7.9-7.9z"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>',
    grad: '<path d="m2 9 10-5 10 5-10 5z"/><path d="M6 11v5c3 2 9 2 12 0v-5"/>',
    copy: '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V3H3v13h5"/>',
    save: '<path d="M5 3h11l3 3v15H5z"/><path d="M8 3v5h8V3"/><path d="M8 21v-7h8v7"/>',
    x: '<path d="M6 6l12 12M18 6 6 18"/>',
    folder: '<path d="M3 6h6l2 2h10v11H3z"/>',
    star: '<path d="m12 3 2.8 5.8 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.3l1-6.2L3 9.7l6.2-.9z"/>',
    zap: '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
    note: '<path d="M4 4h16v12l-4 4H4z"/><path d="M16 20v-4h4"/>',
    download: '<path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M4 21h16"/>',
    upload: '<path d="M12 21V9"/><path d="m7 14 5-5 5 5"/><path d="M4 3h16"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5 19 19M5 19l1.5-1.5M17.5 6.5 19 5"/>',
    send: '<path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4z"/>',
    briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V4h8v3"/><path d="M3 13h18"/>'
  };
  const ic = n => '<svg class="i" viewBox="0 0 24 24" aria-hidden="true">' + (P[n] || '') + '</svg>';

  // ================= Navigation =================
  const VUES = [
    ['accueil', 'Accueil', 'home'],
    ['offres', 'Offres', 'briefcase'],
    ['marche', 'Marché caché', 'building'],
    ['suivi', 'Suivi', 'track'],
    ['profil', 'Profil', 'user']
  ];
  let vue = 'accueil';
  const ui = { filtre: 'toutes', q: '', filtreEnt: 'tous', qEnt: '', openNotes: {} };

  function relances() {
    const out = [];
    DATA.offres.forEach(o => {
      const s = store.offres[o.id];
      if (!s || !['postule', 'relance'].includes(s.statut)) return;
      const d = s.dates[s.statut] || s.dateCandidature;
      if (daysSince(d) > 7) out.push({ kind: 'offre', item: o, s, jours: daysSince(d) });
    });
    DATA.entreprises.forEach(e => {
      const s = store.entreprises[e.id];
      if (!s || !['envoyee', 'relancee'].includes(s.statut)) return;
      const d = s.dates[s.statut];
      if (daysSince(d) > 7) out.push({ kind: 'ent', item: e, s, jours: daysSince(d) });
    });
    return out.sort((a, b) => b.jours - a.jours);
  }

  function renderNav() {
    const nR = relances().length;
    const nA = DATA.offres.filter(o => statutOffre(o.id) === 'a_traiter').length;
    const badge = { offres: nA, suivi: nR };
    const html = VUES.map(([id, label, icon]) =>
      '<button type="button" data-vue="' + id + '"' + (vue === id ? ' aria-current="page"' : '') + '>' + ic(icon) +
      '<span>' + label + '</span>' + (badge[id] ? '<span class="count">' + badge[id] + '</span>' : '') + '</button>').join('');
    $('#nav').innerHTML = html;
    $('#tabbar').innerHTML = html.replace(/Marché caché/, 'Marché');
    $('#sideMaj').textContent = 'Offres mises à jour le ' + fmtMaj(DATA.maj);
  }

  function go(v) {
    vue = v;
    render();
    $('#main').scrollTop = 0;
    document.body.classList.remove('scrolled', 'titled');
  }

  function render() {
    renderNav();
    const lab = (VUES.find(v => v[0] === vue) || [0, ''])[1];
    $('#topTitle').textContent = vue === 'accueil' ? 'Mon Job Méca' : lab;
    const m = $('#main');
    const f = { accueil: vAccueil, offres: vOffres, marche: vMarche, suivi: vSuivi, profil: vProfil }[vue];
    m.innerHTML = '<div class="page">' + f() + '</div>';
    bindPage();
  }

  // ================= Cartes =================
  function selectStatut(kind, id, cur) {
    const list = kind === 'ent' ? STATUTS_ENT : STATUTS;
    return '<select class="status s-' + cur + '" data-statut="' + kind + '" data-id="' + esc(id) + '" aria-label="Statut">' +
      list.map(([v, l]) => '<option value="' + v + '"' + (v === cur ? ' selected' : '') + '>' + l + '</option>').join('') + '</select>';
  }

  function statusLine(s) {
    if (!s || !s.dates) return '';
    const bits = [];
    if (s.dateCandidature) bits.push('Candidature le ' + fmtDate(s.dateCandidature));
    if (s.dates.relance) bits.push('relancé le ' + fmtDate(s.dates.relance));
    if (s.dates.entretien) bits.push('entretien noté le ' + fmtDate(s.dates.entretien));
    if (s.lettre) bits.push('lettre prête');
    return bits.length ? '<div class="status-line">' + ic('clock') + bits.join(' · ') + '</div>' : '';
  }

  function carteOffre(o) {
    const st = statutOffre(o.id);
    const s = store.offres[o.id];
    const xp = niveauXp(o.experience);
    const p = prio(o);
    const notesOpen = ui.openNotes[o.id] || (s && s.note);
    const pub = pubInfo(o);
    return '<article class="card' + (['ecartee', 'refus'].includes(st) ? ' dim' : '') + '" data-offre="' + esc(o.id) + '">' +
      '<div class="card-top"><span class="prio p' + p + '">Prio ' + p + '</span><div style="min-width:0">' +
      '<h3>' + esc(o.poste) + '</h3><div class="co">' + esc(o.entreprise) + '</div>' +
      '<div class="where">' + ic('pin') + esc(o.ville) + (km(o.km) ? ' · ' + km(o.km) : '') + '</div>' +
      '<div class="pub' + (pub.connue ? '' : ' unk') + '">' + ic('clock') + esc(pub.txt) + (pub.nouveau ? '<span class="new">Nouveau</span>' : '') + '</div></div></div>' +
      '<div class="xp ' + xp.cls + '">' + ic(xp.cls === 'ok' ? 'check' : xp.cls === 'no' ? 'x' : 'grad') +
      '<div><small>' + xp.label + '</small>' + esc(o.experience || 'Non précisée') + '</div></div>' +
      '<div class="facts">' +
      (o.contrat ? '<span class="tag">' + ic('doc') + esc(o.contrat) + '</span>' : '') +
      (o.type ? '<span class="tag">' + ic(/concession/i.test(o.type) ? 'building' : 'wrench') + esc(o.type) + '</span>' : '') +
      (o.salaire ? '<span class="tag money">' + ic('euro') + esc(o.salaire) + '</span>' : '') +
      '</div>' +
      (o.note ? '<div class="note">' + esc(o.note) + '</div>' : '') +
      statusLine(s) +
      (notesOpen ? '<div class="mine"><textarea data-note="offre" data-id="' + esc(o.id) + '" placeholder="Mes notes perso (appel, nom du chef d\'atelier, horaires…)">' + esc((s && s.note) || '') + '</textarea></div>' : '') +
      '<div class="card-foot"><div class="foot-row">' + selectStatut('offre', o.id, st) +
      '<span class="spacer"></span>' +
      (!notesOpen ? '<button class="btn btn-quiet btn-sm" data-act="notes" data-id="' + esc(o.id) + '" title="Ajouter une note">' + ic('note') + 'Note</button>' : '') + '</div><div class="foot-row actions">' +
      '<button class="btn btn-primary btn-sm" data-act="postuler" data-id="' + esc(o.id) + '">' + ic('send') + 'Postuler</button>' +
      '<button class="btn btn-sm" data-act="lettre" data-kind="offre" data-id="' + esc(o.id) + '">' + ic('pen') + 'Ma lettre</button>' +
      '</div></div></article>';
  }

  function initiales(nom) {
    return (nom || '?').replace(/[^A-Za-zÀ-ÿ0-9 ]/g, ' ').split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0].toUpperCase()).join('');
  }

  function carteEnt(e) {
    const st = statutEnt(e.id);
    const s = store.entreprises[e.id];
    const isCentre = /centre/i.test(e.type || '');
    const contact = e.contact || '';
    const contactHtml = /@/.test(contact) ? '<a href="mailto:' + esc(contact) + '" data-act="lien" data-url="mailto:' + esc(contact) + '">' + esc(contact) + '</a>'
      : /^[\d\s.+]{9,}$/.test(contact) ? '<a href="tel:' + esc(contact.replace(/\s/g, '')) + '">' + esc(contact) + '</a>' : esc(contact);
    const notesOpen = ui.openNotes['e:' + e.id] || (s && s.note);
    return '<article class="card ent" data-ent="' + esc(e.id) + '">' +
      '<div class="card-top"><div class="brand-badge' + (isCentre ? ' centre' : '') + '">' + esc(initiales(e.marque && !/multi|pneu/i.test(e.marque) ? e.marque : e.nom)) + '</div>' +
      '<div style="min-width:0"><h3>' + esc(e.nom) + '</h3><div class="co">' + esc([e.marque, e.type].filter(Boolean).join(' · ')) + '</div>' +
      '<div class="where">' + ic('pin') + esc(e.ville) + (km(e.km) ? ' · ' + km(e.km) : '') + '</div></div></div>' +
      '<div class="meta">' +
      (e.adresse ? '<div>' + ic('home') + '<span>' + esc(e.adresse) + '</span></div>' : '') +
      (contact ? '<div>' + ic(/@/.test(contact) ? 'mail' : 'phone') + '<span>' + contactHtml + '</span></div>' : '') +
      '</div>' +
      (e.note ? '<div class="note">' + esc(e.note) + '</div>' : '') +
      (s && s.dates && Object.keys(s.dates).length ? '<div class="status-line">' + ic('clock') + 'Dernière action le ' + fmtDate(lastDate(s)) + (s.lettre ? ' · lettre prête' : '') + '</div>' : '') +
      (notesOpen ? '<div class="mine"><textarea data-note="ent" data-id="' + esc(e.id) + '" placeholder="Mes notes perso (qui j\'ai vu, quand repasser…)">' + esc((s && s.note) || '') + '</textarea></div>' : '') +
      '<div class="card-foot"><div class="foot-row">' + selectStatut('ent', e.id, st) + '<span class="spacer"></span>' +
      (!notesOpen ? '<button class="btn btn-quiet btn-sm" data-act="notes" data-id="e:' + esc(e.id) + '">' + ic('note') + 'Note</button>' : '') + '</div><div class="foot-row actions">' +
      (e.lienRecrutement ? '<button class="btn btn-sm" data-act="lien" data-url="' + esc(e.lienRecrutement) + '">' + ic('ext') + 'Recrutement</button>' : '') +
      '<button class="btn btn-primary btn-sm" data-act="lettre" data-kind="ent" data-id="' + esc(e.id) + '">' + ic('pen') + 'Lettre spontanée</button>' +
      '</div></div></article>';
  }

  // ================= Vue Accueil =================
  function vAccueil() {
    const st = DATA.offres.map(o => statutOffre(o.id));
    const nTraiter = st.filter(x => x === 'a_traiter').length;
    const nPret = st.filter(x => x === 'a_postuler').length;
    const nEnv = st.filter(x => ENVOYES.includes(x)).length + DATA.entreprises.filter(e => statutEnt(e.id) !== 'a_contacter').length;
    const nEnt = st.filter(x => x === 'entretien').length;
    const top = sortOffres(DATA.offres.filter(o => ['a_traiter', 'a_postuler'].includes(statutOffre(o.id)))).slice(0, 3);
    const rel = relances();
    const majAge = DATA.maj ? (Date.now() - new Date(DATA.maj).getTime()) / 86400000 : 99;
    const h = new Date().getHours();
    const salut = h >= 18 || h < 5 ? 'Bonsoir' : 'Salut';
    return '<div class="hello"><div><p class="eyebrow">' + new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' }) + '</p>' +
      '<h1 class="title">' + salut + ' ' + PROFIL.prenom + '</h1>' +
      '<p class="lead" style="margin:0">Ta recherche en service rapide autour de Villenave-d\'Ornon. Une candidature bien faite par jour, et ça finit par payer.</p></div>' +
      '<div class="maj-chip"><span class="dot' + (majAge > 7 ? ' old' : '') + '"></span>Offres du ' + esc(fmtMaj(DATA.maj)) + '</div></div>' +
      '<div class="kpis">' +
      '<button class="kpi k1" data-goto="offres" data-filtre="a_traiter"><span class="n">' + nTraiter + '</span><span class="l">À traiter</span></button>' +
      '<button class="kpi k2" data-goto="offres" data-filtre="a_postuler"><span class="n">' + nPret + '</span><span class="l">Prêtes à postuler</span></button>' +
      '<button class="kpi k3" data-goto="suivi"><span class="n">' + nEnv + '</span><span class="l">Candidatures envoyées</span></button>' +
      '<button class="kpi k4" data-goto="suivi"><span class="n">' + nEnt + '</span><span class="l">Entretiens</span></button>' +
      '</div>' +
      (rel.length ? '<div class="alert">' + ic('bell') + '<div><b>' + rel.length + ' relance' + (rel.length > 1 ? 's' : '') + ' à faire</b>' +
        'Envoyée il y a plus de 7 jours sans réponse : un petit appel ou un passage au garage, ça fait la différence.<ul>' +
        rel.slice(0, 5).map(r => '<li>' + esc(r.kind === 'offre' ? r.item.entreprise + ' — ' + r.item.poste : r.item.nom) + ' (il y a ' + r.jours + ' jours)</li>').join('') +
        '</ul><div style="margin-top:8px"><button class="btn btn-sm" data-goto="suivi">' + ic('track') + 'Voir le suivi</button></div></div></div>'
        : '<div class="alert ok">' + ic('check') + '<div><b>Aucune relance en retard</b>Quand tu postules, change le statut en « Postulé » : l\'appli te rappellera de relancer au bout de 7 jours.</div></div>') +
      '<h2 class="h2">' + ic('star') + 'Tes 3 meilleures pistes<span class="sub">Triées par priorité puis distance</span></h2>' +
      (top.length ? '<div class="grid">' + top.map((o, i) => i === 0 ? carteOffre(o).replace('<article class="card', '<article class="card feat') : carteOffre(o)).join('') + '</div>'
        : '<div class="empty"><b>Plus rien à traiter</b>Toutes les offres ont un statut. Regarde le marché caché pour des candidatures spontanées.</div>') +
      '<div style="margin-top:18px" class="row"><button class="btn btn-dark" data-goto="offres">' + ic('briefcase') + 'Toutes les offres (' + DATA.offres.length + ')</button>' +
      '<button class="btn" data-goto="marche">' + ic('building') + 'Marché caché (' + DATA.entreprises.length + ')</button></div>';
  }

  // ================= Vue Offres =================
  const FILTRES = [
    ['toutes', 'Toutes', o => !['ecartee', 'refus'].includes(statutOffre(o.id))],
    ['prio1', 'Prio 1', o => prio(o) === 1 && statutOffre(o.id) !== 'ecartee'],
    ['concession', 'Concession', o => /concession/i.test(o.type + ' ' + o.entreprise) && statutOffre(o.id) !== 'ecartee'],
    ['cdi', 'CDI', o => /cdi/i.test(o.contrat) && statutOffre(o.id) !== 'ecartee'],
    ['interim', 'Intérim', o => /int[ée]rim/i.test(o.contrat) && statutOffre(o.id) !== 'ecartee'],
    ['postulees', 'Postulées', o => ['postule', 'relance', 'entretien', 'refus'].includes(statutOffre(o.id))],
    ['ecartees', 'Écartées', o => statutOffre(o.id) === 'ecartee']
  ];
  const FILTRES_CACHES = { a_traiter: ['À traiter', o => statutOffre(o.id) === 'a_traiter'], a_postuler: ['À postuler', o => statutOffre(o.id) === 'a_postuler'] };

  function matchQ(obj, q) {
    if (!q) return true;
    const t = Object.values(obj).join(' ').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    return q.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').split(/\s+/).every(w => t.includes(w));
  }

  function vOffres() {
    const f = FILTRES.find(x => x[0] === ui.filtre) || (FILTRES_CACHES[ui.filtre] ? [ui.filtre, FILTRES_CACHES[ui.filtre][0], FILTRES_CACHES[ui.filtre][1]] : FILTRES[0]);
    const list = sortOffres(DATA.offres.filter(f[2]).filter(o => matchQ(o, ui.q)));
    const chips = FILTRES.concat(FILTRES_CACHES[ui.filtre] ? [f] : []).map(([id, l, fn]) =>
      '<button class="chip" data-filtre="' + id + '" aria-pressed="' + (ui.filtre === id) + '">' + l + ' <span class="c">' + DATA.offres.filter(fn).length + '</span></button>').join('');
    return '<div class="head-row"><div><p class="eyebrow">' + DATA.offres.length + ' offres repérées</p><h1 class="title">Offres</h1>' +
      '<p class="lead">L\'expérience demandée est en couleur : <b style="color:var(--green)">vert</b> = ça colle à ton profil, <b style="color:var(--amber)">jaune</b> = proche, <b style="color:var(--red)">rouge</b> = demande plus.</p></div></div>' +
      '<div class="toolbar"><div class="chips">' + chips + '</div>' +
      '<label class="search">' + ic('search') + '<input id="q" type="search" placeholder="Chercher une ville, une marque, un mot…" value="' + esc(ui.q) + '"></label></div>' +
      '<div id="list">' + listeOffres(list) + '</div>';
  }
  function listeOffres(list) {
    return list.length ? '<div class="grid">' + list.map(carteOffre).join('') + '</div>' : '<div class="empty"><b>Aucune offre ici</b>Change de filtre ou efface la recherche.</div>';
  }

  // ================= Vue Marché caché =================
  const FILTRES_ENT = [
    ['tous', 'Toutes', () => true],
    ['concession', 'Concessions', e => /concession/i.test(e.type)],
    ['centre', 'Centres auto', e => /centre/i.test(e.type)],
    ['garage', 'Garages', e => /garage/i.test(e.type)],
    ['acontacter', 'À contacter', e => statutEnt(e.id) === 'a_contacter'],
    ['contactees', 'Contactées', e => statutEnt(e.id) !== 'a_contacter']
  ];
  function vMarche() {
    const f = FILTRES_ENT.find(x => x[0] === ui.filtreEnt) || FILTRES_ENT[0];
    const list = DATA.entreprises.filter(f[2]).filter(e => matchQ(e, ui.qEnt)).sort((a, b) => (+a.km || 99) - (+b.km || 99));
    return '<p class="eyebrow">Candidatures spontanées</p><h1 class="title">Marché caché</h1>' +
      '<p class="lead">Beaucoup de postes ne sont jamais publiés. Ces concessions et centres auto sont près de chez toi : dépose ton CV en main propre au chef d\'atelier, ou envoie une lettre spontanée.</p>' +
      '<div class="toolbar"><div class="chips">' + FILTRES_ENT.map(([id, l, fn]) =>
        '<button class="chip" data-filtre-ent="' + id + '" aria-pressed="' + (ui.filtreEnt === id) + '">' + l + ' <span class="c">' + DATA.entreprises.filter(fn).length + '</span></button>').join('') + '</div>' +
      '<label class="search">' + ic('search') + '<input id="qEnt" type="search" placeholder="Chercher une marque, une ville…" value="' + esc(ui.qEnt) + '"></label></div>' +
      '<div id="list">' + listeEnt(list) + '</div>';
  }
  function listeEnt(list) {
    return list.length ? '<div class="grid">' + list.map(carteEnt).join('') + '</div>' : '<div class="empty"><b>Aucune entreprise ici</b>Change de filtre ou efface la recherche.</div>';
  }

  // ================= Vue Suivi =================
  function idee(kind, statut, jours) {
    if (kind === 'offre') {
      if (statut === 'a_postuler') return ['', 'Prépare ta lettre et envoie ta candidature aujourd\'hui : les offres partent vite.'];
      if (statut === 'postule') return jours > 7 ? ['warn', 'Plus de 7 jours sans réponse : appelle et demande le chef d\'atelier. « Bonjour, j\'ai postulé il y a une semaine pour le poste de mécanicien, je voulais savoir si ma candidature avait été vue. »']
        : ['', 'Laisse 7 jours. Si pas de nouvelles, relance par téléphone (l\'appli te le rappellera).'];
      if (statut === 'relance') return jours > 7 ? ['warn', 'Toujours rien : passe directement au garage avec ton CV imprimé, en tenue propre, entre 9h et 11h.']
        : ['', 'Relance faite. Si pas de réponse sous une semaine, passe sur place avec ton CV.'];
      if (statut === 'entretien') return ['', 'Prépare-toi : parle de tes 3 distributions seul (1.7 CDTI, 1.4 HDi, 3.0 V6), de ton autonomie en service rapide, et viens avec ton CV et ton diplôme.'];
      if (statut === 'refus') return ['', 'Pas grave. Demande poliment ce qui a manqué, et propose de repasser dans quelques mois.'];
    } else {
      if (statut === 'envoyee') return jours > 7 ? ['warn', 'Plus de 7 jours : passe sur place et demande à voir le chef d\'atelier 2 minutes.'] : ['', 'Laisse 7 jours avant de relancer.'];
      if (statut === 'relancee') return ['', 'Note le nom de la personne rencontrée, et redonne des nouvelles dans 2 à 3 semaines.'];
      if (statut === 'reponse') return ['', 'Super ! Note la suite (entretien, essai, date) dans tes notes.'];
    }
    return ['', ''];
  }

  function vSuivi() {
    const items = [];
    DATA.offres.forEach(o => {
      const s = store.offres[o.id];
      if (!s || ['a_traiter', 'ecartee'].includes(s.statut)) return;
      items.push({ kind: 'offre', id: o.id, titre: o.poste, co: o.entreprise + ' · ' + o.ville, s, date: s.dateCandidature || lastDate(s) || '', last: s.dates[s.statut] || lastDate(s) });
    });
    DATA.entreprises.forEach(e => {
      const s = store.entreprises[e.id];
      if (!s || s.statut === 'a_contacter') return;
      items.push({ kind: 'ent', id: e.id, titre: e.nom, co: 'Candidature spontanée · ' + e.ville, s, date: s.dates.envoyee || lastDate(s) || '', last: s.dates[s.statut] || lastDate(s) });
    });
    items.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
    const rel = relances();
    return '<p class="eyebrow">Mes candidatures</p><h1 class="title">Suivi</h1>' +
      '<p class="lead">Tout ce que tu as envoyé, du plus récent au plus ancien, avec une idée de ce qu\'il faut faire ensuite.</p>' +
      (rel.length ? '<div class="alert" style="margin:0 0 22px">' + ic('bell') + '<div><b>' + rel.length + ' relance' + (rel.length > 1 ? 's' : '') + ' à faire</b>Elles sont marquées en jaune ci-dessous.</div></div>' : '') +
      (items.length ? '<div class="timeline">' + items.map(it => {
        const j = daysSince(it.last);
        const [cls, txt] = idee(it.kind, it.s.statut, j);
        const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(it.date || '');
        return '<div class="tl-item"><div class="tl-date">' + (m ? '<b>' + (+m[3]) + '</b>' + MOIS[+m[2] - 1] + ' ' + m[1] : '—') + '</div>' +
          '<div class="tl-card"><div class="tl-head"><div><div class="kind">' + (it.kind === 'offre' ? 'Offre' : 'Spontanée') + '</div><h3>' + esc(it.titre) + '</h3><div class="co">' + esc(it.co) + '</div></div>' +
          selectStatut(it.kind, it.id, it.s.statut) + '</div>' +
          (it.last ? '<div class="status-line" style="padding:8px 0 0">' + ic('clock') + LABEL[it.s.statut] + ' depuis ' + (j <= 0 ? 'aujourd\'hui' : j + ' jour' + (j > 1 ? 's' : '')) + (it.s.note ? ' · ' + esc(it.s.note.slice(0, 80)) : '') + '</div>' : '') +
          (txt ? '<div class="tip ' + cls + '">' + ic(cls ? 'bell' : 'zap') + '<span>' + esc(txt) + '</span></div>' : '') +
          '<div class="row" style="margin-top:10px"><button class="btn btn-sm" data-act="lettre" data-kind="' + it.kind + '" data-id="' + esc(it.id) + '">' + ic('pen') + (it.s.lettre ? 'Ma lettre' : 'Préparer ma lettre') + '</button></div>' +
          '</div></div>';
      }).join('') + '</div>'
        : '<div class="empty"><b>Pas encore de candidature</b>Dans « Offres », passe une offre en « Postulé » : elle apparaîtra ici avec la date.</div>');
  }

  // ================= Vue Profil =================
  function vProfil() {
    const r = store.reglages;
    return '<p class="eyebrow">Ce que les recruteurs doivent savoir</p><h1 class="title">Mon profil</h1>' +
      '<p class="lead">C\'est ce profil qui sert à écrire tes lettres de motivation.</p>' +
      '<div class="two"><div style="display:grid;gap:18px">' +
      '<section class="panel"><div class="idcard"><div class="avatar">IH</div><div><div class="nm">' + PROFIL.nom + '</div>' +
      '<div class="rl">Mécanicien automobile · CAP Maintenance des véhicules</div></div></div>' +
      '<div class="contact"><div>' + ic('phone') + PROFIL.tel + '</div><div>' + ic('mail') + PROFIL.mail + '</div><div>' + ic('pin') + PROFIL.ville + '</div><div>' + ic('car') + PROFIL.permis + ' · Disponible immédiatement</div></div></section>' +
      '<section class="panel"><h3>Mon parcours</h3><ul class="parcours">' +
      '<li><span class="ico">' + ic('grad') + '</span><div><b>CAP Maintenance des véhicules — validé</b><p>En apprentissage dans un garage spécialisé Range Rover et BMW : distributions, décaissage, dépose moteur, embrayage, boîte de vitesses avec le mécanicien. En fin de CAP : autonome sur décaissage et dépose moteur, 3 distributions seul (1.7 CDTI, 1.4 HDi, 3.0 V6).</p></div></li>' +
      '<li><span class="ico">' + ic('wrench') + '</span><div><b>1 an et demi de mécanique perso</b><p>Vidanges, train avant, disques et plaquettes, berceau, kit embrayage.</p></div></li>' +
      '</ul></section>' +
      '<section class="panel"><h3>Ce que je sais faire</h3><div class="skills">' +
      ['Service rapide (autonome)', 'Vidange / filtres', 'Freinage disques & plaquettes', 'Train avant', 'Distribution', 'Kit embrayage', 'Décaissage', 'Dépose moteur', 'Boîte de vitesses', 'Berceau']
        .map((s, i) => '<span' + (i < 1 || s === 'Distribution' ? ' class="hi"' : '') + '>' + s + '</span>').join('') + '</div>' +
      '<p style="margin:12px 0 0;color:var(--ink-2);font-size:14px">Objectif : évoluer vers la grosse mécanique et le diagnostic. J\'apprends vite et je suis motivé.</p></section>' +
      '</div><div style="display:grid;gap:18px">' +
      '<section class="panel"><h3>Ce que je cherche</h3><div class="skills" style="margin-bottom:14px"><span class="hi">Service rapide</span><span class="hi">Débutant accepté / ~1 an</span><span>CDI ou intérim</span><span>Idéal : concession pour évoluer</span></div>' +
      '<div style="font-weight:600;font-size:13.5px;margin-bottom:6px">Ma zone, du plus près au plus loin</div><ul class="route">' +
      ZONE.map(([v, k]) => '<li><span class="pin"></span><span>' + v + '</span><span class="km">' + k + '</span></li>').join('') + '</ul></section>' +
      '<section class="panel"><h3>Comment postuler</h3><ol class="steps">' +
      '<li><div><b>Choisis et prépare</b><p>Dans « Offres », prends une piste verte, clique « Préparer ma lettre », relis-la et ajoute un détail sur le garage si tu peux.</p></div></li>' +
      '<li><div><b>Envoie</b><p>« Voir l\'annonce » ouvre le site : joins ton CV et colle ta lettre. Puis mets le statut sur « Postulé » (la date se note toute seule).</p></div></li>' +
      '<li><div><b>Relance</b><p>Au bout de 7 jours sans réponse, l\'appli te prévient : appelle ou passe sur place avec ton CV. C\'est souvent ce qui décide.</p></div></li>' +
      '</ol></section>' +
      '<section class="panel"><h3>Réglages</h3>' +
      '<div class="field"><label for="urlMaj">Adresse de mise à jour en ligne</label><input id="urlMaj" type="url" placeholder="https://… (laisser vide pour l\'instant)" value="' + esc(r.urlMaj) + '">' +
      '<span class="hint">Si une adresse est indiquée, l\'appli télécharge les nouvelles offres depuis internet. Sinon elle lit le fichier « donnees\\offres.json ». Tes statuts et notes ne sont jamais effacés.</span></div>' +
      '<div class="field" hidden><label for="theme">Apparence</label><select id="theme"><option value="auto"' + (r.theme === 'auto' ? ' selected' : '') + '>Automatique (comme Windows)</option><option value="clair"' + (r.theme === 'clair' ? ' selected' : '') + '>Clair</option><option value="sombre"' + (r.theme === 'sombre' ? ' selected' : '') + '>Sombre</option></select></div>' +
      '<div class="row"><button class="btn" data-act="refresh">' + ic('refresh') + 'Actualiser les offres</button>' +
      (isApp ? '<button class="btn" data-act="dossier">' + ic('folder') + 'Dossier des lettres</button>' : '') +
      '<button class="btn" data-act="export">' + ic('download') + 'Sauvegarder mes données</button>' +
      '<label class="btn">' + ic('upload') + 'Restaurer<input type="file" id="importFile" accept=".json,application/json" hidden></label></div>' +
      '<p class="mono" style="margin:12px 0 0" id="infoPath">Source des offres : ' + esc(dataSource || '—') + '</p>' +
      '</section></div></div>';
  }

  // ================= Lettre de motivation (modèle local) =================
  const MARQUES = ['Renault', 'Peugeot', 'Citroën', 'Citroen', 'Toyota', 'Lexus', 'BMW', 'MINI', 'Mercedes', 'Audi', 'Volkswagen', 'Ford', 'Kia', 'Hyundai', 'Dacia', 'Nissan', 'Opel', 'Fiat', 'Skoda', 'Seat', 'Cupra', 'Volvo', 'Land Rover', 'Range Rover', 'Jaguar', 'Tesla', 'Mazda', 'Suzuki', 'Honda', 'DS', 'Jeep', 'Alfa Romeo', 'Porsche', 'MG'];
  const AGENCES = /adecco|randstad|ad[ée]quat|proman|ras int[ée]rim|temporis|camo|capactuel|manpower|start people|synergie|crit|actual|partnaire|samsic|interim|intérim/i;

  function detectMarque(txt) {
    const t = ' ' + (txt || '') + ' ';
    return MARQUES.filter(m => new RegExp('[^A-Za-zÀ-ÿ]' + m.replace(/ /g, '\\s') + '[^A-Za-zÀ-ÿ]', 'i').test(t));
  }
  function nomPropre(n) { return String(n || '').replace(/\s*\(.*?\)\s*/g, ' ').replace(/\s+/g, ' ').trim(); }
  function dateLongue() { const d = new Date(); return d.getDate() + ' ' + MOIS_L[d.getMonth()] + ' ' + d.getFullYear(); }

  function genererLettre(kind, item) {
    const spont = kind === 'ent';
    const brut = spont ? item.nom : item.entreprise;
    const nom = nomPropre(brut);
    const typeTxt = ((item.type || '') + ' ' + brut).toLowerCase();
    const agence = !spont && AGENCES.test(brut);
    const clientTxt = agence ? ((/\((.*?)\)/.exec(brut) || [])[1] || '').replace(/^clients?\s+/i, '') : '';
    const isConcession = /concession|constructeur/.test(typeTxt + ' ' + clientTxt.toLowerCase());
    const isCentre = /centre|feu vert|norauto|speedy|midas|euromaster|point s|first stop|vulco|carglass|entretien/.test(typeTxt + ' ' + clientTxt.toLowerCase());
    const marques = detectMarque((spont ? item.marque + ' ' : '') + brut + ' ' + (item.note || ''));
    const marque = marques.filter(m => !/^(Range Rover|Land Rover)$/i.test(m))[0] || '';
    const poste = spont ? 'mécanicien automobile en service rapide' : (item.poste || 'mécanicien automobile').replace(/\s*[HF]\/[HF]\s*|\s*F\/H\s*/gi, ' ').trim();
    const posteMin = poste.charAt(0).toLowerCase() + poste.slice(1);
    const ville = (item.ville || '').split('/')[0].trim();
    const bonneVille = /villenave|b[èe]gles|cadaujac|bouliac|floirac/i.test(ville);

    const L = [];
    L.push(PROFIL.nom, PROFIL.ville, PROFIL.tel, PROFIL.mail, '');
    L.push(spont ? nom + (item.adresse ? '\n' + item.adresse : '') + (item.ville ? '\n' + item.ville : '') : nom + (ville ? '\n' + ville : ''));
    L.push('', PROFIL.ville + ', le ' + dateLongue(), '');
    L.push(spont ? 'Objet : candidature spontanée — mécanicien automobile (service rapide)' : 'Objet : candidature au poste de ' + posteMin);
    L.push('', item.contact && /chef|responsable|directeur|m\.|mme/i.test(item.contact) && !/@/.test(item.contact) ? 'Madame, Monsieur,' : 'Madame, Monsieur,', '');

    // Accroche
    if (spont) {
      if (isConcession && marque) L.push('Je me permets de vous proposer ma candidature pour un poste de mécanicien en service rapide au sein de votre concession ' + marque + (ville ? ' de ' + ville : '') + (/villenave/i.test(ville) ? '. Habitant moi aussi à ' + PROFIL.ville : '. Habitant à ' + PROFIL.ville + (bonneVille ? ', à quelques minutes de chez vous' : '')) + ', je cherche un atelier où m\'investir sur la durée, et une concession est pour moi le meilleur endroit pour progresser.');
      else if (isCentre) L.push('Je me permets de vous proposer ma candidature pour un poste de mécanicien en service rapide dans votre centre' + (ville ? ' de ' + ville : '') + '. J\'habite à ' + PROFIL.ville + (bonneVille ? ', tout près' : '') + ' et je suis disponible tout de suite.');
      else L.push('Je me permets de vous proposer ma candidature pour un poste de mécanicien automobile dans votre garage' + (ville ? ' de ' + ville : '') + '. J\'habite à ' + PROFIL.ville + (bonneVille ? ', tout près' : '') + ' et je suis disponible tout de suite.');
    } else if (agence) {
      L.push('Votre offre de ' + posteMin + (clientTxt ? ' pour votre client (' + clientTxt + ')' : '') + (ville ? ' à ' + ville : '') + ' a retenu toute mon attention. Titulaire d\'un CAP Maintenance des véhicules, autonome en service rapide et disponible immédiatement, je pense correspondre à ce que recherche votre client.');
    } else if (isConcession) {
      L.push('Votre offre de ' + posteMin + ' chez ' + nom + (ville ? ' à ' + ville : '') + ' a retenu toute mon attention. Travailler en concession' + (marque ? ' sur des véhicules ' + marque : '') + ', avec des méthodes et des outils constructeur, c\'est exactement l\'environnement dans lequel je veux progresser.');
    } else if (isCentre) {
      L.push('Votre offre de ' + posteMin + ' chez ' + nom + (ville ? ' à ' + ville : '') + ' a retenu toute mon attention. Le service rapide, c\'est un travail que je connais et que j\'aime : des interventions bien faites, dans les temps, avec un client qui repart rassuré.');
    } else {
      L.push('Votre offre de ' + posteMin + ' chez ' + nom + (ville ? ' à ' + ville : '') + ' a retenu toute mon attention. Je suis titulaire d\'un CAP Maintenance des véhicules et je suis disponible immédiatement.');
    }
    L.push('');

    // Parcours
    L.push('J\'ai commencé la mécanique par passion, sur mes propres véhicules, pendant un an et demi : vidanges, train avant, disques et plaquettes, berceau, kit embrayage. J\'ai ensuite validé mon CAP Maintenance des véhicules en apprentissage dans un garage spécialisé Range Rover et BMW. Aux côtés du mécanicien, j\'ai participé à des distributions, des décaissages, des déposes moteur, des embrayages et des interventions sur boîte de vitesses. En fin de formation, j\'étais autonome sur le décaissage et la dépose moteur, et j\'ai réalisé seul trois distributions (1.7 CDTI, 1.4 HDi et 3.0 V6).');
    L.push('');

    // Motivation adaptée
    if (isCentre && !isConcession) L.push('Aujourd\'hui, je suis autonome en service rapide (vidange, filtres, freinage, pneus, contrôles) et je sais travailler proprement et efficacement quand l\'atelier est chargé. Je suis à l\'aise avec le contact client et j\'ai envie d\'apprendre encore, notamment en diagnostic.');
    else if (isConcession) L.push('Aujourd\'hui, je suis autonome en service rapide et je souhaite évoluer vers la grosse mécanique et le diagnostic. Rejoindre ' + (agence ? 'une concession' : 'votre équipe') + ', avec ses formations et son suivi, me permettrait de progresser tout en étant utile dès le premier jour sur l\'entretien courant.');
    else L.push('Aujourd\'hui, je suis autonome en service rapide et je souhaite évoluer vers la grosse mécanique et le diagnostic. J\'apprends vite, je suis rigoureux et j\'aime le travail bien fait.');
    L.push('');
    L.push('Motivé, ponctuel et disponible immédiatement, je suis titulaire du permis B. Je serais heureux de vous rencontrer pour un entretien, ou de faire un essai en atelier pour vous montrer ce que je sais faire.');
    L.push('');
    L.push('Je vous prie d\'agréer, Madame, Monsieur, mes salutations distinguées.', '', PROFIL.nom);
    return L.join('\n');
  }

  let sheetCtx = null;
  function ouvrirLettre(kind, id) {
    const item = kind === 'ent' ? DATA.entreprises.find(e => e.id === id) : DATA.offres.find(o => o.id === id);
    if (!item) return;
    const s = kind === 'ent' ? suiviEnt(id) : suiviOffre(id);
    const texte = s.lettre || genererLettre(kind, item);
    sheetCtx = { kind, id, item };
    const titre = kind === 'ent' ? 'Lettre spontanée' : 'Lettre de motivation';
    const sous = kind === 'ent' ? item.nom + ' · ' + item.ville : item.poste + ' — ' + item.entreprise;
    const w = $('#sheet');
    w.innerHTML = '<div class="sheet" role="dialog" aria-modal="true" aria-label="' + titre + '">' +
      '<div class="sheet-head"><div><p class="eyebrow" style="margin:0 0 2px">' + titre + '</p><h2>' + esc(kind === 'ent' ? item.nom : item.entreprise) + '</h2><p>' + esc(sous) + '</p></div>' +
      '<button class="btn btn-quiet close" data-act="fermer" aria-label="Fermer">' + ic('x') + '</button></div>' +
      '<div class="sheet-body"><p style="margin:0 0 12px;color:var(--ink-2);font-size:13.5px">' + ic('pen').replace('class="i"', 'class="i" style="width:14px;height:14px;vertical-align:-2px"') +
      ' Relis-la et modifie ce que tu veux directement dans la feuille. Une phrase perso sur le garage (« je passe souvent devant », « j\'ai vu votre atelier ») fait toujours plaisir.</p>' +
      '<div class="paper"><textarea id="lettre" spellcheck="true">' + esc(texte) + '</textarea></div></div>' +
      '<div class="sheet-foot"><button class="btn btn-primary" data-act="copier">' + ic('copy') + 'Copier</button>' +
      '<button class="btn" data-act="enregistrer">' + ic('save') + 'Enregistrer</button>' +
      '<button class="btn btn-quiet" data-act="regenerer" title="Repartir du modèle">' + ic('refresh') + 'Recommencer</button>' +
      '<span class="spacer"></span><span class="saved-at" id="savedAt">' + (s.lettreDate ? 'Enregistrée le ' + fmtDate(s.lettreDate) : 'Pas encore enregistrée') + '</span></div></div>';
    w.hidden = false;
    const ta = $('#lettre');
    autoSize(ta);
    ta.addEventListener('input', () => autoSize(ta));
    setTimeout(() => ta.focus(), 50);
  }
  function autoSize(ta) { ta.style.height = 'auto'; ta.style.height = Math.max(ta.scrollHeight, 300) + 'px'; }
  function fermerLettre() { $('#sheet').hidden = true; $('#sheet').innerHTML = ''; sheetCtx = null; render(); }

  async function copier(txt) {
    try { await navigator.clipboard.writeText(txt); return true; } catch (_) {
      const t = document.createElement('textarea'); t.value = txt; document.body.appendChild(t); t.select();
      const ok = document.execCommand('copy'); t.remove(); return ok;
    }
  }

  // ================= Événements =================
  function setStatut(kind, id, val) {
    const s = kind === 'ent' ? suiviEnt(id) : suiviOffre(id);
    s.statut = val;
    s.dates = s.dates || {};
    s.dates[val] = today();
    if (kind === 'offre' && val === 'postule' && !s.dateCandidature) s.dateCandidature = today();
    save();
    const msg = {
      postule: 'Candidature notée le ' + fmtDate(today()) + '. Rappel de relance dans 7 jours.',
      envoyee: 'Envoyée le ' + fmtDate(today()) + '. Rappel de relance dans 7 jours.',
      entretien: 'Entretien ! Bravo, prépare-toi bien.',
      ecartee: 'Offre écartée (visible dans le filtre « Écartées »).'
    }[val];
    toast(msg || 'Statut : ' + LABEL[val]);
  }

  function bindPage() {
    const q = $('#q');
    if (q) q.addEventListener('input', () => {
      ui.q = q.value;
      const f = FILTRES.find(x => x[0] === ui.filtre) || [0, 0, FILTRES_CACHES[ui.filtre] ? FILTRES_CACHES[ui.filtre][1] : FILTRES[0][2]];
      $('#list').innerHTML = listeOffres(sortOffres(DATA.offres.filter(f[2]).filter(o => matchQ(o, ui.q))));
    });
    const qe = $('#qEnt');
    if (qe) qe.addEventListener('input', () => {
      ui.qEnt = qe.value;
      const f = FILTRES_ENT.find(x => x[0] === ui.filtreEnt) || FILTRES_ENT[0];
      $('#list').innerHTML = listeEnt(DATA.entreprises.filter(f[2]).filter(e => matchQ(e, ui.qEnt)).sort((a, b) => (+a.km || 99) - (+b.km || 99)));
    });
    const u = $('#urlMaj');
    if (u) u.addEventListener('change', () => { store.reglages.urlMaj = u.value.trim(); save(); toast(u.value.trim() ? 'Adresse enregistrée. Clique sur « Actualiser les offres ».' : 'Adresse effacée : l\'appli lira le fichier local.'); });
    const th = $('#theme');
    if (th) th.addEventListener('change', () => { store.reglages.theme = th.value; save(); applyTheme(); });
    const imp = $('#importFile');
    if (imp) imp.addEventListener('change', async () => {
      const f = imp.files[0]; if (!f) return;
      try {
        const d = JSON.parse(await f.text());
        if (!d || typeof d !== 'object' || (!d.offres && !d.entreprises)) throw new Error('fichier non reconnu');
        if (!confirm('Remplacer tes statuts, notes et lettres actuels par ceux de cette sauvegarde ?')) return;
        localStorage.setItem(KEY, JSON.stringify(d)); store = loadStore(); applyTheme(); render(); toast('Données restaurées');
      } catch (e) { toast('Restauration impossible : ' + e.message); }
    });
    if (isApp && vue === 'profil') window.jobmeca.infos().then(i => {
      const el = $('#infoPath'); if (el) el.innerHTML = 'Fichier des offres : ' + esc(i.dataPath) + '<br>Lettres enregistrées : ' + esc(i.lettersPath) + '<br>Source actuelle : ' + esc(dataSource);
    });
  }

  document.addEventListener('change', e => {
    const sel = e.target.closest('select[data-statut]');
    if (!sel) return;
    setStatut(sel.dataset.statut, sel.dataset.id, sel.value);
    render();
  });

  let noteTimer = null;
  document.addEventListener('input', e => {
    const ta = e.target.closest('textarea[data-note]');
    if (!ta) return;
    const s = ta.dataset.note === 'ent' ? suiviEnt(ta.dataset.id) : suiviOffre(ta.dataset.id);
    s.note = ta.value;
    clearTimeout(noteTimer);
    noteTimer = setTimeout(save, 300);
  });

  document.addEventListener('click', async e => {
    const nav = e.target.closest('[data-vue]');
    if (nav) { go(nav.dataset.vue); return; }
    const gt = e.target.closest('[data-goto]');
    if (gt) { if (gt.dataset.filtre) { ui.filtre = gt.dataset.filtre; ui.q = ''; } go(gt.dataset.goto); return; }
    const ch = e.target.closest('[data-filtre]');
    if (ch) { ui.filtre = ch.dataset.filtre; render(); return; }
    const che = e.target.closest('[data-filtre-ent]');
    if (che) { ui.filtreEnt = che.dataset.filtreEnt; render(); return; }
    if (e.target === $('#sheet')) { fermerLettre(); return; }
    const a = e.target.closest('[data-act]');
    if (!a) return;
    const act = a.dataset.act;
    if (act === 'lien') {
      e.preventDefault();
      const url = a.dataset.url;
      if (isApp) window.jobmeca.ouvrirLien(url); else window.open(url, '_blank', 'noopener');
    } else if (act === 'postuler') {
      const o = DATA.offres.find(x => x.id === a.dataset.id);
      if (!o) return;
      const s = suiviOffre(o.id);
      const lettre = s.lettre || genererLettre('offre', o);
      const ok = await copier(lettre);
      if (!o.lien) { ouvrirLettre('offre', o.id); return; }
      ui.postulEnCours = o.id;
      if (statutOffre(o.id) === 'a_traiter') { s.statut = 'a_postuler'; s.dates = s.dates || {}; s.dates.a_postuler = today(); save(); }
      toast((ok ? 'Lettre copiée. ' : '') + 'Sur l\'annonce : appuie sur « Postuler », ajoute ton CV' + (ok ? ' et colle ta lettre.' : '.'), 6000);
      setTimeout(() => { if (isApp) window.jobmeca.ouvrirLien(o.lien); else window.open(o.lien, '_blank', 'noopener'); }, 350);
    } else if (act === 'postul-oui' || act === 'postul-non') {
      const id = a.dataset.id;
      $('#ask').hidden = true; $('#ask').innerHTML = '';
      if (act === 'postul-oui') { setStatut('offre', id, 'postule'); render(); }
    } else if (act === 'notes') {
      ui.openNotes[a.dataset.id] = true; render();
      const ta = document.querySelector('textarea[data-id="' + CSS.escape(a.dataset.id.replace(/^e:/, '')) + '"]'); if (ta) ta.focus();
    } else if (act === 'lettre') {
      ouvrirLettre(a.dataset.kind, a.dataset.id);
    } else if (act === 'fermer') {
      fermerLettre();
    } else if (act === 'copier') {
      toast(await copier($('#lettre').value) ? 'Lettre copiée. Colle-la (Ctrl+V) dans le formulaire ou ton mail.' : 'Copie impossible : sélectionne le texte et fais Ctrl+C.');
    } else if (act === 'enregistrer' && sheetCtx) {
      const { kind, id, item } = sheetCtx;
      const s = kind === 'ent' ? suiviEnt(id) : suiviOffre(id);
      s.lettre = $('#lettre').value; s.lettreDate = today(); save();
      $('#savedAt').textContent = 'Enregistrée le ' + fmtDate(today());
      if (isApp) {
        const r = await window.jobmeca.enregistrerLettre(kind === 'ent' ? item.nom : item.entreprise + ' - ' + item.poste, s.lettre);
        toast(r.ok ? 'Lettre enregistrée (aussi dans le dossier « lettres »)' : 'Lettre enregistrée dans l\'appli');
      } else toast('Lettre enregistrée');
    } else if (act === 'regenerer' && sheetCtx) {
      if (!confirm('Repartir du modèle ? Tes modifications non enregistrées seront perdues.')) return;
      $('#lettre').value = genererLettre(sheetCtx.kind, sheetCtx.item); autoSize($('#lettre'));
    } else if (act === 'refresh') {
      await refresh(a);
    } else if (act === 'dossier') {
      window.jobmeca.ouvrirDossierLettres();
    } else if (act === 'export') {
      const blob = new Blob([JSON.stringify(store, null, 2)], { type: 'application/json' });
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob); link.download = 'mon-job-meca-sauvegarde-' + today() + '.json';
      document.body.appendChild(link); link.click(); link.remove();
      setTimeout(() => URL.revokeObjectURL(link.href), 2000);
    }
  });

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && sheetCtx) fermerLettre();
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's' && sheetCtx) { e.preventDefault(); const b = document.querySelector('[data-act="enregistrer"]'); if (b) b.click(); }
    if (e.key === 'F5' && !sheetCtx) { e.preventDefault(); refresh(); }
  });

  function demanderSiEnvoye() {
    const id = ui.postulEnCours;
    if (!id || document.hidden) return;
    ui.postulEnCours = null;
    const o = DATA.offres.find(x => x.id === id);
    if (!o || ['postule', 'relance', 'entretien'].includes(statutOffre(id))) return;
    const w = $('#ask');
    w.innerHTML = '<div class="ask-card" role="dialog" aria-modal="true" aria-labelledby="askT">' +
      '<div class="ask-ico">' + ic('send') + '</div>' +
      '<h2 id="askT">Candidature envoyée ?</h2>' +
      '<p>' + esc(o.poste) + '<br><b>' + esc(o.entreprise) + '</b></p>' +
      '<button class="btn btn-primary" data-act="postul-oui" data-id="' + esc(id) + '">Oui, c\'est envoyé</button>' +
      '<button class="btn btn-quiet" data-act="postul-non" data-id="' + esc(id) + '">Pas encore</button></div>';
    w.hidden = false;
  }
  document.addEventListener('visibilitychange', () => setTimeout(demanderSiEnvoye, 400));
  window.addEventListener('focus', () => setTimeout(demanderSiEnvoye, 400));

  async function refresh(btn) {
    const b = btn || $('#btnRefreshSide');
    b.classList.add('spin'); b.disabled = true;
    await loadData(true);
    b.classList.remove('spin'); b.disabled = false;
    if (!sheetCtx) render();
  }

  // ================= Notification =================
  let toastTimer = null;
  function toast(msg, ms) {
    const t = $('#toast'); t.textContent = msg; t.classList.add('show');
    clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('show'), ms || 2800);
  }

  function applyTheme() {
    const t = store.reglages.theme;
    if (t === 'clair' || t === 'sombre') document.documentElement.dataset.theme = t;
    else delete document.documentElement.dataset.theme;
  }

  // ================= Démarrage =================
  async function start() {
    applyTheme();
    const mainEl = $('#main');
    mainEl.addEventListener('scroll', () => {
      document.body.classList.toggle('scrolled', mainEl.scrollTop > 2);
      document.body.classList.toggle('titled', mainEl.scrollTop > 56);
    }, { passive: true });
    $('#btnRefreshSide').innerHTML = ic('refresh') + 'Actualiser les offres';
    $('#btnRefreshSide').addEventListener('click', () => refresh());
    await loadData(false);
    render();
    if (!isApp && 'serviceWorker' in navigator && location.protocol.startsWith('http')) {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    }
  }
  start();
})();
