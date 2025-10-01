// BUDDY AI Service Worker for PWA functionality
const CACHE_NAME = 'buddy-ai-v1.0.0';
const STATIC_CACHE = 'buddy-static-v1.0.0';
const DYNAMIC_CACHE = 'buddy-dynamic-v1.0.0';

// Resources to cache immediately
const STATIC_FILES = [
  '/',
  '/static/index.html',
  '/static/css/mobile.css',
  '/static/js/enhanced-gui.js',
  '/static/manifest.json',
  // Add any icon files when available
  '/static/icon-192.png',
  '/static/icon-512.png'
];

// Dynamic resources that should be cached after first access
const DYNAMIC_URLS = [
  '/api/v1/skills',
  '/api/v1/voice/text',
  '/api/v1/voice/audio'
];

// Install event - cache static resources
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');
  
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => {
        console.log('[SW] Caching static files...');
        // Cache only files that exist, don't fail if some are missing
        return Promise.allSettled(
          STATIC_FILES.map(url => 
            cache.add(url).catch(err => {
              console.warn(`[SW] Failed to cache ${url}:`, err);
            })
          )
        );
      })
      .then(() => {
        console.log('[SW] Static files cached successfully');
        return self.skipWaiting(); // Activate immediately
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE) {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('[SW] Service worker activated');
        return self.clients.claim(); // Take control immediately
      })
  );
});

// Fetch event - implement caching strategies
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Handle different types of requests with appropriate strategies
  if (request.method === 'GET') {
    if (isStaticAsset(request.url)) {
      // Cache First strategy for static assets
      event.respondWith(cacheFirst(request));
    } else if (isAPIRequest(request.url)) {
      // Network First strategy for API calls
      event.respondWith(networkFirst(request));
    } else {
      // Stale While Revalidate for pages
      event.respondWith(staleWhileRevalidate(request));
    }
  } else if (request.method === 'POST' && isAPIRequest(request.url)) {
    // Network Only for POST requests, with offline fallback
    event.respondWith(networkOnlyWithFallback(request));
  }
});

// Cache First Strategy - for static assets
function cacheFirst(request) {
  return caches.match(request)
    .then((cachedResponse) => {
      if (cachedResponse) {
        return cachedResponse;
      }
      
      return fetch(request)
        .then((networkResponse) => {
          if (networkResponse.ok) {
            const responseClone = networkResponse.clone();
            caches.open(STATIC_CACHE)
              .then((cache) => cache.put(request, responseClone));
          }
          return networkResponse;
        })
        .catch(() => {
          // Return offline fallback for critical assets
          if (request.url.includes('.html')) {
            return caches.match('/offline.html');
          }
        });
    });
}

// Network First Strategy - for API calls
function networkFirst(request) {
  return fetch(request)
    .then((networkResponse) => {
      if (networkResponse.ok) {
        const responseClone = networkResponse.clone();
        caches.open(DYNAMIC_CACHE)
          .then((cache) => cache.put(request, responseClone));
      }
      return networkResponse;
    })
    .catch(() => {
      return caches.match(request)
        .then((cachedResponse) => {
          if (cachedResponse) {
            return cachedResponse;
          }
          // Return offline API response
          return new Response(
            JSON.stringify({
              error: 'Offline - Please check your connection',
              offline: true
            }),
            {
              status: 503,
              statusText: 'Service Unavailable',
              headers: { 'Content-Type': 'application/json' }
            }
          );
        });
    });
}

// Stale While Revalidate Strategy - for pages
function staleWhileRevalidate(request) {
  return caches.match(request)
    .then((cachedResponse) => {
      const fetchPromise = fetch(request)
        .then((networkResponse) => {
          if (networkResponse.ok) {
            const responseClone = networkResponse.clone();
            caches.open(DYNAMIC_CACHE)
              .then((cache) => cache.put(request, responseClone));
          }
          return networkResponse;
        });
      
      return cachedResponse || fetchPromise;
    });
}

// Network Only with Fallback - for POST requests
function networkOnlyWithFallback(request) {
  return fetch(request)
    .catch(() => {
      // Store failed requests for retry when online
      return storeFailedRequest(request)
        .then(() => {
          return new Response(
            JSON.stringify({
              error: 'Request queued for when connection is restored',
              queued: true
            }),
            {
              status: 202,
              statusText: 'Accepted',
              headers: { 'Content-Type': 'application/json' }
            }
          );
        });
    });
}

// Helper functions
function isStaticAsset(url) {
  return url.includes('/static/') || 
         url.endsWith('.css') || 
         url.endsWith('.js') || 
         url.endsWith('.png') || 
         url.endsWith('.jpg') ||
         url.endsWith('.ico') ||
         url.endsWith('.woff') ||
         url.endsWith('.woff2');
}

function isAPIRequest(url) {
  return url.includes('/api/');
}

function storeFailedRequest(request) {
  return request.clone().text()
    .then((body) => {
      const failedRequest = {
        url: request.url,
        method: request.method,
        headers: Object.fromEntries(request.headers.entries()),
        body: body,
        timestamp: Date.now()
      };
      
      return caches.open('failed-requests')
        .then((cache) => {
          return cache.put(
            `failed-${Date.now()}`,
            new Response(JSON.stringify(failedRequest))
          );
        });
    });
}

// Background sync for failed requests
self.addEventListener('sync', (event) => {
  if (event.tag === 'retry-failed-requests') {
    event.waitUntil(retryFailedRequests());
  }
});

function retryFailedRequests() {
  return caches.open('failed-requests')
    .then((cache) => {
      return cache.keys();
    })
    .then((keys) => {
      return Promise.all(
        keys.map((key) => {
          return caches.match(key)
            .then((response) => response.json())
            .then((failedRequest) => {
              return fetch(failedRequest.url, {
                method: failedRequest.method,
                headers: failedRequest.headers,
                body: failedRequest.body
              });
            })
            .then(() => {
              return caches.open('failed-requests')
                .then((cache) => cache.delete(key));
            })
            .catch((error) => {
              console.log('[SW] Failed to retry request:', error);
            });
        })
      );
    });
}

// Push notification handling
self.addEventListener('push', (event) => {
  if (event.data) {
    const data = event.data.json();
    const options = {
      body: data.body || 'You have a new message from BUDDY',
      icon: '/static/icon-192.png',
      badge: '/static/badge-72.png',
      vibrate: [200, 100, 200],
      tag: 'buddy-notification',
      actions: [
        {
          action: 'open',
          title: 'Open BUDDY',
          icon: '/static/icon-96.png'
        },
        {
          action: 'dismiss',
          title: 'Dismiss',
          icon: '/static/icon-96.png'
        }
      ]
    };
    
    event.waitUntil(
      self.registration.showNotification(data.title || 'BUDDY AI', options)
    );
  }
});

// Notification click handling
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  if (event.action === 'open') {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

// Message handling from main thread
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(DYNAMIC_CACHE)
        .then((cache) => {
          return cache.addAll(event.data.payload);
        })
    );
  }
});

console.log('[SW] BUDDY AI Service Worker loaded successfully');