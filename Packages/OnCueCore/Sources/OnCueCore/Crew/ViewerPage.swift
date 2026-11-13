import Foundation

/// The viewer page (/view): Multi View (every camera's shots side by side) or Full Page (one
/// camera, or the whole script), for iPads and any screen with a browser. View only. The layout
/// is picked on the page and remembered on the device, or set in the address:
/// /view?mode=multi&cams=1,2,3&next=3 · /view?mode=camera&cam=2 · /view?mode=script
enum ViewerPage {
    static let html = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="theme-color" content="#141518">
<title>OnCue Viewer</title>
<style>
:root{--well:#0F1012;--base:#141518;--panel:#1A1B1F;--raised:#212228;--key:#2A2C33;--ink:#F1F1F3;--dim:#B0B3BC;--faint:#80838E;--tally:#F0313A;--next:#2BD167;--amber:#FFB020;--sel:#5E9BFF}
*{box-sizing:border-box;margin:0;padding:0}
[hidden]{display:none!important}
html,body{background:var(--base);color:var(--ink);font:15px/1.35 -apple-system,BlinkMacSystemFont,"SF Pro Text",system-ui,sans-serif;-webkit-text-size-adjust:100%;height:100%}
body{display:flex;flex-direction:column;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)}
button,select{font:inherit;color:inherit;background:none;border:0;cursor:pointer}
.num{font-variant-numeric:tabular-nums}
header{display:flex;align-items:center;gap:10px 14px;padding:10px 14px;background:var(--panel);flex-wrap:wrap}
.dot{width:8px;height:8px;border-radius:50%;background:var(--faint);flex:none}
.dot.on{background:var(--next)}
.title{flex:1;min-width:140px}
.title b{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.title span{color:var(--faint);font-size:12.5px}
.seg{display:flex;background:var(--well);border-radius:8px;padding:2px}
.seg button{padding:6px 11px;border-radius:6px;color:var(--dim);font-size:13.5px}
.seg button.on{background:var(--key);color:var(--ink)}
select{background:var(--raised);border-radius:7px;padding:6px 8px;font-size:13.5px}
.flag{background:var(--amber);color:#0F1012;font-weight:700;font-size:12.5px;border-radius:6px;padding:3px 8px}
main{flex:1;min-height:0;padding:12px;overflow:auto}
.cols{display:flex;gap:8px;height:100%;min-height:0}
.col{flex:1 0 210px;min-width:210px;background:var(--panel);border-radius:14px;padding:10px;border:5px solid transparent;display:flex;flex-direction:column;gap:7px;overflow:hidden}
.col.pgm{border-color:var(--tally);background:#26131a}
.col.pvw{border-color:var(--next)}
.shapes .col.pvw,.shapes .big.pvw{border-style:dashed}
.ch{display:flex;align-items:baseline;gap:8px}
.ch b{font-size:40px;font-weight:900;color:var(--c);line-height:1}
.ch div{min-width:0}
.ch span{display:block;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ch small{display:block;color:var(--dim);font-size:12.5px}
.word{font-weight:900;font-size:17px;color:var(--faint);letter-spacing:.4px}
.pgm .word,.word.pgm{color:var(--tally)}
.pvw .word,.word.pvw{color:var(--next)}
.card{background:var(--raised);border-radius:10px;padding:8px 9px;display:flex;gap:8px;border:2px solid transparent}
.card.now{border-color:var(--tally)}
.card.nx{border-color:var(--next)}
.card .bd{flex:1;min-width:0}
.card .tag{font-size:11px;color:var(--faint)}
.card .tag i{font-style:normal;font-weight:900;margin-right:6px}
.card.now .tag i{color:var(--tally)}
.card.nx .tag i{color:var(--next)}
.card .tx{font-weight:600;font-size:15.5px}
.card .dt{color:var(--dim);font-size:13px}
.card .nt{color:var(--amber);font-size:13px}
.card .t{font-size:20px;font-weight:700;flex:none}
.soon{color:var(--amber)}
.cn{font-size:30px;font-weight:900;color:var(--c);width:52px;flex:none;text-align:center;line-height:1.1}
.page{max-width:980px;margin:0 auto;display:flex;flex-direction:column;gap:8px}
.page .card .tx{font-size:20px}.page .card .dt,.page .card .nt{font-size:16px}.page .card .t{font-size:26px}
.big{display:flex;align-items:center;gap:18px;background:var(--panel);border-radius:16px;padding:16px 20px;border:6px solid transparent}
.big.pgm{border-color:var(--tally);background:#26131a}.big.pvw{border-color:var(--next)}
.big b{font-size:84px;font-weight:900;color:var(--c);line-height:1}
.big .word{font-size:34px}
.big .who{color:var(--dim);font-size:17px}
.big .count{margin-left:auto;font-size:64px;font-weight:700}
.empty{color:var(--faint);padding:12px 4px}
.offline{position:fixed;left:0;right:0;bottom:0;background:var(--tally);color:#fff;text-align:center;padding:8px;font-weight:600;display:none}
.offline.show{display:block}
</style>
</head>
<body>
<header>
  <span class="dot" id="dot"></span>
  <div class="title"><b id="showName">OnCue</b><span id="where">Connecting…</span></div>
  <span class="flag" id="flag" hidden></span>
  <div class="seg" id="modes">
    <button data-mode="multi">Multi View</button><button data-mode="camera">One camera</button><button data-mode="script">Whole script</button>
  </div>
  <select id="camPick" hidden></select>
</header>
<main id="main"></main>
<div class="offline" id="offline">Lost connection to OnCue. Reconnecting…</div>
<script>
(function(){
  var state=null,receivedAt=0;
  var store={get:function(k){try{return localStorage.getItem(k)}catch(e){return null}},set:function(k,v){try{localStorage.setItem(k,v)}catch(e){}}};
  var q=new URLSearchParams(location.search);
  var mode=q.get('mode')||store.get('oncue.view.mode')||'multi';
  var oneCam=parseInt(q.get('cam')||store.get('oncue.view.cam')||'0',10)||0;
  var onlyCams=(q.get('cams')||'').split(',').map(function(x){return parseInt(x,10)}).filter(function(x){return x>0});
  var nextCount=Math.max(1,Math.min(8,parseInt(q.get('next')||'3',10)||3));
  var $=function(id){return document.getElementById(id)};
  function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  function cam(n){if(!state)return null;for(var i=0;i<state.cameras.length;i++)if(state.cameras[i].number===n)return state.cameras[i];return null}
  function colour(n){var c=cam(n);return c?c.color:'#80838E'}
  function remaining(s){return s.secondsUntil==null?null:s.secondsUntil-(Date.now()-receivedAt)/1000}
  function clock(s){if(s==null)return '';s=Math.max(0,s);var m=Math.floor(s/60),r=s-m*60;return m>0?m+':'+(r<10?'0':'')+Math.floor(r):(s<10?s.toFixed(1):String(Math.floor(s)))}
  function tally(n){return state.program===n?'pgm':(state.preview===n?'pvw':'')}
  function word(t){var s=state&&state.tallyShapes;return t==='pgm'?(s?'● ':'')+'ON AIR':(t==='pvw'?(s?'▲ ':'')+'STAND BY':'CLEAR')}
  function shots(){
    if(state.live){var s=(state.items[0]||{shots:[]}).shots,k=-1;s.forEach(function(x,i){if(x.id===state.nowShotID)k=i});return {now:k>=0?s[k]:null,after:s.slice(k+1)}}
    var all=[];state.items.forEach(function(i){all=all.concat(i.shots)});return {now:null,after:all};
  }
  function card(s,cls,label){
    var r=remaining(s);
    return '<div class="card '+(cls||'')+'" data-s="'+s.id+'"><div class="bd"><div class="tag num">'+(label?'<i>'+label+'</i>':'')+'#'+s.number+' · '+esc(s.position)+(s.transition==='mix'?' · MIX':'')+'</div>'+
      (s.text?'<div class="tx">'+esc(s.text)+'</div>':'')+(s.details?'<div class="dt">'+esc(s.details)+'</div>':'')+(s.note?'<div class="nt">'+esc(s.note)+'</div>':'')+
      '</div>'+(r!=null?'<div class="t num'+(r<5?' soon':'')+'" data-t="'+s.id+'">'+clock(r)+'</div>':'')+'</div>';
  }
  function multi(){
    var p=shots(),list=onlyCams.length?onlyCams.map(cam).filter(Boolean):state.cameras,h='<div class="cols">';
    list.forEach(function(c){
      var t=tally(c.number),mine=p.after.filter(function(s){return s.camera===c.number}).slice(0,nextCount);
      h+='<div class="col '+t+'" style="--c:'+esc(c.color)+'"><div class="ch"><b class="num">'+c.number+'</b><div><span>'+esc(c.name)+'</span>'+(c.operatorName?'<small>'+esc(c.operatorName)+'</small>':'')+'</div></div><div class="word">'+word(t)+'</div>';
      if(p.now&&p.now.camera===c.number)h+=card(p.now,'now','ON AIR');
      if(!mine.length)h+='<div class="empty">No more shots in this song</div>';
      mine.forEach(function(s,i){h+=card(s,i===0?'nx':'',i===0?'NEXT':'')});
      h+='</div>';
    });
    if(!list.length)h+='<div class="empty">The show has no cameras yet.</div>';
    $('main').innerHTML=h+'</div>';
  }
  function page(){
    var p=shots(),h='<div class="page">';
    var list=oneCam?p.after.filter(function(s){return s.camera===oneCam}):p.after;
    if(oneCam){
      var c=cam(oneCam),t=tally(oneCam),n=list[0],r=n?remaining(n):null;
      h+='<div class="big '+t+'" style="--c:'+esc(colour(oneCam))+'"><b class="num">'+oneCam+'</b><div><div class="word">'+word(t)+'</div><div class="who">'+(c?esc(c.name)+(c.operatorName?' · '+esc(c.operatorName):''):'Camera '+oneCam+' is not in this show')+'</div></div>'+
        (r!=null?'<div class="count num'+(r<5?' soon':'')+'" data-t="'+n.id+'">'+clock(r)+'</div>':'')+'</div>';
    }
    function row(s,cls,label){return oneCam?card(s,cls,label):'<div style="display:flex;gap:8px;align-items:flex-start"><div class="cn num" style="--c:'+esc(colour(s.camera))+'">'+(s.camera==null?'–':s.camera)+'</div><div style="flex:1;min-width:0">'+card(s,cls,label)+'</div></div>'}
    if(p.now&&(!oneCam||p.now.camera===oneCam))h+=row(p.now,'now','ON AIR');
    if(!list.length)h+='<div class="empty">'+(oneCam?'No more shots for camera '+oneCam+' in this song':'Nothing more in this song')+'</div>';
    list.slice(0,80).forEach(function(s,i){h+=row(s,i===0?'nx':'',i===0?'NEXT':'')});
    $('main').innerHTML=h+'</div>';
  }
  function render(){
    if(!state)return;
    $('showName').textContent=state.showName||'OnCue';
    $('where').textContent=state.live?((state.itemTitle||'')+(state.section?' · '+state.section:'')):'Not live: the whole script';
    var f=state.live&&state.paused?'PAUSED':(state.live&&state.freeMode?'FREE MODE':'');
    $('flag').hidden=!f;$('flag').textContent=f;
    document.querySelectorAll('[data-mode]').forEach(function(b){b.classList.toggle('on',b.getAttribute('data-mode')===mode)});
    var pick=$('camPick');pick.hidden=mode!=='camera';
    var opts=state.cameras.map(function(c){return '<option value="'+c.number+'"'+(c.number===oneCam?' selected':'')+'>Camera '+c.number+' – '+esc(c.name)+'</option>'}).join('');
    if(pick.getAttribute('data-o')!==opts){pick.innerHTML=opts;pick.setAttribute('data-o',opts)}
    if(mode==='camera'&&!oneCam&&state.cameras.length){oneCam=state.cameras[0].number}
    if(mode==='multi')multi();else if(mode==='camera')page();else{var keep=oneCam;oneCam=0;page();oneCam=keep}
  }
  function find(id){var p=shots();if(p.now&&p.now.id===id)return p.now;for(var i=0;i<p.after.length;i++)if(p.after[i].id===id)return p.after[i];return null}
  function tick(){if(!state||!state.live)return;document.querySelectorAll('[data-t]').forEach(function(el){var s=find(el.getAttribute('data-t'));if(!s)return;var r=remaining(s);el.textContent=clock(r);el.classList.toggle('soon',r!=null&&r<5)})}
  function apply(d){state=d;receivedAt=Date.now();document.body.classList.toggle('shapes',!!d.tallyShapes);render()}
  function connect(){
    if(!window.EventSource){poll();return}
    var es=new EventSource('/events');
    es.onmessage=function(e){try{apply(JSON.parse(e.data))}catch(err){}$('offline').classList.remove('show');$('dot').classList.add('on')};
    es.onerror=function(){$('offline').classList.add('show');$('dot').classList.remove('on')};
  }
  function poll(){fetch('/api/state').then(function(r){return r.json()}).then(function(d){apply(d);$('dot').classList.add('on')}).catch(function(){$('dot').classList.remove('on')}).finally(function(){setTimeout(poll,1000)})}
  document.addEventListener('click',function(e){var b=e.target.closest('[data-mode]');if(b){mode=b.getAttribute('data-mode');store.set('oncue.view.mode',mode);render()}});
  $('camPick').onchange=function(){oneCam=parseInt(this.value,10)||0;store.set('oncue.view.cam',String(oneCam));render()};
  setInterval(tick,100);
  connect();
})();
</script>
</body>
</html>
"""#
}
