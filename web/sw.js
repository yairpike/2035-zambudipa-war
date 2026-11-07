const CACHE = "shattered-monsoon-v3";

// The page, the engine, and the pack. Missing files are skipped so one
// absent icon does not abort install.
const SHELL = [
  "./",
  "./index.html",
  "./index.js",
  "./index.wasm",
  "./index.pck",
  "./index.audio.worklet.js",
  "./index.audio.position.worklet.js",
  "./index.offline.html",
  "./index.icon.png",
  "./index.apple-touch-icon.png",
  "./index.144x144.png",
  "./index.180x180.png",
  "./index.512x512.png",
  "./index.png",
  "./manifest.webmanifest",
  "./index.manifest.json",
  "./audio_unlock.js",
  "./favicon.ico",
];

self.addEventListener("install", (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      Promise.all(SHELL.map((url) => cache.add(url).catch(() => undefined)))
    )
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))
    ).then(() => self.clients.claim())
  );
});

function sameOrigin(url) {
  return url.origin === self.location.origin;
}

function isRuntimeAsset(url) {
  const path = url.pathname;
  return path.includes("/models/") || path.includes("/audio/");
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") {
    return;
  }
  const url = new URL(request.url);
  if (!sameOrigin(url) || url.pathname.endsWith("/sw.js")) {
    return;
  }
  if (request.headers.get("range")) {
    return;
  }
  if (isRuntimeAsset(url)) {
    event.respondWith(networkThenCache(request));
    return;
  }
  event.respondWith(cacheThenNetwork(request));
});

async function networkThenCache(request) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request);
    if (response && response.ok && response.status === 200) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (err) {
    const hit = await cache.match(request);
    if (hit) {
      return hit;
    }
    throw err;
  }
}

async function cacheThenNetwork(request) {
  const cache = await caches.open(CACHE);
  const hit = await cache.match(request, { ignoreSearch: true });
  if (hit) {
    return hit;
  }
  try {
    const response = await fetch(request);
    if (response && response.ok && response.status === 200) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (err) {
    const page = await cache.match("./index.html");
    if (page) {
      return page;
    }
    throw err;
  }
}
