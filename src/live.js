/* ===== Santoro Mail · modo real (conectado a Microsoft 365 a través del servidor) ===== */
(function(){
const ME={email:'',name:'',ai:false};
let prefs={};let loaded=false;let lastOpens={};
Object.assign(T.es,{ai_off:'Para usar la IA añade ANTHROPIC_API_KEY en Cloudflare (Settings → Variables and Secrets).',login_t:'Tu correo, con estilo Santoro.',login_b:'Entrar con Microsoft',loading:'Cargando tu correo…',logout:'Cerrar sesión',live_ok:'Conectado',err:'No se pudo completar',alias_err:'Microsoft no deja enviar desde este alias. Activa «Turn on sending from aliases» en Exchange admin center o envía desde contacto@.',new_mail:'correo nuevo',brand_sent:'Te he enviado una prueba a tu bandeja'});
Object.assign(T.bn,{ai_off:'AI চালাতে Cloudflare-এ ANTHROPIC_API_KEY যোগ করো (Settings → Variables and Secrets)।',login_t:'তোমার মেইল, Santoro স্টাইলে।',login_b:'Microsoft দিয়ে লগইন',loading:'মেইল আনছে…',logout:'লগআউট',live_ok:'কানেক্টেড',err:'করা গেল না',alias_err:'Microsoft এই এলিয়াস থেকে পাঠাতে দিচ্ছে না। Exchange admin center-এ «Turn on sending from aliases» চালু করো, অথবা contacto@ থেকে পাঠাও।',new_mail:'নতুন মেইল',brand_sent:'তোমার ইনবক্সে একটা টেস্ট পাঠিয়েছি'});

async function A(path,opt={}){
  const r=await fetch('/api'+path,{method:opt.method||'GET',headers:{'content-type':'application/json'},credentials:'same-origin',body:opt.body?JSON.stringify(opt.body):undefined});
  if(r.status===401){showLogin();throw new Error('login')}
  const d=await r.json().catch(()=>({}));
  if(!r.ok)throw new Error(d.error||('HTTP '+r.status));
  return d;
}
const fail=e=>{if(e.message!=='login')toast(`${t('err')}: ${esc(e.message)}`,{ms:6000})};

/* ---------- login screen ---------- */
function showLogin(){
  let el=document.getElementById('login');if(el)return;
  el=document.createElement('div');el.id='login';
  el.style.cssText='position:fixed;inset:0;z-index:200;background:var(--acc);color:var(--on);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px;padding:30px;text-align:center';
  el.innerHTML=`<svg viewBox="0 0 900 843" style="width:110px;height:103px;color:var(--on)"><use href="#rider"/></svg>
   <div style="letter-spacing:.42em;font-size:15px">SANTORO</div><div style="font-size:11px;letter-spacing:.2em;opacity:.7">MAIL</div>
   <div style="font-size:14px;opacity:.85;margin-top:10px">${t('login_t')}</div>
   <a href="/auth/login" style="margin-top:14px;background:var(--on);color:var(--acc);text-decoration:none;border-radius:8px;padding:13px 26px;font-size:14px;letter-spacing:.06em;display:inline-flex;gap:10px;align-items:center">
    <svg viewBox="0 0 21 21" width="16" height="16"><rect x="1" y="1" width="9" height="9" fill="#5B1A2C"/><rect x="11" y="1" width="9" height="9" fill="#5B1A2C" opacity=".75"/><rect x="1" y="11" width="9" height="9" fill="#5B1A2C" opacity=".75"/><rect x="11" y="11" width="9" height="9" fill="#5B1A2C" opacity=".5"/></svg>${t('login_b')}</a>`;
  document.body.appendChild(el);
}
function loadingScreen(on){let el=document.getElementById('loadingS');
  if(!on){el&&el.remove();return}
  if(el)return;el=document.createElement('div');el.id='loadingS';el.style.cssText='position:fixed;inset:0;z-index:150;background:var(--bg);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;color:var(--at)';
  el.innerHTML=`<svg viewBox="0 0 900 843" style="width:80px;height:75px;opacity:.85"><use href="#rider"/></svg><div class="cap">${t('loading')}</div>`;document.body.appendChild(el)}

/* ---------- mapping ---------- */
let DOM='hanifhawlader.com';
/* any address of my domain that receives mail (or that I send from) is a real alias */
function detectAliases(raw){const found=new Set();
  raw.forEach(x=>[...(x.to||[]),...(x.cc||[])].forEach(a=>{a=lc(a);if(a.endsWith('@'+DOM))found.add(a)}));
  let added=0;found.forEach(e=>{const a=ALIASES.find(z=>z.email===e);if(a){if(!a.main&&!a.seen){a.seen=true;added++}}else{ALIASES.push({email:e,id:'santoro',seen:true,lbl:e.split('@')[0].replace(/^./,c=>c.toUpperCase()),desc:''});added++}});
  return added}
/* Mac app bridge (Santoro Mail.app): native notifications + Dock badge */
const NATIVE=window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.santoro;
const nativeMsg=m=>{try{NATIVE&&NATIVE.postMessage(m)}catch(e){}};
const CATN={prov:'Proveedores',cli:'Clientes',ped:'Pedidos',col:'Colaboraciones'};
function pickTo(x){const all=[...(x.to||[]),...(x.cc||[])];const al=ALIASES.map(a=>a.email);return all.find(a=>al.includes(a))||ME.email}
function catOf(x,to){for(const [k,v] of Object.entries(CATN))if((x.cats||[]).includes(v))return k;
  if(/^pedidos@/.test(to))return 'ped';if(/^(hola|club)@/.test(to))return 'cli';return 'otr'}
function mapMail(x){const to=pickTo(x);const sz=(prefs.snz||{})[x.id];
  return {id:x.id,live:true,folder:x.folder,to,from:x.from,cat:catOf(x,to),cats:x.cats,pri:x.pri,unread:x.unread,star:x.star,pin:(prefs.pins||[]).includes(x.id),snz:sz&&new Date(sz)>new Date()?sz:null,date:x.date,sub:x.sub,body:x.snip,att:x.att?['adjunto']:[],html:null}}
function mapTrk(r){return {...r,id:'t:'+r.id,tid:r.id,live:true}}

/* ---------- loading ---------- */
async function loadMail(){
  const [inb,arc,spm,trs,snt,drf,trk,sch]=await Promise.all([A('/messages?folder=inbox&top=120'),A('/messages?folder=archive&top=40').catch(()=>[]),A('/messages?folder=spam&top=30').catch(()=>[]),A('/messages?folder=trash&top=30').catch(()=>[]),A('/messages?folder=sent&top=60').catch(()=>[]),A('/messages?folder=drafts&top=30').catch(()=>[]),A('/tracking').catch(()=>[]),A('/sched').catch(()=>[])]);
  if(detectAliases([...inb,...arc,...spm,...trs,...snt.map(x=>({to:[lc(x.from&&x.from.e)]}))]))savePrefs();
  mails=[...inb,...arc,...spm,...trs].map(mapMail);
  const recs=trk.map(mapTrk);
  const extra=[];
  for(const x of snt){const r=recs.find(r=>!r.gid&&lc(r.to.e)===(x.to[0]||'')&&r.sub===x.sub&&Math.abs(new Date(r.date)-new Date(x.sentDate||x.date))<15*60000);
    if(r)r.gid=x.id;else extra.push({id:x.id,gid:x.id,live:true,from:x.from.e||ME.email,to:{n:x.to[0]||'',e:x.to[0]||''},sub:x.sub,body:x.snip,date:x.sentDate||x.date,opens:[],clicks:[],replied:false,wait:false,untracked:true})}
  sent=[...recs,...extra];
  drafts=drf.map(x=>({id:x.id,gid:x.id,from:x.from.e||ME.email,to:x.to[0]||'',toName:'',sub:x.sub==='(sin asunto)'?'':x.sub,body:x.snip,date:x.date}));
  scheduled=sch.map(p=>({id:p.id,from:p.from,to:{n:p.name||p.to,e:p.to},sub:p.subject,body:p.text,at:p.at}));
  A('/alog').then(l=>{alog=l;if(S.view==='auto')renderAuto()}).catch(()=>{});
  trk.forEach(r=>lastOpens[r.id]=r.opens.filter(o=>!o.auto).length);
}
const lc=s=>String(s||'').toLowerCase();

/* ---------- prefs ---------- */
let saveT=null;
function collectPrefs(){return {templates,sigs,favs,rules,aliases:ALIASES,pins:mails.filter(m=>m.pin).map(m=>m.id).concat((prefs.pins||[]).filter(id=>!mails.find(m=>m.id===id))),snz:Object.fromEntries(mails.filter(m=>m.snz).map(m=>[m.id,m.snz])),theme:S.theme,lang:LANG,av:AVV}}
function savePrefs(){clearTimeout(saveT);saveT=setTimeout(()=>{prefs=collectPrefs();A('/prefs',{method:'PUT',body:prefs}).catch(fail)},700)}

/* ---------- hooks from the UI ---------- */
hook=function(kind,x){
  if(!loaded)return;
  if(kind==='prefs')return savePrefs();
  if(kind==='avatar'){const k=x.k;(x.data?A('/avatar/'+k,{method:'PUT',body:{data:x.data}}):A('/avatar/'+k,{method:'DELETE'})).then(r=>{if(x.data)AVV[k]=r.v;else delete AVV[k];savePrefs();toast(x.data?t('av_ok'):t('av_rm'),{wine:true});renderAll()}).catch(fail);return}
  if(kind==='readall'){(async()=>{for(let i=0;i<x.length;i+=6)await Promise.all(x.slice(i,i+6).map(m=>A('/message/'+encodeURIComponent(m.id),{method:'PATCH',body:{read:true}}).catch(()=>{})))})();return}
  if(kind==='alcheck'){A('/me').then(me=>{window.MS_ALIASES=[ME.email,...(me.aliases||[])];(me.aliases||[]).filter(e=>e.endsWith('@'+DOM)&&!ALIASES.find(x=>x.email===e)).forEach(e=>ALIASES.push({email:e,id:'santoro',lbl:e.split('@')[0].replace(/^./,c=>c.toUpperCase()),desc:''}));
    ALIASES=ALIASES.filter(a=>a.main||a.manual||a.seen||window.MS_ALIASES.includes(a.email));savePrefs();toast(t('al_checked')+` · ${ALIASES.length}`,{wine:true});renderAll()}).catch(fail);return}
  if(kind==='open'){if(x.unread)A('/message/'+encodeURIComponent(x.id),{method:'PATCH',body:{read:true}}).catch(fail);return}
  if(kind==='unread')return A('/message/'+encodeURIComponent(x.id),{method:'PATCH',body:{read:false}}).catch(fail);
  if(kind==='star')return A('/message/'+encodeURIComponent(x.id),{method:'PATCH',body:{star:x.star}}).catch(fail);
  if(kind==='label'){const keep=(x.cats||[]).filter(c=>!Object.values(CATN).includes(c));x.cats=[...keep,CATN[x.cat]];return A('/message/'+encodeURIComponent(x.id),{method:'PATCH',body:{cats:x.cats}}).catch(fail)}
  if(kind==='move'){const m=x.m;A('/message/'+encodeURIComponent(m.id)+'/move',{method:'POST',body:{folder:x.folder}}).then(r=>{if(r.id){const pin=m.pin;m.id=r.id;m.pin=pin}}).catch(fail);return}
  if(kind==='emptytrash')return A('/emptytrash',{method:'POST',body:{}}).catch(fail);
  if(kind==='scheddel')return A('/sched/'+x.id,{method:'DELETE'}).catch(fail);
  if(kind==='schednow'){A('/sched/'+x.id+'/now',{method:'POST',body:{}}).then(r=>{scheduled=scheduled.filter(p=>p!==x);sent.unshift(mapTrk(r));closeReader();toast(t('sent_ok'),{wine:true});renderAll()}).catch(fail);return}
  if(kind==='opendraft'){A('/message/'+encodeURIComponent(x.gid||x.id)).then(d=>{openCompose({from:x.from,to:x.to,sub:x.sub,body:htmlToText(d.html),draftId:x.id,draftGid:x.gid})}).catch(()=>openCompose({from:x.from,to:x.to,sub:x.sub,body:x.body,draftId:x.id,draftGid:x.gid}));return}
};
function htmlToText(h){const d=document.createElement('div');d.innerHTML=String(h||'').replace(/<br\s*\/?>/gi,'\n').replace(/<\/(p|div|tr|h\d)>/gi,'\n');return (d.textContent||'').replace(/\n{3,}/g,'\n\n').trim()}

/* ---------- reading real messages ---------- */
bodyHTML=function(m){
  const gid=m.gid||(m.live&&!m.tid?m.id:null);
  if(!gid)return `<div class="rd-text">${esc(m.body)}</div>`;
  if(m.html==null){if(!m._loading){m._loading=true;A('/message/'+encodeURIComponent(gid)).then(d=>{m.html=d.html||esc(m.body);m.atts=d.atts||[];m.att=[];if(S.sel&&(S.sel.id===m.id))renderReader()}).catch(e=>{m.html='<p>'+esc(m.body)+'</p>';fail(e);renderReader()})}
    return `<div class="muted" style="padding:20px 0">${t('loading')}</div>`}
  const clean=String(m.html).replace(/<img[^>]+\/t\/o\/[^>]+>/gi,'').replace(/<script[\s\S]*?<\/script>/gi,'');
  const doc=`<!DOCTYPE html><html><head><base target="_blank"><meta name="viewport" content="width=device-width"><style>body{margin:0;padding:18px;font-family:Georgia,serif;font-size:15px;line-height:1.6;color:#111;word-wrap:break-word}img{max-width:100%;height:auto}table{max-width:100%}a{color:#5B1A2C}</style></head><body>${clean}</body></html>`;
  const atts=(m.atts||[]).map(a=>`<a class="btn" style="text-decoration:none" href="/api/message/${encodeURIComponent(gid)}/att/${encodeURIComponent(a.id)}" target="_blank" rel="noopener">${ic('file','acc')} ${esc(a.name)} <small class="muted">${Math.max(1,Math.round(a.size/1024))} KB</small></a>`).join('');
  return `<div style="max-width:760px;background:#fff;border-radius:8px;overflow:hidden;border:1px solid var(--line)"><iframe class="mframe" sandbox="allow-popups allow-popups-to-escape-sandbox allow-same-origin" style="width:100%;border:0;min-height:120px;display:block" srcdoc="${esc(doc)}" onload="try{this.style.height=(this.contentDocument.documentElement.scrollHeight+4)+'px'}catch(e){}"></iframe></div>${atts?`<div class="att">${atts}</div>`:''}`;
};
footHTML=function(){return `<span class="dot"></span>${t('live_ok')} · ${esc(ME.email)}<br><a href="/auth/logout" style="color:inherit">${t('logout')}</a>`};

/* ---------- AI through the server ---------- */
ask=async function(prompt,onText){
  onText(t('thinking'));
  try{const r=await fetch('/api/ai',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({prompt})});const d=await r.json();
    if(r.status===501){onText(t('ai_off'));return null}if(!r.ok)throw new Error(d.error);onText(d.text);return d.text}
  catch(e){onText('Error: '+e.message);return null}
};

/* ---------- email-safe signature ---------- */
function sigEmail(k){return `<div style="margin-top:10px">${sigBuild(k,true)}</div>`}

/* ---------- sending ---------- */
doSend=function(){
  syncC();if(!C.to.trim()){toast(t('need_to'));return}
  const to=C.to.trim(),name=C.toName||((mails.find(m=>m.from.e===lc(to))||{from:{}}).from.n)||to.split('@')[0];
  const payload={from:C.from,to,name,subject:C.sub||'(sin asunto)',text:fillVars(C.body,name),sig:sigEmail(idOf(C.from)),track:{open:C.trackO,click:C.trackC},follow:+C.follow||0,draftId:C.draftGid||null};
  const draftId=C.draftId,at=C.at;$('#scrim').classList.remove('on');C=null;
  if(at){A('/sched',{method:'POST',body:{...payload,at:new Date(at).toISOString()}}).then(s=>{scheduled=s.map(p=>({id:p.id,from:p.from,to:{n:p.name||p.to,e:p.to},sub:p.subject,body:p.text,at:p.at}));if(draftId)drafts=drafts.filter(d=>d.id!==draftId);toast(t('sched_ok'),{wine:true});renderAll()}).catch(fail);return}
  let undone=false,left=S.undoSec;
  const el=toast(`${t('sending')} <b class="cd">${left}</b>`,{action:t('undo'),ms:S.undoSec*1000+400,onAction:()=>{undone=true;openCompose({from:payload.from,to:payload.to,toName:name,sub:payload.subject,body:payload.text,draftId,draftGid:payload.draftId});toast(t('undone'))}});
  const iv=setInterval(()=>{left--;const b=el.querySelector('.cd');if(b)b.textContent=left;if(left<=0)clearInterval(iv)},1000);
  setTimeout(()=>{if(undone)return;A('/send',{method:'POST',body:payload}).then(r=>{sent.unshift(mapTrk(r));if(draftId)drafts=drafts.filter(d=>d.id!==draftId);toast(t('sent_ok'),{wine:true});renderAll()})
    .catch(e=>{toast(/from|alias|SendAs|permission/i.test(e.message)?t('alias_err'):`${t('err')}: ${esc(e.message)}`,{ms:9000});openCompose({from:payload.from,to:payload.to,toName:name,sub:payload.subject,body:payload.text,draftId,draftGid:payload.draftId})})},S.undoSec*1000+200);
};
closeCompose=function(save=true){
  if(C&&$('#c-from'))syncC();const c=C;$('#scrim').classList.remove('on');C=null;
  if(save&&c&&(c.body.trim()||c.sub.trim())){A('/draft',{method:'POST',body:{id:c.draftGid||null,from:c.from,to:c.to,subject:c.sub,text:c.body}}).then(r=>{
    const d={id:r.id,gid:r.id,from:c.from,to:c.to,toName:c.toName,sub:c.sub,body:c.body,date:new Date().toISOString()};drafts=drafts.filter(x=>x.id!==c.draftId&&x.id!==r.id);drafts.unshift(d);toast(t('draft_ok'));renderAll()}).catch(fail)}
  renderAll()};

/* ---------- polling: new mail + opens ---------- */
async function poll(){
  try{
    const [inb,trk]=await Promise.all([A('/messages?folder=inbox&top=60'),A('/tracking?n=60')]);
    const known=new Set(mails.map(m=>m.id));const fresh=inb.filter(x=>!known.has(x.id));
    if(fresh.length){mails=[...fresh.map(mapMail),...mails];nativeMsg({type:'notify',title:fresh[0].from.n,body:fresh[0].sub});if(S.notif)toast(`${fresh.length} ${t('new_mail')}: ${esc(fresh[0].from.n)} · ${esc(fresh[0].sub)}`,{wine:true,ms:5000})}
    inb.forEach(x=>{const m=mails.find(y=>y.id===x.id);if(m){m.unread=x.unread;m.star=x.star}});
    for(const r of trk){const n=r.opens.filter(o=>!o.auto).length,prev=lastOpens[r.id];
      if(prev!=null&&n>prev)nativeMsg({type:'notify',title:t('demo_open')+' 👁',body:r.to.n+' · '+r.sub});if(prev!=null&&n>prev&&S.notif)toast(`${esc(r.to.n)} ${t('demo_open')} · ${esc(r.sub)}`,{wine:true,ms:6000});lastOpens[r.id]=n;
      const s=sent.find(x=>x.tid===r.id);if(s)Object.assign(s,{opens:r.opens,clicks:r.clicks,replied:r.replied,wait:r.wait});else sent.unshift(mapTrk(r))}
    const u=mails.filter(m=>m.folder==='inbox'&&m.unread).length;document.title=(u?`(${u}) `:'')+'Santoro Mail';nativeMsg({type:'badge',n:u});
    if(!document.querySelector('#scrim.on'))renderAll();
  }catch(e){}
}

/* ---------- start ---------- */
/* la app se actualiza sola cuando subo una versión nueva (sin perder un correo a medio escribir) */
function checkVersion(){fetch('/version',{cache:'no-store'}).then(r=>r.json()).then(d=>{if(d.b&&window.__BUILD&&d.b!==window.__BUILD&&!C){LS.set('justUpdated',1);location.reload()}}).catch(()=>{})}
function liveError(msg){loadingScreen(false);let el=document.getElementById('liveErr');if(!el){el=document.createElement('div');el.id='liveErr';document.body.appendChild(el)}
  el.style.cssText='position:fixed;inset:0;z-index:160;background:var(--bg);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;padding:30px;text-align:center;color:var(--fg)';
  el.innerHTML=`<svg viewBox="0 0 900 843" style="width:70px;height:66px;color:var(--at)"><use href="#rider"/></svg><h2 style="font-weight:500;margin:0">No se pudo cargar tu correo</h2><p style="color:var(--fg2);max-width:420px;margin:0;font-size:14px">${esc(msg)}</p>
   <div style="display:flex;gap:10px;flex-wrap:wrap;justify-content:center"><button class="btn pri" onclick="location.reload()">Reintentar</button><a class="btn" href="/auth/logout">Entrar de nuevo</a></div>`}
(async()=>{
  // nada de datos de ejemplo en la app real
  mails=[];sent=[];drafts=[];scheduled=[];alog=[];favs=[];
  loadingScreen(true);
  try{
    const me=await A('/me');Object.assign(ME,me);
    prefs=await A('/prefs').catch(()=>({}));
    if(prefs.templates)templates=prefs.templates;if(prefs.sigs)sigs=prefs.sigs;if(prefs.rules)rules=prefs.rules;
    favs=prefs.favs||[];AVV=prefs.av||{};
    if(prefs.theme){S.theme=prefs.theme;applyTheme()}
    // aliases: SOLO los reales = Microsoft (lo que creaste en GoDaddy) + los que reciben correo + los que añadiste tú a mano
    DOM=ME.email.split('@')[1];
    const ms=(me.aliases||[]).filter(a=>a.endsWith('@'+DOM));
    const saved=(prefs.aliases||[]).filter(a=>a&&a.email);
    const known=Object.fromEntries(saved.map(a=>[a.email,a]));
    const list=[ME.email,...ms,...saved.filter(a=>a.manual||a.seen).map(a=>a.email)];
    ALIASES=[...new Set(list)].map(e=>Object.assign({email:e,id:e===ME.email?'hanif':'santoro',lbl:e.split('@')[0].replace(/^./,c=>c.toUpperCase()),desc:''},known[e]||{}));
    ALIASES.forEach(a=>{if(a.email===ME.email){a.main=true;a.def=true;a.id='hanif'}});
    if(!ALIASES.some(a=>a.id==='santoro'&&a.def)){const s=ALIASES.find(a=>a.email.startsWith('santoro@'))||ALIASES.find(a=>a.id==='santoro');if(s)s.def=true}
    window.MS_ALIASES=[ME.email,...(me.aliases||[])];
    AI=me.ai?{}:null;
    alog=[];
    await loadMail();
    loaded=true;
    if(!prefs.templates)savePrefs();
    loadingScreen(false);renderAll();
    if(LS.get('justUpdated',0)){LS.set('justUpdated',0);toast(t('upd')+' ✓',{wine:true})}
    if(!LS.get('swHelp',0)&&matchMedia('(max-width:860px)').matches){LS.set('swHelp',1);setTimeout(()=>toast(t('sw_help'),{ms:7000}),1500)}
    setInterval(poll,60000);
    window.__refresh=async()=>{checkVersion();await loadMail();await poll()};
    setInterval(checkVersion,5*60000);document.addEventListener('visibilitychange',()=>{if(!document.hidden)checkVersion()});
    document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')poll()});
    document.addEventListener('visibilitychange',()=>{if(!document.hidden)poll()});
  }catch(e){if(e.message!=='login')liveError(e.message||String(e));else loadingScreen(false)}
})();
})();
