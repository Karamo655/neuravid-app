"""Construit le paquet « Référence NEURAVID » : le dossier web/ que le site ET l'application servent tels quels.

Usage : python3 construire_reference.py <dossier de livraison modules_a_jour> <dossier de sortie>

web/ contient exactement :
- index.html            : l'entrée de l'application et du site (ouvre l'accueil, sans démonstration) ;
- demo.html             : l'entrée de la démonstration (navigateur seulement ; impossible si nv-config.js a une adresse) ;
- NV_MODULE_*.html      : les modules, octet pour octet ceux de la livraison (aucune retouche ici) ;
- nv-config.js          : la configuration de déploiement (adresse du serveur) — le seul fichier qui change selon l'endroit ;
- nv-accueil.webmanifest, icones/, sw-tamtam.js : l'installation sur le téléphone et les notifications ;
- cadeaux3d/            : les images 3D des cadeaux des pages légères (Le Direct, La Salle Baobab) ;
- ia/                   : le moteur de vision de La Forge (MediaPipe, licence Apache 2.0) ;
- version.json          : version, date et empreinte SHA-256 de chaque fichier (l'application s'en sert pour savoir quoi mettre à jour).
"""
import hashlib, json, os, re, shutil, sys
from datetime import datetime, timezone

L, S = sys.argv[1], sys.argv[2]
ICI = os.path.dirname(os.path.abspath(__file__))
CADEAUX = '/home/claude/baobab/v2/cadeaux3d'   # le jeu complet (238 images ; celui du Direct en est un sous-ensemble identique)
IA = '/home/claude/ia_apk'                      # assets/ia de l'APK d'Afaq (MediaPipe, Apache 2.0) + la licence
W = os.path.join(S, 'web')
CONFIG_EXISTANTE = None   # la configuration du déploiement (adresse du serveur) n'est JAMAIS écrasée par une mise à jour
if os.path.isfile(os.path.join(W, 'nv-config.js')): CONFIG_EXISTANTE = open(os.path.join(W, 'nv-config.js'), 'rb').read()
if os.path.isdir(W): shutil.rmtree(W)
os.makedirs(W)

INDEX = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#0B0720"><title>NEURAVID</title><link rel="manifest" href="nv-accueil.webmanifest">
<style>html,body{margin:0;height:100%;background:#0B0720;color:#F7F3FF;font-family:system-ui,sans-serif}p{margin:0;padding:40px 16px;text-align:center}a{color:#FFC93D}</style>
<script>try{ sessionStorage.removeItem('nv_demo'); }catch(e){} try{ location.replace('NV_MODULE_Home.html' + (location.search || '') + (location.hash || '')); }catch(e){}</script>
</head><body><p><a href="NV_MODULE_Home.html">NEURAVID</a></p></body></html>
"""
DEMO = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#0B0720"><title>NEURAVID · Démonstration</title>
<style>html,body{margin:0;height:100%;background:#0B0720;color:#F7F3FF;font-family:system-ui,sans-serif}p{margin:0;padding:40px 16px;text-align:center}a{color:#FFC93D}</style>
<script>try{ sessionStorage.setItem('nv_demo','1'); localStorage.setItem('nv_accueil_seuil',''); }catch(e){} try{ location.replace('NV_MODULE_Home.html#demo'); }catch(e){}</script>
</head><body><p><a href="NV_MODULE_Home.html#demo">NEURAVID · Démonstration</a></p></body></html>
"""
open(os.path.join(W, 'index.html'), 'w', encoding='utf8').write(INDEX)
open(os.path.join(W, 'demo.html'), 'w', encoding='utf8').write(DEMO)
mods = sorted(f for f in os.listdir(L) if re.match(r'^NV_MODULE_[A-Za-z]+(_leger)?\.html$', f))
for f in mods: shutil.copy2(os.path.join(L, f), os.path.join(W, f))
if CONFIG_EXISTANTE is not None: open(os.path.join(W, 'nv-config.js'), 'wb').write(CONFIG_EXISTANTE)
else: shutil.copy2(os.path.join(ICI, 'nv-config.js'), os.path.join(W, 'nv-config.js'))
for f in ('nv-accueil.webmanifest', 'sw-tamtam.js'): shutil.copy2(os.path.join(L, f), os.path.join(W, f))
shutil.copytree(os.path.join(L, 'icones'), os.path.join(W, 'icones'))
shutil.copytree(CADEAUX, os.path.join(W, 'cadeaux3d'))
shutil.copytree(IA, os.path.join(W, 'ia'))   # moteur de vision de La Forge (détourage) : trouvé par la page en « ../ia/ » quand les modules viennent du site

def sha(p): return hashlib.sha256(open(p, 'rb').read()).hexdigest()
fichiers = {}
for racine, _, fs in os.walk(W):
    for f in sorted(fs):
        p = os.path.join(racine, f); r = os.path.relpath(p, W).replace(os.sep, '/')
        if r == 'version.json': continue
        fichiers[r] = {'sha256': sha(p), 'taille': os.path.getsize(p)}
empreinte = hashlib.sha256(json.dumps({k: v['sha256'] for k, v in sorted(fichiers.items()) if k != 'nv-config.js'}, sort_keys=True).encode()).hexdigest()[:12]
maintenant = datetime.now(timezone.utc)
version = {'version': maintenant.strftime('%Y.%m.%d') + '-' + empreinte, 'date': maintenant.strftime('%Y-%m-%dT%H:%M:%SZ'),
           'entree': 'index.html', 'modules': [f for f in mods], 'config': 'nv-config.js (exclu de l\'empreinte : il change selon le déploiement)',
           'fichiers': dict(sorted(fichiers.items()))}
json.dump(version, open(os.path.join(W, 'version.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
print('web/ :', len(mods), 'modules,', len(fichiers), 'fichiers, version', version['version'])
