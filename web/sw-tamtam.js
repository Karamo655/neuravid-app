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
  e.respondWith(copieVerifiee(r, NV_ACCUEIL_CACHE, piece, piece)); });
function reseauPuisCopie(req, nom, cle, frais){ return new Promise(function(ok){ var fini = false, garde = null;
  function servir(x){ if(!fini && x){ fini = true; ok(x); } }
  caches.open(nom).then(function(c){ return c.match(cle); }).then(function(m){ garde = m || null; }).catch(function(){});
  var minuteur = setTimeout(function(){ if(garde) servir(garde.clone()); }, 4000);
  /* « frais » : la carte des versions annonce un fichier changé, on redemande au site sans la copie du navigateur (une réponse 304 si rien n'a bougé) */
  var dem = frais ? fetch(req.url, {cache:'no-cache', credentials:'same-origin'}).then(function(rep){ return rep.redirected ? fetch(req) : rep; }) : fetch(req);
  dem.then(function(rep){ clearTimeout(minuteur); if(rep && rep.ok && rep.type === 'basic' && !rep.redirected) garder(nom, cle, rep); servir(rep); })
    .catch(function(){ clearTimeout(minuteur); caches.open(nom).then(function(c){ return c.match(cle); }).then(function(m){ servir(m || Response.error()); }, function(){ servir(Response.error()); }); }); }); }

/* ── Les autres pages (4 novembre 2026, la vitesse) : chaque module ouvert (NV_MODULE_*.html, index.html, demo.html) est gardé
   par le téléphone. Même règle : réseau d'abord (chaque mise à jour arrive directement), la copie seulement si le réseau
   ne répond pas en 4 secondes ou s'il est coupé. Jamais l'API, ni les vidéos, ni nv-config.js. L'accueil garde sa règle ci-dessus. */
var NV_PAGES_CACHE = 'nv-pages-1';
self.addEventListener('fetch', function(e){ var r = e.request, u; try{ u = new URL(r.url); }catch(x){ return; }
  if(r.method !== 'GET' || u.origin !== self.location.origin || /\/v1\//.test(u.pathname)) return;
  if(NV_ACCUEIL.some(function(p){ return u.pathname.slice(-p.length) === p; })) return;      /* l'accueil : son propre écouteur */
  if(!/(^|\/)(NV_MODULE_[A-Za-z_]+\.html|index\.html|demo\.html)$/.test(u.pathname)) return;
  var cle = u.origin + u.pathname; e.respondWith(copieVerifiee(r, NV_PAGES_CACHE, cle, nomFichier(u)));
  /* Le Direct et la Salle Baobab prennent leurs images de cadeaux dans cadeaux3d/ : on les garde toutes une fois (bon réseau seulement),
     pour qu'aucune ne manque ensuite, même sans réseau */
  if(/NV_MODULE_(Live|Baobab)(_leger)?\.html$/.test(u.pathname)) garderCadeaux(); });

/* ── La copie VÉRIFIÉE (14 novembre 2026, la vitesse) ──
   Chaque page gardée porte l'empreinte SHA-256 de ses octets (X-NV-Sha). Le site publie version.json : l'empreinte de chaque fichier.
   Si l'empreinte de la copie est celle du site, la copie EST la version en ligne, octet pour octet : elle s'ouvre tout de suite,
   sans attendre le réseau. Sinon (nouvelle version, ou carte inconnue), on fait comme avant : réseau d'abord, la copie après 4 s ou sans réseau.
   La carte (quelques Ko) est relue au plus toutes les minutes ; plus vieille que 5 minutes, on la redemande d'abord (1,5 s au plus).
   Sur un bon réseau (4G ou Wi-Fi, jamais en économie de données), les pages déjà gardées qui ont changé sont remises à jour en arrière-plan,
   12 au plus : la prochaine ouverture est aussi immédiate. Les images 3D des cadeaux (cadeaux3d/) suivent la même règle. */
var NV_CARTE_CACHE = 'nv-carte-1', NV_IMAGES_CACHE = 'nv-images-1', CARTE = {f:null, lu:0, prom:null}, CARTE_FRAICHE = 5 * 60000, CARTE_RELIRE = 60000, MAJ_EN_COURS = false;
function nomFichier(u){ var s = new URL(self.registration.scope).pathname, p = u.pathname; if(p.indexOf(s) !== 0) return null; try{ return decodeURIComponent(p.slice(s.length)) || 'index.html'; }catch(e){ return null; } }
function shaDe(buf){ return crypto.subtle.digest('SHA-256', buf).then(function(h){ return Array.prototype.map.call(new Uint8Array(h), function(b){ return (b < 16 ? '0' : '') + b.toString(16); }).join(''); }); }
function garder(nom, cle, rep){ var h = new Headers(rep.headers), st = rep.status, tx = rep.statusText;
  return rep.clone().arrayBuffer().then(function(buf){ return shaDe(buf).then(function(sha){ h.set('X-NV-Sha', sha); h.delete('Content-Encoding'); h.delete('Content-Length');
    return caches.open(nom).then(function(c){ return c.put(cle, new Response(buf, {status:st, statusText:tx, headers:h})); }); }); }).catch(function(){}); }
function carteGardee(){ if(CARTE.f) return Promise.resolve(CARTE);
  return caches.open(NV_CARTE_CACHE).then(function(c){ return c.match('carte'); }).then(function(r){ return r ? r.json() : null; })
    .then(function(j){ if(j && j.f && !CARTE.f){ CARTE.f = j.f; CARTE.lu = +j.lu || 0; } return CARTE; }).catch(function(){ return CARTE; }); }
function lireCarte(){ if(CARTE.prom) return CARTE.prom;
  CARTE.prom = fetch(new URL('version.json', self.registration.scope).href, {cache:'no-cache', credentials:'same-origin'})
    .then(function(r){ if(!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(j){ var f = {}; if(j && j.fichiers && typeof j.fichiers === 'object') Object.keys(j.fichiers).forEach(function(k){ var x = j.fichiers[k]; if(x && typeof x.sha256 === 'string') f[k] = x.sha256; });
      if(!Object.keys(f).length) return CARTE;
      CARTE.f = f; CARTE.lu = Date.now();
      caches.open(NV_CARTE_CACHE).then(function(c){ return c.put('carte', new Response(JSON.stringify({f:f, lu:CARTE.lu}), {headers:{'Content-Type':'application/json'}})); }).catch(function(){});
      majEnArrierePlan(f); return CARTE; })
    .catch(function(){ return CARTE; }).then(function(x){ CARTE.prom = null; return x; });
  return CARTE.prom; }
function auPlus(p, ms){ return Promise.race([p, new Promise(function(ok){ setTimeout(ok, ms); })]); }
function copieVerifiee(req, nom, cle, fichier){
  return Promise.all([caches.open(nom).then(function(c){ return c.match(cle); }).catch(function(){ return null; }), carteGardee()]).then(function(r){
    var garde = r[0], sha = garde && garde.headers.get('X-NV-Sha');
    function juste(){ return !!(sha && fichier && CARTE.f && CARTE.f[fichier] === sha); }
    if(!sha){ lireCarte(); return reseauPuisCopie(req, nom, cle); }
    var age = Date.now() - CARTE.lu;
    if(juste() && age < CARTE_FRAICHE){ if(age > CARTE_RELIRE) lireCarte(); return garde; }
    return auPlus(lireCarte(), 1500).then(function(){ return juste() ? garde : reseauPuisCopie(req, nom, cle, true); });
  }).catch(function(){ return reseauPuisCopie(req, nom, cle); }); }
function bonReseau(){ var c = self.navigator && self.navigator.connection; if(!c) return true; if(c.saveData) return false; return !c.effectiveType || c.effectiveType === '4g'; }
function majEnArrierePlan(f){ if(MAJ_EN_COURS || !bonReseau()) return; MAJ_EN_COURS = true; var travaux = [];
  /* quelques secondes d'abord : la page qu'on ouvre garde tout le réseau pour elle */
  new Promise(function(ok){ setTimeout(ok, 6000); }).then(function(){ return Promise.all([NV_ACCUEIL_CACHE, NV_PAGES_CACHE].map(function(nom){ return caches.open(nom).then(function(c){ return c.keys().then(function(ks){ return Promise.all(ks.map(function(k){ return c.match(k).then(function(rep){
    var fi = nomFichier(new URL(k.url)); if(fi && f[fi] && rep && rep.headers.get('X-NV-Sha') !== f[fi]) travaux.push({nom:nom, cle:k, url:k.url}); }); })); }); }); })); })
  .then(function(){ return travaux.slice(0, 12).reduce(function(p, t){ return p.then(function(){ return fetch(t.url, {cache:'no-cache', credentials:'same-origin'})
      .then(function(rep){ if(rep.ok && rep.type === 'basic' && !rep.redirected) return garder(t.nom, t.cle, rep); }).catch(function(){}); }); }, Promise.resolve()); })
  .catch(function(){}).then(function(){ MAJ_EN_COURS = false; }); }
self.addEventListener('fetch', function(e){ var r = e.request, u; try{ u = new URL(r.url); }catch(x){ return; }
  if(r.method !== 'GET' || u.origin !== self.location.origin || !/\/cadeaux3d\/[0-9a-f_-]+\.webp$/i.test(u.pathname)) return;
  e.respondWith(copieVerifiee(r, NV_IMAGES_CACHE, u.origin + u.pathname, nomFichier(u))); });
/* une page (ou un essai) peut demander de relire la carte tout de suite : {type:'nv_carte_relire'} */
self.addEventListener('message', function(e){ var m = e.data || {}; if(m.type === 'nv_carte_relire'){ CARTE.lu = 0; e.waitUntil(lireCarte()); } });
/* les images 3D des cadeaux, gardées toutes une fois par le téléphone (14 nov. 2026) : seulement sur un bon réseau, 12 s après l'ouverture,
   une à la fois, seulement celles qui manquent ou qui ont changé (empreinte de version.json) */
var CADEAUX_FAIT = false;
function garderCadeaux(){ if(CADEAUX_FAIT || !bonReseau()) return; CADEAUX_FAIT = true;
  new Promise(function(ok){ setTimeout(ok, 12000); }).then(function(){ return carteGardee(); }).then(function(){ return CARTE.f ? CARTE : lireCarte(); }).then(function(){
    var f = CARTE.f || {}, l = Object.keys(f).filter(function(k){ return /^cadeaux3d\/[0-9a-f_-]+\.webp$/i.test(k); });
    return caches.open(NV_IMAGES_CACHE).then(function(c){ return l.reduce(function(p, k){ return p.then(function(){ if(!bonReseau()) return;
      var url = new URL(k, self.registration.scope).href;
      return c.match(url).then(function(m){ if(m && m.headers.get('X-NV-Sha') === f[k]) return;
        return fetch(url, {credentials:'same-origin'}).then(function(rep){ if(rep.ok && rep.type === 'basic' && !rep.redirected) return garder(NV_IMAGES_CACHE, url, rep); }).catch(function(){}); }); }); }, Promise.resolve()); }); })
  .catch(function(){}).then(function(){ /* réessayé à la prochaine vie du service si le réseau a manqué */ }); }
