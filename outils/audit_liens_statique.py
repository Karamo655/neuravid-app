"""Chaque module que le code peut ouvrir existe-t-il ? Lecture du code (pas d'exécution) de tous les NV_MODULE_*.html.
Usage : python3 audit_liens_statique.py <dossier web/>
Cherche ouvrir('Id'…), NVLien.ouvrir('NVId'…), data-module / data-mod / data-ouvrir="Id" ; applique les anciens
identifiants déclarés par chaque module (ANCIENS_IDS) ; vérifie que NV_MODULE_<Id>.html existe (Player → Iris)."""
import os, re, sys
W = sys.argv[1]
mods = sorted(f for f in os.listdir(W) if re.match(r'^NV_MODULE_[A-Za-z]+(_leger)?\.html$', f))
existants = {re.match(r'NV_MODULE_([A-Za-z]+)\.html', f).group(1) for f in mods if '_leger' not in f}
INTERNES = re.compile(r'(?:API|NVPhare|NVLecteur|NVRecolte|NVGriot|A|R|V|L|S|Lecteur|lecteur|this)\.ouvrir\(')
res = {}; anciens = {}
for f in mods:
    s = open(os.path.join(W, f), encoding='utf8', errors='replace').read()
    for m in re.finditer(r'ANCIENS_IDS\s*=\s*\{([^}]*)\}', s):
        for a, b in re.findall(r"([A-Za-z]+)\s*:\s*'([A-Za-z]+)'", m.group(1)): anciens.setdefault(f, {})[a] = b
    ids = set()
    for m in re.finditer(r"(?<![\w.])ouvrir\(\s*'([A-Z][A-Za-z]+)'", s): ids.add(m.group(1))
    for m in re.finditer(r"NVLien\.ouvrir\(\s*'NV([A-Z][A-Za-z]+)'", s): ids.add(m.group(1))
    for m in re.finditer(r'data-(?:module|mod|ouvrir)=\\?["\']([A-Z][A-Za-z]+)', s): ids.add(m.group(1))
    for i in ids:
        j = anciens.get(f, {}).get(i, i)
        if j not in existants and j.startswith('NV') and j[2:] in existants | {'Player'}: j = j[2:]   # La Nations' Arena écrit « NVOrbite »
        j = 'Iris' if j == 'Player' else j
        res.setdefault((i, j), set()).add(f)
casse = 0
for (i, j), d in sorted(res.items()):
    ok = j in existants
    if not ok: casse += 1
    print(('OK    ' if ok else 'CASSÉ ') + i + ('' if i == j else ' → ' + j) + '   ← ' + ', '.join(sorted(d)))
print('identifiants ouverts dans le code :', len(res), '| introuvables :', casse)
sys.exit(1 if casse else 0)
