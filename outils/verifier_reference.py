"""Vérifie qu'une application (APK), un dossier ou un site sert EXACTEMENT la référence NEURAVID.

Usage :
  python3 verifier_reference.py <web/ de la référence> <fichier .apk | dossier | https://site/>

Compare, fichier par fichier, l'empreinte SHA-256 de chaque module (NV_MODULE_*.html) et des fichiers communs.
Résultat : IDENTIQUE / DIFFÉRENT / MANQUANT pour chaque fichier de la référence, et la liste des ANCIENS fichiers
encore présents qui ne font plus partie de NEURAVID (à retirer). Code de sortie 0 seulement si tout est identique
et qu'aucun ancien module ne reste.
nv-config.js n'est jamais comparé : il change selon le déploiement (adresse du serveur).
"""
import hashlib, json, os, re, sys, urllib.request, zipfile

REF, CIBLE = sys.argv[1], sys.argv[2]
version = json.load(open(os.path.join(REF, 'version.json'), encoding='utf8'))
attendus = {k: v['sha256'] for k, v in version['fichiers'].items() if k != 'nv-config.js'}
sha = lambda b: hashlib.sha256(b).hexdigest()

trouves = {}          # chemin relatif (comme dans la référence) -> empreinte
anciens = []          # modules ou scripts présents chez la cible mais absents de la référence
if CIBLE.endswith('.apk') and os.path.isfile(CIBLE):
    z = zipfile.ZipFile(CIBLE)
    noms = [n for n in z.namelist() if n.startswith('assets/') and not n.endswith('/')]
    # la racine web/ dans l'APK : le dossier qui contient NV_MODULE_Home.html (ou, à défaut, le plus de NV_MODULE_*.html)
    dossiers = {}
    for n in noms:
        if re.search(r'/NV_MODULE_[A-Za-z]+(_leger)?\.html$', n): dossiers.setdefault(n.rsplit('/', 1)[0], []).append(n)
    racine = max(dossiers, key=lambda d: (any(x.endswith('/NV_MODULE_Home.html') for x in dossiers[d]), len(dossiers[d]))) if dossiers else None
    print('APK :', CIBLE, '| dossier des modules :', racine or 'introuvable')
    if racine:
        for n in noms:
            if n.startswith(racine + '/'):
                r = n[len(racine) + 1:]; trouves[r] = sha(z.read(n))
        for n in noms:   # scripts/pages d'anciennes générations à côté des modules
            if re.search(r'(NV_MODULE_[A-Za-z]+(_leger)?\.html|NV_[A-Z_]+[A-Za-z_]*\.js|neuravid-accueil[^/]*\.html)$', n) and not n.startswith(racine + '/'):
                anciens.append(n)
elif re.match(r'^https?://', CIBLE):
    base = CIBLE if CIBLE.endswith('/') else CIBLE + '/'
    print('Site :', base)
    for r in attendus:
        try:
            with urllib.request.urlopen(urllib.request.Request(base + r, headers={'Cache-Control': 'no-cache'}), timeout=30) as rep: trouves[r] = sha(rep.read())
        except Exception: pass
else:
    print('Dossier :', CIBLE)
    for racine, _, fs in os.walk(CIBLE):
        for f in fs:
            p = os.path.join(racine, f); trouves[os.path.relpath(p, CIBLE).replace(os.sep, '/')] = sha(open(p, 'rb').read())

identiques = [r for r in attendus if trouves.get(r) == attendus[r]]
differents = [r for r in attendus if r in trouves and trouves[r] != attendus[r]]
manquants = [r for r in attendus if r not in trouves]
en_trop = sorted(r for r in trouves if r not in attendus and r != 'nv-config.js' and r != 'version.json'
                 and re.search(r'(^|/)(NV_MODULE_[A-Za-z]+(_leger)?\.html|NV_[A-Z_]+[A-Za-z_]*\.js|neuravid-accueil[^/]*\.html)$', r))
anciens = sorted(set(anciens) | set(en_trop))
# les anciens scripts communs (NV_*.js) peuvent encore être chargés par le code de l'application : à vérifier, pas à supprimer à l'aveugle
scripts = [x for x in anciens if x.endswith('.js')]
anciens = [x for x in anciens if not x.endswith('.js')]
mods = lambda l: [r for r in l if r.startswith('NV_MODULE_')]
print('Référence', version['version'], ':', len(attendus), 'fichiers dont', len(mods(attendus)), 'modules')
print('IDENTIQUES :', len(identiques), '(dont', len(mods(identiques)), 'modules)')
for titre, l in (('DIFFÉRENTS', differents), ('MANQUANTS', manquants), ('ANCIENS MODULES À RETIRER', anciens),
                 ('ANCIENS SCRIPTS COMMUNS (à retirer seulement si le code de l\'application ne les charge plus)', scripts)):
    print('%s : %d' % (titre, len(l)))
    if l:
        m = [x for x in l if 'NV_MODULE_' in x or x.endswith('.js') or x.endswith('.html')]; autres = len(l) - len(m)
        for x in m: print('  -', x)
        if autres: print('  - … et %d autres fichiers (images, icônes)' % autres)
print('VERDICT :', 'CONFORME' if not (differents or manquants or anciens) else 'NON CONFORME')
sys.exit(0 if not (differents or manquants or anciens) else 1)
