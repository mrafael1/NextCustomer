// node cdp.mjs <script.json>: drives headless Chrome over CDP. steps: {url}|{eval}|{shot}|{wait}|{key}|{click:[x,y]}|{move:[x,y]}
import {spawn} from 'node:child_process'; import fs from 'node:fs';
const steps=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const port=9300+Math.floor(Math.random()*500);
const ud='C:/dev/projects/NextCustomer/docs/art/mockups/start_screen_v4_review/ud'+port;
const ch=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--allow-file-access-from-files','--hide-scrollbars','--window-size=1920,1080',`--remote-debugging-port=${port}`,`--user-data-dir=${ud}`,'about:blank'],{stdio:'ignore'});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let tgt; for(let i=0;i<50;i++){ try{ const l=await (await fetch(`http://127.0.0.1:${port}/json`)).json(); tgt=l.find(t=>t.type==='page'); if(tgt) break; }catch(e){} await sleep(200); }
const ws=new WebSocket(tgt.webSocketDebuggerUrl); await new Promise(r=>ws.onopen=r);
let id=0; const pend={}; const logs=[];
ws.onmessage=m=>{ const d=JSON.parse(m.data); if(d.id&&pend[d.id]){pend[d.id](d);delete pend[d.id];}
  if(d.method==='Runtime.consoleAPICalled') logs.push(d.params.type+': '+d.params.args.map(a=>a.value??a.description).join(' '));
  if(d.method==='Runtime.exceptionThrown') logs.push('EXC: '+(d.params.exceptionDetails.exception?.description||d.params.exceptionDetails.text));
  if(d.method==='Log.entryAdded') logs.push('LOG '+d.params.entry.level+': '+d.params.entry.text+' '+(d.params.entry.url||''));
};
const C=(method,params={})=>new Promise(r=>{const i=++id; pend[i]=r; ws.send(JSON.stringify({id:i,method,params}));});
await C('Runtime.enable'); await C('Log.enable'); await C('Page.enable');
await C('Emulation.setDeviceMetricsOverride',{width:1920,height:1080,deviceScaleFactor:1,mobile:false});
for(const s of steps){
  if(s.url){ await C('Page.navigate',{url:s.url}); await sleep(s.w||2500); }
  if(s.wait) await sleep(s.wait);
  if(s.eval){ const r=await C('Runtime.evaluate',{expression:s.eval,returnByValue:true,awaitPromise:true}); console.log('EVAL['+(s.tag||'')+']', JSON.stringify(r.result.result?.value ?? r.result.exceptionDetails?.exception?.description)); }
  if(s.key){ const k=s.key; const code=k.length===1?k:k; await C('Input.dispatchKeyEvent',{type:'keyDown',key:k,code:k==='Enter'?'Enter':k==='Escape'?'Escape':'Digit'+k,windowsVirtualKeyCode:k==='Enter'?13:k==='Escape'?27:k.charCodeAt(0),text:k==='Enter'?'\r':k.length===1?k:undefined}); await C('Input.dispatchKeyEvent',{type:'keyUp',key:k}); await sleep(s.w||400); }
  if(s.move){ await C('Input.dispatchMouseEvent',{type:'mouseMoved',x:s.move[0],y:s.move[1]}); await sleep(s.w||300); }
  if(s.click){ for(const t of ['mouseMoved','mousePressed','mouseReleased']) await C('Input.dispatchMouseEvent',{type:t,x:s.click[0],y:s.click[1],button:'left',clickCount:1}); await sleep(s.w||400); }
  if(s.shot){ const r=await C('Page.captureScreenshot',{format:'png'}); fs.writeFileSync(s.shot,Buffer.from(r.result.data,'base64')); console.log('SHOT',s.shot); }
}
console.log('LOGS', JSON.stringify(logs));
ws.close(); ch.kill(); await sleep(500); try{fs.rmSync(ud,{recursive:true,force:true});}catch(e){}
process.exit(0);
