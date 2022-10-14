import 'package:flutter/foundation.dart';

late Uint8List RAM;
var settings = FCSettings();

class FC {
  static const JOY_A = 0x01;
  static const JOY_B = 0x02;
  static const JOY_SELECT = 0x04;
  static const JOY_START = 0x08;
  static const JOY_UP = 0x10;
  static const JOY_DOWN = 0x20;
  static const JOY_LEFT = 0x40;
  static const JOY_RIGHT = 0x80;

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
