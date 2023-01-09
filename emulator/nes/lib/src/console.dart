import 'apu.dart';
import 'controller.dart';
import 'cpu.dart';
import 'mapper.dart';
import 'mapper2.dart';
import 'mmc3.dart';
import 'ppu.dart';

import 'cartridge.dart';
import 'mmc1.dart';

class Console {
  Cartridge cartridge;
  CPU cpu;
  APU apu;
  PPU ppu;
  Mapper mapper;
  Controller controller1;
  Controller controller2;

  Console(this.cartridge, this.cpu, this.apu, this.ppu, this.mapper,
      this.controller1, this.controller2);

  double step() {
    var cpuCycles = cpu.step();
    var i = 0;
    while (i++ < cpuCycles * 3) {
      if (!ppu.step()) {
        mapper.step();
      }
    }
    i = 0;
    while (i++ < cpuCycles) {
      apu.step();
    }
    return cpuCycles;
  }

  List<int> videoBuffer() {
    return ppu.front;
  }

  List<double> audioBuffer() {
    return apu.audioBuffer.drain();
  }

  void reset() {
    cpu.reset();
  }

  static Console newConsole(
    Cartridge cartridge, {
    MapperStepCallback? mapperCallback,
    CPUStepCallback? cpuCallback,
    PPUStepCallback? ppuCallback,
    APUStepCallback? apuCallback,
    PPU? ppu,
    Controller? controller1,
    Controller? controller2,
    APU? apu,
    Mapper? mapper,
    CPU? cpu,
  }) {
    ppu ??= PPU(cartridge, stepCallback: ppuCallback);
    controller1 ??= Controller();
    controller2 ??= Controller();
    apu ??= APU(stepCallback: apuCallback);
    mapper ??= Mapper.newMapper(cartridge, mapperCallback);
    cpu ??= CPU(
        mapper, ppu, apu, controller1, controller2, List.filled(2048, 0),
        stepCallback: cpuCallback);
    var console =
        Console(cartridge, cpu, apu, ppu, mapper, controller1, controller2);
    ppu.isMMC3 = mapper is MMC3;
    ppu.isNoOpMapper = mapper is Mapper2 || mapper is MMC1;
    ppu.cpu = cpu;
    mapper.cpu = cpu;
    apu.cpu = cpu;
    return console;
  }
}
