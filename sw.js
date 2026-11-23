// Service worker : l'appli marche hors connexion, les offres sont prises en ligne en priorité
const CACHE = 'job-meca-v1';
const SHELL = ['./', 'index.html', 'styles.css', 'app.js', 'manifest.json', 'icon-192.png', 'icon-512.png', 'apple-touch-icon.png',
  'fonts/anton.woff', 'fonts/fira-Regular.woff', 'fonts/fira-Italic.woff', 'fonts/fira-Medium.woff', 'fonts/fira-SemiBold.woff', 'fonts/fira-Bold.woff'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(k => Promise.all(k.filter(x => x !== CACHE).map(x => caches.delete(x)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET') return;
  if (url.origin !== location.origin || url.pathname.endsWith('.json')) {
    // Données : réseau d'abord, sinon copie en cache
    e.respondWith(fetch(e.request).then(r => { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); return r; })
      .catch(() => caches.match(e.request, { ignoreSearch: true })));
    return;
  }
  e.respondWith(caches.match(e.request, { ignoreSearch: true }).then(r => r || fetch(e.request)));
});
