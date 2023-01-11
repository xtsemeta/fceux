import 'dart:async';
import 'dart:collection';
import 'dart:developer';

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

  late Uint8List cartridgeData;
  MapperStepCallback? mapeprCallback;
  CPUStepCallback? cpuCallback;
  PPUStepCallback? ppuCallback;
  APUStepCallback? apuCallback;

  bool isRunning = false;
  late Cartridge cartridge;
  late Console console;
  late Controller controller1;
  late Controller controller2;

  final _onFrameChanedController = StreamController.broadcast();
  Stream get onFrameChanged => _onFrameChanedController.stream;

  var totalCycles = 0.0;
  var startTime = 0.0;

  Emulator();

  void start(Uint8List romBytes) {
    isRunning = true;
    loadGame(cartridgeData);

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _executeFrame(timer);
    });
  }

  void dispose() {
    isRunning = false;
    _onFrameChanedController.close();
  }

  void _executeFrame(Timer timer) {
    try {
      totalCycles = 0.0;
      startTime = currentTimeMs();
      while (isRunning) {
        totalCycles += console.step();
      }
    } catch (error, stackTrace) {
      log('Timer canceled: $error');
      log(stackTrace.toString());

      timer.cancel();
    }
  }

  void loadGame(Uint8List cartridgeData) {
    cartridge =
        INesFileParser.parseCartridge(ByteArrayInputStream(cartridgeData));
    console = Console.newConsole(
      cartridge,
      mapperCallback: mapeprCallback,
      cpuCallback: cpuCallback,
      ppuCallback: _PPUCallback(_onFrameChanedController),
      apuCallback: apuCallback,
    );
    controller1 = console.controller1;
    controller2 = console.controller2;
    console.reset();
  }

  double _stepSeconds(double seconds, {bool logSpeed = false}) {
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

class _PPUCallback extends PPUStepCallback {
  StreamController controller;
  _PPUCallback(this.controller);

  @override
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
      int bufferedData) {
    // controller.add(bufferedData)
  }
}
