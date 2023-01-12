import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nes/src/isolates/emulator_isolate.dart';
import 'package:nes/src/isolates/messages/emulator_messages.dart';

class EmulatorPageWidget extends StatefulWidget {
  const EmulatorPageWidget({super.key});

  @override
  State<EmulatorPageWidget> createState() => _EmulatorPageWidgetState();
}

class _EmulatorPageWidgetState extends State<EmulatorPageWidget> {
  late _EmulatorController controller;

  @override
  void initState() {
    super.initState();

    controller = _EmulatorController();
    Future.delayed(Duration.zero, () {
      rootBundle.loadString('./assets/nestest.log').then((data) {
        log('log: $data');
        rootBundle.load('./assets/nestest.nes').then((rom) {
          controller.initialize(rom.buffer.asUint8List(), data);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black38,
        child: CustomPaint(
          painter: _EmulatorDrawPainter(controller),
        ),
      ),
    );
  }
}

class _EmulatorController extends ChangeNotifier {
  late Uint8List romBytes;
  var debugLog = '';
  late ReceivePort emulatorReceivePort;
  late SendPort emulatorSendPort;

  ui.Image? currentFrame;

  _EmulatorController();

  void initialize(Uint8List romBytes, [String debugLog = 'emulator']) {
    this.romBytes = romBytes;
    this.debugLog = debugLog;

    _initializeEmulatorIsolate();
  }

  void _initializeEmulatorIsolate() {
    emulatorReceivePort = ReceivePort();
    Isolate.spawn(emulatorIsolateMain, emulatorReceivePort.sendPort);

    emulatorReceivePort.listen((data) {
      var message = data as EmulatorMessageOut;
      switch (message.type) {
        case EmulatorMessageOutType.initialize:
          _onReceiveInitialize(message.data);
          break;
        case EmulatorMessageOutType.updateFrame:
          _onReceiveFrameUpdate(message.data);
          break;
        default:
      }
    });
  }

  void _onReceiveInitialize(SendPort emulatorSendPort) {
    log('on receive initialize');
    this.emulatorSendPort = emulatorSendPort;

    if (debugLog.isNotEmpty) {
      emulatorSendPort.send(
          EmulatorMessageIn(EmulatorMessageInType.setDebugCpuLog, debugLog));
    }

    emulatorSendPort
        .send(EmulatorMessageIn(EmulatorMessageInType.start, romBytes));
  }

  void _onReceiveFrameUpdate(Uint8List framePixels) {
    log('on receive fame update');
    _convertFrameToImage(framePixels).then((ui.Image image) {
      currentFrame = image;
      notifyListeners();
    });
  }
}

class _EmulatorDrawPainter extends CustomPainter {
  _EmulatorController controller;
  late Paint paintObject;

  int framePerSec = 0;
  int lastDrawTime = 0;
  int frameDrawCount = 0;

  _EmulatorDrawPainter(this.controller) : super(repaint: controller) {
    paintObject = Paint();
  }

  @override
  void paint(Canvas canvas, Size size) {
    frameDrawCount++;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - lastDrawTime > 1000) {
      lastDrawTime = currentTime;
      framePerSec = frameDrawCount;
      frameDrawCount = 0;
    }

    canvas.save();
    var scale = (size.width / 256 < size.height / 240)
        ? size.width / 256
        : size.height / 240;
    canvas.scale(scale);

    if (controller.currentFrame != null) {
      canvas.drawImage(controller.currentFrame!, Offset.zero, paintObject);
    }

    // Draw fps
    TextSpan span = TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 8.0),
        text: "fps: $framePerSec");
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, const Offset(5.0, 5.0));

    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

Future<ui.Image> _convertFrameToImage(Uint8List pixels) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    256,
    240,
    ui.PixelFormat.rgba8888,
    c.complete,
  );
  return c.future;
}
