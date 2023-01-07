import 'package:nes/cartridge.dart';
import 'package:nes/mapper2.dart';
import 'package:nes/mmc1.dart';

import 'cpu.dart';
import 'mmc3.dart';

abstract class Mapper {
  late CPU cpu;
  int read(int address);
  void write(int address, int value);
  void step();

  static Mapper newMapper(
      Cartridge cartridge, MapperStepCallback? stepCallback) {
    switch (cartridge.mapper) {
      case 0:
        return Mapper2(cartridge, stepCallback);
      case 1:
        return MMC1(cartridge, stepCallback: stepCallback);
      case 4:
        return MMC3(cartridge, stepCallback: stepCallback);
    }
    throw Exception('Mapper ${cartridge.mapper} not implemented');
  }
}

abstract class MapperStepCallback {
  void onStep(
      int register,
      List<int> registers,
      int prgMode,
      int chrMode,
      List<int> prgOffsets,
      List<int> chrOffsets,
      int reload,
      int counter,
      bool irqEnable);
}
