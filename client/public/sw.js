// v2: 画面(HTML)は毎回ネットから取り直す（オフライン時だけ保存分を使う）。
// v1 は保存分を優先していたため、一度開いた人には更新が届かなかった。
const CACHE = 'tsv-editor-v2';

self.addEventListener('install', e => e.waitUntil(self.skipWaiting()));
self.addEventListener('activate', e => e.waitUntil(
  caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim())
));

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    fetch(e.request).then(resp => {
      if (resp.ok) {
        const copy = resp.clone();
        caches.open(CACHE).then(cache => cache.put(e.request, copy));
      }
      return resp;
    }).catch(() => caches.match(e.request))
  );
});
