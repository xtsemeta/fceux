import 'package:nes/cartridge.dart';
import 'package:nes/mapper.dart';

class Mapper2 with Mapper {
  Cartridge cartridge;
  MapperStepCallback? stepCallback;

  late int prgBanks;
  late int prgBank1 = 0;
  late int prgBank2;
  late List<int> chr;
  late List<int> prg;
  late List<int> sram;

  Mapper2(this.cartridge, this.stepCallback) {
    prgBanks = cartridge.prg.length ~/ 0x4000;
    prgBank2 = prgBanks - 1;
    chr = cartridge.chr;
    prg = cartridge.prg;
    sram = cartridge.sram;
  }
  @override
  int read(int address) {
    if (address < 0x2000) {
      return chr[address];
    } else if (address >= 0xC000) {
      return prg[prgBank2 * 0x4000 + (address - 0xC000)];
    } else if (address >= 0x8000) {
      return prg[prgBank1 * 0x4000 + (address - 0x8000)];
    } else if (address >= 0x6000) {
      return sram[address - 0x6000];
    }
    throw Exception('unhandled mapper2 read at address: $address');
  }

  @override
  void step() {}

  @override
  void write(int address, int value) {
    if (address < 0x2000) {
      chr[address] = value;
    } else if (address >= 0x8000) {
      prgBank1 = value % prgBanks;
    } else if (address >= 0x8000) {
      prgBank1 = value % prgBanks;
    } else if (address >= 0x6000) {
      sram[address - 0x6000] = value;
    }
    throw Exception('unhandled mapper2 write at address: $address');
  }
}
