import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'fc.dart';

class BitrevLut {
  late Uint8List lut;
  BitrevLut() {
    int bits = 8;
    var n = 1 << bits;
    lut = Uint8List(n);

    var m = 1;
    var a = n >> 1;
    var j = 2;

    lut[0] = 0;
    lut[1] = a;

    while (--bits > 0) {
      m <<= 1;
      a >>= 1;
      for (var i = 0; i < m; i++) {
        lut[j++] = lut[i] + a;
      }
    }
  }

  int operator [](int index) {
    return lut[index];
  }
}

class PPU {
  var ppu = Uint8List(4);
  var ppuspl = 0;
  var ntaram = Uint8List(0x800),
      palram = Uint8List(0x20),
      spram = Uint8List(0x100),
      sprbuf = Uint8List(0x100);
  var upalram = Uint8List(0x03); //对应调色板中0x4/0x8/0xC地址，0x20中那些地址为0来非终止渲染。

  int get vblank => ppu[0] & 0x80;
  bool get sprite16 => (ppu[0] & 0x20) != 0;
  int get bgAddrHi => ppu[0] & 0x10;
  int get spAddrHi => ppu[0] & 0x08;
  int get inc32 => ppu[0] & 0x04;

  int get spriteON => ppu[1] & 0x10;
  int get screenON => ppu[1] & 0x08;
  bool get ppuON => (ppu[1] & 0x18) != 0;
  int get grascale => ppu[1] & 0x01;
  int get spriteLeft8 => ppu[1] & 0x04;
  int get bgLeft8 => ppu[1] & 0x02;

  int get status => ppu[2];

  int _readPalNogs(int ofs) => palram[ofs];
  int _readPal(int ofs) => palram[ofs] & (grascale > 0 ? 0x30 : 0xFF);
  int _readUPal(int ofs) => upalram[ofs] & (grascale > 0 ? 0x30 : 0xFF);

  var ppulut1 = Uint32List(256),
      ppulut2 = Uint32List(256),
      ppulut3 = Uint32List(128);

  var newPpuReset = false;
  int test = 0;

  var bitrevLut = BitrevLut();
  var ppuphase;
  var sprRead = STRIPE_READ();
  var idleSynch = 1;
  var ppur = PPUREGS();

  int getNewppuScanline() => ppur.status.sl;
  int getNewppuDot() => ppur.status.cycle;

  void newppuHackyEmergencyReset() {
    if (ppur.status.cycle == 0) {
      ppur.reset();
    }
  }

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

  static var ppudead = 1;
  static var kook = 0;
  var fcindbg = 0;

  //mbg 6/23/08
  //make the no-bg fill color configurable
  //0xFF shall indicate to use palette[0]
  var gNoBgFillColor = 0xff;

  var mmc5Hack = 0;
  var mmc5HackVromMask = 0;
  var mmc5HackExNtaram = [];
  var mmc5HackVrom = [];
  var mmc5HackChrMode = 0;
  var mmc5HackSPMode = 0;
  var mmc50x5130 = 0;
  var mmc5HackSPScroll = 0;
  var mmc5HackSPPage = 0;

  var pec586hack = 0;

  var qtaihack = 0;
  var qraiNtram = Uint8List(2048);
  var qraintramreg = 0;

  var vramBuffer = 0, ppuGenLatch = 0;
  var vnapage = Uint8List(4);
  var ppuNtaRam = 0;
  var ppuChrRam = 0;

  static var deemp = 0; //脱色
  var deempcnt = List.filled(8, 0);

  var vtoggle = 0;
  var xOffset = 0;
  // $4014 / Writing $xx copies 256 bytes by reading from $xx00-$xxFF and writing to $2004 (OAM data)
  var spriteDma = 0;

  var tempAddr = 0, refreshAddr = 0, dummyRead = 0, ntRefreshAddr = 0;

  static var maxsprites = 8;

  var scanline = 0;
  var rasterpos = 0;
  static var scanlinePerFrame = 0;

  var newppu = false;

  int get lastPixel => 0; //Todo
  static var pline = [], plinef = [];
  static var firsttile = 0;
  var linestartts = 0;
  static var tofix = 0;

  static var sprlinebuf = Uint16List(256 + 8);

  var rendersprites = true, renderbg = true;

  void lineUpdate() {
    if (newppu) return;
    if (pline.isNotEmpty) {
      var l = lastPixel;
      refreshLine(l);
    }
  }

  void setRenderPlanes(bool sprites, bool bg) {
    rendersprites = sprites;
    renderbg = bg;
  }

  void init() => makeppulut();
  void reset() {
    vramBuffer = ppu[0] = ppu[1] = ppu[2] = ppu[3] = 0;
    ppuspl = 0;
    ppuGenLatch = 0;
    refreshAddr = 0;
    tempAddr = 0;
    vtoggle = 0;
    ppudead = 2;
    kook = 0;
    idleSynch = 1;

    newPpuReset = true;
  }

  void power() {
    ntaram.fillRange(0, 0x800, 0x00);
    palram.fillRange(0, 0x20, 0x00);
    upalram.fillRange(0, 0x03, 0x00);
    spram.fillRange(0, 0x100, 0x00);
    reset();

    for (var i = 0x2000; i < 0x4000; i += 8) {
      aread[i] = a200x;
    }
  }

  //$2004 地址读取会失败
  int a200x(int a) {
    lineUpdate();
    return ppuGenLatch;
  }

  int a2002(int a) {
    int ret = 0;
    lineUpdate();
    ret = status;
    ret |= ppuGenLatch & 0x1f;
    return ret;
  }

  int a2004(int a) {
    if (newppu) {
      if (ppur.status.sl < 241 && ppuON) {
        // from cycles 0 to 63, the
        // 32 byte OAM buffer gets init
        // to 0xFF
        if (ppur.status.cycle < 64) {
          return sprRead.ret = 0xff;
        } else {
          for (var i = sprRead.last; i != ppur.status.cycle; i++) {
            if (i < 256) {
              switch (sprRead.mode) {
                case 0:
                  if (sprRead.count < 2) {
                    sprRead.ret = (ppu[3] & 0xF8) + (sprRead.count << 2);
                  } else {
                    sprRead.ret = sprRead.count << 2;
                  }

                  sprRead.foundPos[sprRead.found] = sprRead.ret;
                  sprRead.ret = spram[sprRead.ret];

                  if (i & 1 != 0) {
                    //odd cycle
                    //see if in range
                    if (((ppur.status.sl - 1 - sprRead.ret) &
                            ~(sprite16 ? 0xF : 0x7)) !=
                        0) {
                      ++sprRead.found;
                      sprRead.fetch = 1;
                      sprRead.mode = 1;
                    } else {
                      if (++sprRead.count == 64) {
                        sprRead.mode = 4;
                        sprRead.count = 0;
                      } else if (sprRead.found == 8) {
                        sprRead.fetch = 0;
                        sprRead.mode = 2;
                      }
                    }
                  }
                  break;
                case 1: //sprite is in range fetch next 3 bytes
                  if (i & 1 != 0) {
                    ++sprRead.fetch;
                    if (sprRead.fetch == 4) {
                      sprRead.fetch = 1;
                      if (++sprRead.count == 64) {
                        sprRead.count = 0;
                        sprRead.mode = 4;
                      } else if (sprRead.found == 8) {
                        sprRead.fetch = 0;
                        sprRead.mode = 2;
                      } else {
                        sprRead.mode = 0;
                      }
                    }
                  }

                  if (sprRead.count < 2) {
                    sprRead.ret = (ppu[3] & 0xF8) + (sprRead.count << 2);
                  } else {
                    sprRead.ret = sprRead.count << 2;
                  }

                  sprRead.ret = spram[sprRead.ret | sprRead.fetch];
                  break;
                case 2: //8th sprite fetched
                  sprRead.ret = spram[(sprRead.count << 2) | sprRead.fetch];
                  if (i & 1 != 0) {
                    if (((ppur.status.sl -
                                1 -
                                spram[(sprRead.count << 2) | sprRead.fetch]) &
                            ~(sprite16 ? 0xf : 0x7)) !=
                        0) {
                      sprRead.fetch = 1;
                      sprRead.mode = 3;
                    } else {
                      if (++sprRead.count == 64) {
                        sprRead.count = 0;
                        sprRead.mode = 4;
                      }
                      sprRead.fetch = (sprRead.fetch + 1) & 3;
                    }
                  }
                  sprRead.ret = sprRead.count;
                  break;
                case 3: //9th sprite overflow detected
                  sprRead.ret = spram[sprRead.count | sprRead.fetch];
                  if (i & 1 != 0) {
                    if (++sprRead.fetch == 4) {
                      sprRead.count = (sprRead.count + 1) & 63;
                      sprRead.mode = 4;
                    }
                  }
                  break;
                case 4: //read OAM[n][0] until hblank
                  if (i & 1 != 0) sprRead.count = (sprRead.count + 1) & 63;
                  sprRead.fetch = 0;
                  sprRead.ret = spram[sprRead.count << 2];
                  break;
              }
            } else if (i < 320) {
              sprRead.ret = (i & 0x38) >> 3;
              if (sprRead.found < (sprRead.ret + 1)) {
                if (sprRead.num != 0) {
                  sprRead.ret = spram[252];
                  sprRead.num = 0;
                } else {
                  sprRead.ret = 0xff;
                }
              } else if ((i & 7) < 4) {
                sprRead.ret =
                    spram[sprRead.foundPos[sprRead.ret] | sprRead.fetch++];
                if (sprRead.fetch == 4) {
                  sprRead.fetch = 0;
                }
              } else {
                sprRead.ret = spram[sprRead.foundPos[sprRead.ret | 3]];
              }
            } else {
              if (sprRead.found != 0) {
                sprRead.ret = spram[252];
              } else {
                sprRead.ret = spram[sprRead.foundPos[0]];
              }
            }
          }
          sprRead.last = ppur.status.cycle;
          return sprRead.ret;
        }
      } else {
        return spram[ppu[3]];
      }
    } else {
      lineUpdate();
      return ppuGenLatch;
    }
  }
}

//使用内部寄存器概念http://nesdev.icequake.net/PPU%20addressing.txt
class PPUREGS {
  //临时的飞锁寄存器（需要保存状态，可以在任何时候被写入）
  var fv = 0; //3
  var v = 0; //1
  var h = 0; //1
  var vt = 0; //5
  var ht = 0; //5

  var _fv = 0, _v = 0, _h = 0, _vt = 0, _ht = 0;

  var fh = 0; //3
  var s = 0; //1

  var par = 0; //8

  var status = PPUSTATUS();

  void reset() {
    fv = v = h = vt = ht = 0;
    fh = par = s = 0;
    _fv = _v = _h = _vt = _ht = 0;
    status.cycle = 0;
    status.endcycle = 341;
    status.sl = 241;
  }

  void installLatches() {
    _fv = fv;
    _v = v;
    _h = h;
    _vt = vt;
    _ht = ht;
  }

  void installHLatches() {
    _h = h;
    _ht = ht;
  }

  void clearLatches() {
    fv = v = h = vt = ht = 0;
    fh = 0;
  }

  void incrementHsc() {
    _ht++;
    _h += (_ht >> 5);
    _ht &= 31;
    _h &= 1;
  }

  void incrementVs() {
    _fv++;
    var fvOverFlow = _fv >> 3;
    _vt += fvOverFlow;
    _vt &= 31;

    if (_vt == 30 && fvOverFlow == 1) {
      _v++;
      _vt = 0;
    }
    _fv &= 7;
    _v &= 1;
  }

  int get getNtRead => 0x2000 | (_v << 0xB) | (_h << 0xA) | (_vt << 5) | _ht;
  int get get2007Access =>
      ((_fv & 3) << 0xC) | (_v << 0xB) | (_h << 0xA) | (_vt << 5) | _ht;
  int get getAtRead =>
      0x2000 |
      (_v << 0xB) |
      (_h << 0xA) |
      0x3C0 |
      ((_vt & 0x1C) << 1) |
      ((_ht & 0x1C) >> 2);
  int get getPtRead => (s << 0xC) | (par << 0x4) | _fv;

  void increment2007(bool rendering, bool by32) {
    if (rendering) {
      incrementVs();
      return;
    }

    if (by32) {
      _vt++;
    } else {
      _ht++;
      _vt += (_ht >> 5) & 1;
    }
    _h += (_vt >> 5);
    _v += (_h >> 1);
    _fv += (_v >> 1);
    _ht &= 31;
    _vt &= 31;
    _h &= 1;
    _v &= 1;
    _fv &= 7;
  }

  void log() {
    if (kDebugMode) {
      print("ppur: _fv($_fv), _v($_v), _h($_h), _vt($_vt), _ht($_ht)");
      print("      fv($fv), v($v), h($h), vt($vt), ht($ht)");
      print("      fh($fh), s($s), par($par)");
      print(
          "      .status_cycle(${status.cycle}), end_cycle(${status.endcycle}), sl(${status.sl})");
    }
  }
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
