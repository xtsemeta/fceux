import 'package:nes/cartridge.dart';

import 'cpu.dart';

abstract class Mapper {
  late CPU cpu;
  int read(int address);
  void write(int address, int value);
  void step();

  static Mapper newMapper(
      Cartridge cartridge, MapperStepCallback stepCallback) {
    if (cartridge.mapper == 0) {}
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
