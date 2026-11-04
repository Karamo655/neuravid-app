/* NEURAVID — Le Tam-tam : le Service Worker (à servir à la RACINE du site, à côté des modules).
   Un Service Worker est forcément un fichier séparé (règle des navigateurs) : c'est la seule exception au « un module = un fichier ».
   Rôles :
   1. push            → montrer la notification du téléphone (titre, texte, icône) même application fermée ;
   2. notificationclick → ouvrir (ou ramener devant) Le Tam-tam sur cette nouvelle ;
   3. sync 'tamtam-lu' → envoyer les « lu » gardés pendant une coupure de réseau, dès qu'il revient (une file par compte).
   Le serveur envoie dans le push un JSON : {id, titre, texte, icone?, module?, at?, pouls?:{n, niveau, raisons, compte}}, déjà filtré par les réglages, les heures calmes et le contrat de silence de la personne. */
'use strict';
var PAGE = 'NV_MODULE_Notifications.html';
self.addEventListener('install', function(){ self.skipWaiting(); });
self.addEventListener('activate', function(e){ e.waitUntil(self.clients.claim()); });

function propre(s, max){ return typeof s === 'string' ? s.replace(/[<>]/g, '').slice(0, max) : ''; }
self.addEventListener('push', function(e){
  var d = {}; try{ d = e.data ? e.data.json() : {}; }catch(x){ d = {}; }
  var titre = propre(d.titre, 80), texte = propre(d.texte, 240), id = propre(d.id, 80);
  /* un push doit toujours montrer quelque chose (sinon le navigateur affiche son propre message, puis retire l'abonnement) :
     le serveur n'envoie jamais de push vide ; s'il le faisait, on montre seulement « NEURAVID », sans rien inventer */
  /* le pouls (si le serveur le joint : d.pouls = {n, niveau, raisons, compte}) est relayé aux pages ouvertes : la cloche bat tout de suite */
  var relais = d.pouls && typeof d.pouls === 'object' && typeof d.pouls.n === 'number' ? self.clients.matchAll({type:'window', includeUncontrolled:true}).then(function(l){ l.forEach(function(c){ c.postMessage({type:'nv_pouls', pouls:d.pouls}); }); }) : Promise.resolve();
  e.waitUntil(Promise.all([relais, self.registration.showNotification(titre || 'NEURAVID', {
    body:texte, tag:id ? 'tt-' + id : undefined, renotify:false,
    icon:/^https:\/\//.test(d.icone || '') ? d.icone : undefined,
    data:{id:id}, timestamp:typeof d.at === 'number' ? d.at : Date.now()
  })]));
});
self.addEventListener('notificationclick', function(e){
  e.notification.close();
  var id = e.notification.data && e.notification.data.id, url = new URL(PAGE + (id ? '#id=' + encodeURIComponent(id) : ''), self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({type:'window', includeUncontrolled:true}).then(function(l){
    for(var i = 0; i < l.length; i++){ if(l[i].url.indexOf(PAGE) >= 0 && 'focus' in l[i]){ l[i].postMessage({type:'tamtam_ouvrir', id:id}); return l[i].focus(); } }
    return self.clients.openWindow(url);
  }));
});

/* la file des « lu » hors ligne : une entrée PAR COMPTE (ses identifiants et son jeton), vidée dès l'envoi réussi,
   effacée au changement de compte (message « tamtam_vider »). Chaque lecture-écriture se fait dans UNE transaction. */
function base(){ return new Promise(function(ok, ko){ var r = indexedDB.open('nv_tamtam_sw', 2); r.onupgradeneeded = function(){ var d = r.result; if(d.objectStoreNames.contains('lus')) d.deleteObjectStore('lus'); d.createObjectStore('lus'); }; r.onsuccess = function(){ ok(r.result); }; r.onerror = function(){ ko(r.error); }; }); }
/* modifier une entrée dans une seule transaction (rien ne se perd entre une lecture et une écriture) */
function changer(compte, f){ return base().then(function(db){ return new Promise(function(ok){ var t = db.transaction('lus', 'readwrite'), st = t.objectStore('lus'), q = st.get(compte);
  q.onsuccess = function(){ var v = f(q.result || null); if(v) st.put(v, compte); else st.delete(compte); }; t.oncomplete = ok; t.onerror = ok; t.onabort = ok; }); }); }
function toutes(){ return base().then(function(db){ return new Promise(function(ok){ var out = [], q = db.transaction('lus').objectStore('lus').openCursor(); q.onsuccess = function(){ var c = q.result; if(!c) return ok(out); out.push({compte:c.key, v:c.value}); c.continue(); }; q.onerror = function(){ ok(out); }; }); }); }
function vider(){ return base().then(function(db){ return new Promise(function(ok){ var t = db.transaction('lus', 'readwrite'); t.objectStore('lus').clear(); t.oncomplete = ok; t.onerror = ok; }); }); }
self.addEventListener('message', function(e){
  var m = e.data || {};
  if(m.type === 'tamtam_vider'){ e.waitUntil(vider()); return; }
  if(m.type !== 'tamtam_lus' || !/^https:\/\//.test(m.api || '') || !Array.isArray(m.ids) || typeof m.compte !== 'string' || !m.compte) return;
  e.waitUntil(changer(m.compte, function(f){ f = f && f.api === m.api ? f : {api:m.api, ids:[]}; f.token = m.token || ''; m.ids.forEach(function(id){ if(typeof id === 'string' && f.ids.indexOf(id) < 0) f.ids.push(id); }); f.ids = f.ids.slice(-2000); return f; }));
});
function envoyer(x){ var f = x.v; if(!f || !f.ids || !f.ids.length) return Promise.resolve(); var lot = f.ids.slice(0, 500);
  return fetch(f.api + '/v1/notifications/lu', {method:'POST', mode:'cors', headers:Object.assign({'Content-Type':'application/json'}, f.token ? {Authorization:'Bearer ' + f.token} : {}), body:JSON.stringify({ids:lot})})
    .then(function(r){
      /* envoyé, ou refusé pour de bon (400, 403, 404) : ces identifiants sortent de la file ; 401 : le jeton est périmé, on l'oublie et on attend que la page en donne un nouveau */
      if(r.ok || r.status === 400 || r.status === 403 || r.status === 404) return changer(x.compte, function(g){ if(!g) return null; g.ids = g.ids.filter(function(id){ return lot.indexOf(id) < 0; }); return g.ids.length ? g : null; });
      if(r.status === 401) return changer(x.compte, function(g){ if(g) g.token = ''; return g; });
      throw new Error('HTTP ' + r.status);   /* 429, 5xx : le navigateur réessaiera plus tard */
    }); }
self.addEventListener('sync', function(e){
  if(e.tag !== 'tamtam-lu') return;
  e.waitUntil(toutes().then(function(l){ return Promise.all(l.filter(function(x){ return x.v && x.v.token; }).map(envoyer)); }));
});

/* ── L'accueil installable (même service, une seule portée : deux services sur la même portée se remplaceraient) ──
   On garde une copie de l'accueil (et de son manifeste, de ses icônes) pour l'ouvrir sans réseau. Réseau d'abord.
   Jamais les réponses du serveur (/v1/…). Sans réseau, seule une ouverture de l'accueil reçoit la copie de l'accueil. */
var NV_ACCUEIL_CACHE = 'nv-accueil-1', NV_ACCUEIL = ['NV_MODULE_Home.html', 'nv-accueil.webmanifest', 'icones/nv-192.png', 'icones/nv-512.png'];
self.addEventListener('install', function(e){ e.waitUntil(caches.open(NV_ACCUEIL_CACHE).then(function(c){ return Promise.all(NV_ACCUEIL.map(function(p){ return c.add(p).catch(function(){ /* une pièce manque : on garde le reste */ }); })); })); });
self.addEventListener('activate', function(e){ e.waitUntil(caches.keys().then(function(l){ return Promise.all(l.filter(function(k){ return k.indexOf('nv-accueil-') === 0 && k !== NV_ACCUEIL_CACHE; }).map(function(k){ return caches.delete(k); })); })); });
self.addEventListener('fetch', function(e){ var r = e.request, u = new URL(r.url);
  if(r.method !== 'GET' || u.origin !== self.location.origin || /\/v1\//.test(u.pathname)) return;
  var piece = NV_ACCUEIL.filter(function(p){ return u.pathname.slice(-p.length) === p; })[0]; if(!piece) return;
  /* 4 nov. 2026 : sur un réseau très lent, la copie gardée s'ouvre après 4 secondes d'attente (le réseau reste demandé en premier) */
  e.respondWith(reseauPuisCopie(r, NV_ACCUEIL_CACHE, piece)); });
function reseauPuisCopie(req, nom, cle){ return new Promise(function(ok){ var fini = false, garde = null;
  function servir(x){ if(!fini && x){ fini = true; ok(x); } }
  caches.open(nom).then(function(c){ return c.match(cle); }).then(function(m){ garde = m || null; }).catch(function(){});
  var minuteur = setTimeout(function(){ if(garde) servir(garde.clone()); }, 4000);
  fetch(req).then(function(rep){ clearTimeout(minuteur); if(rep && rep.ok && rep.type === 'basic'){ var cp = rep.clone(); caches.open(nom).then(function(c){ return c.put(cle, cp); }).catch(function(){}); } servir(rep); })
    .catch(function(){ clearTimeout(minuteur); caches.open(nom).then(function(c){ return c.match(cle); }).then(function(m){ servir(m || Response.error()); }, function(){ servir(Response.error()); }); }); }); }

/* ── Les autres pages (4 novembre 2026, la vitesse) : chaque module ouvert (NV_MODULE_*.html, index.html, demo.html) est gardé
   par le téléphone. Même règle : réseau d'abord (chaque mise à jour arrive directement), la copie seulement si le réseau
   ne répond pas en 4 secondes ou s'il est coupé. Jamais l'API, ni les vidéos, ni nv-config.js. L'accueil garde sa règle ci-dessus. */
var NV_PAGES_CACHE = 'nv-pages-1';
self.addEventListener('fetch', function(e){ var r = e.request, u; try{ u = new URL(r.url); }catch(x){ return; }
  if(r.method !== 'GET' || u.origin !== self.location.origin || /\/v1\//.test(u.pathname)) return;
  if(NV_ACCUEIL.some(function(p){ return u.pathname.slice(-p.length) === p; })) return;      /* l'accueil : son propre écouteur */
  if(!/(^|\/)(NV_MODULE_[A-Za-z_]+\.html|index\.html|demo\.html)$/.test(u.pathname)) return;
  var cle = u.origin + u.pathname; e.respondWith(reseauPuisCopie(r, NV_PAGES_CACHE, cle)); });
