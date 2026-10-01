(() => {
  const canvas=document.getElementById('screen');
  const ctx=canvas.getContext('2d',{alpha:false});
  const pixels=ctx.createImageData(256,240);
  const buffer=new Uint32Array(pixels.data.buffer);
  const play=document.getElementById('play');
  let running=false,loaded=false,audio,sound=true;
  let last=0,accumulator=0,samples=[],audioTime=0;
  const saveKey='nes-frontier-sram-v1';
  let saveDirty=false;
  const nes=new jsnes.NES({
    sampleRate:44100,
    onBatteryRamWrite(address) {
      if(address>=0x6000&&address<0x6008)saveDirty=true;
    },
    onFrame(frame) {
      for(let i=0;i<frame.length;i++)buffer[i]=0xff000000|frame[i];
      ctx.putImageData(pixels,0,0);
    },
    onAudioSample(left,right) {
      if(!sound||!audio||audio.state!=='running')return;
      samples.push((left+right)*0.25);
      if(samples.length<2048)return;
      const chunk=audio.createBuffer(1,samples.length,44100);
      chunk.copyToChannel(Float32Array.from(samples),0);
      samples=[];
      const source=audio.createBufferSource();
      source.buffer=chunk;source.connect(audio.destination);
      audioTime=Math.max(audioTime,audio.currentTime+0.02);
      if(audioTime>audio.currentTime+0.25)audioTime=audio.currentTime+0.02;
      source.start(audioTime);audioTime+=chunk.duration;
    }
  });
  const C=jsnes.Controller;
  const keys={ArrowUp:C.BUTTON_UP,KeyW:C.BUTTON_UP,ArrowDown:C.BUTTON_DOWN,KeyS:C.BUTTON_DOWN,
    ArrowLeft:C.BUTTON_LEFT,ArrowRight:C.BUTTON_RIGHT,KeyZ:C.BUTTON_A,Enter:C.BUTTON_A,KeyX:C.BUTTON_B,KeyC:C.BUTTON_SELECT,KeyP:C.BUTTON_START};
  const held=new Set();
  function input(code,down) {
    if(!loaded||!(code in keys))return;
    down?held.add(code):held.delete(code);
    const button=keys[code];
    [...held].some(key=>keys[key]===button)?nes.buttonDown(1,button):nes.buttonUp(1,button);
  }
  function release() {
    held.clear();
    for(const button of new Set(Object.values(keys)))nes.buttonUp(1,button);
    last=0;accumulator=0;
  }
  function start() {
    if(!loaded)return;
    if(!running){running=true;last=0;accumulator=0;play.hidden=true;canvas.focus();}
    if(sound){audio||=new AudioContext();audio.resume().catch(()=>{});}
  }
  function reset() {
    if(!loaded)return;
    const battery=nes.cpu.mem.slice(0x6000,0x6008);
    saveBattery();release();nes.reloadROM();restoreBattery(battery);samples=[];audioTime=0;start();
  }
  function restoreBattery(bytes) {
    try {
      bytes||=JSON.parse(localStorage.getItem(saveKey));
      if(!Array.isArray(bytes)||bytes.length!==8||!bytes.every(n=>Number.isInteger(n)&&n>=0&&n<=255))return;
      for(let i=0;i<8;i++)nes.cpu.mem[0x6000+i]=bytes[i];
    } catch {}
  }
  function saveBattery() {
    if(!saveDirty)return;
    saveDirty=false;
    try {localStorage.setItem(saveKey,JSON.stringify(nes.cpu.mem.slice(0x6000,0x6008)));} catch {}
  }
  document.addEventListener('keydown',event=>{
    if(event.ctrlKey||event.metaKey||event.altKey)return;
    if(event.code in keys){event.preventDefault();if(!event.repeat){start();input(event.code,true);}return;}
    if(event.repeat)return;
    if(event.code==='KeyR')reset();
    if(event.code==='KeyM'){sound=!sound;samples=[];if(sound)start();}
    if(event.code==='KeyF')document.fullscreenElement?document.exitFullscreen():canvas.requestFullscreen().catch(()=>{});
  });
  document.addEventListener('keyup',event=>input(event.code,false));
  window.addEventListener('blur',release);
  document.addEventListener('visibilitychange',release);
  window.addEventListener('pagehide',saveBattery);
  play.onclick=start;
  for(const button of document.querySelectorAll('[data-key]')){
    button.onpointerdown=event=>{event.preventDefault();button.setPointerCapture(event.pointerId);start();input(button.dataset.key,true);};
    button.onpointerup=button.onpointercancel=()=>input(button.dataset.key,false);
  }
  function tick(now) {
    if(!loaded||!running||document.hidden){last=0;return;}
    if(!last)last=now;
    accumulator+=Math.min(now-last,100);last=now;
    while(accumulator>=1000/60){nes.frame();accumulator-=1000/60;}
    saveBattery();
  }
  fetch('frontier.nes?v=9').then(response=>{
    if(!response.ok)throw Error('Unable to load cartridge');
    return response.arrayBuffer();
  }).then(bytes=>{
    nes.loadROM(String.fromCharCode(...new Uint8Array(bytes)));loaded=true;
    restoreBattery();
    for(let i=0;i<8;i++)nes.frame();
    saveBattery();
    play.disabled=false;setInterval(()=>tick(performance.now()),1000/60);
  }).catch(error=>{
    play.hidden=true;const message=document.getElementById('error');message.hidden=false;message.textContent=error.message;
  });
  window.frontier={nes,start,reset,input,get running(){return running},get loaded(){return loaded}};
})();
