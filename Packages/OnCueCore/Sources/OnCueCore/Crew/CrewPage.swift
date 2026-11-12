import Foundation

/// The crew page: one self-contained page served to phones and tablets on the local network.
/// Operators pick their camera once (remembered on the device); the page then shows their tally,
/// a countdown to their next shot and what is coming, or the whole script for review with comments.
enum CrewPage {
    static let html = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="theme-color" content="#141518">
<title>OnCue Crew</title>
<style>
:root{--well:#0F1012;--base:#141518;--panel:#1A1B1F;--raised:#212228;--key:#2A2C33;--ink:#F1F1F3;--dim:#B0B3BC;--faint:#80838E;--tally:#F0313A;--next:#2BD167;--amber:#FFB020;--sel:#5E9BFF}
*{box-sizing:border-box;margin:0;padding:0}
[hidden]{display:none!important}
html,body{background:var(--base);color:var(--ink);font:15px/1.4 -apple-system,BlinkMacSystemFont,"SF Pro Text",system-ui,sans-serif;-webkit-text-size-adjust:100%}
body{min-height:100vh;padding:env(safe-area-inset-top) 0 env(safe-area-inset-bottom)}
button{font:inherit;color:inherit;background:none;border:0;cursor:pointer}
.num{font-variant-numeric:tabular-nums}
header{display:flex;align-items:center;gap:12px;padding:12px 16px;background:var(--panel)}
header .show{flex:1;min-width:0}
header .show b{display:block;font-size:15px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
header .show span{color:var(--faint);font-size:12.5px}
.link{color:var(--sel);font-size:13.5px;padding:6px 2px}
.dot{width:8px;height:8px;border-radius:50%;background:var(--faint);flex:none}
.dot.on{background:var(--next)}
.tabs{display:flex;gap:4px;padding:8px 16px 0}
.tabs button{padding:7px 12px;border-radius:7px;color:var(--dim);font-size:13.5px}
.tabs button.on{background:var(--key);color:var(--ink)}
main{padding:16px}
.picker h1{font-size:20px;margin:8px 0 4px}
.picker p{color:var(--dim);margin-bottom:16px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:10px}
.cam{background:var(--raised);border-radius:12px;padding:12px;text-align:left;border-left:5px solid var(--c)}
.cam b{display:block;font-size:34px;font-weight:800;color:var(--c);line-height:1}
.cam span{display:block;font-size:13px;color:var(--ink);margin-top:6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.cam small{display:block;color:var(--faint);font-size:12px}
.tally{border-radius:18px;padding:20px;background:var(--panel);border:6px solid transparent;display:flex;gap:18px;align-items:center;transition:border-color .12s}
.tally.pgm{border-color:var(--tally);background:#2a1214}
.tally.pvw{border-color:var(--next)}
.badge{width:112px;height:112px;border-radius:16px;background:var(--c);color:#0F1012;display:flex;align-items:center;justify-content:center;font-size:72px;font-weight:900;flex:none;letter-spacing:-2px}
.state{flex:1;min-width:0}
.state .word{font-size:30px;font-weight:800;letter-spacing:.5px}
.tally.pgm .word{color:var(--tally)}
.tally.pvw .word{color:var(--next)}
.state .sub{color:var(--dim);margin-top:4px}
.count{font-size:56px;font-weight:700;margin-top:4px;line-height:1}
.count.soon{color:var(--amber)}
.where{display:flex;gap:6px 16px;color:var(--dim);font-size:13.5px;margin:14px 2px 18px;flex-wrap:wrap}
.where b{color:var(--ink);font-weight:600}
.banner{background:var(--amber);color:#0F1012;border-radius:10px;padding:10px 14px;font-weight:600;margin-bottom:12px}
.label{color:var(--faint);font-size:12.5px;font-weight:600;margin:18px 2px 8px}
.shot{display:flex;gap:12px;align-items:flex-start;padding:11px 12px;border-radius:10px;background:var(--panel);margin-bottom:6px;border-left:4px solid var(--c)}
.shot.mine{background:var(--raised)}
.shot.now{outline:2px solid var(--tally)}
.shot.next{outline:2px solid var(--next)}
.shot .n{color:var(--faint);width:28px;flex:none;font-size:13px;padding-top:2px}
.shot .cn{font-size:20px;font-weight:800;color:var(--c);width:34px;flex:none;line-height:1.1}
.shot .body{flex:1;min-width:0}
.shot .body b{font-weight:500;display:block}
.shot .body i{font-style:normal;color:var(--dim);font-size:13px;display:block}
.shot .meta{color:var(--faint);font-size:12.5px;text-align:right;flex:none}
.shot .meta .t{color:var(--ink);font-size:15px}
.cmt{margin-top:6px;font-size:13px;color:var(--amber)}
.cmt.res{color:var(--faint);text-decoration:line-through}
.empty{color:var(--faint);padding:20px 4px}
.item h2{font-size:16px;margin:22px 2px 8px}
.item h2 small{color:var(--faint);font-weight:400;margin-left:6px}
.sheet{position:fixed;inset:0;background:rgba(0,0,0,.55);display:none;align-items:flex-end;justify-content:center}
.sheet.open{display:flex}
.sheet form{background:var(--panel);width:100%;max-width:520px;border-radius:16px 16px 0 0;padding:16px 16px calc(16px + env(safe-area-inset-bottom))}
.sheet h3{font-size:16px;margin-bottom:4px}
.sheet p{color:var(--dim);font-size:13.5px;margin-bottom:10px}
.sheet input,.sheet textarea{width:100%;background:var(--well);color:var(--ink);border:1px solid var(--key);border-radius:9px;padding:10px;font:inherit;margin-bottom:8px}
.sheet textarea{min-height:90px;resize:vertical}
.row{display:flex;gap:8px;justify-content:flex-end}
.btn{padding:10px 16px;border-radius:9px;background:var(--key)}
.btn.primary{background:var(--sel);color:#fff;font-weight:600}
.offline{position:fixed;left:0;right:0;bottom:0;background:var(--tally);color:#fff;text-align:center;padding:8px calc(8px + env(safe-area-inset-bottom));font-weight:600;display:none}
.offline.show{display:block}
@media (min-width:700px){main{max-width:760px;margin:0 auto}}
</style>
</head>
<body>
<header>
  <span class="dot" id="dot"></span>
  <div class="show"><b id="showName">OnCue</b><span id="showSub">Connecting…</span></div>
  <button class="link" id="changeCam" hidden>Change camera</button>
</header>
<div class="tabs" id="tabs" hidden>
  <button data-tab="me" class="on">My shots</button>
  <button data-tab="all">Whole script</button>
</div>
<main id="main"></main>
<div class="sheet" id="sheet">
  <form id="commentForm">
    <h3>Comment on this shot</h3>
    <p id="commentFor"></p>
    <input id="author" placeholder="Your name" maxlength="40" autocomplete="name">
    <textarea id="commentText" placeholder="What should the director know?" maxlength="1000" required></textarea>
    <div class="row"><button type="button" class="btn" id="cancelComment">Cancel</button><button class="btn primary">Send comment</button></div>
  </form>
</div>
<div class="offline" id="offline">Lost connection to OnCue. Reconnecting…</div>
<script>
(function(){
  var state=null, receivedAt=0, serverOffset=0, tab='me', commentShot=null, lastVersion=null;
  var store={get:function(k){try{return localStorage.getItem(k)}catch(e){return null}},set:function(k,v){try{localStorage.setItem(k,v)}catch(e){}}};
  var myCam=parseInt(store.get('oncue.camera')||'',10); if(isNaN(myCam)) myCam=null;
  var $=function(id){return document.getElementById(id)};
  function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  function cam(n){if(!state)return null;for(var i=0;i<state.cameras.length;i++)if(state.cameras[i].number===n)return state.cameras[i];return null}
  function colour(n){var c=cam(n);return c?c.color:'#80838E'}
  function remaining(shot){if(shot.secondsUntil==null)return null;return shot.secondsUntil-(Date.now()-receivedAt)/1000}
  function clock(s){if(s==null)return '';s=Math.max(0,s);var m=Math.floor(s/60),r=s-m*60;return m>0?m+':'+(r<10?'0':'')+Math.floor(r):(s<10?s.toFixed(1):String(Math.floor(s)))}

  function picker(){
    var h='<div class="picker"><h1>Which camera are you on?</h1><p>OnCue remembers this on this device.</p><div class="grid">';
    (state?state.cameras:[]).forEach(function(c){
      h+='<button class="cam" style="--c:'+esc(c.color)+'" data-cam="'+c.number+'"><b class="num">'+c.number+'</b><span>'+esc(c.name)+'</span><small>'+esc(c.operatorName||' ')+'</small></button>';
    });
    if(!state||!state.cameras.length) h+='<div class="empty">The show has no cameras yet.</div>';
    h+='</div><p style="margin-top:16px"><button class="link" data-cam="0">Just follow the script, no camera</button></p></div>';
    $('main').innerHTML=h;
  }

  function shotRow(s,opts){
    var mine=myCam&&s.camera===myCam, cls='shot'+(mine?' mine':'')+(state.nowShotID===s.id?' now':'')+(state.nextShotID===s.id?' next':'');
    var r=remaining(s), t=r!=null?'<div class="t num">'+clock(r)+'</div>':'';
    var cm='';(s.comments||[]).forEach(function(c){cm+='<div class="cmt'+(c.resolved?' res':'')+'">'+esc(c.author)+': '+esc(c.text)+'</div>'});
    return '<div class="'+cls+'" style="--c:'+esc(colour(s.camera))+'" data-shot="'+s.id+'" data-item="'+s.itemID+'">'+
      '<div class="n num">'+s.number+'</div><div class="cn num">'+(s.camera==null?'–':s.camera)+'</div>'+
      '<div class="body"><b>'+esc(s.text||(cam(s.camera)?cam(s.camera).name:'No camera'))+'</b>'+(s.note?'<i>'+esc(s.note)+'</i>':'')+cm+'</div>'+
      '<div class="meta"><div class="num">'+esc(s.position)+'</div>'+(s.transition==='mix'?'<div>Mix</div>':'')+t+'</div></div>';
  }

  function liveView(){
    var item=state.items[0]||{shots:[]}, shots=item.shots, c=cam(myCam);
    var onPgm=myCam&&state.program===myCam, onPvw=myCam&&!onPgm&&state.preview===myCam;
    var nowIdx=-1;shots.forEach(function(s,i){if(s.id===state.nowShotID)nowIdx=i});
    var upcoming=shots.slice(nowIdx+1), mineNext=null;
    upcoming.forEach(function(s){if(!mineNext&&myCam&&s.camera===myCam)mineNext=s});
    var h='';
    if(state.paused) h+='<div class="banner">The show is paused. Follow the director.</div>';
    else if(state.freeMode) h+='<div class="banner">Free mode: the director is calling shots live.</div>';
    if(myCam){
      var word=onPgm?'ON AIR':(onPvw?'STAND BY':'CLEAR'), sub='', count='';
      var counter=function(s){var r=remaining(s);return r==null?'':'<div class="count num'+(r<5?' soon':'')+'" data-count="'+s.id+'">'+clock(r)+'</div>'};
      var nextShot=upcoming[0];
      if(onPgm){
        if(nextShot&&nextShot.camera!==myCam){sub='Clear when camera '+(nextShot.camera==null?'–':nextShot.camera)+' takes';count=counter(nextShot)}
        else sub='You are on program';
      }
      else if(onPvw){sub='You are next to air'+(mineNext?': '+esc(mineNext.text||('shot '+mineNext.number)):'');if(mineNext)count=counter(mineNext)}
      else if(mineNext){sub='Your next shot: '+esc(mineNext.text||('shot '+mineNext.number));count=counter(mineNext)}
      else sub='No more shots for you in this song';
      h+='<div class="tally'+(onPgm?' pgm':(onPvw?' pvw':''))+'" style="--c:'+esc(colour(myCam))+'"><div class="badge num">'+myCam+'</div><div class="state"><div class="word">'+word+'</div><div class="sub">'+sub+'</div>'+count+'</div></div>';
    }
    h+='<div class="where"><span>Now <b>'+esc(item.title||'')+'</b></span>'+(state.section?'<span>Section <b>'+esc(state.section)+'</b></span>':'')+'<span>Program <b class="num">'+(state.program==null?'–':state.program)+'</b></span><span>Preview <b class="num">'+(state.preview==null?'–':state.preview)+'</b></span></div>';
    var list=tab==='me'&&myCam?upcoming.filter(function(s){return s.camera===myCam}):upcoming;
    var now=nowIdx>=0?shots[nowIdx]:null;
    if(now&&tab!=='me'){h+='<div class="label">On air</div>'+shotRow(now)}
    h+='<div class="label">'+(tab==='me'&&myCam?'Your shots still to come':'Coming up')+'</div>';
    if(!list.length) h+='<div class="empty">Nothing more in this song.</div>';
    list.slice(0,tab==='me'?20:40).forEach(function(s){h+=shotRow(s)});
    $('main').innerHTML=h;
  }

  function reviewView(){
    var h='<div class="where"><span>The show is not live. Tap a shot to leave a comment for the director.</span></div>';
    state.items.forEach(function(item){
      var shots=tab==='me'&&myCam?item.shots.filter(function(s){return s.camera===myCam}):item.shots;
      if(!shots.length&&tab==='me')return;
      h+='<div class="item"><h2>'+esc(item.title)+'<small>'+item.shots.length+' shots</small></h2>';
      if(!shots.length)h+='<div class="empty">No shots yet.</div>';
      shots.forEach(function(s){h+=shotRow(s)});
      h+='</div>';
    });
    if(h.indexOf('class="item"')<0)h+='<div class="empty">No shots for camera '+myCam+' in this script.</div>';
    $('main').innerHTML=h;
  }

  function render(){
    if(!state)return;
    $('showName').textContent=state.showName||'OnCue';
    var c=cam(myCam);
    $('showSub').textContent=(state.live?'Live':'Script review')+(c?' · Camera '+c.number+' '+c.name:'');
    if(myCam===null){$('tabs').hidden=true;$('changeCam').hidden=true;picker();return}
    $('tabs').hidden=!myCam;$('changeCam').hidden=false;
    if(state.live)liveView();else reviewView();
  }

  function tick(){
    if(!state||!state.live)return;
    document.querySelectorAll('[data-count]').forEach(function(el){
      var id=el.getAttribute('data-count');var s=null;state.items[0].shots.forEach(function(x){if(x.id===id)s=x});
      if(!s)return;var r=remaining(s);el.textContent=clock(r);el.classList.toggle('soon',r!=null&&r<5);
    });
    document.querySelectorAll('.shot .t').forEach(function(el){
      var id=el.closest('.shot').getAttribute('data-shot');var s=null;state.items[0].shots.forEach(function(x){if(x.id===id)s=x});
      if(s)el.textContent=clock(remaining(s));
    });
  }

  function apply(data){
    state=data;receivedAt=Date.now();
    if(navigator.vibrate&&lastVersion!==null&&state.scriptVersion!==lastVersion)navigator.vibrate(80);
    lastVersion=state.scriptVersion;
    render();
  }

  function connect(){
    if(!window.EventSource){poll();return}
    var es=new EventSource('/events');
    es.onmessage=function(e){try{apply(JSON.parse(e.data))}catch(err){}$('offline').classList.remove('show');$('dot').classList.add('on')};
    es.onerror=function(){$('offline').classList.add('show');$('dot').classList.remove('on')};
  }
  function poll(){fetch('/api/state').then(function(r){return r.json()}).then(function(d){apply(d);$('dot').classList.add('on')}).catch(function(){$('dot').classList.remove('on')}).finally(function(){setTimeout(poll,1000)})}

  document.addEventListener('click',function(e){
    var b=e.target.closest('[data-cam]');
    if(b){var n=parseInt(b.getAttribute('data-cam'),10);myCam=n>0?n:0;store.set('oncue.camera',String(myCam));render();return}
    var t=e.target.closest('[data-tab]');
    if(t){tab=t.getAttribute('data-tab');document.querySelectorAll('[data-tab]').forEach(function(x){x.classList.toggle('on',x===t)});render();return}
    if(e.target.closest('#changeCam')){myCam=null;render();return}
    var s=e.target.closest('[data-shot]');
    if(s&&state&&!state.live){
      commentShot={item:s.getAttribute('data-item'),cue:s.getAttribute('data-shot')};
      $('commentFor').textContent=s.querySelector('.body b').textContent;
      $('author').value=store.get('oncue.author')||'';$('commentText').value='';
      $('sheet').classList.add('open');setTimeout(function(){$('commentText').focus()},50);
    }
  });
  $('cancelComment').onclick=function(){$('sheet').classList.remove('open')};
  $('commentForm').onsubmit=function(e){
    e.preventDefault();if(!commentShot)return;
    var author=$('author').value.trim();store.set('oncue.author',author);
    fetch('/api/comment',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({itemID:commentShot.item,cueID:commentShot.cue,author:author,text:$('commentText').value})})
      .then(function(){$('sheet').classList.remove('open')}).catch(function(){alert('Could not send the comment. Check the Wi-Fi.')});
  };
  setInterval(tick,100);
  connect();
})();
</script>
</body>
</html>
"""#
}
