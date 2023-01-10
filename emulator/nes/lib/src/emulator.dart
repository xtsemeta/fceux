import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'apu.dart';
import 'byte_array_input_stream.dart';
import 'cartridge.dart';
import 'console.dart';
import 'controller.dart';
import 'cpu.dart';
import 'ines_file_parser.dart';
import 'mapper.dart';
import 'ppu.dart';

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
  late Controller controller1;
  late Controller controller2;

  Emulator(this.cartridgeData) {
    cartridge =
        INesFileParser.parseCartridge(ByteArrayInputStream(cartridgeData));
    console = Console.newConsole(
      cartridge,
      mapperCallback: mapeprCallback,
      cpuCallback: cpuCallback,
      ppuCallback: ppuCallback,
      apuCallback: apuCallback,
    );
    controller1 = console.controller1;
    controller2 = console.controller2;
    console.reset();
  }

  double stepSeconds(double seconds, {bool logSpeed = false}) {
    isRunning = true;
    var cyclesToRun = seconds * CPU.frequencyHZ;
    var totalCycles = 0.0;
    var startTime = currentTimeMs();
    while (isRunning && totalCycles < cyclesToRun) {
      totalCycles += console.step();
    }
    if (logSpeed) {
      trackConsoleSpeed(startTime.toDouble(), totalCycles);
    }

    return currentTimeMs() - startTime;
  }

  double currentTimeMs() {
    return DateTime.now().millisecondsSinceEpoch.toDouble();
  }

  double trackConsoleSpeed(double startTime, double totalCycles) {
    var currentTime = currentTimeMs();
    var secondsSpent = (currentTime - startTime) / 1000;
    var expectedClock = CPU.frequencyHZ;
    var actualClock = totalCycles / secondsSpent;
    var relativeSpeed = actualClock / expectedClock;
    print('clock=${actualClock}Hz (${relativeSpeed}x)');
    return currentTime.toDouble();
  }

  void reset() {
    isRunning = false;
    console.reset();
  }

  void pause() {
    isRunning = false;
  }

  List<double> audioBuffer() {
    return console.audioBuffer();
  }

  List<int> videoBuffer() {
    return console.videoBuffer();
  }

  Map<String, String> dumpState() {
    // return console.state()
    return HashMap();
  }

  void restoreState(Map<String, dynamic> state) {
    // console.restoreState(state)
  }
}
