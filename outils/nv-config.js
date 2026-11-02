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
    api: '',                 /* adresse du serveur, sans « / » final. Vide = aucune adresse. */
    avatarOrigines: [],      /* origines autorisées pour les photos des créateurs (ex. 'https://cdn.neuravid.com') */
    iaServeur: '',           /* serveur d'IA (idées de défis de La Ruche : POST /v1/ia/idees-defi). Vide = les idées du guide de chaque défi. */
    modules: './'            /* où sont les autres modules : './' = à côté de cette page (site web). L'application peut poser NV_MODULES_BASE elle-même. */
  };
  try{
    if(CONFIG.api && !window.NV_API_BASE) window.NV_API_BASE = CONFIG.api;
    if(CONFIG.avatarOrigines.length && !window.NV_AVATAR_ORIGINES) window.NV_AVATAR_ORIGINES = CONFIG.avatarOrigines.slice();
    if(CONFIG.iaServeur && !window.NV_IA_SERVEUR) window.NV_IA_SERVEUR = CONFIG.iaServeur;
    if(CONFIG.modules && !window.NV_MODULES_BASE) window.NV_MODULES_BASE = CONFIG.modules;
    /* NV_IA_BASE garde un seul sens : le dossier du moteur de vision de La Forge (sans valeur : « /ia/ » à côté des modules). */
  }catch(e){ /* rien */ }
})();
