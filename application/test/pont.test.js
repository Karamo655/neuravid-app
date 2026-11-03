// Essais de application/pont.js hors téléphone (Playwright) : un faux téléphone reçoit ce que le pont lui confie.
// Lancer : node application/test/pont.test.js http://127.0.0.1:8899/   (le dossier web/ servi)
const {chromium}=require('playwright'); const fs=require('fs'); const path=require('path');
const ok=(c,m)=>{ console.log((c?'OK  ':'ÉCHEC ')+m); if(!c) process.exitCode=1; };
const BASE=process.argv[2]||'http://127.0.0.1:8899/';
const PONT=fs.readFileSync(path.join(__dirname,'..','pont.js'),'utf8');
async function page(b){ const c=await b.newContext({viewport:{width:360,height:780}});
  await c.addInitScript(()=>{ window.__appels=[]; window.__morceaux={};
    window.flutter_inappwebview={callHandler:(n,d)=>{ window.__appels.push([n,d&&d.type||'',d]);
      if(n==='nvEnregistrer'||n==='nvTelecharger'){ (window.__morceaux[d.id]=window.__morceaux[d.id]||[])[d.partie]=d.base64; }
      return Promise.resolve({ok:true}); }};
    window.NV_MODULES_BASE='./'; window.NV_LANG='fr'; });
  await c.addInitScript(PONT);
  const p=await c.newPage(); const err=[]; p.on('pageerror',e=>err.push(e.message)); return {c,p,err}; }
(async()=>{ const b=await chromium.launch();
  { const {c,p,err}=await page(b); await p.goto(BASE+'NV_MODULE_Report.html'); await p.waitForTimeout(800);
    ok(await p.evaluate(()=>typeof window.NVLien.ouvrir==='function' && typeof window.NVTelecharger==='function' && typeof navigator.share==='function'), 'le pont est posé : NVLien, NVTelecharger, navigator.share');
    // fichier de 5 Mo : 3 morceaux, assemblés à l'identique
    const r=await p.evaluate(async()=>{ const n=5*1024*1024+123, a=new Uint8Array(n); for(let i=0;i<n;i++) a[i]=(i*7+3)&255;
      await window.NVTelecharger(new Blob([a],{type:'video/mp4'}),'essai.mp4');
      const id=Object.keys(window.__morceaux)[0], parts=window.__morceaux[id];
      const bin=parts.map(x=>atob(x)).join(''); let same=bin.length===n; for(let i=0;same&&i<n;i+=9973) same=bin.charCodeAt(i)===((i*7+3)&255);
      const meta=window.__appels.filter(x=>x[0]==='nvEnregistrer').map(x=>({nom:x[2].nom,type:x[2].type,partie:x[2].partie,total:x[2].total}));
      return {n:parts.length, same, meta}; });
    ok(r.n===3 && r.same, 'NVTelecharger : 5 Mo en 3 morceaux, identiques à l\'octet près');
    ok(r.meta.every(m=>m.nom==='essai.mp4'&&m.type==='video/mp4'&&m.total===3), '… avec le nom, le type et le nombre de morceaux');
    // <a download> vers un blob : par code (comme La Forge) et par un vrai toucher
    const n1=await p.evaluate(async()=>{ window.__appels=[]; window.__morceaux={}; const u=URL.createObjectURL(new Blob(['BEGIN:VCALENDAR'],{type:'text/calendar'}));
      const a=document.createElement('a'); a.href=u; a.download='agenda.ics'; document.body.appendChild(a); a.click(); a.remove();
      await new Promise(r=>setTimeout(r,500)); return window.__appels.filter(x=>x[0]==='nvEnregistrer').map(x=>x[2].nom+'|'+atob(x[2].base64)); });
    ok(n1.length===1 && n1[0]==='agenda.ics|BEGIN:VCALENDAR', 'un lien de téléchargement (a.click) est confié à l\'application : '+n1.join(','));
    await p.evaluate(()=>{ window.__appels=[]; const a=document.createElement('a'); a.id='lienT'; a.textContent='x'; a.style.cssText='position:fixed;top:0;left:0;width:80px;height:40px;display:block;z-index:99999;background:#fff'; a.href='data:text/plain;base64,'+btoa('bonjour'); a.download='note.txt'; document.body.appendChild(a); });
    await p.click('#lienT'); await p.waitForTimeout(500);
    const n2=await p.evaluate(()=>window.__appels.filter(x=>x[0]==='nvEnregistrer').map(x=>x[2].nom+'|'+atob(x[2].base64)));
    ok(n2.length===1 && n2[0]==='note.txt|bonjour', '… et un vrai toucher sur un lien data: aussi');
    ok(p.url().endsWith('NV_MODULE_Report.html'), '… sans quitter la page');
    // partage
    const s=await p.evaluate(async()=>{ window.__appels=[]; await navigator.share({title:'NEURAVID', text:'Regardez', url:'https://x.y/1'}); let refus=false; try{ await navigator.share({files:[new File(['a'],'a.txt')]}); }catch(e){ refus=e.name; } return {a:window.__appels.map(x=>[x[0],x[2]]), refus}; });
    ok(s.a.length===1 && s.a[0][0]==='nvPartager' && s.a[0][1].texte==='Regardez' && s.a[0][1].lien==='https://x.y/1', 'navigator.share → la feuille de partage du téléphone');
    ok(s.refus==='NotSupportedError', '… un partage de fichiers est refusé proprement (le module garde sa solution de repli)');
    // nouvelle fenêtre
    const w=await p.evaluate(()=>{ window.__appels=[]; const r=window.open('NV_MODULE_Live.html'); window.open('https://exemple.org/produit'); return {r, a:window.__appels.map(x=>x[2].url)}; });
    ok(w.r===null && w.a[0]===BASE+'NV_MODULE_Live.html' && w.a[1]==='https://exemple.org/produit', 'window.open → l\'application décide (adresse complète)');
    ok(err.length===0, 'aucune erreur ('+err.join(' | ')+')'); await c.close(); }
  { // NVLien : Orbite « regarder le direct » ouvre Le Direct avec son contexte
    const {c,p,err}=await page(b); await p.goto(BASE+'NV_MODULE_Orbite.html'); await p.waitForTimeout(1500);
    const ctx=await p.evaluate(()=>{ window.NVLien.ouvrir('NVLive', {live:'live-42', depuis:'Orbite'}); return JSON.parse(sessionStorage.getItem('nv_ctx_Live')||'{}').live; }); await p.waitForTimeout(1500);
    ok(/NV_MODULE_Live\.html$/.test(p.url()), 'NVLien.ouvrir(\'NVLive\') ouvre Le Direct');
    ok(ctx==='live-42', '… avec son contexte (nv_ctx_Live, lu puis effacé par Le Direct à l\'arrivée)');
    await p.evaluate(()=>window.NVLien.ouvrir('NVPlayer', null)); await p.waitForTimeout(1500);
    ok(/NV_MODULE_Iris\.html$/.test(p.url()), 'NVPlayer → Iris');
    ok(await p.evaluate(()=>window.NVLien.ouvrir('../x', null))===false, 'un identifiant invalide est refusé');
    ok(err.length===0, 'aucune erreur ('+err.join(' | ')+')'); await c.close(); }
  { // les 38 pages se chargent sans erreur avec le pont
    const {c,p,err}=await page(b); const mods=fs.readdirSync(path.join(__dirname,'..','..','web')).filter(f=>/^NV_MODULE_.*\.html$/.test(f));
    const mauvais=[]; for(const f of mods){ const e0=err.length; await p.goto(BASE+f); await p.waitForTimeout(1200); if(err.length>e0) mauvais.push(f+': '+err.slice(e0).join(' | ').slice(0,120)); }
    ok(mauvais.length===0, 'les '+mods.length+' pages se chargent sans erreur avec le pont'+(mauvais.length?' — '+mauvais.join(' ; '):''));
    await c.close(); }
  await b.close(); })();
