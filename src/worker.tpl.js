/*
 * Santoro Mail — servidor (Cloudflare Worker)
 * Lee y envía el correo de Microsoft 365 (contacto@hanifhawlader.com y sus alias),
 * registra aperturas y clics, envía programados, ejecuta automatizaciones
 * y recibe pedidos de la web Santoro.
 *
 * Variables (Settings → Variables and Secrets):
 *   CLIENT_ID        Application (client) ID de Microsoft Entra
 *   TENANT_ID        Directory (tenant) ID
 *   CLIENT_SECRET    (secreto) Value del client secret
 *   ALLOWED_EMAIL    contacto@hanifhawlader.com
 *   WEBHOOK_KEY      (secreto, opcional) clave que usará la web para avisar de pedidos
 *   ANTHROPIC_API_KEY (secreto, opcional) para respuestas con Claude
 *   AI_MODEL         (opcional) por defecto claude-haiku-5-5
 *   ORDER_FROM       (opcional) remitente de los emails de marca, por defecto pedidos@hanifhawlader.com
 * Enlace KV (Bindings): nombre DB
 * Cron (Triggers): 0,10,20,30,40,50 * * * *  (cada 10 minutos)
 */

const APP_HTML = __HTML__;
const PNG = { wine: __PNG_WINE__, cream: __PNG_CREAM__ };
const SIGGIF = { santoro: __GIF_S_B64__, hanif: __GIF_H_B64__ };
const GIF = Uint8Array.from(atob('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'), c => c.charCodeAt(0));
const GRAPH = 'https://graph.microsoft.com/v1.0';
const SCOPES = 'offline_access User.Read Mail.ReadWrite Mail.Send';
const SEL = 'id,subject,bodyPreview,from,toRecipients,ccRecipients,receivedDateTime,sentDateTime,isRead,flag,hasAttachments,importance,categories,conversationId,internetMessageId';
const FOLDERS = { inbox: 'inbox', sent: 'sentitems', drafts: 'drafts', archive: 'archive', spam: 'junkemail', trash: 'deleteditems' };

/* ---------------- utils ---------------- */
const json = (d, s = 200, h = {}) => new Response(JSON.stringify(d), { status: s, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...h } });
const rid = (n = 16) => [...crypto.getRandomValues(new Uint8Array(n))].map(b => b.toString(16).padStart(2, '0')).join('');
const esc = s => String(s == null ? '' : s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const lc = s => String(s || '').toLowerCase();
async function kget(env, k, d = null) { const v = await env.DB.get(k); return v == null ? d : JSON.parse(v); }
const kput = (env, k, v, opt) => env.DB.put(k, JSON.stringify(v), opt);
function cookie(req, name) { const m = (req.headers.get('cookie') || '').match(new RegExp('(?:^|; )' + name + '=([^;]+)')); return m && m[1]; }
const allowed = env => lc(env.ALLOWED_EMAIL || 'contacto@hanifhawlader.com');

/* ---------------- Microsoft auth ---------------- */
function authUrl(env, origin, state) {
  const p = new URLSearchParams({ client_id: env.CLIENT_ID, response_type: 'code', redirect_uri: origin + '/auth/callback', response_mode: 'query', scope: SCOPES, state, login_hint: allowed(env), prompt: 'select_account' });
  return `https://login.microsoftonline.com/${env.TENANT_ID}/oauth2/v2.0/authorize?${p}`;
}
async function tokenReq(env, body) {
  const r = await fetch(`https://login.microsoftonline.com/${env.TENANT_ID}/oauth2/v2.0/token`, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ client_id: env.CLIENT_ID, client_secret: env.CLIENT_SECRET, scope: SCOPES, ...body }) });
  const d = await r.json(); if (!r.ok) throw new Error(d.error_description || d.error || 'token error'); return d;
}
async function accessToken(env) {
  const tok = await kget(env, 'tok'); if (!tok) throw new Error('NOT_CONNECTED');
  if (tok.exp - 120 > Date.now() / 1000) return tok.access;
  const d = await tokenReq(env, { grant_type: 'refresh_token', refresh_token: tok.refresh });
  const n = { access: d.access_token, refresh: d.refresh_token || tok.refresh, exp: Math.floor(Date.now() / 1000) + d.expires_in };
  await kput(env, 'tok', n); return n.access;
}
async function g(env, path, opt = {}) {
  const at = await accessToken(env);
  const r = await fetch(path.startsWith('http') ? path : GRAPH + path, { ...opt, headers: { authorization: 'Bearer ' + at, 'content-type': 'application/json', prefer: 'outlook.body-content-type="html"', ...(opt.headers || {}) } });
  if (r.status === 202 || r.status === 204) return {};
  const t = await r.text(); const d = t ? JSON.parse(t) : {};
  if (!r.ok) { const e = new Error((d.error && d.error.message) || ('Graph ' + r.status)); e.status = r.status; throw e; }
  return d;
}

/* ---------------- sessions ---------------- */
async function session(req, env) { const s = cookie(req, 'sm_s'); if (!s) return null; return kget(env, 'sess:' + s); }

/* ---------------- email building ---------------- */
function textToHtml(t) {
  return esc(t).replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>').replace(/\n/g, '<br>');
}
function wrapEmail(inner, sig) {
  return `<div style="font-family:Georgia,'Times New Roman',serif;font-size:15px;line-height:1.6;color:#111">${inner}${sig ? '<br><br>' + sig : ''}</div>`;
}
function addTracking(html, id, origin, opts) {
  const links = [];
  if (opts.click) html = html.replace(/<a\s([^>]*?)href="(https?:\/\/[^"]+)"/gi, (m, pre, url) => { if (url.startsWith(origin)) return m; links.push(url); return `<a ${pre}href="${origin}/t/c/${id}/${links.length - 1}"`; });
  if (opts.open) html += `<img src="${origin}/t/o/${id}.gif" width="1" height="1" alt="" style="display:block;width:1px;height:1px;border:0">`;
  return { html, links };
}
const rcpt = list => (Array.isArray(list) ? list : String(list || '').split(/[,;]\s*/)).map(s => s.trim()).filter(Boolean).map(a => ({ emailAddress: { address: a } }));

async function sendTracked(env, origin, m) {
  // m: {from, to, cc, subject, text|html, sig, track:{open,click}, follow, name}
  const id = rid(10);
  let html = m.html || wrapEmail(textToHtml(m.text || ''), m.sig || '');
  const tr = addTracking(html, id, origin, m.track || { open: true, click: true });
  const msg = { subject: m.subject || '', body: { contentType: 'HTML', content: tr.html }, toRecipients: rcpt(m.to), ccRecipients: rcpt(m.cc) };
  const me = allowed(env);
  if (m.from && lc(m.from) !== me) msg.from = { emailAddress: { address: m.from } };
  await g(env, '/me/sendMail', { method: 'POST', body: JSON.stringify({ message: msg, saveToSentItems: true }) });
  const rec = { id, from: m.from || me, to: { n: m.name || String(m.to).split('@')[0], e: lc(Array.isArray(m.to) ? m.to[0] : String(m.to).split(/[,;]/)[0].trim()) }, sub: m.subject || '', body: m.text || '', date: new Date().toISOString(), opens: [], clicks: [], links: tr.links, replied: false, wait: !!m.follow, follow: m.follow ? new Date(Date.now() + m.follow * 864e5).toISOString() : null, tracked: !!(m.track && (m.track.open || m.track.click)) };
  await kput(env, 'trk:' + id, rec, { expirationTtl: 60 * 60 * 24 * 365 });
  const idx = await kget(env, 'trkidx', []); idx.unshift(id); await kput(env, 'trkidx', idx.slice(0, 400));
  return rec;
}

/* ---------------- branded emails ---------------- */
function brandEmail(origin, k, d = {}) {
  const W = '#5B1A2C', C = '#F7F5E9', name = esc(d.name || ''), order = esc(d.order || '');
  const btn = (l, u) => `<a href="${esc(u || 'https://hanifhawlader.com')}" style="display:inline-block;background:${W};color:${C};text-decoration:none;font-size:12px;letter-spacing:3px;padding:13px 28px;border-radius:6px">${l}</a>`;
  const items = (d.items || []).map(i => `<tr><td style="padding:12px 0;border-bottom:1px solid #eee4e6">${esc(i.name)}</td><td align="right" style="border-bottom:1px solid #eee4e6">${esc(i.price || '')}</td></tr>`).join('');
  let title = '', body = '';
  if (k === 'order') { title = `Gracias, ${name}.`; body = `<p style="color:#555">Tu pedido está confirmado. Cada prenda Santoro se revisa a mano antes de salir del taller.</p>${items || d.total ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:22px 0;font-size:14px;border-top:1px solid #e5d8db">${items}<tr><td style="padding:12px 0;letter-spacing:2px;font-size:11px;color:${W}">TOTAL</td><td align="right" style="font-size:16px">${esc(d.total || '')}</td></tr></table>` : ''}<p style="text-align:center;margin-top:24px">${btn('VER MI PEDIDO', d.url)}</p>`; }
  if (k === 'ship') { title = 'Tu pedido va de camino.'; body = `<p style="color:#555">Hola ${name}, tu pedido ha salido hoy del taller. Lo recibirás en 24–48 horas.</p>${d.tracking ? `<div style="margin:22px 0;padding:16px;background:${C};border-radius:6px;font-size:13px"><span style="letter-spacing:2px;font-size:10px;color:${W}">SEGUIMIENTO</span><br>${esc(d.tracking)}</div>` : ''}<p style="text-align:center;margin-top:24px">${btn('SEGUIR MI ENVÍO', d.url)}</p>`; }
  if (k === 'club') { title = `Bienvenido a la casa, ${name}.`; body = `<p style="color:#555">Serás el primero en ver cada colección, tendrás acceso a ediciones limitadas y a encuentros privados.</p><p style="text-align:center;margin-top:24px">${btn('DESCUBRIR', d.url)}</p>`; }
  const kicker = k === 'club' ? 'SANTORO CLUB' : `PEDIDO ${order}`;
  return `<!DOCTYPE html><html><body style="margin:0;background:#EFEDE2;padding:24px 12px"><table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
<table width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;background:#fff;font-family:Georgia,serif;color:#111;border-radius:8px;overflow:hidden">
<tr><td style="background:${W};padding:30px 24px 22px;text-align:center"><img src="${origin}/brand/rider-cream.png" width="58" alt="Santoro" style="display:block;margin:0 auto"><div style="color:${C};font-size:13px;letter-spacing:6px;margin-top:12px">SANTORO</div></td></tr>
<tr><td style="padding:32px"><div style="font-size:10px;letter-spacing:4px;color:${W}">${kicker}</div><div style="font-size:24px;margin:8px 0 14px">${title}</div><div style="font-size:14px;line-height:1.7">${body}</div></td></tr>
<tr><td style="padding:22px;text-align:center;font-size:11px;letter-spacing:2px;color:#888;border-top:1px solid #eee4e6">SANTANDER · ESPAÑA<br><span style="letter-spacing:0">hanifhawlader.com</span></td></tr>
</table></td></tr></table></body></html>`;
}
const BRAND_SUBJ = { order: d => `Tu pedido Santoro ${d.order || ''} está confirmado`, ship: d => `Tu pedido Santoro ${d.order || ''} va de camino`, club: () => 'Bienvenido a Santoro Club' };

/* ---------------- AI ---------------- */
async function claude(env, prompt, max = 900) {
  if (!env.ANTHROPIC_API_KEY) throw new Error('NO_AI_KEY');
  const r = await fetch('https://api.anthropic.com/v1/messages', { method: 'POST', headers: { 'x-api-key': env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' }, body: JSON.stringify({ model: env.AI_MODEL || 'claude-haiku-5-5', max_tokens: max, messages: [{ role: 'user', content: prompt }] }) });
  const d = await r.json(); if (!r.ok) throw new Error((d.error && d.error.message) || 'AI error');
  return (d.content || []).map(c => c.text || '').join('');
}
const BRAND = 'Escribes para Hanif Hawlader, fundador de Santoro (marca de ropa de lujo de Santander, España). Estilo: elegante, breve, cálido, sin emojis.';

/* ---------------- tracking endpoints ---------------- */
function device(ua) {
  ua = ua || '';
  if (/GoogleImageProxy/i.test(ua)) return 'Gmail';
  if (/YahooMailProxy/i.test(ua)) return 'Yahoo Mail';
  if (/iPhone/.test(ua)) return 'iPhone'; if (/iPad/.test(ua)) return 'iPad'; if (/Android/.test(ua)) return 'Android';
  if (/Outlook|Microsoft Office/i.test(ua)) return 'Outlook';
  if (/Macintosh/.test(ua)) return 'Mac'; if (/Windows/.test(ua)) return 'Windows';
  return 'Ordenador';
}
async function trackOpen(req, env, id) {
  const rec = await kget(env, 'trk:' + id); if (!rec) return;
  const ip = req.headers.get('cf-connecting-ip') || '', self = await env.DB.get('selfip');
  if (self && ip === self) return;
  const cf = req.cf || {}, ua = req.headers.get('user-agent') || '';
  const auto = /apple/i.test(cf.asOrganization || '') || (Date.now() - new Date(rec.date)) < 15000;
  rec.opens.push({ t: new Date().toISOString(), d: device(ua), p: [cf.city, cf.country].filter(Boolean).join(', ') || '—', auto });
  rec.opens = rec.opens.slice(-60);
  await kput(env, 'trk:' + id, rec, { expirationTtl: 60 * 60 * 24 * 365 });
}

/* ---------------- mapping ---------------- */
const addr = x => x && x.emailAddress ? { n: x.emailAddress.name || x.emailAddress.address, e: lc(x.emailAddress.address) } : { n: '', e: '' };
function mapMsg(m, folder) {
  return { id: m.id, folder, from: addr(m.from), to: (m.toRecipients || []).map(r => lc(r.emailAddress.address)), cc: (m.ccRecipients || []).map(r => lc(r.emailAddress.address)), sub: m.subject || '(sin asunto)', snip: m.bodyPreview || '', date: m.receivedDateTime || m.sentDateTime, sentDate: m.sentDateTime, unread: !m.isRead, star: m.flag && m.flag.flagStatus === 'flagged', att: !!m.hasAttachments, pri: m.importance === 'high', cats: m.categories || [], conv: m.conversationId };
}

/* ---------------- cron: scheduled + rules ---------------- */
async function cron(env, origin) {
  origin = origin || (await env.DB.get('origin')) || '';
  if (!(await env.DB.get('tok'))) return;
  const prefs = await kget(env, 'prefs', {});
  // 1. scheduled sends
  const sched = await kget(env, 'sched', []); const now = Date.now(); let changed = false;
  for (const p of sched.filter(p => new Date(p.at) <= now)) { try { await sendTracked(env, origin, p); } catch (e) { p.error = String(e.message); continue; } p.done = true; changed = true; }
  if (changed) await kput(env, 'sched', sched.filter(p => !p.done));
  // 2. new inbox mail → rules + replied detection
  const state = await kget(env, 'state', { last: new Date(now - 10 * 60000).toISOString() });
  const d = await g(env, `/me/mailFolders/inbox/messages?$top=25&$select=${SEL}&$orderby=receivedDateTime desc&$filter=receivedDateTime gt ${state.last}`);
  const msgs = (d.value || []).map(m => mapMsg(m, 'inbox'));
  const rules = (prefs.rules || []).filter(r => r.on);
  const log = await kget(env, 'alog', []);
  if (msgs.length) {
    const idx = await kget(env, 'trkidx', []);
    const senders = new Set(msgs.map(m => m.from.e));
    for (const id of idx.slice(0, 120)) { const r = await kget(env, 'trk:' + id); if (r && !r.replied && senders.has(r.to.e)) { r.replied = true; r.wait = false; await kput(env, 'trk:' + id, r, { expirationTtl: 60 * 60 * 24 * 365 }); } }
    for (const m of msgs.reverse()) {
      for (const r of rules) {
        const hit = (r.w === 'from' && (m.from.e.includes(lc(r.wv)) || lc(m.from.n).includes(lc(r.wv)))) || (r.w === 'to' && m.to.includes(lc(r.wv))) || (r.w === 'has' && lc(m.sub + ' ' + m.snip).includes(lc(r.wv)));
        if (!hit) continue;
        try { const txt = await runAction(env, origin, r, m, prefs); if (txt) log.unshift({ t: new Date().toISOString(), r: r.id, txt }); } catch (e) { log.unshift({ t: new Date().toISOString(), r: r.id, txt: 'Error: ' + e.message }); }
      }
    }
    state.last = msgs.map(m => m.date).sort().pop() || state.last;
  }
  // 3. no-reply reminders (drafts)
  const nr = rules.find(r => r.w === 'noreply');
  if (nr) {
    const idx = await kget(env, 'trkidx', []);
    for (const id of idx.slice(0, 60)) {
      const r = await kget(env, 'trk:' + id);
      if (r && r.wait && !r.replied && !r.reminded && r.follow && new Date(r.follow) < now) {
        const tp = (prefs.templates || []).find(t => t.id === nr.dv); const body = tp ? fillVars(tp.body, r.to.n) : 'Hola,\n\nTe escribo para retomar mi correo anterior.\n\nUn saludo,\nHanif';
        await g(env, '/me/messages', { method: 'POST', body: JSON.stringify({ subject: 'Re: ' + r.sub, body: { contentType: 'HTML', content: wrapEmail(textToHtml(body)) }, toRecipients: rcpt(r.to.e) }) });
        r.reminded = true; await kput(env, 'trk:' + id, r, { expirationTtl: 60 * 60 * 24 * 365 });
        log.unshift({ t: new Date().toISOString(), r: nr.id, txt: 'Borrador de recordatorio para ' + r.to.n });
      }
    }
  }
  await kput(env, 'state', state);
  await kput(env, 'alog', log.slice(0, 60));
}
function fillVars(s, name) { name = String(name || '').trim(); if (!name) return s; const nm = name.includes('·') ? name.split('·').pop().trim().split(/\s+/)[0] : name.split(/\s+/)[0]; const emp = name.includes('·') ? name.split('·')[0].trim() : name; return s.replace(/\{\{nombre\}\}/g, nm).replace(/\{\{empresa\}\}/g, emp); }
async function runAction(env, origin, r, m, prefs) {
  if (r.d === 'star') { await g(env, `/me/messages/${m.id}`, { method: 'PATCH', body: JSON.stringify({ flag: { flagStatus: 'flagged' } }) }); return 'Destacado: ' + m.sub; }
  if (r.d === 'pin') { const p = await kget(env, 'prefs', {}); p.pins = [...new Set([m.id, ...(p.pins || [])])]; await kput(env, 'prefs', p); return 'Fijado: ' + m.sub; }
  if (r.d === 'label') { await g(env, `/me/messages/${m.id}`, { method: 'PATCH', body: JSON.stringify({ categories: [...new Set([...(m.cats || []), r.dv || 'Santoro'])] }) }); return 'Etiqueta «' + (r.dv || 'Santoro') + '»: ' + m.sub; }
  if (r.d === 'fwd' && r.dv) { await g(env, `/me/messages/${m.id}/forward`, { method: 'POST', body: JSON.stringify({ toRecipients: rcpt(r.dv), comment: '' }) }); return 'Reenviado a ' + r.dv; }
  if (r.d === 'notify') return 'Aviso: ' + m.from.n + ' · ' + m.sub;
  let text = '';
  if (r.d === 'ai') { const tone = { lux: 'elegante y exclusivo', formal: 'formal y profesional', warm: 'cercano y amable' }[r.dv] || 'elegante'; text = await claude(env, `${BRAND}\nResponde a este correo en su mismo idioma, tono ${tone}. No inventes precios ni fechas: usa [corchetes]. Firma "Hanif". Solo el cuerpo.\n\nDe: ${m.from.n} <${m.from.e}>\nAsunto: ${m.sub}\n\n${m.snip}`); }
  if (r.d === 'tpl' || r.d === 'remind') { const tp = (prefs.templates || []).find(t => t.id === r.dv); text = tp ? fillVars(tp.body, m.from.n) : ''; }
  if (!text) return '';
  const from = m.to.find(a => a.endsWith('@hanifhawlader.com')) || allowed(env);
  if (r.mode === 'send') { await sendTracked(env, origin, { from, to: m.from.e, name: m.from.n, subject: 'Re: ' + m.sub, text, track: { open: true, click: true } }); return 'Respuesta enviada a ' + m.from.n; }
  const dr = await g(env, `/me/messages/${m.id}/createReply`, { method: 'POST', body: '{}' });
  await g(env, `/me/messages/${dr.id}`, { method: 'PATCH', body: JSON.stringify({ body: { contentType: 'HTML', content: wrapEmail(textToHtml(text)) + (dr.body ? dr.body.content : '') } }) });
  return 'Borrador preparado para ' + m.from.n;
}

/* ---------------- API ---------------- */
async function api(req, env, url, origin) {
  const p = url.pathname.replace(/^\/api/, ''), method = req.method;
  const body = method === 'GET' ? null : await req.json().catch(() => ({}));
  if (p === '/me') { const me = await g(env, '/me?$select=displayName,mail,userPrincipalName,proxyAddresses'); return json({ name: me.displayName, email: lc(me.mail || me.userPrincipalName), aliases: (me.proxyAddresses || []).map(x => lc(x.replace(/^smtp:/i, ''))), ai: !!env.ANTHROPIC_API_KEY, origin }); }
  if (p === '/messages') {
    const f = FOLDERS[url.searchParams.get('folder') || 'inbox'] || 'inbox', top = Math.min(+url.searchParams.get('top') || 60, 200);
    const ord = f === 'sentitems' || f === 'drafts' ? 'sentDateTime' : 'receivedDateTime';
    const d = await g(env, `/me/mailFolders/${f}/messages?$top=${top}&$select=${SEL}&$orderby=${f === 'drafts' ? 'lastModifiedDateTime' : ord} desc`);
    return json((d.value || []).map(m => mapMsg(m, url.searchParams.get('folder') || 'inbox')));
  }
  let m;
  if ((m = p.match(/^\/avatar\/(santoro|hanif)$/))) {
    if (method === 'DELETE') { await env.DB.delete('av:' + m[1]); return json({ ok: true }); }
    const mm = String(body.data || '').match(/^data:(image\/(?:gif|png|jpeg|webp));base64,(.+)$/);
    if (!mm) return json({ error: 'Formato de imagen no válido' }, 400);
    const bin = Uint8Array.from(atob(mm[2]), c => c.charCodeAt(0));
    if (bin.length > 3e6) return json({ error: 'Imagen demasiado grande (máx. 3 MB)' }, 413);
    await env.DB.put('av:' + m[1], bin, { metadata: { type: mm[1] } });
    return json({ v: Date.now() });
  }
  if ((m = p.match(/^\/message\/([^/]+)$/)) && method === 'GET') {
    const id = encodeURIComponent(decodeURIComponent(m[1]));
    const d = await g(env, `/me/messages/${id}?$select=${SEL},body`);
    let atts = []; if (d.hasAttachments) { const a = await g(env, `/me/messages/${id}/attachments?$select=id,name,contentType,size,isInline`); atts = (a.value || []).filter(x => !x.isInline).map(x => ({ id: x.id, name: x.name, type: x.contentType, size: x.size })); }
    return json({ ...mapMsg(d, ''), html: d.body ? d.body.content : '', atts });
  }
  if ((m = p.match(/^\/message\/([^/]+)\/att\/([^/]+)$/))) {
    const a = await g(env, `/me/messages/${encodeURIComponent(decodeURIComponent(m[1]))}/attachments/${encodeURIComponent(decodeURIComponent(m[2]))}`);
    const bin = Uint8Array.from(atob(a.contentBytes || ''), c => c.charCodeAt(0));
    return new Response(bin, { headers: { 'content-type': a.contentType || 'application/octet-stream', 'content-disposition': `inline; filename="${(a.name || 'archivo').replace(/"/g, '')}"` } });
  }
  if ((m = p.match(/^\/message\/([^/]+)$/)) && method === 'PATCH') {
    const id = encodeURIComponent(decodeURIComponent(m[1])), patch = {};
    if ('read' in body) patch.isRead = !!body.read;
    if ('star' in body) patch.flag = { flagStatus: body.star ? 'flagged' : 'notFlagged' };
    if ('cats' in body) patch.categories = body.cats;
    await g(env, `/me/messages/${id}`, { method: 'PATCH', body: JSON.stringify(patch) }); return json({ ok: true });
  }
  if ((m = p.match(/^\/message\/([^/]+)\/move$/))) {
    const r = await g(env, `/me/messages/${encodeURIComponent(decodeURIComponent(m[1]))}/move`, { method: 'POST', body: JSON.stringify({ destinationId: FOLDERS[body.folder] || body.folder }) });
    return json({ ok: true, id: r.id });
  }
  if ((m = p.match(/^\/message\/([^/]+)$/)) && method === 'DELETE') { await g(env, `/me/messages/${encodeURIComponent(decodeURIComponent(m[1]))}`, { method: 'DELETE' }); return json({ ok: true }); }
  if (p === '/send') {
    const rec = await sendTracked(env, origin, body);
    if (body.draftId) await g(env, `/me/messages/${encodeURIComponent(body.draftId)}`, { method: 'DELETE' }).catch(() => {});
    return json(rec);
  }
  if (p === '/draft') {
    const msg = { subject: body.subject || '', body: { contentType: 'HTML', content: wrapEmail(textToHtml(body.text || '')) }, toRecipients: rcpt(body.to) };
    if (body.from && lc(body.from) !== allowed(env)) msg.from = { emailAddress: { address: body.from } };
    const r = body.id ? await g(env, `/me/messages/${encodeURIComponent(body.id)}`, { method: 'PATCH', body: JSON.stringify(msg) }) : await g(env, '/me/messages', { method: 'POST', body: JSON.stringify(msg) });
    return json({ id: r.id || body.id });
  }
  if (p === '/emptytrash') { const d = await g(env, `/me/mailFolders/deleteditems/messages?$top=100&$select=id`); for (const x of d.value || []) await g(env, `/me/messages/${x.id}`, { method: 'DELETE' }).catch(() => {}); return json({ ok: true }); }
  if (p === '/tracking') { const idx = await kget(env, 'trkidx', []); const recs = (await Promise.all(idx.slice(0, +url.searchParams.get('n') || 80).map(id => kget(env, 'trk:' + id)))).filter(Boolean); return json(recs); }
  if (p === '/sched') {
    let s = await kget(env, 'sched', []);
    if (method === 'POST') { s.push({ ...body, id: 'p' + rid(5) }); await kput(env, 'sched', s); }
    return json(s);
  }
  if ((m = p.match(/^\/sched\/([^/]+)(\/now)?$/))) {
    let s = await kget(env, 'sched', []); const it = s.find(x => x.id === m[1]);
    s = s.filter(x => x.id !== m[1]); await kput(env, 'sched', s);
    if (m[2] && it) { const rec = await sendTracked(env, origin, it); return json(rec); }
    return json({ ok: true });
  }
  if (p === '/prefs') { if (method === 'PUT') { await kput(env, 'prefs', body); return json({ ok: true }); } return json(await kget(env, 'prefs', {})); }
  if (p === '/alog') return json(await kget(env, 'alog', []));
  if (p === '/ai') { try { return json({ text: await claude(env, body.prompt, body.max || 1200) }); } catch (e) { return json({ error: e.message }, e.message === 'NO_AI_KEY' ? 501 : 500); } }
  if (p === '/brand-test') { const k = body.k || 'order'; const d = { name: body.name || 'Hanif', order: '#TEST', items: [{ name: 'Camisa Oxford crema · M', price: '89,00 €' }], total: '89,00 €' }; await g(env, '/me/sendMail', { method: 'POST', body: JSON.stringify({ message: { subject: '[Prueba] ' + BRAND_SUBJ[k](d), body: { contentType: 'HTML', content: brandEmail(origin, k, d) }, toRecipients: rcpt(allowed(env)) } }) }); return json({ ok: true }); }
  if (p === '/cron') { await cron(env, origin); return json({ ok: true }); }
  return json({ error: 'not found' }, 404);
}

/* ---------------- webhook from the Santoro website ---------------- */
async function webhook(req, env, origin) {
  const key = req.headers.get('x-santoro-key') || new URL(req.url).searchParams.get('key');
  if (!env.WEBHOOK_KEY || key !== env.WEBHOOK_KEY) return json({ error: 'unauthorized' }, 401);
  const d = await req.json(); const type = d.type === 'ship' ? 'ship' : d.type === 'signup' || d.type === 'club' ? 'club' : 'order';
  const prefs = await kget(env, 'prefs', {}); const trig = { order: 'order', ship: 'ship', club: 'signup' }[type];
  const rule = (prefs.rules || []).find(r => r.on && r.w === trig && r.d === 'brand');
  if (!rule) return json({ ok: true, skipped: 'rule off' });
  const from = env.ORDER_FROM || 'pedidos@hanifhawlader.com';
  const html = brandEmail(origin, rule.dv || type, d);
  if (rule.mode === 'send') await sendTracked(env, origin, { from, to: d.email, name: d.name, subject: BRAND_SUBJ[rule.dv || type](d), html, track: { open: true, click: true } });
  else await g(env, '/me/messages', { method: 'POST', body: JSON.stringify({ subject: BRAND_SUBJ[rule.dv || type](d), body: { contentType: 'HTML', content: html }, toRecipients: rcpt(d.email), from: { emailAddress: { address: from } } }) });
  const log = await kget(env, 'alog', []); log.unshift({ t: new Date().toISOString(), r: rule.id, txt: `${rule.name} → ${d.name || d.email}` }); await kput(env, 'alog', log.slice(0, 60));
  return json({ ok: true });
}

/* ---------------- router ---------------- */
export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url), origin = url.origin, path = url.pathname;
    try {
      if (path.startsWith('/t/o/')) { const id = path.slice(5).replace(/\.gif$/, ''); ctx.waitUntil(trackOpen(req, env, id)); return new Response(GIF, { headers: { 'content-type': 'image/gif', 'cache-control': 'no-store, no-cache, must-revalidate, max-age=0' } }); }
      if (path.startsWith('/t/c/')) {
        const [, , , id, n] = path.split('/'); const rec = await kget(env, 'trk:' + id); const to = rec && rec.links && rec.links[+n];
        if (!to) return Response.redirect('https://hanifhawlader.com', 302);
        const ip = req.headers.get('cf-connecting-ip'), self = await env.DB.get('selfip');
        if (ip !== self) { rec.clicks.push({ t: new Date().toISOString(), u: to, d: device(req.headers.get('user-agent')) }); ctx.waitUntil(kput(env, 'trk:' + id, rec, { expirationTtl: 60 * 60 * 24 * 365 })); }
        return Response.redirect(to, 302);
      }
      if (path.startsWith('/brand/rider-')) { const k = path.includes('cream') ? 'cream' : 'wine'; return new Response(Uint8Array.from(atob(PNG[k]), c => c.charCodeAt(0)), { headers: { 'content-type': 'image/png', 'cache-control': 'public, max-age=604800' } }); }
      if (path === '/brand/sig-santoro.gif' || path === '/brand/sig-hanif.gif') { const k = path.includes('hanif') ? 'hanif' : 'santoro'; return new Response(Uint8Array.from(atob(SIGGIF[k]), c => c.charCodeAt(0)), { headers: { 'content-type': 'image/gif', 'cache-control': 'public, max-age=86400' } }); }
      if (path.startsWith('/brand/avatar-')) {
        const k = path.slice(14); if (!/^(santoro|hanif)$/.test(k)) return new Response('', { status: 404 });
        const r = await env.DB.getWithMetadata('av:' + k, 'arrayBuffer'); if (!r || !r.value) return new Response('', { status: 404 });
        return new Response(r.value, { headers: { 'content-type': (r.metadata && r.metadata.type) || 'image/jpeg', 'cache-control': 'public, max-age=31536000, immutable' } });
      }
      if (path === '/manifest.json') return json({ name: 'Santoro Mail', short_name: 'Santoro', start_url: '/', display: 'standalone', background_color: '#F7F5E9', theme_color: '#5B1A2C', icons: [{ src: '/brand/rider-wine.png', sizes: '176x165', type: 'image/png' }] });
      if (path === '/api/pedido' && req.method === 'POST') return webhook(req, env, origin);
      if (path === '/auth/login') {
        if (!env.CLIENT_ID || !env.TENANT_ID || !env.CLIENT_SECRET) return new Response('Faltan CLIENT_ID, TENANT_ID o CLIENT_SECRET en Settings → Variables and Secrets.', { status: 500 });
        const st = rid(); await kput(env, 'oauth:' + st, 1, { expirationTtl: 600 });
        return Response.redirect(authUrl(env, origin, st), 302);
      }
      if (path === '/auth/callback') {
        const code = url.searchParams.get('code'), st = url.searchParams.get('state');
        if (url.searchParams.get('error')) return new Response('Microsoft: ' + url.searchParams.get('error_description'), { status: 400 });
        if (!st || !(await env.DB.get('oauth:' + st))) return new Response('Sesión caducada. Vuelve a intentarlo.', { status: 400 });
        const d = await tokenReq(env, { grant_type: 'authorization_code', code, redirect_uri: origin + '/auth/callback' });
        const me = await (await fetch(GRAPH + '/me?$select=mail,userPrincipalName', { headers: { authorization: 'Bearer ' + d.access_token } })).json();
        const email = lc(me.mail || me.userPrincipalName);
        if (email !== allowed(env)) return new Response('Esta cuenta no tiene acceso: ' + email, { status: 403 });
        await kput(env, 'tok', { access: d.access_token, refresh: d.refresh_token, exp: Math.floor(Date.now() / 1000) + d.expires_in });
        await env.DB.put('origin', origin);
        const sid = rid(24); await kput(env, 'sess:' + sid, { email }, { expirationTtl: 60 * 60 * 24 * 60 });
        return new Response(null, { status: 302, headers: { location: '/', 'set-cookie': `sm_s=${sid}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${60 * 60 * 24 * 60}` } });
      }
      if (path === '/auth/logout') { const s = cookie(req, 'sm_s'); if (s) await env.DB.delete('sess:' + s); return new Response(null, { status: 302, headers: { location: '/', 'set-cookie': 'sm_s=; Path=/; Max-Age=0' } }); }
      if (path.startsWith('/api/')) {
        const s = await session(req, env); if (!s) return json({ error: 'login' }, 401);
        const ip = req.headers.get('cf-connecting-ip'); if (ip) ctx.waitUntil(env.DB.get('selfip').then(v => v !== ip && env.DB.put('selfip', ip)));
        try { return await api(req, env, url, origin); } catch (e) { return json({ error: e.message }, e.message === 'NOT_CONNECTED' ? 401 : (e.status || 500)); }
      }
      if (path === '/' || path === '/index.html') return new Response(APP_HTML, { headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } });
      return new Response('Not found', { status: 404 });
    } catch (e) { return new Response('Error: ' + e.message, { status: 500 }); }
  },
  async scheduled(ev, env, ctx) { ctx.waitUntil(cron(env).catch(() => {})); }
};
