const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {NES,Controller:C} = require('jsnes');
const {PNG} = require('pngjs');
const root = path.resolve(__dirname,'..');
const rom = fs.readFileSync(path.join(root,'public/frontier.nes'));
const asm = fs.readFileSync(path.join(root,'src/asm/Frontier.asm'),'utf8');
const V = {};let address=0;
for(const m of asm.matchAll(/^(\w+)\s+\.rs\s+(\d+)/gm)){V[m[1]]=address;address+=Number(m[2]);}
const symbols={};
for(const m of fs.readFileSync(path.join(root,'src/asm/Frontier.fns'),'utf8').matchAll(/^(\w+)\s+= \$([0-9A-F]+)/gm))symbols[m[1]]=parseInt(m[2],16);
for(const m of asm.matchAll(/^(\w+)\s*= \$([0-9A-F]+)/gm))symbols[m[1]]=parseInt(m[2],16);
const timingMarkers=new Set(['GameStateChooser','UpdateBackground','LoadGameSprites','FrameLogicDone'].map(name=>symbols[name]));
let framebuffer, audioEnergy=0;
function boot(battery){
  const nes=new NES({onFrame:f=>framebuffer=f.slice(),onAudioSample:(l,r)=>audioEnergy+=Math.abs(l)+Math.abs(r)});
  nes.loadROM(rom.toString('binary'));
  if(battery)for(let i=0;i<battery.length;i++)nes.cpu.mem[0x6000+i]=battery[i];
  const cpu=nes.cpu, stack=[];
  nes.timing={maxNmi:0,maxPpu:0,overruns:0,peak:null};
  const nmi=cpu.doNonMaskableInterrupt.bind(cpu), emulate=cpu.emulate.bind(cpu);
  cpu.doNonMaskableInterrupt=function(status){
    if(!(this.mem[0x2000]&128))return nmi(status);
    if(stack.length)nes.timing.overruns++;
    stack.push({cycles:7});return nmi(status);
  };
  cpu.emulate=function(){
    const pc=this.REG_PC+1, opcode=nes.mmap.load(pc), interrupted=this.irqRequested&&this.irqType===1;
    if(stack.length&&pc===symbols.FrameGraphicsDone)nes.timing.maxPpu=Math.max(nes.timing.maxPpu,stack.at(-1).cycles);
    if(stack.length&&timingMarkers.has(pc))stack.at(-1)[pc]=stack.at(-1).cycles;
    if(stack.length&&pc===symbols.OverlayPrepared){
      nes.lastOverlay={scroll:cpu.mem[V.scrollpage]*256+cpu.mem[V.scrollx],
        keys:Array.from({length:cpu.mem[V.newlen]},(_,i)=>cpu.mem[symbols.newhi+i]*256+cpu.mem[symbols.newlo+i])};
    }
    const halt=this.cyclesToHalt, cycles=emulate();
    for(const active of stack)active.cycles+=cycles+Math.max(0,this.cyclesToHalt-halt);
    if(stack.length&&opcode===0x40&&!interrupted){
      const active=stack.pop();
      if(active.cycles>nes.timing.maxNmi){
        nes.timing.maxNmi=active.cycles;
        nes.timing.peak={stages:active,vars:Object.fromEntries(['phaserangle','beamtx','beamty','newlen','oldlen','queuecount','oamindex'].map(name=>[name,cpu.mem[V[name]]]))};
      }
    }
    return cycles;
  };
  for(let i=0;i<8;i++)nes.frame();
  return nes;
}
let nes=boot();
const run=n=>{for(let i=0;i<n;i++)nes.frame();};
const get=name=>nes.cpu.mem[V[name]];
const set=(name,value)=>{nes.cpu.mem[V[name]]=value;};
const button=(key,frames)=>{nes.buttonDown(1,key);run(frames);nes.buttonUp(1,key);run(1);};
const clear=()=>{for(let i=0;i<4;i++)nes.cpu.mem[0x300+i]=0;for(let i=0;i<8;i++)nes.cpu.mem[0x340+i]=0;set('spawnclock',250);set('phaserheat',0);set('phaseroverheated',0);set('sfxheat',0);};
const enemy=(slot,type,x,y,hp=120)=>{
  for(const [base,val] of [[0x300,type],[0x304,x],[0x308,y],[0x30c,hp],[0x310,90],[0x314,0],[0x318,Math.max(120,hp)]])nes.cpu.mem[base+slot]=val;
};
const digits=base=>Number(nes.cpu.mem.slice(base,base+5).join(''));
const score=()=>digits(V.score);
const best=()=>digits(0x6002);
function check(name,fn){fn();console.log(`PASS ${name}`);}
const qa=path.join(process.env.HOME,'.local/state/nesfrontier-qa');
fs.mkdirSync(qa,{recursive:true});
function saveFrame(name){
  const png=new PNG({width:256,height:240});
  for(let i=0;i<framebuffer.length;i++){
    png.data[i*4]=framebuffer[i]&255;png.data[i*4+1]=(framebuffer[i]>>8)&255;
    png.data[i*4+2]=(framebuffer[i]>>16)&255;png.data[i*4+3]=255;
  }
  fs.writeFileSync(path.join(qa,name),PNG.sync.write(png));
}

check('valid mapper-0 cartridge and exact CHR bank',()=>{
  assert.equal(rom.length,24592);assert.equal(rom[4],1);assert.equal(rom[5],1);assert.equal(rom[6]&0xf0,0);
  assert.equal(rom[6]&3,3,'Vertical mirroring and battery RAM must be declared');
  assert.deepEqual(rom.subarray(16400),fs.readFileSync(path.join(root,'src/asm/sprites.chr')));
  assert.equal(get('shields'),3);assert.equal(get('gamestate'),0);
  assert(framebuffer.filter(p=>p!==0).length>100);
});
check('controller input moves vertically and stops at bounds',()=>{
  clear();const y=get('shipypos');button(C.BUTTON_UP,10);assert(get('shipypos')<y);
  button(C.BUTTON_DOWN,200);assert.equal(get('shipypos'),196);
  clear();button(C.BUTTON_UP,360);assert.equal(get('shipypos'),56);
  set('shipypos',108);
});
check('impulse changes starfield and enemy velocity',()=>{
  clear();enemy(0,1,232,50);set('scrollfraction',0);set('enemyfraction',0);
  let start=get('scrollx');nes.buttonDown(1,C.BUTTON_RIGHT);run(16);
  assert.equal(get('shipspeed'),3);assert.equal((get('scrollx')-start+256)%256,12);
  assert.equal(nes.cpu.mem[0x304],220);
  nes.buttonUp(1,C.BUTTON_RIGHT);nes.buttonDown(1,C.BUTTON_LEFT);start=get('scrollx');run(16);
  assert.equal(get('shipspeed'),1);assert.equal((get('scrollx')-start+256)%256,4);
  assert.equal(nes.cpu.mem[0x304],216);
  nes.buttonUp(1,C.BUTTON_LEFT);run(1);assert.equal(get('shipspeed'),2);
  set('scrollx',255);set('scrollfraction',3);const page=get('scrollpage');run(1);assert.equal(get('scrollpage'),page^1);
});
check('pause freezes the assembly simulation; Start resumes',()=>{
  button(C.BUTTON_START,1);assert.equal(get('gamestate'),1);
  const x=get('scrollx');const f=get('frame');run(15);
  assert.equal(get('scrollx'),x);assert.equal(get('frame'),f);
  button(C.BUTTON_START,1);assert.equal(get('gamestate'),0);
});
check('sprite pause menu renders, selects resume/restart, and clears on return',()=>{
  for(const parity of [0,1]){
    clear();set('frame',parity);set('shipypos',108);enemy(0,3,200,45,60);
    const y=get('shipypos'),charge=get('shieldcharge');
    button(C.BUTTON_START,2);run(16);
    assert.equal(get('gamestate'),1);assert.equal(get('pausechoice'),0);
    assert.equal(get('newlen'),64);assert.equal(get('oldlen'),64);
    assert.equal(get('queueread'),get('queuecount'));
    assert.equal(get('oamindex'),28,'Only the seven paired menu sprites are visible');
    assert.equal(get('shipypos'),y);assert.equal(get('shieldcharge'),charge);
    assert.equal(nes.cpu.mem[0x30c],60);
    saveFrame('pause.png');
    button(C.BUTTON_DOWN,2);assert.equal(get('pausechoice'),1);assert.equal(get('shipypos'),y);
    button(C.BUTTON_UP,2);assert.equal(get('pausechoice'),0);
    button(C.BUTTON_A,2);assert.equal(get('gamestate'),0);assert.equal(nes.cpu.mem[0x30c],60);
    clear();run(16);assert.equal(get('oldlen'),0);assert(get('oamindex')>28);
  }
  clear();set('shipypos',160);set('shields',1);set('torpedoes',0);set('sector',2);
  button(C.BUTTON_START,2);run(12);button(C.BUTTON_DOWN,2);button(C.BUTTON_A,2);
  assert.equal(get('gamestate'),0);assert.equal(get('shipypos'),108);
  assert.equal(get('shields'),3);assert.equal(get('torpedoes'),2);assert.equal(get('sector'),0);
  assert.equal(get('shieldcharge'),120);run(16);
  assert.equal(get('oldlen'),0);assert.equal(nes.timing.overruns,0);
});
check('phaser misses unaligned targets; Up/Down manually rotate without moving the ship',()=>{
  clear();set('shipypos',108);set('phaserangle',3);enemy(0,3,210,45);enemy(1,2,220,178);
  const ammo=get('torpedoes');nes.buttonDown(1,C.BUTTON_A);run(10);
  assert.equal(get('phasertarget'),255);assert.equal(get('phaseractive'),1);
  assert.equal(nes.cpu.mem[0x30c],120);assert.equal(nes.cpu.mem[0x30d],120);
  assert.equal(get('beamty'),124);assert.equal(get('beamtx'),248);
  assert.equal(get('torpedoes'),ammo);
  assert(!nes.cpu.mem.slice(0x340,0x348).includes(1),'Phaser must never be a moving bolt');
  set('frame',1);button(C.BUTTON_UP,2);assert.equal(get('phaserangle'),2);assert.equal(get('shipypos'),108);
  set('frame',1);button(C.BUTTON_UP,2);assert.equal(get('phaserangle'),1);
  run(1);assert.equal(get('phasertarget'),0);assert(nes.cpu.mem[0x30c]<120);
  button(C.BUTTON_DOWN,32);assert.equal(get('phaserangle'),6);assert.equal(get('shipypos'),108);
  button(C.BUTTON_UP,64);assert.equal(get('phaserangle'),0);
  nes.buttonUp(1,C.BUTTON_A);run(1);assert.equal(get('phaseractive'),0);
});
check('60 contact frames burn a cruiser; partial damage persists on release',()=>{
  clear();set('phaserangle',3);set('shipypos',108);enemy(0,3,232,112);
  nes.buttonDown(1,C.BUTTON_A);run(30);nes.buttonUp(1,C.BUTTON_A);run(5);
  assert.equal(nes.cpu.mem[0x30c],60);assert.equal(nes.cpu.mem[0x300],3);
  nes.buttonDown(1,C.BUTTON_A);run(29);assert.equal(nes.cpu.mem[0x30c],2);
  run(1);assert.equal(nes.cpu.mem[0x300],4);nes.buttonUp(1,C.BUTTON_A);run(1);
});
check('manual ray hits all seven angles and only damages the nearest intersected object',()=>{
  for(let angle=0;angle<7;angle++){
    clear();set('shipypos',108);set('phaserangle',angle);
    const slope=[-1,-0.5,-0.25,0,0.25,0.5,1][angle],y=124+64*slope-8;
    enemy(0,1,132,y);nes.buttonDown(1,C.BUTTON_A);run(1);
    assert.equal(get('phasertarget'),0,'angle '+angle);assert.equal(nes.cpu.mem[0x30c],118);
    nes.buttonUp(1,C.BUTTON_A);run(1);
  }
  clear();set('phaserangle',3);enemy(0,1,210,116);enemy(1,1,132,116);
  nes.buttonDown(1,C.BUTTON_A);run(1);assert.equal(get('phasertarget'),1);
  assert.equal(nes.cpu.mem[0x30c],120);assert.equal(nes.cpu.mem[0x30d],118);
  nes.buttonUp(1,C.BUTTON_A);run(1);
});
check('angled beam clips to the playfield and restores underlying stars on release',()=>{
  clear();set('phaserangle',0);set('shipypos',180);
  nes.buttonDown(1,C.BUTTON_A);run(6);assert.equal(get('beamty'),28);assert.equal(get('beamtx'),236);
  assert(get('newlen')>10);assert(get('queuecount')<=144);assert(get('queueread')<=get('queuecount'));
  nes.buttonUp(1,C.BUTTON_A);clear();run(16);
  for(let i=0;i<20&&(get('queueread')!==get('queuecount')||get('overlaypending'));i++)run(1);
  assert.equal(get('queueread'),get('queuecount'));assert.equal(get('overlaypending'),0);
  assert.equal(get('oldlen'),0); // floating scores and meters never occupy background tiles
  const overlay=new Set(Array.from({length:get('oldlen')},(_,i)=>(nes.cpu.mem[symbols.oldhi+i]*256+nes.cpu.mem[symbols.oldlo+i])-0x2000));
  for(let i=0;i<2048;i++)if(!overlay.has(i))assert.equal(nes.ppu.vramMem[0x2000+i],rom[16+0x3000+i],'Starfield restored at '+i);
});
check('one photon torpedo destroys a Klingon and spends one charge',()=>{
  clear();set('shipypos',108);set('torpedocool',0);set('torpedoes',2);enemy(0,3,92,116);
  button(C.BUTTON_B,12);assert.equal(nes.cpu.mem[0x300],4);assert.equal(get('torpedoes'),1);
});
check('torpedoes destroy either asteroid size immediately on impact',()=>{
  for(const type of [1,2]){
    clear();set('shipypos',108);set('torpedocool',0);set('torpedoes',2);enemy(0,type,92,128);
    button(C.BUTTON_B,12);assert.equal(nes.cpu.mem[0x300],4);assert.equal(get('torpedoes'),1);
  }
});
check('held shield absorbs shots and collisions; exhaustion requires release; charge regenerates',()=>{
  clear();set('shipypos',108);set('invuln',0);set('shields',3);set('shieldcharge',120);set('shieldlatched',0);
  nes.buttonDown(1,C.BUTTON_SELECT);
  nes.cpu.mem[0x340]=3;nes.cpu.mem[0x348]=55;nes.cpu.mem[0x350]=116;run(1);
  assert.equal(get('shieldactive'),1);assert.equal(get('shields'),3);assert.equal(nes.cpu.mem[0x340],0);
  enemy(0,1,45,112);run(1);assert.equal(get('shields'),3);assert.equal(nes.cpu.mem[0x300],4);
  clear();run(118);assert.equal(get('shieldcharge'),0);assert.equal(get('shieldactive'),1);
  run(1);assert.equal(get('shieldactive'),0);assert.equal(get('shieldlatched'),1);
  run(8);assert.equal(get('shieldcharge'),0);
  nes.buttonUp(1,C.BUTTON_SELECT);run(4);assert.equal(get('shieldcharge'),1);assert.equal(get('shieldlatched'),0);
  set('shieldcharge',119);set('frame',3);run(1);assert.equal(get('shieldcharge'),120);
});
check('unprotected hull damage, invulnerability, destruction and A/Enter restart',()=>{
  clear();set('invuln',0);set('shields',3);enemy(0,1,45,112);run(1);
  assert.equal(get('shields'),2);assert(get('invuln')>0);
  enemy(0,1,45,112);run(1);assert.equal(get('shields'),2);
  for(let i=0;i<2;i++){set('invuln',0);enemy(0,1,45,112);run(1);}
  assert.equal(get('gamestate'),2);assert.equal(get('shields'),0);
  run(55);assert.equal(get('deathclock'),0);
  button(C.BUTTON_A,1);assert.equal(get('gamestate'),0);assert.equal(get('shields'),3);
});
check('shield and photon recharge timers',()=>{
  clear();set('shields',2);set('regen',119);set('torpedoes',1);set('recharge',44);set('frame',3);
  run(1);assert.equal(get('shields'),3);assert.equal(get('torpedoes'),2);
});
check('Klingon disruptor hits shields and clips left edge',()=>{
  clear();set('invuln',0);set('shipypos',108);set('shields',3);
  nes.cpu.mem[0x340]=3;nes.cpu.mem[0x348]=55;nes.cpu.mem[0x350]=116;run(1);
  assert.equal(get('shields'),2);assert.equal(nes.cpu.mem[0x340],0);
  nes.cpu.mem[0x340]=3;nes.cpu.mem[0x348]=0;nes.cpu.mem[0x350]=20;run(1);
  assert.equal(nes.cpu.mem[0x340],0);
});
check('survival advances asteroid / Klingon / mixed sectors and difficulty',()=>{
  clear();set('difficulty',0);set('sector',0);set('sectorclock',255);set('frame',3);run(1);assert.equal(get('sector'),1);assert.equal(get('difficulty'),1);
  set('sectorclock',255);set('frame',3);run(1);assert.equal(get('sector'),2);assert.equal(get('difficulty'),2);
  set('sectorclock',255);set('frame',3);run(1);assert.equal(get('sector'),0);assert.equal(get('difficulty'),3);
  set('difficulty',8);set('sectorclock',255);set('frame',3);run(1);assert.equal(get('difficulty'),8);
});
check('phaser heat, audible overload, cooldown and pause freeze',()=>{
  nes=boot();clear();set('shipypos',108);set('scoreclock',60);
  nes.buttonDown(1,C.BUTTON_A);run(60);
  assert.equal(get('phaserheat'),60);assert.equal(get('phaseractive'),1);
  nes.buttonUp(1,C.BUTTON_A);run(10);assert.equal(get('phaserheat'),30);
  button(C.BUTTON_START,1);const heat=get('phaserheat'),clock=get('scoreclock');run(20);
  assert.equal(get('phaserheat'),heat);assert.equal(get('scoreclock'),clock);
  button(C.BUTTON_A,1);assert.equal(get('gamestate'),0);
  clear();nes.buttonDown(1,C.BUTTON_A);run(191);
  assert.equal(get('phaserheat'),191);assert.equal(get('phaseractive'),1);
  run(1);assert.equal(get('phaserheat'),192);assert.equal(get('phaseroverheated'),1);
  assert.equal(get('phaseractive'),0);assert.equal(get('sfxphaser'),0);assert(get('sfxheat')>0);
  const beforeAudio=audioEnergy;run(8);assert(audioEnergy>beforeAudio);
  assert(get('sfxheat')>0);assert.equal(get('phaseractive'),0);
  saveFrame('overheat.png');
  run(87);assert.equal(get('phaserheat'),2);assert.equal(get('phaseroverheated'),1);
  run(1);assert.equal(get('phaserheat'),0);assert.equal(get('phaseroverheated'),0);
  run(1);assert.equal(get('phaserheat'),1);assert.equal(get('phaseractive'),1);
  nes.buttonUp(1,C.BUTTON_A);run(1);assert.equal(get('phaserheat'),0);
});
check('survival, kill rewards, decimal carry, record retention and saturation',()=>{
  nes=boot();clear();set('scoreclock',60);run(59);assert.equal(score(),0);
  run(1);assert.equal(score(),1);assert.equal(best(),1);
  button(C.BUTTON_START,1);const current=score();run(120);assert.equal(score(),current);
  button(C.BUTTON_A,1);
  for(const [type,points] of [[1,25],[2,50],[3,100]]){
    clear();set('scoreclock',60);set('phaserangle',3);enemy(0,type,132,116,2);
    const before=score();button(C.BUTTON_A,1);
    assert.equal(nes.cpu.mem[0x300],4);assert.equal(score()-before,points);assert.equal(best(),score());
    run(20);assert.equal(score()-before,points,'An explosion cannot award points twice');
  }
  clear();set('scoreclock',60);set('invuln',0);enemy(0,1,45,112);
  const beforeRam=score();run(1);assert.equal(score(),beforeRam,'Ramming cannot farm weapon rewards');
  const record=best();set('gamestate',2);run(120);assert.equal(score(),beforeRam);
  button(C.BUTTON_A,1);assert.equal(score(),0);assert.equal(best(),record);
  clear();[0,0,9,9,9].forEach((d,i)=>nes.cpu.mem[V.score+i]=d);
  set('scoreclock',1);run(1);assert.equal(score(),1000);assert.equal(best(),1000);
  [9,9,9,9,0].forEach((d,i)=>nes.cpu.mem[V.score+i]=d);
  set('scoreclock',60);enemy(0,3,132,116,2);button(C.BUTTON_A,1);
  assert.equal(score(),99999);assert.equal(best(),99999);
  set('scoreclock',1);run(1);assert.equal(score(),99999);
  const battery=nes.cpu.mem.slice(0x6000,0x6008);
  nes=boot(battery);assert.equal(best(),99999);assert.equal(score(),0);
  for(const offset of [0,2,7]){
    const damaged=battery.slice();damaged[offset]^=0x80;
    nes=boot(damaged);assert.equal(best(),0,'Invalid battery record at byte '+offset);
  }
});
check('later enemies have more HP, faster fire, faster travel and proportional health bars',()=>{
  for(const level of [0,8]){
    nes=boot();clear();set('difficulty',level);set('sector',1);set('spawnclock',1);run(1);
    assert.equal(nes.cpu.mem[0x300],3);assert.equal(nes.cpu.mem[0x30c],120+16*level);
    assert.equal(nes.cpu.mem[0x318],120+16*level);assert.equal(get('spawnclock'),160-8*level);
    clear();enemy(0,3,220,60);nes.cpu.mem[0x310]=1;set('enemyfraction',0);run(1);
    assert.equal(nes.cpu.mem[0x310],156-8*level);assert.equal(nes.cpu.mem[0x340],3);
    clear();enemy(0,1,220,60);set('enemyfraction',0);run(16);
    assert.equal(nes.cpu.mem[0x304],level===0?212:204);
  }
  nes=boot();clear();set('phaserangle',3);enemy(0,2,232,116,248);
  nes.buttonDown(1,C.BUTTON_A);run(123);assert.equal(nes.cpu.mem[0x30c],2);
  run(1);assert.equal(nes.cpu.mem[0x300],4);nes.buttonUp(1,C.BUTTON_A);run(1);
  clear();set('torpedocool',0);set('torpedoes',2);enemy(0,3,92,116,248);
  button(C.BUTTON_B,12);assert.equal(nes.cpu.mem[0x300],4,'Torpedoes bypass scaled health');
  const health=Array.from({length:9},(_,i)=>rom[16+symbols.healthtiles-0xc000+i]);
  for(const [hp,left,right] of [[248,8,8],[124,8,0],[1,1,0]]){
    clear();enemy(0,2,200,180,hp);nes.cpu.mem[0x318]=248;run(8);
    const world=(get('scrollpage')*256+get('scrollx')+nes.cpu.mem[0x304]+4)&511;
    const address=0x2000+(world>>8)*1024+21*32+((world&255)>>3);
    const tileAt=address=>{
      for(let i=0;i<get('newlen');i++)if(nes.cpu.mem[symbols.newhi+i]*256+nes.cpu.mem[symbols.newlo+i]===address)return nes.cpu.mem[symbols.newdata+i];
    };
    assert.equal(tileAt(address),health[left]);assert.equal(tileAt(address+1),health[right]);
  }
});
check('full shield, three cruisers and three shots fit OAM with every manual beam angle',()=>{
  clear();set('shipypos',108);set('invuln',0);set('torpedoes',2);set('shields',3);
  nes.buttonDown(1,C.BUTTON_RIGHT);nes.buttonDown(1,C.BUTTON_A);nes.buttonDown(1,C.BUTTON_SELECT);
  for(let angle=0;angle<7;angle++){
    clear();set('phaserangle',angle);set('shieldcharge',120);set('shieldlatched',0);
    for(let slot=0;slot<3;slot++){
      enemy(slot,3,80+slot,180+10*slot);
      nes.cpu.mem[0x340+slot]=3;nes.cpu.mem[0x348+slot]=210;nes.cpu.mem[0x350+slot]=30+30*slot;
    }
    run(8);assert.equal(get('phasertarget'),255);assert.equal(get('oamindex'),228);
    assert.equal(get('gamestate'),0);
  }
  assert(nes.timing.maxPpu<2250);assert.equal(nes.timing.overruns,0);
  nes.buttonUp(1,C.BUTTON_RIGHT);nes.buttonUp(1,C.BUTTON_A);nes.buttonUp(1,C.BUTTON_SELECT);run(1);
});
check('scores align, speed and ammo stay at the top, and both meters follow the ship',()=>{
  nes=boot();clear();
  const meterTiles=Array.from({length:9},(_,i)=>rom[16+symbols.metertiles-0xc000+i]);
  const hotTiles=Array.from({length:9},(_,i)=>rom[16+symbols.hottiles-0xc000+i]);
  const sprites=()=>Array.from({length:get('oamindex')/4},(_,i)=>{
    const address=0x200+i*4;
    return {y:nes.cpu.mem[address]+1,tile:nes.cpu.mem[address+1],attr:nes.cpu.mem[address+2],x:nes.cpu.mem[address+3]};
  });
  const glyphs=[
    '111101101101101101111','010010010010010010010','111001001111100100111',
    '111001001111001001111','101101101111001001001','111100100111001001111',
    '111100100111101101111','111001001001001001001','111101101111101101111',
    '111101101111001001111'
  ];
  // Rasterize the first eight sprites on each scanline, including CHR-bank
  // selection and flips. This catches hardware dropout and misplaced ink.
  const pixel=(list,x,y)=>{
    const selected=list.filter(s=>y>=s.y&&y<s.y+16).slice(0,8);
    for(const s of selected){
      if(x<s.x||x>=s.x+8)continue;
      let row=y-s.y,col=x-s.x;
      if(s.attr&128)row=15-row;
      if(s.attr&64)col=7-col;
      const tile=(s.tile&254)+(row>>3);
      const base=16400+(s.tile&1)*4096+tile*16+(row&7);
      const color=((rom[base]>>(7-col))&1)|(((rom[base+8]>>(7-col))&1)<<1);
      if(color)return color;
    }
    return 0;
  };
  const assertNumber=(list,digits,x)=>{
    digits.forEach((digit,i)=>{
      for(let row=0;row<7;row++)for(let col=0;col<4;col++){
        const expected=col<3&&glyphs[digit][row*3+col]==='1'?2:0;
        assert.equal(pixel(list,x+i*4+col,25+row),expected,
          'Score pixel '+digit+' at '+(x+i*4+col)+','+(25+row));
      }
    });
  };
  nes.buttonDown(1,C.BUTTON_RIGHT);
  for(const y of [56,108,196])for(const scroll of [0,1,7,31,127,255]){
    set('shipypos',y);set('scrollx',scroll);set('scrollpage',scroll&1);
    set('shieldcharge',120);set('phaserheat',96);set('scoreclock',60);
    [1,2,3,4,5].forEach((d,i)=>nes.cpu.mem[V.score+i]=d);
    [9,8,7,6,5].forEach((d,i)=>nes.cpu.mem[0x6002+i]=d);
    run(6);const list=sprites();
    assertNumber(list,[1,2,3,4,5],72);
    assertNumber(list,[9,8,7,6,5],136);
    for(const x of [14,22,30,104,112,120,222,230])
      assert(list.some(s=>s.x===x&&s.y===8),'Missing top indicator at '+x);
    assert(list.some(s=>s.x===24&&s.y===y-16&&s.tile===meterTiles[8]));
    assert(list.some(s=>s.x===32&&s.y===y-16&&s.tile===meterTiles[8]));
    assert(list.some(s=>s.x===48&&s.y===y-16&&s.tile===hotTiles[8]));
    assert(list.some(s=>s.x===56&&s.y===y-16&&hotTiles.includes(s.tile)));
    assert(list.some(s=>s.x===64&&s.y===y-16&&s.tile===hotTiles[0]));
    assert.equal(get('oldlen'),0);assert.equal(get('newlen'),0);
    // Flipped digit patterns begin above their ink. Their overlap with the
    // top indicators occurs only in blank rows; every visible row fits.
    for(const row of [...Array.from({length:8},(_,i)=>8+i),...Array.from({length:7},(_,i)=>25+i)])
      assert(list.filter(s=>row>=s.y&&row<s.y+16).length<=8,'Header scanline overflow at '+row);
  }
  nes.buttonUp(1,C.BUTTON_RIGHT);
  for(let pair=0;pair<100;pair++){
    clear();set('scoreclock',60);
    const a=Math.floor(pair/10),b=pair%10;
    const current=[a,b,9,a,b],record=[9,a,b,b,a];
    current.forEach((d,i)=>nes.cpu.mem[V.score+i]=d);
    record.forEach((d,i)=>nes.cpu.mem[0x6002+i]=d);
    run(4);const list=sprites();
    assertNumber(list,current,72);assertNumber(list,record,136);
  }
  for(const [key,speed] of [[C.BUTTON_LEFT,1],[null,2],[C.BUTTON_RIGHT,3]]){
    if(key!==null)nes.buttonDown(1,key);
    run(4);
    const chevrons=sprites().filter(s=>s.y===8&&[104,112,120].includes(s.x));
    assert.equal(chevrons.length,speed);
    if(key!==null)nes.buttonUp(1,key);
  }
});
check('long beams and a complete floating HUD fit OAM and NTSC timing',()=>{
  nes=boot();let peakOverlay=0;
  const pairTiles=new Set(Array.from({length:100},(_,i)=>rom[16+symbols.digitpairtiles-0xc000+i]));
  nes.buttonDown(1,C.BUTTON_RIGHT);nes.buttonDown(1,C.BUTTON_A);nes.buttonDown(1,C.BUTTON_SELECT);
  for(const y of [56,108,180,196])for(let angle=0;angle<7;angle++)for(let phase=0;phase<8;phase++){
    clear();set('shipypos',y);set('phaserangle',angle);set('scrollx',phase);
    set('difficulty',8);set('invuln',0);set('shields',3);set('torpedoes',2);
    set('shieldcharge',120);set('shieldlatched',0);
    for(let slot=0;slot<3;slot++){
      enemy(slot,3,84+slot,y<=108?180+10*slot:36+10*slot,124);nes.cpu.mem[0x318+slot]=248;
      nes.cpu.mem[0x340+slot]=3;nes.cpu.mem[0x348+slot]=220;nes.cpu.mem[0x350+slot]=80+30*slot;
    }
    run(8);const overlay=nes.lastOverlay;peakOverlay=Math.max(peakOverlay,overlay.keys.length);
    assert(overlay.keys.length<=72);assert.equal(get('gamestate'),0);assert.equal(get('oamindex'),228);
    const positions=Array.from({length:get('oamindex')/4},(_,i)=>{
      const address=0x200+i*4,attr=nes.cpu.mem[address+2],pair=pairTiles.has(nes.cpu.mem[address+1]);
      return [nes.cpu.mem[address+3]+(pair&&(attr&64)?1:0),nes.cpu.mem[address]+1+(pair&&(attr&128)?7:0)];
    });
    for(const [x,row,count] of [[24,y-16,2],[104,8,3],[222,8,2],[128,24,1],[48,y-16,3]]){
      for(let i=0;i<count;i++)assert(positions.some(([sx,sy])=>sx===x+i*8&&sy===row),`HUD missing at ${y}/${angle}/${phase}: ${x}/${row}/${i}`);
    }
    for(const x of [72,136])for(const offset of [0,8,12])
      assert(positions.some(([sx,sy])=>sx===x+offset&&sy===24),'Aligned score pair missing');
  }
  console.log(`  Peak ${peakOverlay}/72 background tiles; ${nes.timing.maxNmi} NMI cycles; ${nes.timing.overruns} overruns.`);
  assert.equal(nes.timing.overruns,0);assert(nes.timing.maxNmi<29780);assert(nes.timing.maxPpu<2250);
  button(C.BUTTON_START,1);run(12);assert.equal(get('oldlen'),64);
  button(C.BUTTON_START,1);run(12);assert.equal(get('gamestate'),0);
  nes.buttonUp(1,C.BUTTON_RIGHT);nes.buttonUp(1,C.BUTTON_A);nes.buttonUp(1,C.BUTTON_SELECT);
});
check('ten-thousand-frame CPU, spawning, firing and OAM soak',()=>{
  nes=boot();let sectors=new Set(),types=new Set(),maxOam=0;
  nes.buttonDown(1,C.BUTTON_A);nes.buttonDown(1,C.BUTTON_B);
  for(let i=0;i<10000;i++){
    if(i%180===0)set('phaserangle',Math.floor(i/180)%7);
    if(i%240===0){set('shieldcharge',120);nes.buttonDown(1,C.BUTTON_SELECT);}
    if(i%240===120)nes.buttonUp(1,C.BUTTON_SELECT);
    set('invuln',200);nes.frame();sectors.add(get('sector'));
    for(let j=0;j<4;j++)types.add(nes.cpu.mem[0x300+j]);
    assert(get('oamindex')<=252);
    maxOam=Math.max(maxOam,get('oamindex')/4);
    assert.equal(get('gamestate'),0);
    assert.equal(nes.cpu.mem[0x303],0);
    for(let j=3;j<8;j++)assert.equal(nes.cpu.mem[0x340+j],0);
    assert(!nes.cpu.mem.slice(0x340,0x348).includes(1));
    assert(get('newlen')<=72);assert(get('queuecount')<=144);assert(get('queueread')<=get('queuecount'));
  }
  nes.buttonUp(1,C.BUTTON_A);nes.buttonUp(1,C.BUTTON_B);
  assert.equal(sectors.size,3);for(const type of [1,2,3,4])assert(types.has(type));
  assert.equal(get('difficulty'),8);
  assert(audioEnergy>0);
  assert(nes.timing.maxPpu<2250,'PPU writes must fit in NTSC vblank');
  console.log(`  Observed all sectors and enemies; peak ${maxOam}/64 OAM sprites; APU audio emitted.`);
  console.log(`  Timing: ${nes.timing.maxPpu} cycles for vblank writes; ${nes.timing.maxNmi} cycles peak NMI; ${nes.timing.overruns} guarded overruns.`);
  if(nes.timing.overruns)console.log(nes.timing.peak);
  assert.equal(nes.timing.overruns,0,'Simulation must complete before the next NMI');
});

// Representative scene rendered by the ROM, with deterministic test fixtures.
nes=boot();clear();set('shipypos',108);enemy(0,3,194,54,85);enemy(1,2,156,172,65);enemy(2,1,225,113,110);set('phaserangle',1);
nes.buttonDown(1,C.BUTTON_A);
nes.buttonDown(1,C.BUTTON_SELECT);
nes.cpu.mem[0x340]=2;nes.cpu.mem[0x348]=104;nes.cpu.mem[0x350]=133;
run(8);
saveFrame('gameplay.png');
console.log('All emulator checks passed.');
