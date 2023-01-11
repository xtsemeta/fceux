import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:nes/src/isolates/messages/emulator_messages.dart';

import '../emulator/emulator.dart';

void emulatorIsolateMain(SendPort sendPort) {}

class EmulatorIsolate {
  final SendPort sendPort; //parent
  final ReceivePort receivePort; //child, inside isolate

  late Emulator emulator;

  EmulatorIsolate(this.sendPort, this.receivePort);

  void main() async {
    sendPort.send(EmulatorMessageOut(
        EmulatorMessageOutType.initialize, receivePort.sendPort));

    _initEmulator();

    await for (var m in receivePort) {
      var message = m as EmulatorMessageIn;
      switch (message.type) {
        case EmulatorMessageInType.start:
          _startEmulator(message.data as Uint8List);
          break;
        default:
      }
    }
  }

  void _initEmulator() {
    emulator = Emulator();
    emulator.onFrameChanged.listen((frame) {
      sendPort
          .send(EmulatorMessageOut(EmulatorMessageOutType.updateFrame, frame));
    });
  }

  void _startEmulator(Uint8List romBytes) {
    emulator.start(romBytes);
  }
}
