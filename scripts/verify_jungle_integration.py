"""Read-only checks of BDF wiring, preserved gameplay and protected configuration.

Requires git history containing 19ae76c (the preceding verified graphics build).
Run from any directory. Geometry/map/ROM checks live in the converter/tests.
--qsf-index explicitly checks the staged QSF when later local configuration edits
must be preserved but excluded from the verified graphics commit.
"""
import argparse
import re
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE='19ae76c'

def previous(path):
    return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode().replace('\r\n','\n')

def read(path): return (ROOT/path).read_text()

def blocks(text,kind):
    # Ignore quoted parentheses and comment/license blocks.
    for match in re.finditer(r'^\('+kind+r'\b',text,re.M):
        depth=0;quoted=False
        for end in range(match.start(),len(text)):
            char=text[end]
            if char=='"': quoted=not quoted
            if not quoted:
                if char=='(': depth+=1
                elif char==')': depth-=1
            if depth==0:
                yield text[match.start():end+1];break

def symbol(text,name):
    return next(b for b in blocks(text,'symbol') if re.search(r'\(text "'+re.escape(name)+r'"',b))

def net(text,x,y):
    matches=[b for b in blocks(text,'connector') if f'(pt {x} {y})' in b]
    named=[re.search(r'\(text "([^"]+)"',b)[1] for b in matches if '(text ' in b]
    assert len(named)==1,(x,y,matches)
    return named[0]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--qsf-index',action='store_true')
    args=parser.parse_args()
    protected=['RTL/VGA/snake_head.sv','RTL/VGA/game_controller.sv','RTL/VGA/appleCounter.sv',
        'RTL/VGA/highscoreComp.sv','RTL/VGA/relic_collection_counters.sv','RTL/VGA/blue_apple_controller.sv',
        'RTL/VGA/randomCounter.sv','RTL/VGA/apple_TopLeft_Calc.sv','RTL/VGA/ScoreConstants.sv',
        'RTL/VGA/Score_Block.bdf','RTL/VGA/Apple_Block.bdf','RTL/VGA/objects_mux.sv',
        'RTL/VGA/square_object.sv','RTL/VGA/End_Message_Display.sv','constraints/pin.tcl',
        'DE10_Standard_Audio.sdc','constraints/DE10_Standard_Audio.sdc',
        'CLK_31P5.qip','CLK_31P5.sip','CLK_31P5.v','CLK_31P5/CLK_31P5_0002.v',
        'RTL/mifs/numbers_new_font.mif','jungle-temple-reference.png']
    # Byte comparisons include binaries without decoding; never write originals.
    for path in protected:
        if not (ROOT/path).exists():
            raise AssertionError('Missing protected file '+path)
        raw=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
        now=(ROOT/path).read_bytes()
        assert now.replace(b'\r\n',b'\n')==raw.replace(b'\r\n',b'\n'),path
    before=previous('Lab1Demo.qsf');now=read('Lab1Demo.qsf')
    if args.qsf_index:
        staged=subprocess.check_output(['git','show',':Lab1Demo.qsf'],cwd=ROOT).decode().replace('\r\n','\n')
        if staged!=now:
            print('NOTICE: working QSF differs from staged/compiled configuration; local changes are NOT verified by the previous build')
        now=staged
    assert now.replace('set_global_assignment -name SYSTEMVERILOG_FILE RTL/VGA/jungle_head_draw.sv\n','')==before
    # Only body visual outputs change; every state update and self-hit line remains.
    before=previous('RTL/VGA/snake_body.sv');now=read('RTL/VGA/snake_body.sv')
    assert before.rsplit('//------------- Outputs -----------',1)[0]==now.rsplit('//------------- Outputs -----------',1)[0]
    assert before[before.index('assign snakeSelfCollision'):].strip()==now[now.index('assign snakeSelfCollision'):].strip()
    before=previous('RTL/VGA/headBitMap.sv');now=read('RTL/VGA/headBitMap.sv')
    now=now.replace('\t// Frozen legacy silhouette: this output now drives collision only.\n','').replace('snake_head_collision_24.mif','snake_head_24.mif')
    assert before.strip()==now.strip()
    for path in ['RTL/VGA/NumbersBitMap.sv','RTL/VGA/hud_labels.sv']:
        # Palette-only edits, no numeric/label positioning or logic changes.
        assert re.sub(r"8'h[0-9A-Fa-f]+",'COLOR',previous(path)).strip()==re.sub(r"8'h[0-9A-Fa-f]+",'COLOR',read(path)).strip()
    top=read('RTL/VGA/TOP_VGA_DEMO.bdf');snake=read('RTL/VGA/Snake_Block.bdf')
    assert symbol(top,'game_controller')==symbol(previous('RTL/VGA/TOP_VGA_DEMO.bdf'),'game_controller')
    assert symbol(top,'objects_mux')==symbol(previous('RTL/VGA/TOP_VGA_DEMO.bdf'),'objects_mux')
    assert net(top,488,64)=='snakeHeadVisual_DR'
    assert net(top,-728,-144)=='snakeHead_DR'
    assert net(top,-416,808)=='snakeHeadVisual_DR'
    assert net(snake,1144,720)=='topLeftX[10..0]' and net(snake,1144,736)=='topLeftY[10..0]'
    assert net(snake,1144,752)=='snakeHeadDir[2..0]'
    for name in ['square_object','headBitMap','snake_body']:
        assert symbol(snake,name)==symbol(previous('RTL/VGA/Snake_Block.bdf'),name),name
    assert '"OBJECT_WIDTH_X"\n\t\t"22"' in snake and '"OBJECT_HEIGHT_Y"\n\t\t"24"' in snake
    print('PASS: visual-only head mux wiring, legacy collision BDF interfaces, body state, HUD geometry, score/movement/input/audio/timing/pins preserved')

if __name__=='__main__': main()
