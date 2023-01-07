import 'cartridge.dart';
import 'interrupt.dart';
import 'mapper.dart';

class MMC3 with Mapper {
  Cartridge cartridge;
  MapperStepCallback? stepCallback;
  MMC3(this.cartridge, {this.stepCallback}) {
    prgOffsets[0] = prgBankOffset(0);
    prgOffsets[1] = prgBankOffset(1);
    prgOffsets[2] = prgBankOffset(-2);
    prgOffsets[3] = prgBankOffset(-1);
  }

  int register = 0;
  var registers = List.filled(8, 0);
  int prgMode = 0;
  int chrMode = 0;
  var prgOffsets = List.filled(4, 0);
  var chrOffsets = List.filled(8, 0);
  int reload = 0;
  int counter = 0;
  bool irqEnable = false;
  late var chr = cartridge.chr;
  late var prg = cartridge.prg;
  late var sram = cartridge.sram;

  @override
  int read(int address) {
    if (address < 0x2000) {
      var bank = address ~/ 0x0400;
      var offset = address % 0x0400;
      return chr[chrOffsets[bank] + offset];
    }
    if (address >= 0x8000) {
      var addr = address - 0x8000;
      var bank = addr ~/ 0x2000;
      var offset = addr % 0x2000;
      return prg[prgOffsets[bank] + offset];
    }
    if (address >= 0x6000) {
      return sram[address - 0x6000];
    }
    throw Exception("unhandled mapper4 read at address: $address");
  }

  @override
  void step() {
//    stepCallback?.onStep(register, registers, prgMode, chrMode, prgOffsets, chrOffsets, reload,
//        counter, irqEnable)
    if (counter == 0) {
      counter = reload;
    } else {
      counter = (counter - 1) & 0xFF;
      if (counter == 0 && irqEnable) {
        // trigger IRQ causes an IRQ interrupt to occur on the next cycle
        if (cpu.I == 0) {
          cpu.interrupt = Interrupt.irq;
        }
      }
    }
  }

  @override
  void write(int address, int value) {
    if (address < 0x2000) {
      var bank = address ~/ 0x0400;
      var offset = address % 0x0400;
      chr[chrOffsets[bank] + offset] = value;
    } else if (address >= 0x8000) {
      // write register
      if (address <= 0x9FFF && address % 2 == 0) {
        // write bank select
        prgMode = (value >> 6) & 1;
        chrMode = (value >> 7) & 1;
        register = value & 7;
        updateOffsets();
      } else if (address <= 0x9FFF && address % 2 == 1) {
        registers[register] = value;
        updateOffsets();
      } else if (address <= 0xBFFF && address % 2 == 0) {
        switch (value & 1) {
          case 0:
            cartridge.mirror = mirrorVertical;
            break;
          case 1:
            cartridge.mirror = mirrorHorizontal;
            break;
        }
      } else if (address <= 0xBFFF && address % 2 == 1) {
      } else if (address <= 0xDFFF && address % 2 == 0) {
        reload = value;
      } else if (address <= 0xDFFF && address % 2 == 1) {
        counter = 0;
      } else if (address <= 0xFFFF && address % 2 == 0) {
        irqEnable = false;
      } else if (address <= 0xFFFF && address % 2 == 1) {
        irqEnable = true;
      }
    } else if (address >= 0x6000) {
      sram[address - 0x6000] = value;
    } else
      throw Exception("unhandled mapper4 write at address $address");
  }

  void restoreState(String serializedState) {
    // val state = StatePersistence.restoreState(serializedState)
    // register = state.next()
    // registers = state.next()
    // prgMode = state.next()
    // chrMode = state.next()
    // prgOffsets = state.next()
    // chrOffsets = state.next()
    // reload = state.next()
    // counter = state.next()
    // irqEnable = state.next()
    // prg = state.next()
    // chr = state.next()
    // sram = state.next()
    // println("MMC3 state restored")
  }

  String dumpState() {
    // return StatePersistence.dumpState(
    //     register, registers, prgMode, chrMode, prgOffsets, chrOffsets, reload, counter, irqEnable,
    //     prg, chr, sram
    // ).also { println("MMC3 state saved") }
    return '';
  }

  void updateOffsets() {
    switch (prgMode) {
      case 0:
        {
          prgOffsets[0] = prgBankOffset(registers[6]);
          prgOffsets[1] = prgBankOffset(registers[7]);
          prgOffsets[2] = prgBankOffset(-2);
          prgOffsets[3] = prgBankOffset(-1);
        }
        break;
      case 1:
        {
          prgOffsets[0] = prgBankOffset(-2);
          prgOffsets[1] = prgBankOffset(registers[7]);
          prgOffsets[2] = prgBankOffset(registers[6]);
          prgOffsets[3] = prgBankOffset(-1);
        }
        break;
    }
    switch (chrMode) {
      case 0:
        {
          chrOffsets[0] = chrBankOffset(registers[0] & 0xFE);
          chrOffsets[1] = chrBankOffset(registers[0] | 0x01);
          chrOffsets[2] = chrBankOffset(registers[1] & 0xFE);
          chrOffsets[3] = chrBankOffset(registers[1] | 0x01);
          chrOffsets[4] = chrBankOffset(registers[2]);
          chrOffsets[5] = chrBankOffset(registers[3]);
          chrOffsets[6] = chrBankOffset(registers[4]);
          chrOffsets[7] = chrBankOffset(registers[5]);
        }
        break;
      case 1:
        {
          chrOffsets[0] = chrBankOffset(registers[2]);
          chrOffsets[1] = chrBankOffset(registers[3]);
          chrOffsets[2] = chrBankOffset(registers[4]);
          chrOffsets[3] = chrBankOffset(registers[5]);
          chrOffsets[4] = chrBankOffset(registers[0] & 0xFE);
          chrOffsets[5] = chrBankOffset(registers[0] | 0x01);
          chrOffsets[6] = chrBankOffset(registers[1] & 0xFE);
          chrOffsets[7] = chrBankOffset(registers[1] | 0x01);
        }
        break;
    }
  }

  int chrBankOffset(int index) {
    var idx = index;
    if (idx >= 0x80) {
      idx -= 0x100;
    }
    var size = chr.length;
    idx %= size ~/ 0x0400;
    var offset = idx * 0x0400;
    if (offset < 0) {
      offset += size;
    }
    return offset;
  }

  int prgBankOffset(int index) {
    var idx = index;
    if (idx >= 0x80) {
      idx -= 0x100;
    }
    var size = prg.length;
    idx %= size ~/ 0x2000;
    var offset = idx * 0x2000;
    if (offset < 0) {
      offset += size;
    }
    return offset;
  }

  static const mirrorHorizontal = 0;
  static const mirrorVertical = 1;
  static const mirrorSingle0 = 2;
  static const mirrorSingle1 = 3;
  static const mirrorFour = 4;
}
