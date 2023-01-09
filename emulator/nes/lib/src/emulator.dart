import 'package:flutter/foundation.dart';
import 'package:nes/src/apu.dart';
import 'package:nes/src/byte_array_input_stream.dart';
import 'package:nes/src/cartridge.dart';
import 'package:nes/src/console.dart';
import 'package:nes/src/cpu.dart';
import 'package:nes/src/ines_file_parser.dart';
import 'package:nes/src/mapper.dart';
import 'package:nes/src/ppu.dart';

class Emulator {
  static const fps = 60;
  late var secsPerFrame = 1 / fps;
  late var msPerFrame = (secsPerFrame * 1000).toInt();

  Uint8List cartridgeData;
  MapperStepCallback? mapeprCallback;
  CPUStepCallback? cpuCallback;
  PPUStepCallback? ppuCallback;
  APUStepCallback? apuCallback;

  bool isRunning = false;
  late Cartridge cartridge;
  late Console console;
  Emulator(this.cartridgeData) {
    cartridge =
        INesFileParser.parseCartridge(ByteArrayInputStream(cartridgeData));
  }
}
