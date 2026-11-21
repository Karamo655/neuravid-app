/* NEURAVID — la configuration unique de déploiement.
   Chargée tout en haut de chaque module (<script src="nv-config.js">), avant tout le reste.
   C'est le SEUL fichier qui change d'un déploiement à l'autre : les modules, eux, restent identiques partout
   (démonstration, site web, application).

   - Démonstration (artifact) : laisser « api » vide. Les modules restent en démonstration dans le navigateur.
   - Site web et application : mettre l'adresse du serveur NEURAVID, par exemple 'https://api.neuravid.com'.
     Dès qu'elle est posée, chaque module passe en réel et la démonstration ne peut plus s'allumer.
   - L'application peut aussi poser window.NV_API_BASE / NV_TOKEN / NV_USER / NV_LANG avant le chargement
     de la page (script injecté au démarrage du document) : ce fichier ne remplace jamais une valeur déjà posée. */
(function(){
  var CONFIG = {
    api: 'https://api.neuravid.com',   /* 18 nov. 2026 : le site et l'application parlent au vrai serveur (essai réussi de Karamo). Sans « / » final. */
    avatarOrigines: [],      /* origines autorisées pour les photos des créateurs (ex. 'https://cdn.neuravid.com') */
    iaServeur: '',           /* serveur d'IA (idées de défis de La Ruche : POST /v1/ia/idees-defi). Vide = les idées du guide de chaque défi. */
    modules: './',           /* où sont les autres modules : './' = à côté de cette page (site web). L'application peut poser NV_MODULES_BASE elle-même. */
    essai: 'https://api.neuravid.com'                /* 15 nov. 2026 — le mode essai des testeurs : l'adresse du VRAI serveur, utilisée seulement par les téléphones
                                branchés depuis essai.html (localStorage « nv_essai_api »), tant que « api » est vide. Jamais une autre adresse. */
  };
  /* le mode essai : seulement si « api » est vide, jamais dans l'aperçu, et seulement pour l'adresse écrite ici */
  var apercuTot = false;
  try{ apercuTot = !!window.NV_APERCU || /(^#|&)demo(=1)?(&|$)/.test(location.hash || '') || (sessionStorage.getItem('nv_demo') === '1' && !CONFIG.api); }catch(e){ /* rien */ }
  try{
    window.NV_ESSAI_ADRESSE = (!CONFIG.api && CONFIG.essai) ? CONFIG.essai : '';
    var choisi = localStorage.getItem('nv_essai_api');
    window.NV_ESSAI_ACTIF = !!(choisi && window.NV_ESSAI_ADRESSE && choisi === window.NV_ESSAI_ADRESSE && !apercuTot);
    if(window.NV_ESSAI_ACTIF && !window.NV_API_BASE) window.NV_API_BASE = window.NV_ESSAI_ADRESSE;
    /* un ancien choix qui ne correspond plus à rien (adresse changée, site passé en réel) est oublié avec sa session d'essai */
    if(choisi && !apercuTot && (!window.NV_ESSAI_ADRESSE || choisi !== window.NV_ESSAI_ADRESSE)){
      localStorage.removeItem('nv_essai_api'); if(!CONFIG.api) localStorage.removeItem('nv_session');
    }
  }catch(e){ /* rien */ }
  try{
    if(CONFIG.api && !window.NV_API_BASE) window.NV_API_BASE = CONFIG.api;
    if(CONFIG.avatarOrigines.length && !window.NV_AVATAR_ORIGINES) window.NV_AVATAR_ORIGINES = CONFIG.avatarOrigines.slice();
    if(CONFIG.iaServeur && !window.NV_IA_SERVEUR) window.NV_IA_SERVEUR = CONFIG.iaServeur;
    if(CONFIG.modules && !window.NV_MODULES_BASE) window.NV_MODULES_BASE = CONFIG.modules;
    /* NV_IA_BASE garde un seul sens : le dossier du moteur de vision de La Forge (sans valeur : « /ia/ » à côté des modules). */
  }catch(e){ /* rien */ }
  /* 4 nov. 2026 — la session ouverte par L'Entrée (NV_MODULE_Entree.html) : { jeton, utilisateur, expire } dans localStorage
     « nv_session ». Posée seulement si l'application ne l'a pas déjà fait ; une session expirée est oubliée. Jamais dans l'aperçu. */
  try{
    var apercu = !!window.NV_APERCU || /(^#|&)demo(=1)?(&|$)/.test(location.hash || '');
    /* 21 nov. 2026 : avec un vrai serveur réglé ici, le repère de session « nv_demo » ne compte plus (un module passé en aperçu
       le posait, et la personne paraissait déconnectée dans TOUS les modules jusqu'à la fin de la session) */
    try{ if(sessionStorage.getItem('nv_demo') === '1' && !CONFIG.api) apercu = true; }catch(e){ /* rien */ }
    if(!window.NV_TOKEN && !apercu){
      var ses = JSON.parse(localStorage.getItem('nv_session') || 'null');
      if(ses && typeof ses.jeton === 'string' && ses.jeton && (!ses.expire || ses.expire > Date.now())){
        window.NV_TOKEN = ses.jeton;
        if(ses.utilisateur && typeof ses.utilisateur === 'object' && !window.NV_USER) window.NV_USER = ses.utilisateur;
      } else if(ses) localStorage.removeItem('nv_session');
    }
  }catch(e){ /* rien */ }
})();
