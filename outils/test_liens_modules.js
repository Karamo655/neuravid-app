// Balayage des liens entre modules : dans chaque module (démonstration), on touche chaque bouton visible de l'écran
// d'arrivée et on note chaque module que la page essaie d'ouvrir. Chaque destination doit exister dans la référence.
// Usage : node test_liens_modules.js <dossier web/> <port servi>   (le dossier doit être servi : python3 -m http.server <port>)
const {chromium}=require('playwright'); const fs=require('fs'); const path=require('path');
const [,, W, PORT]=process.argv; const B='http://127.0.0.1:'+PORT+'/';
const mods=fs.readdirSync(W).filter(f=>/^NV_MODULE_[A-Za-z]+\.html$/.test(f)).sort();
const existe=f=>fs.existsSync(path.join(W,f));
(async()=>{ const b=await chromium.launch(); const vus={}; let erreurs=0, cassés=0, touchés=0;
 for(const f of mods){
  const c=await b.newContext({viewport:{width:390,height:844},locale:'fr-FR'}); await c.addInitScript(()=>{ try{ sessionStorage.setItem('nv_demo','1'); }catch(e){} window.alert=()=>{}; window.confirm=()=>false; window.prompt=()=>null; });
  const p=await c.newPage(); const err=[]; p.on('pageerror',e=>err.push(e.message.slice(0,100))); p.on('dialog',d=>d.dismiss().catch(()=>{}));
  let premier=true;
  await p.route(/NV_MODULE_[A-Za-z]+(_leger)?\.html/, async r=>{ const u=new URL(r.request().url()); const n=u.pathname.split('/').pop();
    if(n===f){ premier=false; return r.continue(); }   /* sa propre page (arrivée, retour) : toujours permise */
    if(r.request().isNavigationRequest()){ (vus[n]=vus[n]||new Set()).add(f); return r.abort(); } return r.continue(); });
  await p.goto(B+f+'#demo').catch(()=>{}); await p.waitForTimeout(2200);
  const marquer=()=>p.evaluate(()=>{ const l=[...document.querySelectorAll('button, [role=button], a[href], [data-act], [data-ouvrir], [data-module]')].filter(e=>{ const r=e.getBoundingClientRect(); const s=getComputedStyle(e); return r.width>4&&r.height>4&&r.bottom>0&&r.top<innerHeight*3&&s.visibility!=='hidden'&&s.display!=='none'&&!e.closest('[hidden]'); }); l.forEach((e,i)=>e.setAttribute('data-balai',i)); return l.length; }).catch(()=>0);
  const n=await marquer();
  const lim=Math.min(n,45);
  for(let i=0;i<lim;i++){
    if(!p.url().includes(f)) { await p.goto(B+f+'#demo').catch(()=>{}); await p.waitForTimeout(1200); await marquer(); }
    const el=await p.$('[data-balai="'+i+'"]'); if(!el) continue;
    try{ await el.evaluate(e=>e.click()); touchés++; }catch(e){}
    await p.waitForTimeout(160);
    // refermer ce qui s'est ouvert (Échap) pour revenir à l'écran d'arrivée
    await p.keyboard.press('Escape').catch(()=>{});
  }
  if(err.length){ erreurs++; console.log('ERREURS JS', f, '|', [...new Set(err)].slice(0,3).join(' | ')); }
  await c.close();
 }
 const dest=Object.keys(vus).sort();
 for(const d of dest){ const ok=existe(d); if(!ok) cassés++; console.log((ok?'OK    ':'CASSÉ ')+d+'  ← '+[...vus[d]].join(', ')); }
 console.log('modules balayés', mods.length, '| boutons touchés', touchés, '| destinations', dest.length, '| cassées', cassés, '| modules avec erreur JS', erreurs);
 process.exitCode = cassés ? 1 : 0; await b.close(); })();
