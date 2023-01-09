import 'mmc3.dart';

import 'cartridge.dart';
import 'mapper.dart';

class MMC1 with Mapper {
  Cartridge cartridge;
  MapperStepCallback? stepCallback;
  MMC1(this.cartridge, {this.stepCallback}) {
    prgOffsets[1] = prgBankOffset(-1);
  }

  int shiftRegister = 0x10; // Byte
  int control = 0; // Byte
  int prgMode = 0; // Byte
  int chrMode = 0; // Byte
  int prgBank = 0; // Byte
  int chrBank0 = 0; // Byte
  int chrBank1 = 0; // Byte
  var prgOffsets = [0, 0];
  var chrOffsets = [0, 0];
  late var chr = cartridge.chr;
  late var prg = cartridge.prg;
  late var sram = cartridge.sram;

  @override
  int read(int address) {
    if (address < 0x2000) {
      var bank = address ~/ 0x1000;
      var offset = address % 0x1000;
      return chr[chrOffsets[bank] + offset];
    }
    if (address >= 0x8000) {
      var addr = address - 0x8000;
      var bank = addr ~/ 0x4000;
      var offset = addr % 0x4000;
      var index = prgOffsets[bank] + offset;
      var ret = prg[index];
      return ret;
    }
    if (address >= 0x6000) {
      return sram[address - 0x6000];
    }
    throw Exception('unhandled mapper1 read at address: $address');
  }

  @override
  void step() {}

  @override
  void write(int address, int value) {
    if (address < 0x2000) {
      var bank = address ~/ 0x1000;
      var offset = address % 0x1000;
      chr[chrOffsets[bank] + offset] = value;
    } else if (address >= 0x8000) {
      // load register
      if (value & 0x80 == 0x80) {
        shiftRegister = 0x10;
        writeControl(control | 0x0C);
      } else {
        var complete = shiftRegister & 1 == 1;
        shiftRegister = shiftRegister >> 1;
        shiftRegister = shiftRegister | ((value & 1) << 4);
        if (complete) {
          // write register
          if (address <= 0x9FFF) {
            writeControl(shiftRegister);
          } else if (address <= 0xBFFF) {
            // CHR bank 0 (internal, $A000-$BFFF)
            chrBank0 = shiftRegister;
            updateOffsets();
          } else if (address <= 0xDFFF) {
            // CHR bank 1 (internal, $C000-$DFFF)
            chrBank1 = shiftRegister;
            updateOffsets();
          } else if (address <= 0xFFFF) {
            // PRG bank (internal, $E000-$FFFF)
            prgBank = shiftRegister & 0x0F;
            updateOffsets();
          }
          shiftRegister = 0x10;
        }
      }
    } else if (address >= 0x6000) {
      sram[address - 0x6000] = value;
    }
    throw Exception("unhandled mapper1 write at address: $address");
  }

  void restoreState(String serializedState) {
    // val state = StatePersistence.restoreState(serializedState)
    // shiftRegister = state.next()
    // control = state.next()
    // prgMode = state.next()
    // chrMode = state.next()
    // prgBank = state.next()
    // chrBank0 = state.next()
    // chrBank1 = state.next()
    // prgOffsets = state.next()
    // chrOffsets = state.next()
  }

  String dumpState() {
    // return StatePersistence.dumpState(
    //     shiftRegister,
    //     control,
    //     prgMode,
    //     chrMode,
    //     prgBank,
    //     chrBank0,
    //     chrBank1,
    //     prgOffsets,
    //     chrOffsets
    // ).also { println("MMC1 state saved") }
    return '';
  }

  void writeControl(int value) {
    control = value;
    chrMode = (value >> 4) & 1 & 0xFF;
    prgMode = (value >> 2) & 3 & 0xFF;
    switch (value & 3) {
      case 0:
        cartridge.mirror = MMC3.mirrorSingle0;
        break;
      case 1:
        cartridge.mirror = MMC3.mirrorSingle1;
        break;
      case 2:
        cartridge.mirror = MMC3.mirrorVertical;
        break;
      case 3:
        cartridge.mirror = MMC3.mirrorHorizontal;
        break;
    }
    updateOffsets();
  }

  // PRG ROM bank mode (0, 1: switch 32 KB at $8000, ignoring low bit of bank number;
  //                    2: fix first bank at $8000&switch 16 KB bank at $C000;
  //                    3: fix last bank at $C000&switch 16 KB bank at $8000)
  // CHR ROM bank mode (0: switch 8 KB at a time; 1: switch two separate 4 KB banks)
  void updateOffsets() {
    switch (prgMode) {
      case 0:
      case 1:
        {
          prgOffsets[0] = prgBankOffset(prgBank & 0xFE);
          prgOffsets[1] = prgBankOffset(prgBank | 0x01);
        }
        break;
      case 2:
        {
          prgOffsets[0] = 0;
          prgOffsets[1] = prgBankOffset(prgBank);
        }
        break;
      case 3:
        {
          prgOffsets[0] = prgBankOffset(prgBank);
          prgOffsets[1] = prgBankOffset(-1);
        }
        break;
    }
    switch (chrMode) {
      case 0:
        {
          chrOffsets[0] = chrBankOffset(chrBank0 & 0xFE);
          chrOffsets[1] = chrBankOffset(chrBank0 | 0x01);
        }
        break;
      case 1:
        {
          chrOffsets[0] = chrBankOffset(chrBank0);
          chrOffsets[1] = chrBankOffset(chrBank1);
        }
        break;
    }
  }

  int prgBankOffset(int index) {
    var idx = index;
    if (idx >= 0x80) {
      idx -= 0x100;
    }
    idx %= (prg.length ~/ 0x4000);
    var offset = idx * 0x4000;
    if (offset < 0) {
      offset += prg.length;
    }
    return offset;
  }

  int chrBankOffset(int index) {
    var idx = index;
    if (idx >= 0x80) {
      idx -= 0x100;
    }
    idx %= chr.length ~/ 0x1000;
    var offset = idx * 0x1000;
    if (offset < 0) {
      offset += chr.length;
    }
    return offset;
  }
}
