; NES Frontier
; A side scrolling space game written in 6502 assembly.
; NESASM header, reset, and game states
;
; Author: Jakob Langtry

  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 3   ; vertical mirroring and battery-backed high score

  .rsset $0000

; declaring and reserving bytes for variables
frame              .rs 1
p1buttons          .rs 1
oldp1buttons       .rs 1
p1pressed          .rs 1
gamestate          .rs 1       ; 0 playing, 1 paused, 2 destroyed
shipypos           .rs 1
shipspeed          .rs 1       ; impulse: 1, 2 or 3; spring back to 2
shields            .rs 1
invuln             .rs 1
regen              .rs 1
phaseractive       .rs 1
torpedocool        .rs 1
torpedoes          .rs 1
recharge           .rs 1
scrollx            .rs 1
scrollpage         .rs 1
rng                .rs 1
spawnclock         .rs 1
sectorclock        .rs 1
sector             .rs 1       ; 0 asteroids, 1 Klingons, 2 mixed
difficulty         .rs 1
deathclock         .rs 1
enemyindex         .rs 1
shotindex          .rs 1
temp               .rs 1
temp2              .rs 1
newtype            .rs 1
newx               .rs 1
newy               .rs 1
drawx              .rs 1
drawy              .rs 1
drawptr            .rs 2
drawcount          .rs 1
oamindex           .rs 1
ax                 .rs 1
ay                 .rs 1
aw                 .rs 1
ah                 .rs 1
bx                 .rs 1
by                 .rs 1
bw                 .rs 1
bh                 .rs 1
sfxphaser          .rs 1
sfxtorpedo         .rs 1
sfxnoise           .rs 1
ntptr              .rs 2
hudindex           .rs 1

phasertarget       .rs 1       ; $FF miss, otherwise first enemy intersecting the ray
phaserangle        .rs 1       ; 0..6: up 45 degrees through level to down 45 degrees
aimshift           .rs 1       ; slope denominator: 1, 2 or 4
aimsign            .rs 1
aimentryy          .rs 1
shieldactive       .rs 1
shieldcharge       .rs 1       ; 120 frames of protection, recharges on release
shieldlatched      .rs 1       ; exhaustion requires release before raising again
scrollfraction     .rs 1
enemyfraction      .rs 1
enemystep          .rs 1
beamtx             .rs 1
beamty             .rs 1
beamaxis           .rs 1       ; 0 horizontal-major, 1 vertical-major
beamsign           .rs 1
beammajor          .rs 1
beamminor          .rs 1
beamerror          .rs 1
beambase           .rs 1
beamremainder      .rs 1
beamsteps          .rs 1
beamrise           .rs 1
beamdebt           .rs 1
beamphase          .rs 1
beamtilex          .rs 1
beamtiley          .rs 1
beamspill          .rs 1
worldlo            .rs 1
worldhi            .rs 1
originy            .rs 1
originphase        .rs 1
oldlen             .rs 1
newlen             .rs 1
queueread          .rs 1
queuecount         .rs 1
keyhi              .rs 1
keylo              .rs 1
keydata            .rs 1
hashbucket         .rs 1
overlayindex       .rs 1
healthindex        .rs 1
healthfill         .rs 1
enginebusy         .rs 1       ; overrun guard: never re-enter the simulation
overlaypending     .rs 1       ; prepared overlay awaits next frame's diff/upload
pausechoice        .rs 1       ; 0 resume, 1 restart
menux              .rs 1
menurow            .rs 1
menucolumn         .rs 1
menustartx         .rs 1
phaserheat         .rs 1       ; 192 firing frames, then a full cooling lockout
phaseroverheated   .rs 1
sfxheat            .rs 1
score              .rs 5       ; five decimal digits, most significant first
scoreclock         .rs 1
scoreadd           .rs 1
scoretens          .rs 1
savecheck          .rs 1
healthremainder    .rs 1
healthmaximum      .rs 1
healthsteps        .rs 1
meterindex         .rs 1

; 72 overlay tiles, 64 hash buckets, and 144 queued PPU writes. All fit in
; the NES's internal 2 KB RAM alongside OAM, the stack, and game objects.
oldheads  = $0358
newheads  = $0398
oldnext   = $03D8
oldhi     = $0420
oldlo     = $0468
olddata   = $04B0
queuehi   = $04F8
queuelo   = $0588
queuedata = $0618
newnext   = $06A8
newhi     = $06F0
newlo     = $0738
newdata   = $0780

enemytype = $0300          ; four slots: 0 free, 1 small rock, 2 large, 3 ship, 4 blast
enemyx    = $0304
enemyy    = $0308
enemyhp   = $030C
enemytime = $0310
enemydy   = $0314
enemymaxhp = $0318
bestscore = $6002          ; $6000/$6001 signature, $6007 checksum
shottype  = $0340          ; three active slots: 2 photon, 3 disruptor (no phaser bolts)
shotx     = $0348
shoty     = $0350

; declaring constants
playing   = $00
paused    = $01
destroyed = $02
shipx     = $18

  .bank 0
  .org $C000
RESET:
  SEI
  CLD
  LDX #$40
  STX $4017
  LDX #$FF
  TXS
  INX
  STX $2000
  STX $2001
  STX $4010
  STX $4015
  BIT $2002
vblankwait1:
  BIT $2002
  BPL vblankwait1
memclr:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE memclr
vblankwait2:
  BIT $2002
  BPL vblankwait2

LoadPalettes:
  LDA #$3F
  STA $2006
  LDA #$00
  STA $2006
  LDX #$00
LoadPalettesLoop:
  LDA palette, x
  STA $2007
  INX
  CPX #$20
  BNE LoadPalettesLoop

  ; Load both distinct starfields and their zero attribute tables.
  LDA #LOW(starfield)
  STA ntptr
  LDA #HIGH(starfield)
  STA ntptr+1
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006
  LDX #$08
  LDY #$00
LoadStarfield:
  LDA [ntptr], y
  STA $2007
  INY
  BNE LoadStarfield
  INC ntptr+1
  DEX
  BNE LoadStarfield

  JSR LoadHighScore
  JSR NewGame
  JSR LoadGameSprites
  LDA #$00
  STA $2003
  LDA #$02
  STA $4014
  LDA #$00
  STA $2005
  STA $2005
  LDA #$B0                 ; NMI; background $1000, paired 8x16 sprites
  STA $2000
  LDA #$1E                 ; both layers, including leftmost eight pixels
  STA $2001
KeepRunning:
  JMP KeepRunning

NMI:
  PHA
  TXA
  PHA
  TYA
  PHA
  LDA enginebusy
  BNE NmiReturn
  LDA #$01
  STA enginebusy
  ; Upload last frame's OAM and scroll during vblank; game logic follows.
  LDA #$00
  STA $2003
  LDA #$02
  STA $4014
  BIT $2002
  JSR FlushBackground
  BIT $2002
  LDA scrollpage
  ORA #%10110000
  STA $2000
  LDA scrollx
  STA $2005
  LDA #$00
  STA $2005
FrameGraphicsDone:
  JSR Readp1controller
  JSR GameStateChooser
  JSR UpdateSound
  ; Simulation remains 60 Hz. Slow motion moves one pixel per graphics tick.
  ; Split background preparation from diffing, then construct OAM at 30 Hz
  ; so a full-screen beam and three cruisers always fit in one NTSC frame.
  JSR UpdateBackground
  LDA gamestate
  CMP #paused
  BEQ FrameDrawSprites
  LDA frame
  AND #%00000001
  BEQ FrameLogicDone
FrameDrawSprites:
  JSR LoadGameSprites
FrameLogicDone:
  LDA #$00
  STA enginebusy
NmiReturn:
  PLA
  TAY
  PLA
  TAX
  PLA
  RTI
IRQ:
  RTI

NewGame:
  LDA #$00
  STA gamestate
  STA invuln
  STA regen
  STA phaseractive
  STA torpedocool
  STA recharge
  STA scrollx
  STA scrollpage
  STA frame
  STA sectorclock
  STA sector
  STA difficulty
  STA deathclock
  STA sfxphaser
  STA sfxtorpedo
  STA sfxnoise
  STA shieldactive
  STA shieldlatched
  STA scrollfraction
  STA enemyfraction
  STA overlaypending
  STA pausechoice
  STA phaserheat
  STA phaseroverheated
  STA sfxheat
  LDX #$00
NewClearScore:
  STA score, x
  INX
  CPX #$05
  BNE NewClearScore
  LDX #$00
NewClearEnemies:
  STA enemytype, x
  INX
  CPX #$04
  BNE NewClearEnemies
  LDX #$00
NewClearShots:
  STA shottype, x
  INX
  CPX #$08
  BNE NewClearShots
  LDA #$6C
  STA shipypos
  LDA #$03
  STA shields
  STA phaserangle
  LDA #$78
  STA shieldcharge
  LDA #$02
  STA shipspeed
  STA torpedoes
  LDA #$5A
  STA spawnclock
  LDA #$FF
  STA phasertarget
  LDA #$A7
  STA rng
  LDA #$3C
  STA scoreclock
  RTS

Readp1controller:
  LDA p1buttons
  STA oldp1buttons
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  STA p1buttons
  LDX #$08
ReadBit:
  LDA $4016
  LSR A
  ROL p1buttons
  DEX
  BNE ReadBit
  LDA oldp1buttons
  EOR #%11111111
  AND p1buttons
  STA p1pressed
  RTS

GameStateChooser:
  LDA p1pressed
  AND #%00010000
  BEQ NoStart
  LDA gamestate
  CMP #destroyed
  BNE TogglePause
  JSR NewGame
  RTS
TogglePause:
  EOR #%00000001
  STA gamestate
  BEQ NoStart
  LDA #$00
  STA pausechoice
  RTS
NoStart:
  LDA gamestate
  CMP #paused
  BNE GameNotPaused
  JMP PausedEngine
GameNotPaused:
  INC frame
  LDA gamestate
  CMP #destroyed
  BNE PlayingEngine
  LDA p1pressed
  AND #%10000000
  BEQ DeathWait
  JSR NewGame
  RTS
DeathWait:
  LDA deathclock
  BEQ DeathDrift
  DEC deathclock
DeathDrift:
  LDA #$01
  STA shipspeed
  JMP ScrollSpace
PlayingEngine:
  LDA #$02
  STA shipspeed
  LDA p1buttons
  AND #%00000010
  BEQ NoSlow
  LDA #$01
  STA shipspeed
NoSlow:
  LDA p1buttons
  AND #%00000001
  BEQ NoFast
  LDA #$03
  STA shipspeed
NoFast:
  LDA p1buttons
  AND #%10000000
  BNE NoDown               ; while firing, Up/Down aim instead of steering
  LDA frame
  AND #%00000001
  BNE NoDown               ; half a pixel/frame rather than two
  LDA p1buttons
  AND #%00001000
  BEQ NoUp
  LDA shipypos
  CMP #$39                 ; leave space for floating HUD and ship meters
  BCC NoUp
  SEC
  SBC #$01
  STA shipypos
NoUp:
  LDA p1buttons
  AND #%00000100
  BEQ NoDown
  LDA shipypos
  CMP #$C4
  BCS NoDown
  CLC
  ADC #$01
  STA shipypos
NoDown:
  LDA invuln
  BEQ NoInvuln
  DEC invuln
NoInvuln:
  LDA torpedocool
  BEQ NoTorpedoCool
  DEC torpedocool
NoTorpedoCool:
  LDA frame
  AND #%00000011
  BNE NoRegenTick
  LDA shields
  CMP #$03
  BCS RegenAmmo
  INC regen
  LDA regen
  CMP #$78                 ; eight seconds without damage
  BCC RegenAmmo
  INC shields
  LDA #$00
  STA regen
RegenAmmo:
  LDA torpedoes
  CMP #$02
  BCS NoRegenTick
  INC recharge
  LDA recharge
  CMP #$2D                  ; one torpedo every three seconds
  BCC NoRegenTick
  INC torpedoes
  LDA #$00
  STA recharge
NoRegenTick:
  JSR UpdateShield
  JSR FireWeapons
  JSR UpdateSector
  JSR MoveEnemies
  JSR MoveShots
  JSR UpdatePhaser
  JSR CheckHits
  JSR UpdateScore
ScrollSpace:
  LDA scrollfraction
  CLC
  ADC shipspeed
  STA scrollfraction
  LSR A
  LSR A
  STA temp
  LDA scrollfraction
  AND #%00000011
  STA scrollfraction
  LDA scrollx
  CLC
  ADC temp
  STA scrollx
  BCC ScrollDone
  LDA scrollpage
  EOR #%00000001
  STA scrollpage
ScrollDone:
  RTS

; Up/Down choose the play or restart sprite. A/Enter confirms; Start/P resumes.
PausedEngine:
  LDA p1pressed
  AND #%00001000
  BEQ PauseCheckDown
  LDA #$00
  STA pausechoice
PauseCheckDown:
  LDA p1pressed
  AND #%00000100
  BEQ PauseCheckConfirm
  LDA #$01
  STA pausechoice
PauseCheckConfirm:
  LDA p1pressed
  AND #%10000000
  BEQ PauseDone
  LDA pausechoice
  BNE PauseRestart
  LDA #$00
  STA gamestate
PauseDone:
  RTS
PauseRestart:
  JSR NewGame
  RTS

; Survive for one point per second. Weapons award 25/50/100 by enemy type.
; Decimal digits keep the visible counter cheap to draw on the NES.
UpdateScore:
  LDA gamestate
  BNE ScoreTickDone
  DEC scoreclock
  BNE ScoreTickDone
  LDA #$3C
  STA scoreclock
  LDA #$01
  JSR AddScore
ScoreTickDone:
  RTS
ScoreEnemy:
  LDA enemytype, x
  TAY
  LDA points, y
  JMP AddScore
points:
  .db $00,$19,$32,$64

AddScore:
  STA scoreadd
  TXA
  PHA
  TYA
  PHA
  LDA #$00
  STA scoretens
  LDA scoreadd
ScoreSplit:
  CMP #$0A
  BCC ScoreUnits
  SEC
  SBC #$0A
  INC scoretens
  JMP ScoreSplit
ScoreUnits:
  CLC
  ADC score+4
  CMP #$0A
  BCC ScoreUnitsReady
  SBC #$0A
ScoreUnitsReady:
  STA score+4
  LDA score+3
  ADC scoretens
  CMP #$0A
  BCC ScoreTensReady
  SBC #$0A
ScoreTensReady:
  STA score+3
  BCC ScoreAdded
  LDX #$02
ScoreCarry:
  INC score, x
  LDA score, x
  CMP #$0A
  BCC ScoreAdded
  LDA #$00
  STA score, x
  DEX
  BPL ScoreCarry
  LDA #$09                 ; saturate at 99999 rather than wrapping to zero
  LDX #$04
ScoreLimit:
  STA score, x
  DEX
  BPL ScoreLimit
ScoreAdded:
  JSR UpdateBestScore
  PLA
  TAY
  PLA
  TAX
  RTS

; A checked record lives in cartridge SRAM and survives a new game or reset.
LoadHighScore:
  LDA $6000
  CMP #$46
  BNE ClearHighScore
  LDA $6001
  CMP #$52
  BNE ClearHighScore
  LDA #$A5
  STA savecheck
  LDX #$00
CheckHighDigit:
  LDA bestscore, x
  CMP #$0A
  BCS ClearHighScore
  EOR savecheck
  STA savecheck
  INX
  CPX #$05
  BNE CheckHighDigit
  LDA savecheck
  CMP $6007
  BNE ClearHighScore
  RTS
ClearHighScore:
  LDA #$00
  LDX #$04
ClearHighDigit:
  STA bestscore, x
  DEX
  BPL ClearHighDigit
  LDA #$A5
  STA $6007
  JMP HighScoreSignature
UpdateBestScore:
  LDX #$00
CompareHighDigit:
  LDA score, x
  CMP bestscore, x
  BCC HighScoreDone
  BNE StoreHighScore
  INX
  CPX #$05
  BNE CompareHighDigit
HighScoreDone:
  RTS
StoreHighScore:
  LDA #$00
  STA $6000
  LDA #$A5
  STA savecheck
  LDX #$00
StoreHighDigit:
  LDA score, x
  STA bestscore, x
  EOR savecheck
  STA savecheck
  INX
  CPX #$05
  BNE StoreHighDigit
  LDA savecheck
  STA $6007
HighScoreSignature:
  LDA #$52
  STA $6001
  LDA #$46
  STA $6000
  RTS

; Select on a controller, C in the browser. Two seconds of held protection;
; eight seconds to recharge fully. Exhaustion requires releasing the button.
UpdateShield:
  LDA #$00
  STA shieldactive
  LDA p1buttons
  AND #%00100000
  BEQ ShieldReleased
  LDA shieldlatched
  BNE ShieldDone
  LDA shieldcharge
  BEQ ShieldExhausted
  DEC shieldcharge
  LDA #$01
  STA shieldactive
  RTS
ShieldExhausted:
  LDA #$01
  STA shieldlatched
ShieldDone:
  RTS
ShieldReleased:
  LDA #$00
  STA shieldlatched
  LDA frame
  AND #%00000011
  BNE ShieldDone
  LDA shieldcharge
  CMP #$78
  BCS ShieldDone
  INC shieldcharge
  RTS

FireWeapons:
TryTorpedo:
  LDA p1buttons
  AND #%01000000                 ; B: hold for repeating photon torpedoes
  BEQ WeaponsDone
  LDA torpedocool
  BNE WeaponsDone
  LDA torpedoes
  BEQ WeaponsDone
  LDA #$02
  STA newtype
  LDA #shipx+32
  STA newx
  LDA shipypos
  CLC
  ADC #$17
  STA newy
  JSR AddShot
  BCC WeaponsDone
  DEC torpedoes
  LDA #$24
  STA torpedocool
  LDA #$10
  STA sfxtorpedo
  LDA #$0B
  STA $4015
  LDA #$8B
  STA $4004
  LDA #$F0
  STA $4006
  LDA #$09
  STA $4007
WeaponsDone:
  RTS

AddShot:
  LDX #$00
FindShot:
  LDA shottype, x
  BEQ PlaceShot
  INX
  CPX #$03                   ; beam uses background; three projectile slots
  BNE FindShot
  CLC
  RTS
PlaceShot:
  LDA newtype
  STA shottype, x
  LDA newx
  STA shotx, x
  LDA newy
  STA shoty, x
  SEC
  RTS

Random:
  LDA rng
  LSR A
  BCC RandomStore
  EOR #%10111000
RandomStore:
  STA rng
  RTS

UpdateSector:
  LDA frame
  AND #%00000011
  BNE SpawnTick
  INC sectorclock
  BNE SpawnTick
  INC sector
  LDA sector
  CMP #$03
  BCC SectorHarder
  LDA #$00
  STA sector
SectorHarder:
  LDA difficulty
  CMP #$08
  BCS SpawnTick
  INC difficulty
SpawnTick:
  DEC spawnclock
  BEQ SpawnReady
  RTS
SpawnReady:
  LDA difficulty
  ASL A
  ASL A
  ASL A
  STA temp
  LDA #$A0
  SEC
  SBC temp
  STA spawnclock
  LDA sector
  CMP #$02
  BNE SpawnFind
  LDA spawnclock
  SEC
  SBC #$10
  STA spawnclock
SpawnFind:
  LDX #$00
FindEnemy:
  LDA enemytype, x
  BEQ SpawnEnemy
  INX
  CPX #$03                   ; three simultaneous threats; fourth slot stays unused
  BNE FindEnemy
  RTS
SpawnEnemy:
  STX enemyindex
  JSR Random
  AND #%01111111
  CLC
  ADC #$2C
  STA enemyy, x
  ; Extra vertical range when bit 7 of the LFSR is set.
  LDA rng
  BPL SpawnType
  LDA enemyy, x
  CLC
  ADC #$1C
  STA enemyy, x
SpawnType:
  LDA sector
  CMP #$01
  BEQ SpawnKlingon
  CMP #$02
  BNE SpawnRock
  JSR Random
  AND #%00000001
  BNE SpawnKlingon
SpawnRock:
  JSR Random
  AND #%00000001
  CLC
  ADC #$01
  JMP StoreEnemy
SpawnKlingon:
  LDA #$03
StoreEnemy:
  STA enemytype, x
  LDA difficulty
  ASL A
  ASL A
  ASL A
  ASL A
  CLC
  ADC #$78                 ; 120..248 HP, two damage per phaser contact frame
  STA enemyhp, x
  STA enemymaxhp, x
  LDA #$E8
  STA enemyx, x
  JSR Random
  AND #%00111111
  CLC
  ADC #$64
  STA enemytime, x
  LDA difficulty
  ASL A
  ASL A
  ASL A
  STA temp
  LDA enemytime, x
  SEC
  SBC temp
  STA enemytime, x
  LDA rng
  AND #%00000001
  STA enemydy, x
  RTS

MoveEnemies:
  LDA difficulty
  LSR A
  LSR A
  STA temp
  LDA enemyfraction
  CLC
  ADC shipspeed
  CLC
  ADC temp
  STA enemyfraction
  LSR A
  LSR A
  STA enemystep
  LDA enemyfraction
  AND #%00000011
  STA enemyfraction
  LDX #$00
MoveEnemyLoop:
  STX enemyindex
  LDA enemytype, x
  BNE MoveEnemyActive
  JMP NextEnemy
MoveEnemyActive:
  CMP #$04
  BNE EnemyAlive
  DEC enemytime, x
  BNE EnemyBlastTravel
  JMP RemoveEnemy
EnemyBlastTravel:
  JMP EnemyTravel
EnemyAlive:
  CMP #$03
  BNE EnemyTravel
  LDA frame
  AND #%00000111
  BNE EnemyShoot
  LDA enemydy, x
  BEQ EnemyGoUp
  INC enemyy, x
  LDA enemyy, x
  CMP #$C8
  BCC EnemyShoot
  LDA #$00
  STA enemydy, x
  JMP EnemyShoot
EnemyGoUp:
  DEC enemyy, x
  LDA enemyy, x
  CMP #$20
  BCS EnemyShoot
  LDA #$01
  STA enemydy, x
EnemyShoot:
  DEC enemytime, x
  BNE EnemyTravel
  LDA difficulty
  ASL A
  ASL A
  ASL A
  STA temp
  LDA #$9C
  SEC
  SBC temp
  STA enemytime, x
  LDA enemyx, x
  CMP #$46
  BCC EnemyTravel
  STA newx
  LDA enemyy, x
  CLC
  ADC #$0A
  STA newy
  LDA #$03
  STA newtype
  JSR AddShot
  LDX enemyindex
EnemyTravel:
  LDA enemystep           ; quarter/half/three-quarter pixel per frame
  BEQ NextEnemy
  STA temp
DoEnemyTravel:
  LDA enemyx, x
  SEC
  SBC temp
  BCC RemoveEnemy
  STA enemyx, x
  JMP NextEnemy
RemoveEnemy:
  LDA #$00
  STA enemytype, x
NextEnemy:
  INX
  CPX #$04
  BEQ EnemiesDone
  JMP MoveEnemyLoop
EnemiesDone:
  RTS

MoveShots:
  LDX #$00
MoveShotLoop:
  LDA shottype, x
  BEQ NextShot
  CMP #$03
  BEQ HostileTravel
TorpedoTravel:
  LDA #$03
FriendlyTravel:
  CLC
  ADC shotx, x
  BCS RemoveShot
  CMP #$F0
  BCS RemoveShot
  STA shotx, x
  JMP NextShot
HostileTravel:
  LDA shotx, x
  SEC
  SBC #$01
  BCC RemoveShot
  STA shotx, x
  JMP NextShot
RemoveShot:
  LDA #$00
  STA shottype, x
NextShot:
  INX
  CPX #$08
  BNE MoveShotLoop
  RTS

; Carry set iff the rectangles overlap. Overflow at the right edge is handled.
Overlap:
  LDA ax
  CLC
  ADC aw
  BCS OverlapRight
  CMP bx
  BCC NoOverlap
  BEQ NoOverlap
OverlapRight:
  LDA bx
  CLC
  ADC bw
  BCS OverlapLeft
  CMP ax
  BCC NoOverlap
  BEQ NoOverlap
OverlapLeft:
  LDA ay
  CLC
  ADC ah
  CMP by
  BCC NoOverlap
  BEQ NoOverlap
  LDA by
  CLC
  ADC bh
  CMP ay
  BCC NoOverlap
  BEQ NoOverlap
  SEC
  RTS
NoOverlap:
  CLC
  RTS

EnemyBox:
  LDX enemyindex
  LDA enemyx, x
  STA bx
  LDA enemyy, x
  STA by
  LDA #$18
  STA bw
  STA bh
  LDA enemytype, x
  CMP #$03
  BNE EnemyBoxRock
  LDA #$28
  STA bw
  RTS
EnemyBoxRock:
  CMP #$01
  BNE EnemyBoxDone
  LDA #$10
  STA bw
  STA bh
EnemyBoxDone:
  RTS

ShipBox:
  LDA #shipx+4
  STA ax
  LDA shipypos
  CLC
  ADC #$06
  STA ay
  LDA #$28
  STA aw
  LDA #$18
  STA ah
  RTS

CheckHits:
  LDX #$00
HitShotLoop:
  STX shotindex
  LDA shottype, x
  BNE HitShotActive
  JMP HitNextShot
HitShotActive:
  CMP #$03
  BNE HitFriendly
  LDA invuln
  BEQ HostileCanHit
  JMP HitNextShot
HostileCanHit:
  JSR ShipBox
  LDX shotindex
  LDA shotx, x
  STA bx
  LDA shoty, x
  STA by
  LDA #$06
  STA bw
  STA bh
  JSR Overlap
  BCC HitNextShot
  LDX shotindex
  LDA #$00
  STA shottype, x
  JSR DamageShip
  JMP HitNextShot
HitFriendly:
  LDA shotx, x
  STA ax
  LDA shoty, x
  CLC
  ADC #$02
  STA ay
  LDA #$04
  STA ah
  LDA #$08
  STA aw
HitFindEnemy:
  LDA #$00
  STA enemyindex
HitEnemyLoop:
  LDX enemyindex
  LDA enemytype, x
  BEQ HitNextEnemy
  CMP #$04
  BEQ HitNextEnemy
  JSR EnemyBox
  JSR Overlap
  BCC HitNextEnemy
  LDX shotindex
  LDA #$00
  STA shottype, x
  LDX enemyindex
DestroyEnemy:
  JSR ScoreEnemy
  JSR ExplodeEnemy
  JMP HitNextShot
HitNextEnemy:
  INC enemyindex
  LDA enemyindex
  CMP #$04
  BNE HitEnemyLoop
HitNextShot:
  LDX shotindex
  INX
  CPX #$08
  BEQ CheckRamming
  JMP HitShotLoop
CheckRamming:
  LDA gamestate
  BNE HitsDone
  LDA invuln
  BNE HitsDone
  JSR ShipBox
  LDA #$00
  STA enemyindex
RamLoop:
  LDX enemyindex
  LDA enemytype, x
  BEQ RamNext
  CMP #$04
  BEQ RamNext
  JSR EnemyBox
  JSR Overlap
  BCC RamNext
  LDX enemyindex
  JSR ExplodeEnemy
  JSR DamageShip
  RTS
RamNext:
  INC enemyindex
  LDA enemyindex
  CMP #$04
  BNE RamLoop
HitsDone:
  RTS

ExplodeEnemy:
  LDA #$04
  STA enemytype, x
  LDA #$14
  STA enemytime, x
  LDA #$0C
  STA sfxnoise
  LDA #$0B
  STA $4015
  LDA #$1A
  STA $400C
  LDA #$08
  STA $400E
  LDA #$08
  STA $400F
  RTS

DamageShip:
  LDA gamestate
  BNE DamageDone
  LDA shieldactive
  BNE DamageDone
  LDA invuln
  BNE DamageDone
  LDA #$5A
  STA invuln
  LDA #$00
  STA regen
  DEC shields
  BNE DamageDone
  LDA #$02
  STA gamestate
  LDA #$30
  STA deathclock
  STA sfxnoise
  LDA #$00
  STA phaseractive
  LDA #$FF
  STA phasertarget
  LDA #$0B
  STA $4015
  LDA #$1F
  STA $400C
  LDA #$0C
  STA $400E
  LDA #$08
  STA $400F
  LDA #$00
  LDX #$00
DeathClear:
  STA enemytype, x
  STA shottype, x
  INX
  CPX #$08
  BNE DeathClear
DamageDone:
  RTS

UpdateSound:
  LDA gamestate
  CMP #paused
  BNE SoundPlaying
  LDA #$00
  STA $4015
  RTS
SoundPlaying:
  LDA #$00
  STA temp
  LDA sfxheat
  BEQ SoundPhaser
  DEC sfxheat
  LDA #$01
  STA temp
  LDA #$B8
  STA $4000
  LDA #$18
  SEC
  SBC sfxheat
  ASL A
  ASL A
  ASL A
  CLC
  ADC #$40
  STA $4002
  JMP SoundPhoton
SoundPhaser:
  LDA sfxphaser
  BEQ SoundPhoton
  DEC sfxphaser
  LDA #$01
  STA temp
  LDA sfxphaser
  ASL A
  ASL A
  CLC
  ADC #$50
  STA $4002
SoundPhoton:
  LDA sfxtorpedo
  BEQ SoundBlast
  DEC sfxtorpedo
  LDA temp
  ORA #%00000010
  STA temp
  LDA sfxtorpedo
  ASL A
  ASL A
  CLC
  ADC #$90
  STA $4006
SoundBlast:
  LDA sfxnoise
  BEQ SoundCommit
  DEC sfxnoise
  LDA temp
  ORA #%00001000
  STA temp
SoundCommit:
  LDA temp
  STA $4015
  RTS

LoadGameSprites:
  ; Unroll the 64 Y hides. Only Y must be cleared; hidden tile/attribute/X
  ; bytes do not render. This leaves time for a long angled beam at 60 Hz.
  LDA #$FE
ClearSprites:
  STA $0200
  STA $0204
  STA $0208
  STA $020C
  STA $0210
  STA $0214
  STA $0218
  STA $021C
  STA $0220
  STA $0224
  STA $0228
  STA $022C
  STA $0230
  STA $0234
  STA $0238
  STA $023C
  STA $0240
  STA $0244
  STA $0248
  STA $024C
  STA $0250
  STA $0254
  STA $0258
  STA $025C
  STA $0260
  STA $0264
  STA $0268
  STA $026C
  STA $0270
  STA $0274
  STA $0278
  STA $027C
  STA $0280
  STA $0284
  STA $0288
  STA $028C
  STA $0290
  STA $0294
  STA $0298
  STA $029C
  STA $02A0
  STA $02A4
  STA $02A8
  STA $02AC
  STA $02B0
  STA $02B4
  STA $02B8
  STA $02BC
  STA $02C0
  STA $02C4
  STA $02C8
  STA $02CC
  STA $02D0
  STA $02D4
  STA $02D8
  STA $02DC
  STA $02E0
  STA $02E4
  STA $02E8
  STA $02EC
  STA $02F0
  STA $02F4
  STA $02F8
  STA $02FC
  LDA #$00
  STA oamindex
  LDA gamestate
  CMP #paused
  BNE DrawGameSprites
  JMP LoadPauseSprites
DrawGameSprites:
  LDA #shipx
  STA drawx
  LDA shipypos
  STA drawy
  LDA gamestate
  CMP #destroyed
  BNE DrawShipAlive
  LDA deathclock
  BEQ DrawHUD
  JSR ChooseExplosion
  JSR DrawMeta
  JMP DrawHUD
DrawShipAlive:
  LDA invuln
  BEQ DrawShip
  LDA frame
  AND #%00000100
  BNE DrawHUD
DrawShip:
  LDA #LOW(enterprisesprites)
  STA drawptr
  LDA #HIGH(enterprisesprites)
  STA drawptr+1
  JSR DrawMeta
  LDA shieldactive
  BEQ DrawHUD
  LDA #shipx+46
  STA drawx
  LDA shipypos
  CLC
  ADC #$04
  STA drawy
  LDA #LOW(shieldfieldsprites)
  STA drawptr
  LDA #HIGH(shieldfieldsprites)
  STA drawptr+1
  JSR DrawMeta
DrawHUD:
  LDA #$08
  STA drawy
  LDA #$00
  STA hudindex
DrawShieldLoop:
  LDA hudindex
  ASL A
  ASL A
  ASL A
  CLC
  ADC #$0E
  STA drawx
  LDA hudindex
  CMP shields
  BCS DrawEmptyShield
  LDA #LOW(shieldsprites)
  STA drawptr
  LDA #HIGH(shieldsprites)
  JMP DrawShieldPointer
DrawEmptyShield:
  LDA #LOW(shieldemptysprites)
  STA drawptr
  LDA #HIGH(shieldemptysprites)
DrawShieldPointer:
  STA drawptr+1
  JSR DrawMeta
  INC hudindex
  LDA hudindex
  CMP #$03
  BNE DrawShieldLoop
  JSR DrawScoreSprites
  LDA #$08
  STA drawy
  LDA #$00
  STA hudindex
DrawAmmoLoop:
  LDA hudindex
  CMP torpedoes
  BCS DrawThrottle
  ASL A
  ASL A
  ASL A
  CLC
  ADC #$DE
  STA drawx
  LDA #LOW(torpedosprites)
  STA drawptr
  LDA #HIGH(torpedosprites)
  STA drawptr+1
  JSR DrawMeta
  INC hudindex
  JMP DrawAmmoLoop
DrawThrottle:
  LDA gamestate
  BEQ DrawShipStatus
  JMP DrawObjects
DrawShipStatus:
  JSR DrawShipMeters
  LDA #$08
  STA drawy
  LDA #$00
  STA hudindex
ThrottleLoop:
  LDA hudindex
  CMP shipspeed
  BCS DrawObjects
  ASL A
  ASL A
  ASL A
  CLC
  ADC #$68
  STA drawx
  LDA #LOW(impulsesprites)
  STA drawptr
  LDA #HIGH(impulsesprites)
  STA drawptr+1
  JSR DrawMeta
  INC hudindex
  JMP ThrottleLoop
DrawObjects:
  LDA #$00
  STA shotindex
DrawShotLoop:
  LDX shotindex
  LDA shottype, x
  BEQ DrawNextShot
  STA temp2
  LDA shotx, x
  STA drawx
  LDA shoty, x
  STA drawy
  LDA temp2
  CMP #$03
  BEQ DrawDisruptor
  CMP #$02
  BEQ DrawPhoton
  JMP DrawNextShot
DrawDisruptor:
  LDA #LOW(disruptorsprites)
  STA drawptr
  LDA #HIGH(disruptorsprites)
  JMP DrawShotPointer
DrawPhoton:
  LDA frame
  AND #%00000100
  BEQ DrawPhotonFirst
  LDA #LOW(torpedoaltsprites)
  STA drawptr
  LDA #HIGH(torpedoaltsprites)
  JMP DrawShotPointer
DrawPhotonFirst:
  LDA #LOW(torpedosprites)
  STA drawptr
  LDA #HIGH(torpedosprites)
DrawShotPointer:
  STA drawptr+1
  JSR DrawMeta
DrawNextShot:
  INC shotindex
  LDA shotindex
  CMP #$08
  BNE DrawShotLoop
  ; Rotate enemy OAM order to share the eight-sprites-per-scanline budget.
  LDA #$00
  STA hudindex
DrawEnemyLoop:
  LDA frame
  CLC
  ADC hudindex
  AND #%00000011
  TAX
  LDA enemytype, x
  BEQ DrawNextEnemy
  STA temp2
  LDA enemyx, x
  STA drawx
  LDA enemyy, x
  STA drawy
  LDA temp2
  CMP #$04
  BEQ DrawEnemyExplosion
  CMP #$03
  BEQ DrawKlingon
  CMP #$02
  BEQ DrawLargeRock
  LDA #LOW(asteroidsprites)
  STA drawptr
  LDA #HIGH(asteroidsprites)
  JMP DrawEnemyPointer
DrawKlingon:
  LDA #LOW(klingonsprites)
  STA drawptr
  LDA #HIGH(klingonsprites)
  JMP DrawEnemyPointer
DrawLargeRock:
  LDA #LOW(asteroidlargesprites)
  STA drawptr
  LDA #HIGH(asteroidlargesprites)
DrawEnemyPointer:
  STA drawptr+1
  JSR DrawMeta
  JMP DrawNextEnemy
DrawEnemyExplosion:
  JSR ChooseExplosion
  JSR DrawMeta
DrawNextEnemy:
  INC hudindex
  LDA hudindex
  CMP #$04
  BNE DrawEnemyLoop
  RTS

; Fixed screen coordinates: the numbers float over scrolling stars, like
; the lives. Paired digits keep both scores aligned within eight sprites.
DrawScoreSprites:
  LDA #$18
  STA drawy
  LDA #$48
  STA drawx
  LDA #LOW(score)
  STA drawptr
  LDA #HIGH(score)
  STA drawptr+1
  JSR DrawNumberSprites

  LDA #$80
  STA drawx
  LDA #beststartile
  JSR DrawHUDSprite
  JSR NextHUDSprite
  LDA #LOW(bestscore)
  STA drawptr
  LDA #HIGH(bestscore)
  STA drawptr+1
  JSR DrawNumberSprites
  RTS

DrawNumberSprites:
  LDA #$00
  STA hudindex
  JSR DrawDigitPair
  JSR NextHUDSprite
  LDA #$02
  STA hudindex
  JSR DrawDigitPair
  ; Repeat digit four in the overlap, then append digit five.
  LDA drawx
  CLC
  ADC #$04
  STA drawx
  LDA #$03
  STA hudindex
  JSR DrawDigitPair
  RTS

DrawDigitPair:
  LDY hudindex
  LDA [drawptr], y
  ASL A
  STA temp
  ASL A
  ASL A
  CLC
  ADC temp
  STA temp
  INY
  LDA [drawptr], y
  CLC
  ADC temp
  TAX
  LDA digitpairtiles, x
  STA temp2
  LDA digitpairattributes, x
  STA temp
  LDX oamindex
  CPX #$FC
  BCS DrawDigitPairDone
  STA $0202, x
  LDA temp2
  STA $0201, x
  ; Flipping the padded pattern shifts its ink by one X or seven Y pixels.
  LDA temp
  AND #%01000000
  BEQ DrawDigitPairX
  LDA drawx
  SEC
  SBC #$01
  JMP DrawDigitPairStoreX
DrawDigitPairX:
  LDA drawx
DrawDigitPairStoreX:
  STA $0203, x
  LDA temp
  BMI DrawDigitPairFlipY
  LDA drawy
  SEC
  SBC #$01
  JMP DrawDigitPairStoreY
DrawDigitPairFlipY:
  LDA drawy
  SEC
  SBC #$08
DrawDigitPairStoreY:
  STA $0200, x
  TXA
  CLC
  ADC #$04
  STA oamindex
DrawDigitPairDone:
  RTS

; Both meters follow the Enterprise. White shield charge sits on the left;
; blue phaser heat sits on the right and flashes white while overheated.
DrawShipMeters:
  LDA shipypos
  SEC
  SBC #$10
  STA drawy
  LDA #shipx
  STA drawx
  LDA shieldcharge
  BEQ DrawShieldFill
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$01
DrawShieldFill:
  STA healthfill
  LDA #$00
  STA meterindex
DrawShieldMeterLoop:
  LDA healthfill
  CMP #$08
  BCC DrawShieldMeterTile
  LDA #$08
DrawShieldMeterTile:
  TAX
  LDA metertiles, x
  JSR DrawHUDSprite
  JSR NextMeterSprite
  INC meterindex
  LDA meterindex
  CMP #$02
  BNE DrawShieldMeterLoop

  LDA #shipx+24
  STA drawx
  LDA phaserheat
  CLC
  ADC #$07
  LSR A
  LSR A
  LSR A
  STA healthfill
  LDA #$00
  STA meterindex
DrawHeatMeterLoop:
  LDA healthfill
  CMP #$08
  BCC DrawHeatMeterFill
  LDA #$08
DrawHeatMeterFill:
  TAX
  LDA phaseroverheated
  BEQ DrawHeatMeterBlue
  LDA frame
  AND #%00001000
  BEQ DrawHeatMeterBlue
  LDA metertiles, x
  JMP DrawHeatMeterTile
DrawHeatMeterBlue:
  LDA hottiles, x
DrawHeatMeterTile:
  JSR DrawHUDSprite
  JSR NextMeterSprite
  INC meterindex
  LDA meterindex
  CMP #$03
  BNE DrawHeatMeterLoop
  RTS
NextMeterSprite:
  LDA healthfill
  SEC
  SBC #$08
  BCS DrawMeterRemaining
  LDA #$00
DrawMeterRemaining:
  STA healthfill
NextHUDSprite:
  LDA drawx
  CLC
  ADC #$08
  STA drawx
  RTS
DrawHUDSprite:
  LDX oamindex
  CPX #$FC
  BCS DrawHUDSpriteDone
  STA $0201, x
  LDA drawy
  SEC
  SBC #$01
  STA $0200, x
  LDA drawx
  STA $0203, x
  LDA #$00
  STA $0202, x
  TXA
  CLC
  ADC #$04
  STA oamindex
DrawHUDSpriteDone:
  RTS

LoadPauseSprites:
  LDA scrollx
  AND #%00000111
  STA temp
  LDA #$78
  SEC
  SBC temp
  STA menux
  STA drawx
  LDA #$4C
  STA drawy
  LDA #LOW(pauseiconsprites)
  STA drawptr
  LDA #HIGH(pauseiconsprites)
  STA drawptr+1
  JSR DrawMeta

  LDA menux
  STA drawx
  LDA #$60
  STA drawy
  LDA #LOW(resumeiconsprites)
  STA drawptr
  LDA #HIGH(resumeiconsprites)
  STA drawptr+1
  JSR DrawMeta

  LDA menux
  STA drawx
  LDA #$74
  STA drawy
  LDA #LOW(restarticonsprites)
  STA drawptr
  LDA #HIGH(restarticonsprites)
  STA drawptr+1
  JSR DrawMeta

  LDA menux
  SEC
  SBC #$10
  STA drawx
  LDA pausechoice
  BEQ PauseCursorResume
  LDA #$78
  JMP PauseCursorY
PauseCursorResume:
  LDA #$64
PauseCursorY:
  STA drawy
  LDA #LOW(menucursorsprites)
  STA drawptr
  LDA #HIGH(menucursorsprites)
  STA drawptr+1
  JSR DrawMeta
  RTS

ChooseExplosion:
  LDA frame
  AND #%00000100
  BEQ ExplosionFirst
  LDA #LOW(explosionaltsprites)
  STA drawptr
  LDA #HIGH(explosionaltsprites)
  STA drawptr+1
  RTS
ExplosionFirst:
  LDA #LOW(explosionsprites)
  STA drawptr
  LDA #HIGH(explosionsprites)
  STA drawptr+1
  RTS

; Generic metasprite renderer. Clip tiles at the right edge instead of wrapping.
DrawMeta:
  LDY #$00
  LDA [drawptr], y
  STA drawcount
  INY
MetaLoop:
  LDX oamindex
  CPX #$FC
  BCS MetaDone
  LDA [drawptr], y
  CLC
  ADC drawx
  BCS MetaSkip
  STA $0203, x
  INY
  LDA [drawptr], y
  CLC
  ADC drawy
  SEC
  SBC #$01
  STA $0200, x
  INY
  LDA [drawptr], y
  STA $0201, x
  INY
  LDA [drawptr], y
  STA $0202, x
  INY
  TXA
  CLC
  ADC #$04
  STA oamindex
  DEC drawcount
  BNE MetaLoop
MetaDone:
  RTS
MetaSkip:
  INY
  INY
  INY
  INY
  DEC drawcount
  BNE MetaLoop
  RTS

; background and phaser routines

; Player-aimed phaser: hold A, use Up/Down to rotate through seven angles.
; The ray never tracks a target. The first rectangle it intersects stops it.
; Two HP per frame: 120 HP takes one second of sustained, accurate contact.
UpdatePhaser:
  LDA #$00
  STA phaseractive
  LDA #$FF
  STA phasertarget
  JSR UpdatePhaserHeat
  BCC PhaserHeld
  RTS
PhaserHeld:
  LDA p1pressed
  AND #%00001100
  BNE PhaserAim
  LDA frame
  AND #%00000111
  BNE PhaserDirection
PhaserAim:
  LDA p1buttons
  AND #%00001000
  BEQ PhaserAimDown
  LDA phaserangle
  BEQ PhaserAimDown
  DEC phaserangle
PhaserAimDown:
  LDA p1buttons
  AND #%00000100
  BEQ PhaserDirection
  LDA phaserangle
  CMP #$06
  BCS PhaserDirection
  INC phaserangle
PhaserDirection:
  LDX phaserangle
  LDA AimShiftTable, x
  STA aimshift
  LDA #$00
  CPX #$03
  BCS PhaserSignReady
  LDA #$01
PhaserSignReady:
  STA aimsign
  LDA shipypos
  CLC
  ADC #$10
  STA originy
  LDA #$01
  STA phaseractive
  LDA #$F8
  STA beamtx
  JSR BeamAtX
  STA beamty
  CMP #$1C
  BCC PhaserClipTop
  CMP #$DF
  BCC PhaserRayReady
  LDA #$DE
  STA beamty
  SEC
  SBC originy
  JMP PhaserClipX
PhaserClipTop:
  LDA #$1C
  STA beamty
  LDA originy
  SEC
  SBC #$1C
PhaserClipX:
  JSR AimDistanceToX
  STA beamtx
PhaserRayReady:
  LDX #$00
PhaserFindLoop:
  STX enemyindex
  LDA enemytype, x
  BNE PhaserCheckLive
  JMP PhaserNextEnemy
PhaserCheckLive:
  CMP #$04
  BCC PhaserCheckForward
  JMP PhaserNextEnemy
PhaserCheckForward:
  JSR EnemyBox
  LDA bx
  CMP #shipx+45
  BCS PhaserEntryReady
  LDA #shipx+45
PhaserEntryReady:
  CMP beamtx
  BCC PhaserEntryInRay
  JMP PhaserNextEnemy
PhaserEntryInRay:
  STA ax
  JSR BeamAtX
  STA aimentryy
  LDA by
  CLC
  ADC bh
  SEC
  SBC #$01
  STA ay                   ; last row of the target rectangle
  LDA bx
  CLC
  ADC bw
  BCS PhaserExitClip
  SEC
  SBC #$01
  CMP beamtx
  BCC PhaserExitReady
PhaserExitClip:
  LDA beamtx
PhaserExitReady:
  CMP ax
  BCS PhaserExitInRay
  JMP PhaserNextEnemy       ; target is behind the firing point
PhaserExitInRay:
  JSR BeamAtX
  STA temp2
  LDA aimsign
  BNE PhaserCheckUp
  LDA aimentryy
  CMP ay
  BCC PhaserDownEntry
  BEQ PhaserDownEntry
  JMP PhaserNextEnemy
PhaserDownEntry:
  LDA temp2
  CMP by
  BCS PhaserIntersects
  JMP PhaserNextEnemy
PhaserCheckUp:
  LDA aimentryy
  CMP by
  BCC PhaserNextEnemy
  LDA temp2
  CMP ay
  BCC PhaserIntersects
  BEQ PhaserIntersects
  JMP PhaserNextEnemy
PhaserIntersects:
  LDA aimentryy
  CMP by
  BCC PhaserContactTop
  CMP ay
  BCC PhaserContactEntry
  BEQ PhaserContactEntry
  LDA originy             ; upward ray enters through the lower edge
  SEC
  SBC ay
  JMP PhaserContactEdge
PhaserContactTop:
  LDA by                   ; downward ray enters through the upper edge
  SEC
  SBC originy
PhaserContactEdge:
  JSR AimDistanceToX
  JMP PhaserContact
PhaserContactEntry:
  LDA ax
PhaserContact:
  STA beamtx
  JSR BeamAtX
  STA beamty
  LDX enemyindex
  STX phasertarget
PhaserNextEnemy:
  LDX enemyindex
  INX
  CPX #$03
  BEQ PhaserDamage
  JMP PhaserFindLoop
PhaserDamage:
  LDX phasertarget
  CPX #$03
  BCS PhaserSustain
  LDA enemyhp, x
  CMP #$03
  BCC PhaserDestroy
  SEC
  SBC #$02
  STA enemyhp, x
  JMP PhaserSustain
PhaserDestroy:
  LDA #$00
  STA enemyhp, x
  JSR ScoreEnemy
  JSR ExplodeEnemy
PhaserSustain:
  ; Continuous hum even when firing into empty space.
  LDA #$02
  STA sfxphaser
  LDA #$0B
  STA $4015
  LDA #$B5
  STA $4000
  LDA frame
  AND #%00011111
  BNE PhaserSoundDone
  LDA #$08
  STA $4003
PhaserSoundDone:
  RTS

; Firing heats the phaser, even on a miss. Release cools it three units per
; frame. At 192 it chirps and locks out until a 96-frame cooling cycle ends.
; Carry clear means the weapon may fire this frame. Pause freezes all heat.
UpdatePhaserHeat:
  LDA phaseroverheated
  BEQ HeatCheckTrigger
  LDA phaserheat
  SEC
  SBC #$02
  BEQ HeatCooled
  BCC HeatCooled
  STA phaserheat
  SEC
  RTS
HeatCooled:
  LDA #$00
  STA phaserheat
  STA phaseroverheated
  SEC
  RTS
HeatCheckTrigger:
  LDA p1buttons
  AND #%10000000
  BNE HeatFiring
  LDA phaserheat
  SEC
  SBC #$03
  BCS HeatReleaseStore
  LDA #$00
HeatReleaseStore:
  STA phaserheat
  SEC
  RTS
HeatFiring:
  INC phaserheat
  LDA phaserheat
  CMP #$C0
  BCS HeatOverload
  CLC
  RTS
HeatOverload:
  LDA #$01
  STA phaseroverheated
  LDA #$00
  STA sfxphaser
  LDA #$18
  STA sfxheat
  LDA #$0B
  STA $4015
  LDA #$B8
  STA $4000
  LDA #$40
  STA $4002
  LDA #$08
  STA $4003
  SEC
  RTS

; Return ray Y at screen X in A; saturate offscreen values rather than wrap.
; Preserves X so intersection tests cannot change the chosen enemy slot.
BeamAtX:
  SEC
  SBC #shipx+44
  LDY aimshift
  BEQ BeamAimDelta
BeamAimDivide:
  LSR A
  DEY
  BNE BeamAimDivide
BeamAimDelta:
  STA temp
  LDA phaserangle
  CMP #$03
  BNE BeamAimSlope
  LDA originy
  RTS
BeamAimSlope:
  LDA aimsign
  BNE BeamAimUp
  LDA originy
  CLC
  ADC temp
  BCC BeamAimDone
  LDA #$FF
  RTS
BeamAimUp:
  LDA originy
  SEC
  SBC temp
  BCS BeamAimDone
  LDA #$00
BeamAimDone:
  RTS

AimDistanceToX:
  LDY aimshift
  BEQ AimDistanceReady
AimDistanceMultiply:
  ASL A
  DEY
  BNE AimDistanceMultiply
AimDistanceReady:
  CLC
  ADC #shipx+44
  RTS

AimShiftTable:
  .db 0,1,2,0,2,1,0

; 32 queued nametable writes cost less than 1,250 CPU cycles. Together with
; OAM DMA and scroll setup, PPU writes fit within NTSC vblank. Long angle
; changes drain across multiple frames while simulation continues at 60 Hz.
FlushBackground:
  LDX queueread
  LDY #$20
FlushLoop:
  CPX queuecount
  BEQ FlushDone
  LDA queuehi, x
  STA $2006
  LDA queuelo, x
  STA $2006
  LDA queuedata, x
  STA $2007
  INX
  DEY
  BNE FlushLoop
FlushDone:
  STX queueread
  RTS

; Hashed sparse overlay: compare new tiles with the previous image, upload
; only changes, and restore the original ROM star tiles after a beam moves.
UpdateBackground:
  LDA overlaypending
  BEQ OverlayCheckPrepare
  JMP OverlayCommit
OverlayCheckPrepare:
  LDA gamestate
  CMP #paused
  BEQ OverlayPrepare
  LDA frame
  AND #%00000001
  BNE OverlayWait
OverlayPrepare:
  LDA queueread
  CMP queuecount
  BEQ OverlayReady
OverlayWait:
  RTS
OverlayReady:
  LDA #$00
  STA newlen
  STA queueread
  STA queuecount
  LDX #$00
  LDA #$FF
ClearHashes:
  STA oldheads, x
  STA oldheads+16, x
  STA oldheads+32, x
  STA oldheads+48, x
  STA newheads, x
  STA newheads+16, x
  STA newheads+32, x
  STA newheads+48, x
  INX
  CPX #$10
  BNE ClearHashes
  LDX #$00
HashOldLoop:
  CPX oldlen
  BEQ GenerateOverlay
  LDA oldlo, x
  EOR oldhi, x
  AND #%00111111
  TAY
  LDA oldheads, y
  STA oldnext, x
  TXA
  STA oldheads, y
  INX
  JMP HashOldLoop
GenerateOverlay:
  LDA gamestate
  CMP #paused
  BNE GenerateGameOverlay
  JSR GeneratePausePanel
  JMP OverlayPrepared
GenerateGameOverlay:
  LDA phaseractive
  BEQ OverlayHealth
  LDA gamestate
  CMP #destroyed
  BEQ OverlayHealth
  JSR GenerateBeam
OverlayHealth:
  JSR GenerateHealth
OverlayPrepared:
  LDA #$01
  STA overlaypending
  RTS
OverlayCommit:
  LDA #$00
  STA overlaypending
  STA overlayindex
DiffNewLoop:
  LDX overlayindex
  CPX newlen
  BNE DiffNewTile
  JMP RestoreOldStart
DiffNewTile:
  LDA newhi, x
  STA keyhi
  LDA newlo, x
  STA keylo
  EOR keyhi
  AND #%00111111
  TAY
  LDA newdata, x
  STA keydata
  LDX oldheads, y
DiffFindOld:
  CPX #$FF
  BEQ DiffUpload
  LDA oldhi, x
  AND #%01111111
  CMP keyhi
  BNE DiffChain
  LDA oldlo, x
  CMP keylo
  BNE DiffChain
  LDA oldhi, x
  ORA #%10000000
  STA oldhi, x
  LDA olddata, x
  CMP keydata
  BEQ DiffNewNext
  JMP DiffUpload
DiffChain:
  LDA oldnext, x
  TAX
  JMP DiffFindOld
DiffUpload:
  JSR EnqueueTile
DiffNewNext:
  INC overlayindex
  JMP DiffNewLoop
RestoreOldStart:
  LDX #$00
RestoreOldLoop:
  CPX oldlen
  BEQ SaveNewOverlay
  LDA oldhi, x
  BMI RestoreNext
  STA keyhi
  AND #%00000111
  CLC
  ADC #HIGH(starfield)
  STA ntptr+1
  LDA oldlo, x
  STA keylo
  STA ntptr                 ; starfield is page-aligned at $F000
  LDY #$00
  LDA [ntptr], y
  STA keydata
  TXA
  PHA
  JSR EnqueueTile
  PLA
  TAX
RestoreNext:
  INX
  JMP RestoreOldLoop
SaveNewOverlay:
  LDX #$00
  LDY newlen
  BEQ SaveOverlayDone
SaveOverlayLoop:
  LDA newhi, x
  STA oldhi, x
  LDA newlo, x
  STA oldlo, x
  LDA newdata, x
  STA olddata, x
  INX
  DEY
  BNE SaveOverlayLoop
SaveOverlayDone:
  LDA newlen
  STA oldlen
  RTS

EnqueueTile:
  LDX queuecount
  CPX #$90
  BCS EnqueueDone
  LDA keyhi
  STA queuehi, x
  LDA keylo
  STA queuelo, x
  LDA keydata
  STA queuedata, x
  INC queuecount
EnqueueDone:
  RTS

; Add or replace one tile in the new overlay. Health bars take priority if
; a line crosses them; duplicate addresses never leave ghost tiles.
AddOverlay:
  LDA keylo
  EOR keyhi
  AND #%00111111
  STA hashbucket
  TAY
  LDX newheads, y
NewFindTile:
  CPX #$FF
  BEQ NewInsert
  LDA newhi, x
  CMP keyhi
  BNE NewChain
  LDA newlo, x
  CMP keylo
  BNE NewChain
  LDA keydata
  STA newdata, x
  RTS
NewChain:
  LDA newnext, x
  TAX
  JMP NewFindTile
NewInsert:
  LDX newlen
  CPX #$48
  BCS NewInsertDone
  LDA keyhi
  STA newhi, x
  LDA keylo
  STA newlo, x
  LDA keydata
  STA newdata, x
  LDY hashbucket
  LDA newheads, y
  STA newnext, x
  TXA
  STA newheads, y
  INC newlen
NewInsertDone:
  RTS

; Beam columns occupy unique tile addresses, so they can skip the search.
AddBeamOverlay:
  LDA keylo
  EOR keyhi
  AND #%00111111
  STA hashbucket
  JMP NewInsert

; Global tile column 0..63 and row 0..29 -> PPU nametable address.
TileAddress:
  LDX beamtiley
  LDA rowhi, x
  STA keyhi
  LDY beamtilex
  LDA colhi, y
  ORA keyhi
  STA keyhi
  TYA
  AND #%00011111
  ORA rowlo, x
  STA keylo
  RTS

; A is screen X. Return circular, nine-bit world X in worldhi:worldlo.
WorldPoint:
  CLC
  ADC scrollx
  STA worldlo
  LDA scrollpage
  ADC #$00
  AND #%00000001
  STA worldhi
  RTS
WorldTile:
  LDA worldhi
  LSR A
  LDA worldlo
  ROR A
  LSR A
  LSR A
  STA beamtilex
  RTS

GenerateBeam:
  LDA shipypos
  CLC
  ADC #$10
  STA originy
  LDA #shipx+44
  JSR WorldPoint
  LDA worldlo
  AND #%00000111
  STA originphase
  LDA beamtx
  SEC
  SBC #shipx+44
  STA beammajor
  LDA #$00
  STA beamsign
  STA beamaxis
  STA beamerror
  STA beamdebt
  LDA beamty
  SEC
  SBC originy
  BCS BeamMagnitude
  EOR #%11111111
  CLC
  ADC #$01
  INC beamsign
BeamMagnitude:
  STA beamminor
  CMP beammajor
  BCC BeamHorizontal
  BEQ BeamHorizontal
  JMP BeamVertical
BeamHorizontal:
  LDA beammajor
  CLC
  ADC originphase
  STA beammajor
  JSR WorldTile
  LDA originy
  AND #%00000111
  STA beamphase
  LDA originy
  LSR A
  LSR A
  LSR A
  STA beamtiley
  JMP BeamStepCount
BeamVertical:
  LDA #$01
  STA beamaxis
  LDA beammajor
  STA beamminor            ; absolute screen X delta
  LDA beamsign
  BNE BeamAbove
  LDA originy
  AND #%11111000
  STA temp
  LDA beamty
  SEC
  SBC temp
  STA beammajor
  LDA #shipx+44
  JSR WorldPoint
  LDA originy
  JMP BeamVerticalOrigin
BeamAbove:
  LDA beamty
  AND #%11111000
  STA temp
  LDA originy
  SEC
  SBC temp
  STA beammajor
  LDA beamtx
  JSR WorldPoint
  LDA beamty
BeamVerticalOrigin:
  LSR A
  LSR A
  LSR A
  STA beamtiley
  LDA worldlo
  AND #%00000111
  STA beamphase
  JSR WorldTile
BeamStepCount:
  LDA beammajor
  CLC
  ADC #$07
  LSR A
  LSR A
  LSR A
  STA beamsteps
  BNE BeamRatio
  RTS
BeamRatio:
  ; Divide 8*minor by major once. Each following column only adds the
  ; remainder, rather than repeating eight pixel-DDA divisions per column.
  LDA #$00
  STA beamrise
  LDY #$08
BeamDDA:
  LDA beamerror
  CLC
  ADC beamminor
  BCS BeamSubtract
  CMP beammajor
  BCC BeamErrorStore
BeamSubtract:
  SEC
  SBC beammajor
  INC beamrise
BeamErrorStore:
  STA beamerror
  DEY
  BNE BeamDDA
  LDA beamrise
  STA beambase
  LDA beamerror
  STA beamremainder
  LDA #$00
  STA beamerror
BeamColumn:
  LDA beambase
  STA beamrise
  LDA beamerror
  CLC
  ADC beamremainder
  BCS BeamColumnCarry
  CMP beammajor
  BCC BeamColumnStore
BeamColumnCarry:
  SEC
  SBC beammajor
  INC beamrise
BeamColumnStore:
  STA beamerror
  LDA beamaxis
  BEQ BeamLookup
  LDA beamrise
  CLC
  ADC beamdebt
  PHA
  AND #%00000001
  STA beamdebt
  PLA
  AND #%11111110
  STA beamrise
BeamLookup:
  LDA beamsign
  BNE BeamLookupNegative
  LDA beamrise
  CLC
  ADC #$08
  JMP BeamLookupIndex
BeamLookupNegative:
  LDA #$08
  SEC
  SBC beamrise
BeamLookupIndex:
  ASL A
  ASL A
  ASL A
  CLC
  ADC beamphase
  TAX
  LDA beamaxis
  BNE BeamVerticalTiles
  LDA beamhspill, x
  STA beamspill
  LDA beamhmain, x
  JMP BeamMainTile
BeamVerticalTiles:
  LDA beamvspill, x
  STA beamspill
  LDA beamvmain, x
BeamMainTile:
  STA keydata
  JSR TileAddress
  JSR AddBeamOverlay
  LDA beamspill
  BEQ BeamAdvance
  STA keydata
  LDA beamaxis
  BNE BeamSpillX
  LDA beamtiley
  PHA
  LDA beamsign
  BNE BeamSpillUp
  INC beamtiley
  JMP BeamSpillYWrite
BeamSpillUp:
  DEC beamtiley
BeamSpillYWrite:
  JSR TileAddress
  JSR AddBeamOverlay
  PLA
  STA beamtiley
  JMP BeamAdvance
BeamSpillX:
  LDA beamtilex
  PHA
  LDA beamsign
  BNE BeamSpillLeft
  INC beamtilex
  JMP BeamSpillXWrite
BeamSpillLeft:
  DEC beamtilex
BeamSpillXWrite:
  LDA beamtilex
  AND #%00111111
  STA beamtilex
  JSR TileAddress
  JSR AddBeamOverlay
  PLA
  STA beamtilex
BeamAdvance:
  LDA beamsign
  BNE BeamAdvanceNegative
  LDA beamphase
  CLC
  ADC beamrise
  CMP #$08
  BCC BeamPhaseStore
  SEC
  SBC #$08
  STA beamphase
  LDA beamaxis
  BNE BeamSecondaryRight
  INC beamtiley
  JMP BeamPrimaryAdvance
BeamSecondaryRight:
  INC beamtilex
  JMP BeamPrimaryAdvance
BeamAdvanceNegative:
  LDA beamphase
  SEC
  SBC beamrise
  BCS BeamPhaseStore
  CLC
  ADC #$08
  STA beamphase
  LDA beamaxis
  BNE BeamSecondaryLeft
  DEC beamtiley
  JMP BeamPrimaryAdvance
BeamSecondaryLeft:
  DEC beamtilex
  JMP BeamPrimaryAdvance
BeamPhaseStore:
  STA beamphase
BeamPrimaryAdvance:
  LDA beamaxis
  BNE BeamPrimaryY
  INC beamtilex
  JMP BeamPrimaryWrap
BeamPrimaryY:
  INC beamtiley
BeamPrimaryWrap:
  LDA beamtilex
  AND #%00111111
  STA beamtilex
  DEC beamsteps
  BEQ BeamDone
  JMP BeamColumn
BeamDone:
  RTS

; A 64-tile box replaces stars and old beams while paused. It fits the same
; sparse overlay and vblank upload budget as the game's phaser.
GeneratePausePanel:
  LDA #$60
  JSR WorldPoint
  JSR WorldTile
  LDA beamtilex
  STA menustartx
  LDA #$00
  STA menurow
PausePanelRow:
  LDA #$00
  STA menucolumn
PausePanelColumn:
  LDA menustartx
  CLC
  ADC menucolumn
  AND #%00111111
  STA beamtilex
  LDA menurow
  CLC
  ADC #$09
  STA beamtiley

  LDA menurow
  BEQ PausePanelTop
  CMP #$07
  BEQ PausePanelBottom
  LDY #$00
  LDA menucolumn
  BEQ PausePanelLeft
  CMP #$07
  BEQ PausePanelRight
  JMP PausePanelTile
PausePanelLeft:
  LDY #$04
  BNE PausePanelTile
PausePanelRight:
  LDY #$05
  BNE PausePanelTile
PausePanelTop:
  LDY #$02
  LDA menucolumn
  BEQ PausePanelTopLeft
  CMP #$07
  BNE PausePanelTile
  LDY #$03
  BNE PausePanelTile
PausePanelTopLeft:
  LDY #$01
  BNE PausePanelTile
PausePanelBottom:
  LDY #$07
  LDA menucolumn
  BEQ PausePanelBottomLeft
  CMP #$07
  BNE PausePanelTile
  LDY #$08
  BNE PausePanelTile
PausePanelBottomLeft:
  LDY #$06
PausePanelTile:
  LDA menutiles, y
  STA keydata
  JSR TileAddress
  JSR AddBeamOverlay       ; every panel address is unique
  INC menucolumn
  LDA menucolumn
  CMP #$08
  BNE PausePanelColumn
  INC menurow
  LDA menurow
  CMP #$08
  BEQ PausePanelDone
  JMP PausePanelRow
PausePanelDone:
  RTS

GenerateHealth:
  LDA #$00
  STA healthindex
HealthEnemyLoop:
  LDX healthindex
  LDA enemytype, x
  BNE HealthEnemyActive
  JMP HealthNextEnemy
HealthEnemyActive:
  CMP #$04
  BCC HealthLive
  JMP HealthNextEnemy
HealthLive:
  ; Sixteen fill pixels proportional to this enemy's original health.
  ; Repeated addition avoids a slow general-purpose 16-bit divide.
  LDA enemymaxhp, x
  STA healthmaximum
  LDA #$00
  STA healthfill
  STA healthremainder
  LDA #$10
  STA healthsteps
HealthFraction:
  LDA healthremainder
  CLC
  ADC enemyhp, x
  BCS HealthFractionSubtract
  CMP healthmaximum
  BCC HealthFractionNext
HealthFractionSubtract:
  SEC
  SBC healthmaximum
  INC healthfill
HealthFractionNext:
  STA healthremainder
  DEC healthsteps
  BNE HealthFraction
  LDA healthremainder
  BEQ HealthFractionReady
  INC healthfill
HealthFractionReady:
  LDA #$00
  STA temp
  LDA enemytype, x
  CMP #$01
  BEQ HealthCenter
  LDA #$04
  STA temp
  LDA enemytype, x
  CMP #$03
  BNE HealthCenter
  LDA #$0C
  STA temp
HealthCenter:
  LDA enemyx, x
  CLC
  ADC temp
  JSR WorldPoint
  JSR WorldTile
  LDX healthindex
  LDA enemyy, x
  SEC
  SBC #$08
  LSR A
  LSR A
  LSR A
  STA beamtiley
  LDA healthfill
  CMP #$08
  BCC HealthLeftFill
  LDA #$08
HealthLeftFill:
  TAX
  LDA healthtiles, x
  STA keydata
  JSR TileAddress
  JSR AddOverlay
  INC beamtilex
  LDA beamtilex
  AND #%00111111
  STA beamtilex
  LDA healthfill
  SEC
  SBC #$08
  BCS HealthRightFill
  LDA #$00
HealthRightFill:
  TAX
  LDA healthtiles, x
  STA keydata
  JSR TileAddress
  JSR AddOverlay
HealthNextEnemy:
  INC healthindex
  LDA healthindex
  CMP #$03
  BEQ HealthDone
  JMP HealthEnemyLoop
HealthDone:
  RTS

  .bank 1
  .org $E000
palette:
  .db $0F,$00,$21,$30, $0F,$00,$21,$30, $0F,$00,$21,$30, $0F,$00,$21,$30
  .db $0F,$10,$30,$21, $0F,$00,$10,$19, $0F,$07,$17,$27, $0F,$10,$27,$30
  .include "sprites.inc"
  .org $E800
; Page-aligned address tables keep long beams within the NTSC frame budget.
rowhi:
  .db $20,$20,$20,$20,$20,$20,$20,$20,$21,$21,$21,$21,$21,$21,$21,$21
  .db $22,$22,$22,$22,$22,$22,$22,$22,$23,$23,$23,$23,$23,$23,$23,$23
rowlo:
  .db $00,$20,$40,$60,$80,$A0,$C0,$E0,$00,$20,$40,$60,$80,$A0,$C0,$E0
  .db $00,$20,$40,$60,$80,$A0,$C0,$E0,$00,$20,$40,$60,$80,$A0,$C0,$E0
colhi:
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
  .db $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
  .org $F000
starfield:
  .incbin "starfield.bin"

  .org $FFFA
  .dw NMI
  .dw RESET
  .dw IRQ
  .bank 2
  .org $0000
  .incbin "sprites.chr"
