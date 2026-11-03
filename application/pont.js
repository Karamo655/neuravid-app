/* NEURAVID — le pont de l'application officielle (posé au tout début de chaque page, avant les modules).
   Une vue web d'application ne sait pas faire seule ce qu'un navigateur fait : ouvrir un module par NVLien, enregistrer
   un fichier (« blob: »), partager, ouvrir une nouvelle fenêtre. Ce pont le confie à l'application (application/lib/pont.dart).
   Il ne pose JAMAIS NV_APERCU ni de fausses données. Essayé hors téléphone par application/test/pont.test.js. */
(function(){
  if(window.__nvPont) return; window.__nvPont = true;
  function appel(nom, donnees){
    var f = window.flutter_inappwebview;
    if(f && typeof f.callHandler === 'function') return Promise.resolve(f.callHandler(nom, donnees));
    return Promise.reject(new Error('pont'));
  }
  var FICHIERS = {Player:'Iris'};
  function base(){ var b = window.NV_MODULES_BASE || ''; if(b && b.slice(-1) !== '/') b += '/'; return b; }

  /* 1. Ouvrir un module : les modules appellent d'abord window.NVLien.ouvrir('NV<id>', contexte) */
  if(!window.NVLien) window.NVLien = {
    ouvrir: function(cible, ctx){
      var id = String(cible || '').replace(/^NV(?=[A-Z])/, '');
      if(!/^[A-Za-z_]{2,40}$/.test(id)) return false;
      if(ctx){ try{ sessionStorage.setItem('nv_ctx_' + id, JSON.stringify(ctx)); }catch(e){ /* rien */ } }
      try{ localStorage.setItem('nv_retour', JSON.stringify({de:null, vers:id, at:Date.now()})); }catch(e){ /* rien */ }
      location.href = base() + 'NV_MODULE_' + (FICHIERS[id] || id) + '.html';
      return true;
    }
  };

  /* 2. Enregistrer un fichier sur le téléphone : par morceaux de 2 Mo vers l'application, qui les assemble */
  if(typeof window.NVTelecharger !== 'function') window.NVTelecharger = function(blob, nom){
    var T = 2097152, total = Math.max(1, Math.ceil((blob && blob.size || 0) / T)), k = 0;
    var id = 'f' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
    return new Promise(function(ok, ko){
      (function suite(){
        var fr = new FileReader();
        fr.onload = function(){
          appel('nvEnregistrer', {id:id, nom:String(nom || 'NEURAVID'), type:blob.type || '', partie:k, total:total, base64:String(fr.result || '').split(',')[1] || ''})
            .then(function(r){ k++; if(k >= total) ok(r); else suite(); }, ko);
        };
        fr.onerror = function(){ ko(fr.error); };
        fr.readAsDataURL(blob.slice(k * T, (k + 1) * T));
      })();
    });
  };
  /* un lien <a download> vers un « blob: » ou un « data: » (La Forge « Garder », l'agenda des événements…) */
  function parAncre(a){
    var h = a && a.getAttribute && a.getAttribute('href') || '';
    if(!a.hasAttribute('download') || !/^(blob:|data:)/.test(h)) return false;
    var nom = a.getAttribute('download') || 'NEURAVID';
    fetch(h).then(function(r){ return r.blob(); }).then(function(b){ return window.NVTelecharger(b, nom); }).catch(function(){ /* l'application affiche l'échec */ });
    return true;
  }
  var clicOrigine = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function(){ if(parAncre(this)) return; return clicOrigine.apply(this, arguments); };
  document.addEventListener('click', function(e){
    var a = e.target && e.target.closest && e.target.closest('a[download]');
    if(a && parAncre(a)) e.preventDefault();
  }, true);

  /* 3. Partager : la feuille de partage du téléphone (la vue web d'Android n'a pas navigator.share) */
  if(!navigator.share){
    try{
      navigator.share = function(d){
        d = d || {};
        if(d.files && d.files.length) return Promise.reject(new DOMException('Partage de fichiers', 'NotSupportedError'));
        return appel('nvPartager', {titre:d.title || '', texte:d.text || '', lien:d.url || ''}).then(function(){ return undefined; });
      };
    }catch(e){ /* rien */ }
  }

  /* 4. Une nouvelle fenêtre : l'application décide (NEURAVID dans l'application, le reste dans le navigateur) */
  window.open = function(u){
    if(u){ try{ appel('nvOuvrirLien', {url:String(new URL(String(u), location.href))}); }catch(e){ /* rien */ } }
    return null;
  };
})();
