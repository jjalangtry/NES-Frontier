"""Build the cartridge's 2bpp tiles and NESASM sprite tables."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'src' / 'asm'
assets = []

def add(name, rows, palette=0):
    width = max(map(len, rows))
    assert width % 8 == 0 and len(rows) % 8 == 0, name
    pixels = [[int(c) if c != '.' else 0 for c in r.ljust(width,'.')] for r in rows]
    assert all(0 <= p <= 4 for row in pixels for p in row)
    assets.append((name,pixels,palette))

# More detailed 48x32 Enterprise: saucer windows, secondary-hull windows,
# two staggered nacelles, blue grilles, and orange Bussard collector tips.
# Logical color 4 is orange; its sprite uses the effects palette.
def canvas_sprite(name, size, palette, paint):
    image = Image.new('P', size, 0)
    paint(ImageDraw.Draw(image))
    pixels = list(image.get_flattened_data())
    add(name, [''.join(str(p) if p else '.' for p in pixels[y*size[0]:(y+1)*size[0]])
               for y in range(size[1])], palette)

def enterprise(d):
    d.polygon([(13,8),(15,8),(19,24),(16,24)], fill=1)
    d.line([(14,9),(17,23)], fill=2)
    d.polygon([(21,25),(29,18),(33,18),(26,26)], fill=1)
    d.line([(23,24),(31,18)], fill=2)
    d.rectangle((2,2,26,5), fill=1)
    d.rectangle((3,3,25,4), fill=2)
    d.line((4,4,20,4), fill=3)
    d.rectangle((24,3,26,4), fill=4)
    d.point((25,3),fill=2)
    d.rectangle((0,8,29,12),fill=1)
    d.rectangle((1,9,28,11),fill=2)
    d.line((3,10,20,10),fill=3)
    d.rectangle((26,9,28,11),fill=4)
    d.point((27,9),fill=2)
    d.ellipse((27,10,47,20),fill=1)
    d.ellipse((28,11,46,18),fill=2)
    d.rectangle((30,18,44,19),fill=1)
    d.line((30,17,44,17),fill=1)
    for x in (31,34,37,40,43): d.point((x,17),fill=3)
    d.rectangle((35,9,39,10),fill=1)
    d.line((36,9,38,9),fill=2)
    d.polygon([(9,23),(26,23),(33,25),(30,29),(12,29),(8,27)],fill=1)
    d.polygon([(10,24),(26,24),(31,25),(28,28),(12,28),(9,27)],fill=2)
    for x in (12,15,18,21,24): d.point((x,26),fill=3)
    d.line((12,28,26,28),fill=1)
    d.point((8,26),fill=1)
    d.point((30,25),fill=3)

# TOS D7, bow left, matching the supplied three-quarter model reference.
# Wide swept engineering hull, long exposed neck, round command bulb,
# raised vented block, and nacelles suspended below the wing tips.
# Paired 8x16 tiles leave room for floating scores and ship meters in OAM.
def klingon(d):
    # Far nacelle and its downturned pylon, behind the broad hull.
    d.rectangle((19,9,20,12),fill=1)
    d.rounded_rectangle((17,12,28,15),radius=1,fill=1)
    d.line((19,13,27,13),fill=2)
    d.point((18,14),fill=3)
    # Wing shoulders sweep out from the recessed neck root.
    d.polygon([(17,6),(25,3),(29,4),(32,7),(39,10),(38,13),
               (28,12),(23,9),(20,8)],fill=1)
    d.polygon([(18,6),(25,4),(29,5),(32,8),(38,10),(36,11),
               (28,10),(23,7),(20,7)],fill=2)
    d.line((28,12,38,12),fill=1)
    # Raised engineering block, two rails, and front vent slots.
    d.polygon([(24,2),(29,1),(32,3),(30,6),(23,5)],fill=1)
    d.polygon([(25,2),(29,2),(31,3),(29,4),(24,4)],fill=2)
    d.line((24,1,28,0),fill=2)
    d.line((29,2,31,2),fill=2)
    for x in (24,26,28): d.point((x,5),fill=3)
    # Near pylon falls below the wing; long engine sits underneath it.
    d.polygon([(35,12),(38,12),(37,19),(35,19)],fill=1)
    d.line((36,13,36,18),fill=2)
    d.rounded_rectangle((25,18,39,22),radius=1,fill=1)
    d.line((27,19,38,19),fill=2)
    d.line((28,21,38,21),fill=2)
    d.line((26,19,26,21),fill=2)
    d.line((37,20,39,20),fill=3)
    # Narrow neck: open space separates it from the wings and engines.
    d.polygon([(7,11),(21,7),(23,8),(8,13)],fill=1)
    d.line((9,11,22,7),fill=2)
    # Broad command cap over the rounded lower bulb, with bridge dome.
    d.ellipse((2,9,8,15),fill=1)
    d.line((3,14,7,14),fill=2)
    d.polygon([(0,10),(3,9),(9,10),(10,11),(8,13),(1,12)],fill=2)
    d.line((1,12,8,12),fill=1)
    for x in (2,4,6,8): d.point((x,12),fill=3)
    d.ellipse((3,8,5,10),fill=1)
    d.point((4,8),fill=2)

canvas_sprite('enterprise',(48,32),0,enterprise)
canvas_sprite('klingon',(40,24),1,klingon)
add('asteroid', [
 '................', '.....11111......', '...112222211....', '..12233222221...',
 '.1223332222221..', '.12333222112221.', '122332221111221.', '122222221112221.',
 '122222222222221.', '.12222122233221.', '.1222112233321..', '..12222223321...',
 '...122222221....', '....1122211.....', '......111.......', '................'
],2)
add('asteroid_large', [
 '........................', '.........111111.........', '......11122222211.......',
 '....112222333222211.....', '...12222233333222221....', '..1222223333322222221...',
 '..12222333332222222221..', '.122223333322221122221..', '.1222223322222111122221.',
 '12222222222221111122221.', '12222222222222111222221.', '12222111222222222222221.',
 '12221111222222222222221.', '.1221111222222233322221.', '.1222112222222333332221.',
 '.122222222222233332221..', '..12222222222233322221..', '..1222222112222222221...',
 '...12222111222222221....', '....122221222222211.....', '.....112222222211.......',
 '.......11222211.........', '.........1111...........', '........................'
],2)
add('torpedo', ['...1....','..121...','.12321..','1233321.','.12321..','..121...','...1....','........'],3)
add('torpedo_alt', ['..1.1...','...2....','1.232.1.','.23332..','1.232.1.','...2....','..1.1...','........'],3)
add('disruptor', ['........','........','..22....','.233222.','..22....','........','........','........'],1)
add('shield', ['..333...','.32223..','3222223.','3221223.','.32223..','.32223..','..323...','...3....'])
add('shield_empty', ['..111...','.1...1..','1.....1.','1.....1.','.1...1..','.1...1..','..1.1...','...1....'])
add('shield_field', ['.3......','..3.....','...3....','....3...','.....3..','.....3..','......3.','......3.',
 '......3.','......3.','......3.','......3.','......3.','......3.','......3.','......3.',
 '......3.','......3.','.....3..','.....3..','....3...','...3....','..3.....','.3......'])
add('impulse', ['........','....3...','....33..','....333.','....33..','....3...','........','........'])
add('explosion', ['................','...1.......1....','....2.....2.....','.....2...2......',
 '......222.......','...12233221.....','....233332......','..1233333321....',
 '....233332......','...12233221.....','......222.......','.....2...2......',
 '....2.....2.....','...1.......1....','................','................'],3)
add('explosion_alt', ['................','...2.......2....','....3.....3.....','..2.........2...',
 '.......1........','..3..11211..3...','.....12221......','.2..1222221..2..',
 '.....12221......','..3..11211..3...','.......1........','..2.........2...',
 '....3.....3.....','...2.......2....','................','................'],3)

def pause_icon(d):
    d.rectangle((4,2,6,13),fill=3)
    d.rectangle((9,2,11,13),fill=3)
    d.line((4,2,4,13),fill=2)
    d.line((9,2,9,13),fill=2)

def resume_icon(d):
    d.polygon([(4,2),(4,13),(13,7)],fill=3,outline=2)

def restart_icon(d):
    d.arc((2,2,13,13),20,320,fill=2,width=2)
    d.polygon([(10,0),(15,2),(11,5)],fill=3)

canvas_sprite('pause_icon',(16,16),0,pause_icon)
canvas_sprite('resume_icon',(16,16),0,resume_icon)
canvas_sprite('restart_icon',(16,16),0,restart_icon)
add('menu_cursor', ['........','..3.....','..33....','..333...','..33....','..3.....','........','........'])

# Two narrow digits share one sprite, keeping both scores on the same row
# within the NES's eight-sprites-per-scanline limit. Flip-equivalent pairs
# share CHR patterns; the last pair overlaps the preceding digit exactly.
digits = [tuple(glyph[y:y+3] for y in range(0,21,3)) for glyph in (
    '111101101101101101111', '010010010010010010010',
    '111001001111100100111', '111001001111001001111',
    '101101101111001001001', '111100100111001001111',
    '111100100111101101111', '111001001001001001001',
    '111101101111101101111', '111101101111001001111',
)]
add('best_star', ['........','...3....','..323...','...3....','........','........','........','........'])
for filled in range(9):
    for name,color in [('meter',2),('heat_meter',3)]:
        rows=['........','........','11111111']
        rows += [str(color)*filled+'.'*(8-filled)]*2
        rows += ['11111111','........','........']
        add(f'{name}_{filled}',rows)

def tile_bytes(pixels):
    result = bytearray()
    for ty in range(0,len(pixels),8):
        for tx in range(0,len(pixels[0]),8):
            for plane in range(2):
                for row in pixels[ty:ty+8]:
                    value = 0
                    for p in row[tx:tx+8]: value = (value<<1) | ((p>>plane)&1)
                    result.append(value)
    return result

bank = bytearray(32)
include = ['; 8x16 sprite count, then horizontal offset, vertical offset, even tile, palette']
for name,pixels,palette in assets:
    parts, data = [], bytearray()
    start = len(bank)//16
    for ty in range(0,len(pixels),16):
        for tx in range(0,len(pixels[0]),8):
            logical = [row[tx:tx+8] for row in pixels[ty:ty+16]]
            logical += [[0]*8 for _ in range(16-len(logical))]
            accent = any(4 in row for row in logical)
            pal = 3 if accent else palette
            if accent:
                assert not any(3 in row for row in logical)
                mapped = [[{0:0,1:1,2:3,4:2}[p] for p in row] for row in logical]
            else: mapped = logical
            chunk = tile_bytes(mapped)
            if any(chunk):
                index = len(data)//16
                data.extend(chunk)
                parts.append((tx,ty,start+index,pal))
    bank.extend(data)
    label = name.replace('_','')
    include += [f'{label}tile = ${start:02X}', f'{label}sprites:',f'  .db ${len(parts):02X}']
    include += ['  .db '+', '.join(f'${v:02X}' for v in part) for part in parts]
include += ['metertiles:', '  .db '+','.join(f'meter{i}tile' for i in range(9))]
include += ['hottiles:', '  .db '+','.join(f'heatmeter{i}tile' for i in range(9))]

stars = []
for points in [[(2,3,1)],[(4,4,2)],[(3,2,2),(2,3,2),(3,3,3),(4,3,2),(3,4,2)]]:
    pixels = [[0]*8 for _ in range(8)]
    for x,y,c in points: pixels[y][x]=c
    stars.append(tile_bytes(pixels))
# Pre-rendered beam tile masks. Horizontal-major paths have one-pixel rises;
# vertical-major paths use even rises, with sub-tile interpolation error <=2px.
# A variable rise per tile yields a continuous line between moving endpoints.
background = bytearray(bytes(16) + b''.join(stars))
beam_tiles = {bytes(16):0}
def register_beam(rows):
    data=bytes(8)+bytes(rows)  # beam uses color 2 (blue), one bitplane
    if data in beam_tiles: return beam_tiles[data]
    index=len(background)//16
    background.extend(data)
    beam_tiles[data]=index
    return index
lookup=[]
for axis in range(2):
    main,spill=[],[]
    for rise in range(-8,9):
        for phase in range(8):
            if axis==1 and rise%2:
                main.append(0);spill.append(0);continue
            tiles={}
            for primary in range(8):
                secondary=phase+primary*rise//8
                rows=tiles.setdefault(secondary//8,bytearray(8))
                if axis==0: rows[secondary%8] |= 1<<(7-primary)
                else: rows[primary] |= 1<<(7-secondary%8)
            main.append(register_beam(tiles.get(0,bytearray(8))))
            spill.append(register_beam(tiles.get(-1 if rise<0 else 1,bytearray(8))))
    lookup.extend([main,spill])
include += ['; Beam masks are in background pattern table $1000.']
for name,data in zip(('beamhmain','beamhspill','beamvmain','beamvspill'),lookup):
    include += [name+':']
    for i in range(0,len(data),16): include += ['  .db '+','.join(f'${v:02X}' for v in data[i:i+16])]
health=[]
for filled in range(9):
    rows=[0]*8
    # Border in dim gray (plane 0); bright fill (planes 0+1).
    lo=[0]*8;hi=[0]*8
    lo[2]=lo[5]=255
    for y in (3,4):
        lo[y]=(255 << (8-filled))&255
        hi[y]=lo[y]
    index=len(background)//16
    background.extend(bytes(lo)+bytes(hi))
    health.append(index)
include += ['healthtiles:', '  .db '+','.join(f'${v:02X}' for v in health)]
# Eight blue border tiles frame the paused game's 64-tile panel.
menu = [0]
for edge in ('tl','t','tr','l','r','bl','b','br'):
    rows=[0]*8
    if 't' in edge: rows[0]=255
    if 'b' in edge: rows[7]=255
    if 'l' in edge:
        for y in range(8): rows[y]|=128
    if 'r' in edge:
        for y in range(8): rows[y]|=1
    if len(edge)==2:
        y=0 if 't' in edge else 7
        rows[y]&=127 if 'l' in edge else 254
    menu.append(len(background)//16)
    background.extend(bytes(8)+bytes(rows))
include += ['menutiles:', '  .db '+', '.join(f'${v:02X}' for v in menu)]

# 8x16 sprites may select either pattern table with tile bit zero. Use the
# spare tail of the background table once the sprite table is full.
if len(background)//16 % 2:
    background.extend(bytes(16))
pair_patterns = {}
pair_tiles, pair_attributes = [], []
for left in digits:
    for right in digits:
        rows = tuple(a+'0'+b+'0' for a,b in zip(left,right))
        mirrored = tuple(row[:7][::-1]+'0' for row in rows)
        variants = [(rows,0), (mirrored,0x40), (rows[::-1],0x80),
                    (mirrored[::-1],0xc0)]
        canonical, attribute = min(variants)
        if canonical not in pair_patterns:
            pixels = [[0]*8]+[[int(p)*2 for p in row] for row in canonical]+[[0]*8 for _ in range(8)]
            chunk = tile_bytes(pixels)
            target = bank if len(bank)+len(chunk)<=4096 else background
            tile = len(target)//16
            target.extend(chunk)
            pair_patterns[canonical] = tile | (target is background)
        pair_tiles.append(pair_patterns[canonical])
        pair_attributes.append(attribute)
for name,data in [('digitpairtiles',pair_tiles),('digitpairattributes',pair_attributes)]:
    include += [name+':']
    for i in range(0,len(data),16):
        include += ['  .db '+','.join(f'${v:02X}' for v in data[i:i+16])]
assert len(background)<=4096
assert len(bank)<=4096
chr_data=bytes(bank).ljust(4096,b'\0')+bytes(background).ljust(4096,b'\0')
(OUT/'sprites.chr').write_bytes(chr_data)
(OUT/'sprites.inc').write_text('\n'.join(include)+'\n')
print(f'Generated {len(bank)//16} sprite tiles and {len(background)//16} background tiles.')
