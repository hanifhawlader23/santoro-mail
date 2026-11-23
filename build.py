# Construye worker.js a partir de src/ (python3 build.py)
import json,base64
r=lambda p:open('src/'+p).read()
html=r('app.html').replace('__RIDER__',r('rider.svgpath').strip()).replace('__GIF_S__','/brand/sig-santoro.gif').replace('__GIF_H__','/brand/sig-hanif.gif')
head='<link rel="manifest" href="/manifest.json"><link rel="apple-touch-icon" href="/brand/rider-wine.png"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="Santoro"><meta name="theme-color" content="#5B1A2C">'
html=html.replace('</head>',head+'</head>',1)
i=html.index('<script>\n/* ================= i18n'); html=html[:i]+'<script>window.__LIVE__=true</script>\n'+html[i:]
j=html.rindex('</script>')+len('</script>'); html=html[:j]+'\n<script>\n'+r('live.js')+'\n</script>'+html[j:]
b64=lambda p:json.dumps(base64.b64encode(open('src/'+p,'rb').read()).decode())
w=r('worker.tpl.js').replace('__HTML__',json.dumps(html,ensure_ascii=False),1).replace('__PNG_WINE__',b64('rider-wine.png'),1).replace('__PNG_CREAM__',b64('rider-cream.png'),1).replace('__GIF_S_B64__',b64('sig-santoro.gif'),1).replace('__GIF_H_B64__',b64('sig-hanif.gif'),1)
open('worker.js','w').write(w); print('worker.js', len(w))
