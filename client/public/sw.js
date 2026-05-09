const CACHE = 'tsv-editor-v1';

self.addEventListener('install', e => e.waitUntil(self.skipWaiting()));
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.open(CACHE).then(cache =>
      cache.match(e.request).then(cached =>
        cached || fetch(e.request).then(resp => {
          if (resp.ok) cache.put(e.request, resp.clone());
          return resp;
        }).catch(() => cached)
      )
    )
  );
});
