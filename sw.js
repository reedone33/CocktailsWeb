/* ===========================================================================
   Service worker for Last Call.
   ---------------------------------------------------------------------------
   Its whole job is to make the app work with no signal. It keeps a copy of
   every file in the browser's cache, so opening the app on a plane still
   shows your bar.

   CACHE_VERSION is rewritten by update.command on every publish. Changing it
   is what tells the phone "there is new data, stop serving the old copy" -
   without it, iOS would happily show last month's numbers forever.
   =========================================================================== */

const CACHE_VERSION = "lastcall-20260906-1036";      // rewritten automatically on publish
const FILES = [
  "./",
  "./index.html",
  "./cocktails.json",
  "./vendor/chart.umd.js",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png"
];

/* On install: download everything up front so the first offline open works. */
self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then(cache => cache.addAll(FILES))
      .then(() => self.skipWaiting())        // don't wait for old tabs to close
  );
});

/* On activate: throw away caches from previous versions, so old data can't
   linger and reappear. */
self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(names => Promise.all(
        names.filter(n => n !== CACHE_VERSION).map(n => caches.delete(n))
      ))
      .then(() => self.clients.claim())
  );
});

/* On every request: try the network first so a fresh publish is picked up
   promptly, and fall back to the cached copy when there is no signal.
   (Cache-first would be faster but would show stale numbers after a refresh,
   which is the exact complaint this is meant to avoid.) */
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;
  event.respondWith(
    fetch(event.request)
      .then(response => {
        const copy = response.clone();
        caches.open(CACHE_VERSION).then(cache => cache.put(event.request, copy));
        return response;
      })
      .catch(() => caches.match(event.request).then(hit => hit || caches.match("./index.html")))
  );
});
