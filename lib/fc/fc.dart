import 'package:fc_flutter/fc/file.dart';
import 'package:fc_flutter/fc/git.dart';
import 'package:fc_flutter/fc/ines.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

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
  var PAL = 0;
  var dendy = 0;
  var loadedRomPatchFile = "";

  late FCGI gameInfo;

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

  void loadGame(String path) async {
    int lastpal = PAL;
    int lastdendy = dendy;

    FCFile? file = await FCFile.open(path, loadedRomPatchFile);

    if (file == null) {
      throw Exception('error opening $path');
    }

    resetGameLoaded();

    closeGame();

    gameInfo = FCGI();
    gameInfo.filename = file.filename!;
    gameInfo.soundchan = 0;
    gameInfo.soundrate = 0;
    gameInfo.name = "";
    gameInfo.type = EGIT.GIT_CART;
    gameInfo.vidsys = EGIV.GIV_USER;
    gameInfo.input[0] = gameInfo.input[1] = ESI.SI_UNSET;
    gameInfo.inputfc = ESIFC.SIFC_UNSET;
    gameInfo.cspecial = ESIS.SIS_NONE;
  }

  void resetGameLoaded() {}
  void closeGame() {}

  void xload(FCFile file) {
    if (file.stream == null) return;
    var bytes = file.stream!.read(16);
    INesHeader head = INesHeader();
    head.id = bytes.sublist(0, 4);
    head.romSize = bytes[4];
    head.vromSize = bytes[5];
    head.romType = bytes[6];
    head.romType2 = bytes[7];
    head.romType3 = bytes[8];
    head.upperRomVromSize = bytes[9];
    head.ramSize = bytes[10];
    head.vramSize = bytes[11];
    head.vsHardware = bytes[12];
    head.reserved = bytes.sublist(13, 15);

    if (!head.id.equals("NES\x1a".codeUnits)) {
      return;
    }

    int mapper = head.romType >> 4;
    mapper |= head.romType2 & 0xF0;
  }
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
