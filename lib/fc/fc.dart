import 'package:flutter/foundation.dart';

late Uint8List RAM;
var settings = FCSettings();

typedef ARead = int Function(int a);

List<ARead> aread = List.filled(0x10000, ((a) => 0));

enum JoyInput {
  a(val: 0x01),
  b(val: 0x02),
  select(val: 0x04),
  start(val: 0x08),
  up(val: 0x10),
  down(val: 0x20),
  left(val: 0x40),
  right(val: 0x80);

  final int val;
  const JoyInput({required this.val});
}

class FC {
  /// x6502
  int main(List<String> arguments) {
    if (!initialise()) {
      exit();
      return 1;
    }

    return 0;
  }

  bool initialise() {
    allocBuffers();

    settings.usrFirstSLine[0] = 0;
    settings.usrFirstSLine[1] = 0;
    settings.usrLastSLine[0] = 239;
    settings.usrLastSLine[1] = 239;
    settings.soundVolume = 150; //0-150
    settings.triangleVolume = 256; //0-256 (最大256)
    settings.square1Volume = 256; //0-256 (最大256)
    settings.square2Volume = 256; //0-256 (最大256)
    settings.noiseVolume = 256; //0-256 (最大256)
    settings.pcmVolume = 256; //0-256 (最大256)

    ppuInit();

    return true;
  }

  void allocBuffers() {
    RAM = Uint8List(0x800);
  }

  void ppuInit() {}

  void exit() {}
}

class FCSettings {
  int pal = 0;
  int networkPlay = 0;
  int soundVolume = 0; //主音量
  int triangleVolume = 0;
  int square1Volume = 0;
  int square2Volume = 0;
  int noiseVolume = 0;
  int pcmVolume = 0;
  bool gameGenie = false;

  // 当前选择的第一条和最后一条渲染的扫描线
  int firstSLine = 0;
  int lastSLine = 0;

  // 当前选择的配置中的扫描线数量
  int totalScanlines() => lastSLine - firstSLine + 1;

  // 驱动程序提供的用户选择的第一和最后渲染的扫描线
  // usr*SLine[0] is for NTSC, usr*SLine[1] is for PAL
  var usrFirstSLine = List.filled(2, 0);
  var usrLastSLine = List.filled(2, 0);

  int sndRate = 0;
  int soundq = 0;
  int lowpass = 0;
}
