"""La configuration unique de déploiement dans chaque module : <script src="nv-config.js"> tout en haut de <head>,
AVANT la démonstration (qui doit savoir s'il y a un serveur). Entre <!--NV_CONFIG--> et <!--/NV_CONFIG-->. Idempotent.
Usage : python3 injecter_config.py <dossier des modules>
À relancer après chaque reconstruction d'un module ; injecter_demo.py place ensuite la démonstration juste après ce bloc."""
import os, re, sys
D = sys.argv[1]; n = 0
BLOC = '\n<!--NV_CONFIG--><script src="nv-config.js"></script><!--/NV_CONFIG-->'
for f in sorted(os.listdir(D)):
    if not (f.startswith('NV_MODULE_') and f.endswith('.html')): continue
    p = os.path.join(D, f); s = open(p, encoding='utf8').read()
    s = re.sub(r'\n?<!--NV_CONFIG-->.*?<!--/NV_CONFIG-->', '', s, flags=re.S)
    m = re.search(r'<head[^>]*>', s, flags=re.I)
    if not m: print('PAS DE <head>', f); continue
    s = s[:m.end()] + BLOC + s[m.end():]
    open(p, 'w', encoding='utf8').write(s); n += 1
print(n, 'modules avec la configuration unique')
