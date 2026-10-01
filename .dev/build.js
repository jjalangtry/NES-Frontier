const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const asm = path.join(root, 'src/asm');

// Deterministic two-screen background. Sparse stars at three luminances.
const field = Buffer.alloc(2048);
let rng = 0x1701;
for (let page = 0; page < 2; page++) {
  for (let row = 0; row < 30; row++) {
    for (let col = 0; col < 32; col++) {
      rng ^= rng << 13; rng ^= rng >>> 17; rng ^= rng << 5;
      if ((rng >>> 0) % 19 === 0) field[page*1024+row*32+col] = 1 + ((rng>>>8) % 3);
    }
  }
}
fs.writeFileSync(path.join(asm,'starfield.bin'),field);
const binary = process.env.NESASM || path.join(root,'bin','nesasm');
const output = path.join(asm,'Frontier.nes');
fs.rmSync(output,{force:true});
const result = spawnSync(binary,['Frontier.asm'],{cwd:asm,encoding:'utf8'});
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) throw result.error;
if (result.status || !fs.existsSync(output)) throw Error('NESASM did not produce a ROM');
const rom = fs.readFileSync(output);
if (rom.length !== 24592 || rom.subarray(0,4).toString('hex') !== '4e45531a') throw Error('Invalid NROM-128 ROM');
fs.mkdirSync(path.join(root,'public/js'),{recursive:true});
fs.copyFileSync(output,path.join(root,'public/frontier.nes'));
fs.copyFileSync(path.join(root,'node_modules/jsnes/dist/jsnes.min.js'),path.join(root,'public/js/jsnes.min.js'));
fs.copyFileSync(path.join(root,'node_modules/jsnes/LICENSE'),path.join(root,'public/js/jsnes-LICENSE.txt'));
console.log(`Built ${rom.length} byte mapper-0 ROM.`);
