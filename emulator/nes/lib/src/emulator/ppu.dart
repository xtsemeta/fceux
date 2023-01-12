import 'cartridge.dart';
import 'cpu.dart';
import 'interrupt.dart';
import 'mapper.dart';

class PPU {
  Cartridge cartridge;
  PPUStepCallback? stepCallback;
  int cycle = 0; // 0-340
  int scanLine = 0; // 0-261, 0-239=visible, 240=post, 241-260=vblank, 261=pre
  int frame = 0; // frame counter

  // storage variables
  var paletteData = List.filled(32, 0);
  var nameTableData = List.filled(2048, 0);
  var oamData = List.filled(256, 0);
  late List<int> front = List.filled(imgWidth * imgHeight, 0);
  late List<int> back = List.filled(imgWidth * imgHeight, 0);

  // ppu registers
  int v = 0; // current vram address (15 bit)
  int t = 0; // temporary vram address (15 bit)
  int x = 0; // fine x scroll (3 bit)
  int w = 0; // write toggle (1 bit)
  int f = 0; // even/odd frame flag (1 bit)
  int register = 0;

  bool nmiOccurred = false;
  bool nmiOutput = false;
  bool nmiPrevious = false;
  int nmiDelay = 0;

  // background temporaty variables
  int nameTableByte = 0;
  int attributeTableByte = 0;
  int lowTileByte = 0;
  int highTileByte = 0;
  int tileData = 0;

  // sprite temporary variables
  int spriteCount = 0;
  List<int> spritePatterns = List.filled(8, 0);
  List<int> spritePositions = List.filled(8, 0);
  List<int> spritePriorities = List.filled(8, 0);
  List<int> spriteIndexes = List.filled(8, 0);

  // $2000 ppu ctrl
  /// 0:$2000<br/> 1:$2400<br/> 2:$2800<br/> 3:$2C00<br/>
  int flagNameTable = 0;

  /// 0: add 1<br/>
  /// 1: add 32
  int flagIncrement = 0;

  /// 0:$0000<br>
  /// 1:$1000<br>
  /// ignored in 8x16 mode
  int flagSpriteTable = 0;

  /// 0:$0000<br>
  /// 1:$1000<br>
  int flagBackgroundTable = 0;

  /// 0:8x8
  /// 1:8x16
  int flagSpriteSize = 0;

  /// 0: read EXT<br/>
  /// 1: write Ext
  int flagMasterSlave = 0;

  // $2001 ppu mask
  int flagGrayscale = 0;
  int flagShowLeftBackground = 0;
  int flagShowLeftSprites = 0;
  int flagShowBackground = 0;
  int flagShowSprites = 0;
  int flagRedTint = 0;
  int flagGreenTint = 0;
  int flagBlueTint = 0;

  // $2002 ppu status
  int flagSpriteZeroHit = 0;
  int flagSpriteOverflow = 0;

  // $2003 ppu oam addr
  int oamAddress = 0;

  // $2007 ppu data
  int bufferedData = 0; // for buffered reads

  var zeroTo255 = List.generate(256, (index) => index);
  var zeroTo63 = List.generate(64, (index) => index);
  var zeroTo7 = List.generate(8, (index) => index);
  late int mirror = cartridge.mirror;

  late CPU cpu;
  Mapper? mapper;
  bool isMMC3 = false;
  bool isNoOpMapper = false;

  PPU(this.cartridge, {this.stepCallback}) {
    reset();
  }

  int readRegister(int address) {
    if (address == 0x2002) {
      // read status
      var result = register & 0x1F;
      result = result | (flagSpriteOverflow << 5);
      result = result | (flagSpriteZeroHit << 6);
      if (nmiOccurred) {
        result = result | (1 << 7);
      }
      nmiOccurred = false;
      nmiChange();
      w = 0;
      return result;
    }
    if (address == 0x2004) {
      return oamData[oamAddress];
    }
    if (address == 0x2007) {
      // read data
      var value = read(v);
      if (v % 0x4000 < 0x3F00) {
        var buffered = bufferedData;
        bufferedData = value;
        value = buffered;
      } else {
        bufferedData = read(v - 0x1000);
      }
      v += flagIncrement == 0 ? 1 : 32;
      return value;
    }
    return 0;
  }

  writeRegister(int address, int value) {
    register = value;
    switch (address) {
      case 0x2000:
        writeControl(value);
        break;
      case 0x2001:
        writeMask(value);
        break;
      case 0x2003: // write oam address
        oamAddress = value;
        break;
      case 0x2004: // write oam data
        oamData[oamAddress++] = value;
        break;
      case 0x2005:
        // write scroll
        if (w == 0) {
          // t: ........ ...HGFED = d: HGFED...
          // x:               CBA = d: .....CBA
          // w:                   = 1
          t = (t & 0xFFE0) | (value >> 3);
          x = value & 0x07;
          w = 1;
        } else {
          // t: .CBA..HG FED..... = d: HGFEDCBA
          // w:                   = 0
          t = (t & 0x8FFF) | ((value & 0x07) << 12);
          t = (t & 0xFC1F) | ((value & 0xF8) << 2);
          w = 0;
        }
        break;
      case 0x2006:
        // write address
        if (w == 0) {
          // t: ..FEDCBA ........ = d: ..FEDCBA
          // t: .X...... ........ = 0
          // w:                   = 1
          t = (t & 0x80FF) | ((value & 0x3F) << 8);
          w = 1;
        } else {
          // t: ........ HGFEDCBA = d: HGFEDCBA
          // v                    = t
          // w:                   = 0
          t = (t & 0xFF00) | value;
          v = t;
          w = 0;
        }
        break;
      case 0x2007:
        // write data
        write(v, value);
        v += flagIncrement == 0 ? 1 : 32;
        break;
      case 0x4014:
        // write dma
        var address1 = value << 8;
        for (var it in zeroTo255) {
          oamData[oamAddress] = cpu.read(address1);
          oamAddress = (oamAddress + 1) & 0xFF;
          address1++;
        }
        cpu.stall += 513;
        if (cpu.cycles % 2.0 == 1.0) {
          cpu.stall++;
        }
        break;
    }
  }

  String dumpState() {
    // return StatePersistence.dumpState(
    //     cycle, scanLine, frame, paletteData, nameTableData,
    //     oamData, v, t, x, w, f, register, nmiOccurred, nmiOutput, nmiPrevious,
    //     nmiDelay, nameTableByte, attributeTableByte, lowTileByte, highTileByte, tileData,
    //     spriteCount, spritePatterns, spritePositions,
    //     spritePriorities, spriteIndexes, flagNameTable, flagIncrement,
    //     flagSpriteTable, flagBackgroundTable, flagSpriteSize, flagMasterSlave, flagGrayscale,
    //     flagShowLeftBackground, flagShowLeftSprites, flagShowBackground, flagShowSprites,
    //     flagRedTint, flagGreenTint, flagBlueTint, flagSpriteZeroHit, flagSpriteOverflow,
    //     oamAddress, bufferedData, mirror
    // ).also { println("PPU state saved") }
    return '';
  }

  restoreState(String serializedState) {
    // var state = StatePersistence.restoreState(serializedState)
    // cycle = state.next()
    // scanLine = state.next()
    // frame = state.next()
    // paletteData = state.next()
    // nameTableData = state.next()
    // oamData = state.next()
    // v = state.next()
    // t = state.next()
    // x = state.next()
    // w = state.next()
    // f = state.next()
    // register = state.next()
    // nmiOccurred = state.next()
    // nmiOutput = state.next()
    // nmiPrevious = state.next()
    // nmiDelay = state.next()
    // nameTableByte = state.next()
    // attributeTableByte = state.next()
    // lowTileByte = state.next()
    // highTileByte = state.next()
    // tileData = state.next()
    // spriteCount = state.next()
    // spritePatterns = state.next()
    // spritePositions = state.next()
    // spritePriorities = state.next()
    // spriteIndexes = state.next()
    // flagNameTable = state.next()
    // flagIncrement = state.next()
    // flagSpriteTable = state.next()
    // flagBackgroundTable = state.next()
    // flagSpriteSize = state.next()
    // flagMasterSlave = state.next()
    // flagGrayscale = state.next()
    // flagShowLeftBackground = state.next()
    // flagShowLeftSprites = state.next()
    // flagShowBackground = state.next()
    // flagShowSprites = state.next()
    // flagRedTint = state.next()
    // flagGreenTint = state.next()
    // flagBlueTint = state.next()
    // flagSpriteZeroHit = state.next()
    // flagSpriteOverflow = state.next()
    // oamAddress = state.next()
    // bufferedData = state.next()
    // mirror = state.next()
    // println("PPU state restored")
  }

  bool step() {
//    stepCallback?.step(cycle, scanLine, frame, paletteData, nameTableData, oamData, v, t, x, w, f,
//        register, nmiOccurred, nmiOutput, nmiPrevious, nmiDelay, nameTableByte, attributeTableByte,
//        lowTileByte, highTileByte, tileData, spriteCount, spritePatterns, spritePositions, spritePriorities,
//        spriteIndexes, flagNameTable, flagIncrement, flagSpriteTable, flagBackgroundTable,
//        flagSpriteSize, flagMasterSlave, flagGrayscale, flagShowLeftBackground, flagShowLeftSprites,
//        flagShowBackground, flagShowSprites, flagRedTint, flagGreenTint, flagBlueTint,
//        flagSpriteZeroHit, flagSpriteOverflow, oamAddress, bufferedData)
    // tick()
    var tickDone = false;
    if (nmiDelay > 0) {
      nmiDelay--;
      if (nmiDelay == 0 && nmiOutput && nmiOccurred) {
        // trigger NMI causes a non-maskable interrupt to occur on the next cycle
        cpu.interrupt = Interrupt.nmi;
      }
    }
    if (flagShowBackground != 0 || flagShowSprites != 0) {
      if (f == 1 && scanLine == 261 && cycle == 339) {
        cycle = 0;
        scanLine = 0;
        frame++;
        f = f ^ 1;
        tickDone = true;
      }
    }
    if (!tickDone) {
      cycle++;
      if (cycle > 340) {
        cycle = 0;
        scanLine++;
        if (scanLine > 261) {
          scanLine = 0;
          frame++;
          f = f ^ 1;
        }
      }
    }
    var renderingEnabled = flagShowBackground != 0 || flagShowSprites != 0;
    var preLine = scanLine == 261;
    var visibleLine = scanLine < 240;
    // postLine = scanLine == 240
    var renderLine = preLine || visibleLine;
    var preFetchCycle = 321 <= cycle && cycle <= 336;
    var visibleCycle = 1 <= cycle && cycle <= 256;
    var fetchCycle = preFetchCycle || visibleCycle;
    if (renderingEnabled) {
      if (visibleLine && visibleCycle) {
        // render pixel
        var x1 = cycle - 1;
        var y = scanLine;
        var background = 0; /* Byte */
        if (flagShowBackground != 0) {
          background = (tileData >> 32 >> ((7 - x) * 4)) & (0x0F);
        }
        var spritePixelI = 0;
        var spritePixelSprite = 0;
        // sprite pixel
        if (flagShowSprites == 0) {
          spritePixelI = 0;
          spritePixelSprite = 0;
        } else {
          var spritePixelDone = false;
          for (var i = 0; i < spriteCount; i++) {
            var offset = (cycle - 1) - spritePositions[i];
            if (offset < 0 || offset > 7) {
              continue;
            }
            offset = 7 - offset;
            var color = (spritePatterns[i] >> ((offset * 4) & 0xFF)) & 0x0F;
            if (color % 4 == 0) {
              continue;
            }
            spritePixelI = i;
            spritePixelSprite = color;
            spritePixelDone = true;
          }
          if (!spritePixelDone) {
            spritePixelI = 0;
            spritePixelSprite = 0;
          }
        }
        if (x1 < 8 && flagShowLeftBackground == 0) {
          background = 0;
        }
        if (x1 < 8 && flagShowLeftSprites == 0) {
          spritePixelSprite = 0;
        }
        var b = background % 4 != 0;
        var s = spritePixelSprite % 4 != 0;
        var color = 0; /* Byte */
        if (!b && !s) {
          color = 0;
        } else if (!b && s) {
          color = spritePixelSprite | 0x10;
        } else if (b && !s) {
          color = background;
        } else {
          if (spriteIndexes[spritePixelI] == 0 && x1 < 255) {
            color = flagSpriteZeroHit = 1;
          }
          if (spritePriorities[spritePixelI] == 0) {
            color = spritePixelSprite | 0x10;
          } else {
            color = background;
          }
        }
        back[y * imgWidth + x1] = palette[
            paletteData[(color >= 16 && color % 4 == 0) ? color - 16 : color] %
                64];
      }
      if (renderLine && fetchCycle) {
        tileData = tileData << 4;
        switch (cycle % 8) {
          case 1:
            {
              // fetch name table byte
              nameTableByte = (read(0x2000 | (v & 0x0FFF))) & 0xFF;
            }
            break;
          case 3:
            {
              // fetch attribute table byte
              var address =
                  0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07);
              var shift = ((v >> 4) & 4) | (v & 2);
              attributeTableByte = ((read(address) >> shift) & 3) << 2;
            }
            break;
          case 5:
            {
              // fetch low tile byte
              var fineY = (v >> 12) & 7;
              var table = flagBackgroundTable;
              var tile = nameTableByte;
              var address = 0x1000 * table + tile * 16 + fineY;
              lowTileByte = read(address);
            }
            break;
          case 7:
            {
              // fetch high tile byte
              highTileByte = read(0x1000 * flagBackgroundTable +
                  nameTableByte * 16 +
                  ((v >> 12) & 7) +
                  8);
            }
            break;
          case 0:
            {
              // store tile data
              var data = 0;
              for (var i in zeroTo7) {
                var a = attributeTableByte;
                var p1 = (lowTileByte & 0x80) >> 7;
                var p2 = (highTileByte & 0x80) >> 6;
                lowTileByte = (lowTileByte << 1) & 0xFF;
                highTileByte = (highTileByte << 1) & 0xFF;
                data = data << 4;
                data = data | (a | p1 | p2);
              }
              tileData = tileData | data;
            }
            break;
        }
      }
      if (preLine && cycle >= 280 && cycle <= 304) {
        // copy y
        v = (v & 0x841F) | (t & 0x7BE0);
      }
      if (renderLine) {
        if (fetchCycle && cycle % 8 == 0) {
          // increment x
          if (v & 0x001F == 31) {
            // coarse X = 0
            v = v & 0xFFE0;
            // switch horizontal nametable
            v = v ^ 0x0400;
          } else {
            // increment coarse X
            v++;
          }
        }
        if (cycle == 256) {
          // increment y
          if (v & 0x7000 != 0x7000) {
            // increment fine Y
            v += 0x1000;
          } else {
            // fine Y = 0
            v = v & 0x8FFF;
            // let y = coarse Y
            var y = (v & 0x03E0) >> 5;
            switch (y) {
              case 29:
                {
                  // coarse Y = 0
                  y = 0;
                  // switch vertical nametable
                  v = v ^ 0x0800;
                }
                break;
              case 31: // coarse Y = 0, nametable not switched
                y = 0;
                break;
              default: // increment coarse Y
                y++;
                break;
            }
            // put coarse Y back into v
            v = (v & 0xFC1F) | (y << 5);
          }
        }
        if (cycle == 257) {
          // copy x
          v = (v & 0xFBE0) | (t & 0x041F);
        }
      }
    }

    // sprite logic
    if (renderingEnabled) {
      if (cycle == 257) {
        if (visibleLine) {
          // evaluate sprites
          var h = (flagSpriteSize == 0) ? 8 : 16;
          var count = 0;
          for (var i in zeroTo63) {
            var y = oamData[i * 4 + 0];
            var a = oamData[i * 4 + 2];
            var x = oamData[i * 4 + 3];
            var row = scanLine - y;
            if (row < 0 || row >= h) {
              continue;
            }
            if (count < 8) {
              var tile = oamData[i * 4 + 1];
              int attributes = oamData[i * 4 + 2] & 0xFF;
              int address = 0;
              if (flagSpriteSize == 0) {
                if (attributes & 0x80 == 0x80) {
                  row = 7 - row;
                }
                address = 0x1000 * flagSpriteTable + tile * 16 + row;
              } else {
                if (attributes & 0x80 == 0x80) {
                  row = 15 - row;
                }
                var table = tile & 1;
                tile = tile & 0xFE;
                if (row > 7) {
                  tile++;
                  row -= 8;
                }
                address = 0x1000 * table + tile * 16 + row;
              }
              var a_ = (attributes & 3) << 2;
              var lowTileByte = read(address);
              var highTileByte = read(address + 8);
              var data = 0;
              for (var it in zeroTo7) {
                var p1 = 0;
                var p2 = 0;
                if (attributes & 0x40 == 0x40) {
                  p1 = ((lowTileByte & 1) << 0);
                  p2 = ((highTileByte & 1) << 1);
                  lowTileByte = lowTileByte >> 1;
                  highTileByte = highTileByte >> 1;
                } else {
                  p1 = ((lowTileByte & 0x80) >> 7);
                  p2 = ((highTileByte & 0x80) >> 6);
                  lowTileByte = lowTileByte << 1;
                  highTileByte = highTileByte << 1;
                }
                data = data << 4;
                data = data | (a_ | p1 | p2);
              }
              spritePatterns[count] = data;
              spritePositions[count] = x;
              spritePriorities[count] = (a >> 5) & 1;
              spriteIndexes[count] = i & 0xFF;
            }
            count++;
          }
          if (count > 8) {
            count = 8;
            flagSpriteOverflow = 1;
          }
          spriteCount = count;
        } else {
          spriteCount = 0;
        }
      }
    }

    // vblank logic
    if (scanLine == 241 && cycle == 1) {
      // set vertical blank
      var temp = front;
      front = back;
      back = temp;
      nmiOccurred = true;
      nmiChange();
    }
    if (preLine && cycle == 1) {
      // clear vertical blank
      nmiOccurred = false;
      nmiChange();
      flagSpriteZeroHit = 0;
      flagSpriteOverflow = 0;
    }
    // TODO: this *should* be 260
    // Returning false means we need to step the mapper too (TODO move this logic to the mapper)
    if (isNoOpMapper) {
      return true;
    } else if (!isMMC3) {
      return false;
    } else {
      return cycle != 280 ||
          240 <= scanLine && scanLine <= 260 ||
          (flagShowBackground == 0 && flagShowSprites == 0);
    }
  }

  int read(int addr) /* Byte */ {
    var address = addr % 0x4000;
    if (address < 0x2000) {
      return mapper?.read(address) ?? 0;
    } else if (address < 0x3F00) {
      // mirror address
      var newAddress = (address - 0x2000) % 0x1000;
      var mirrorAddr = 0x2000 +
          mirrorLookup[mirror][newAddress ~/ 0x0400] * 0x0400 +
          (newAddress % 0x0400);
      return nameTableData[mirrorAddr % 2048];
    } else if (address < 0x4000) {
      var paletteAddress = address % 32;
      var data = paletteData[(paletteAddress >= 16 && paletteAddress % 4 == 0)
          ? paletteAddress - 16
          : paletteAddress];
      return data;
    } else {
      throw Exception("unhandled PPU memory read at address: $address");
    }
  }

  write(int addr, int value /* Byte */) {
    var address = addr % 0x4000;
    if (address < 0x2000) {
      mapper?.write(address, value);
    } else if (address < 0x3F00) {
      // mirror address
      var newAddress = (address - 0x2000) % 0x1000;
      var mirrorAddr = 0x2000 +
          mirrorLookup[mirror][newAddress ~/ 0x0400] * 0x0400 +
          (newAddress % 0x0400);
      nameTableData[mirrorAddr % 2048] = value & 0xFF;
    } else if (address < 0x4000) {
      var paletteAddress = address % 32;
      paletteData[(paletteAddress >= 16 && paletteAddress % 4 == 0)
          ? paletteAddress - 16
          : paletteAddress] = value;
    } else {
      throw Exception("unhandled ppu memory write at address: $address");
    }
  }

  writeMask(int value) {
    flagGrayscale = (value >> 0) & 1;
    flagShowLeftBackground = (value >> 1) & 1;
    flagShowLeftSprites = (value >> 2) & 1;
    flagShowBackground = (value >> 3) & 1;
    flagShowSprites = (value >> 4) & 1;
    flagRedTint = (value >> 5) & 1;
    flagGreenTint = (value >> 6) & 1;
    flagBlueTint = (value >> 7) & 1;
  }

  // $2000: PPUCTRL
  writeControl(int value) {
    flagNameTable = (value >> 0) & 3;
    flagIncrement = (value >> 2) & 1;
    flagSpriteTable = (value >> 3) & 1;
    flagBackgroundTable = (value >> 4) & 1;
    flagSpriteSize = (value >> 5) & 1;
    flagMasterSlave = (value >> 6) & 1;
    nmiOutput = (value >> 7) & 1 == 1;
    nmiChange();
    // t: ....BA.. ........ = d: ......BA
    t = (t & 0xF3FF) | ((value & 0x03) << 10);
  }

  nmiChange() {
    var nmi = nmiOutput && nmiOccurred;
    if (nmi && !nmiPrevious) {
      // TODO: this fixes some games but the delay shouldn't have to be so
      // long, so the timings are off somewhere
      nmiDelay = 15;
    }
    nmiPrevious = nmi;
  }

  void reset() {
    cycle = 340;
    scanLine = 240;
    frame = 0;
    oamAddress = 0;
  }

  // const variables
  final int imgWidth = 256;
  final int imgHeight = 240;

  /**
        0x666666, 0x002A88, 0x1412A7, 0x3B00A4, 0x5C007E, 0x6E0040, 0x6C0600, 0x561D00,
        0x333500, 0x0B4800, 0x005200, 0x004F08, 0x00404D, 0x000000, 0x000000, 0x000000,
        0xADADAD, 0x155FD9, 0x4240FF, 0x7527FE, 0xA01ACC, 0xB71E7B, 0xB53120, 0x994E00,
        0x6B6D00, 0x388700, 0x0C9300, 0x008F32, 0x007C8D, 0x000000, 0x000000, 0x000000,
        0xFFFEFF, 0x64B0FF, 0x9290FF, 0xC676FF, 0xF36AFF, 0xFE6ECC, 0xFE8170, 0xEA9E22,
        0xBCBE00, 0x88D800, 0x5CE430, 0x45E082, 0x48CDDE, 0x4F4F4F, 0x000000, 0x000000,
        0xFFFEFF, 0xC0DFFF, 0xD3D2FF, 0xE8C8FF, 0xFBC2FF, 0xFEC4EA, 0xFECCC5, 0xF7D8A5,
        0xE4E594, 0xCFEF96, 0xBDF4AB, 0xB3F3CC, 0xB5EBF2, 0xB8B8B8, 0x000000, 0x000000
  */
  final palette = [
    0x666666,
    0x002A88,
    0x1412A7,
    0x3B00A4,
    0x5C007E,
    0x6E0040,
    0x6C0600,
    0x561D00,
    0x333500,
    0x0B4800,
    0x005200,
    0x004F08,
    0x00404D,
    0x000000,
    0x000000,
    0x000000,
    0xADADAD,
    0x155FD9,
    0x4240FF,
    0x7527FE,
    0xA01ACC,
    0xB71E7B,
    0xB53120,
    0x994E00,
    0x6B6D00,
    0x388700,
    0x0C9300,
    0x008F32,
    0x007C8D,
    0x000000,
    0x000000,
    0x000000,
    0xFFFEFF,
    0x64B0FF,
    0x9290FF,
    0xC676FF,
    0xF36AFF,
    0xFE6ECC,
    0xFE8170,
    0xEA9E22,
    0xBCBE00,
    0x88D800,
    0x5CE430,
    0x45E082,
    0x48CDDE,
    0x4F4F4F,
    0x000000,
    0x000000,
    0xFFFEFF,
    0xC0DFFF,
    0xD3D2FF,
    0xE8C8FF,
    0xFBC2FF,
    0xFEC4EA,
    0xFECCC5,
    0xF7D8A5,
    0xE4E594,
    0xCFEF96,
    0xBDF4AB,
    0xB3F3CC,
    0xB5EBF2,
    0xB8B8B8,
    0x000000,
    0x000000
  ];

  final mirrorLookup = [
    [0, 0, 1, 1],
    [0, 1, 0, 1],
    [0, 0, 0, 0],
    [1, 1, 1, 1],
    [0, 1, 2, 3],
  ];
}

abstract class PPUStepCallback {
  void step(
    int cycle,
    int scanLine,
    int frame,
    List<int> paletteData,
    List<int> nameTableData,
    List<int> oamData,
    int v,
    int t,
    int x,
    int w,
    int f,
    int register,
    bool nmiOccurred,
    bool nmiOutput,
    bool nmiPrevious,
    int nmiDelay,
    int nameTableByte,
    int attributeTableByte,
    int lowTileByte,
    int highTileByte,
    int tileData,
    int spriteCount,
    List<int> spritePatterns,
    List<int> spritePositions,
    List<int> spritePriorties,
    List<int> spriteIndexes,
    int flagNameTable,
    int flagIncrement,
    int flagSpriteTable,
    int flagBackgroundTable,
    int flagSpriteSize,
    int flagMasterSlave,
    int flagGrayscale,
    int flagShowLeftBackground,
    int flagShowLeftSprites,
    int flagShowBackground,
    int flagShowSprites,
    int flagRedTint,
    int flagGreenTint,
    int flagBlueTint,
    int flagSpriteZeroHit,
    int flagSpriteOverflow,
    int oamAdress,
    int bufferedData,
  );
}
