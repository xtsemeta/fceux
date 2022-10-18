import 'dart:typed_data';

var PPU = List.filled(4, 0);
var PPUSPL = 0;
var NTARAM = List.filled(0x800, 0);
var PALRAM = List.filled(0x20, 0);
var SPRAM = List.filled(0x100, 0);
var SPBUF = List.filled(0x100, 0);
var UPALRAM = List.filled(0x03, 0); //对应调色板中0x4/0x8/0xC地址，0x20中那些地址为0来非终止渲染。

var ppulut1 = Uint32List(256);
var ppulut2 = Uint32List(256);
var ppulut3 = Uint32List(256);

var VBlankON = PPU[0] & 0x80; //生成VBlank NMI
var Sprite16 = PPU[0] & 0x20; //精灵 8x16/8x8
var BGAdrHI = PPU[0] & 0x10; //背景模式地址 $0000/$1000
var SpAdrHI = PPU[0] & 0x08; //精灵模式地址 $0000/$1000
var INC32 = PPU[0] & 0x04; //自增1/32

var SpriteON = PPU[1] & 0x10; //显示精灵
var ScreenON = PPU[1] & 0x08; //显示屏幕
var PPUON = PPU[1] & 0x18; //PPU应该运行
var GRAYSCALE = PPU[1] & 0x01; //灰度（和调色板条目 0x30）

var SpriteLeft8 = PPU[1] & 0x04;
var BGLeft8 = PPU[1] & 0x02;

var PPU_status = PPU[2];

var genLatch = 0;

//使用内部寄存器概念http://nesdev.icequake.net/PPU%20addressing.txt
class PPUREGS {
  var fv = 0;
  var v = 0;
  var h = 0;
  var vt = 0;
  var ht = 0;

  var _fv = 0, _v = 0, _h = 0, _vt = 0, _ht = 0;

  var fh = 0;
  var s = 0;

  var par = 0;

  var status = PPUSTATUS();
}

class PPUSTATUS {
  var sl = 0;
  var cycle = 0;
  var endcycle = 0;
}

class STRIPE_READ {
  var num = 0;
  var count = 0;
  var fetch = 0;
  var found = 0;
  var foundPos = List.filled(8, 0);
  var ret = 0;
  var last = 0;
  var mode = 0;

  void reset() {
    num = count = fetch = found = ret = last = mode = 0;
    foundPos[0] = foundPos[1] = foundPos[2] = foundPos[3] = 0;
    foundPos[4] = foundPos[5] = foundPos[6] = foundPos[7] = 0;
  }

  void startScanline() {
    num = 1;
    found = 0;
    fetch = 1;
    count = 0;
    last = 64;
    mode = 0;

    foundPos[0] = foundPos[1] = foundPos[2] = foundPos[3] = 0;
    foundPos[4] = foundPos[5] = foundPos[6] = foundPos[7] = 0;
  }
}

enum PPUPHASE { VBL, BG, OBJ }

// ppu look-up-table
void makeppulut() {
  for (int x = 0; x < 256; x++) {
    ppulut1[x] = 0;
    for (var y = 0; y < 8; y++) {
      ppulut1[x] |= ((x >> (7 - y)) & 1) << (y * 4);
    }
    ppulut2[x] = ppulut1[x] << 1;
  }

  for (var cc = 0; cc < 16; cc++) {
    for (var xo = 0; xo < 8; xo++) {
      ppulut3[xo | (cc << 3)] = 0;
      for (var pixel = 0; pixel < 8; pixel++) {
        var shiftr = (pixel + xo) ~/ 8;
        shiftr *= 2;
        ppulut3[xo | (cc << 3)] |= ((cc >> shiftr) & 3) << (2 + pixel * 4);
      }
    }
  }
}

void init() {}
void reset() {}
void power() {}
void loop() {}

void lineUpdate() {}
void setVideoSystem(int w) {}

void saveState() {}
void loadState(int version) {}
void peekAddress() {}

typedef ARead = int Function(int a);

//$2004 地址读取会失败
ARead a200x = (int a) {
  lineUpdate();
  return genLatch;
};

ARead a2002 = (int a) {
  var ret = 0;
  lineUpdate();

  return ret;
};
