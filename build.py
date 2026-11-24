# Construye worker.js a partir de src/ (python3 build.py)
import json,base64,os
r=lambda p:open('src/'+p).read()
import hashlib
BV={f:hashlib.md5(open('src/brand/'+f,'rb').read()).hexdigest()[:8] for f in sorted(os.listdir('src/brand'))}
SIGJS=r('sig.js').replace('__BRANDV_JSON__',json.dumps(BV))
html=r('app.html').replace('__RIDER__',r('rider.svgpath').strip()).replace('__GIF_S__','/brand/sig-santoro.gif').replace('__GIF_H__','/brand/sig-hanif.gif').replace('__AV_S__','/brand/av-santoro.gif?v='+BV['av-santoro.gif']).replace('__AV_H__','/brand/av-hanif.gif?v='+BV['av-hanif.gif']).replace('__AV_F__','/brand/av-flip.gif?v='+BV['av-flip.gif']).replace('/*__SIG_JS__*/',SIGJS)
head='<link rel="manifest" href="/manifest.json"><link rel="apple-touch-icon" href="/brand/rider-wine.png"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="Santoro"><meta name="theme-color" content="#5B1A2C">'
html=html.replace('</head>',head+'</head>',1)
import hashlib
BUILD=hashlib.md5((r('app.html')+r('live.js')+SIGJS).encode()).hexdigest()[:10]
i=html.index('<script>\n/* ================= i18n'); html=html[:i]+f'<script>window.__LIVE__=true;window.__BUILD="{BUILD}"</script>\n'+html[i:]
j=html.rindex('</script>')+len('</script>'); html=html[:j]+'\n<script>\n'+r('live.js')+'\n</script>'+html[j:]
b64=lambda p:json.dumps(base64.b64encode(open('src/'+p,'rb').read()).decode())
w=r('worker.tpl.js').replace('__BUILD__',BUILD,1).replace('__HTML__',json.dumps(html,ensure_ascii=False),1).replace('__PNG_WINE__',b64('rider-wine.png'),1).replace('__PNG_CREAM__',b64('rider-cream.png'),1).replace('/*__SIG_JS__*/',SIGJS,1).replace('__BRAND_FILES__',json.dumps({f:base64.b64encode(open('src/brand/'+f,'rb').read()).decode() for f in sorted(os.listdir('src/brand'))}),1)
open('worker.js','w').write(w); print('worker.js', len(w))
