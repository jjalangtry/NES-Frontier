# NES Frontier

6502 assembly, NESASM, mapper 0. One 16 KB PRG bank and one 8 KB CHR bank.

W/S or Up/Down move. Left/Right change impulse. Hold Z to fire; Up/Down aim
while firing. X launches torpedoes. Hold C for the shield. P pauses; Up/Down
choose resume or restart, Enter confirms. Enter also retries after destruction.
On a NES controller, Start pauses and A confirms.

Survive for one point per second. Destroy small asteroids for 25, large ones
for 50, and Klingons for 100. Asteroid, Klingon, and mixed sectors cycle every
17 seconds; each raises health, spawn pressure, and Klingon firing frequency.
Enemy speed rises gradually. Torpedoes always kill in one hit. Phaser heat
fills the blue bar over 3.2 seconds; overheating chirps and locks firing for
1.6 seconds. Releasing the phaser cools it faster. A star marks the high score,
saved in cartridge battery RAM and the browser's local storage.
Scores align in one row of fixed foreground sprites, below the lives,
speed and torpedo indicators. Shield charge and phaser heat float
directly above the Enterprise and follow its movement.

```sh
npm ci
npm run build
npm test
npm start
```

Load `public/frontier.nes` in a NES emulator. `public/` contains only the
cartridge and browser emulator. Railway serves the public site at
https://nesfrontier.lab86.io/ using the Dockerfile and Caddyfile.

`src/asm/Frontier.asm` follows the original Pong NESASM layout: reserved
variables, constants, reset, game states, sprite routines, and data banks.
`sprites.inc`, `sprites.chr`, and `starfield.bin` are cartridge data.

To edit tiles, install `requirements.txt` in a Python environment and run
`tools/generate-sprites.py`. The bundled NESASM binary is for ARM64 macOS;
set `NESASM` to a compatible compiler on another platform.
