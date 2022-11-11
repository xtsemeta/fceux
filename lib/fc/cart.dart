import 'package:fc_flutter/fc/ppu.dart';
import 'package:flutter/foundation.dart';

class CartInfo {
  int mirror = 0;
  int mirrorAs2Bits = 0;
  int bettery = 0;
  int ines2 = 0;
  int submapper = 0;
  int wramSize = 0;
  int batteryWramSize = 0;
  int vramSize = 0;
  int batteryVramSize = 0;
  var md5 = Uint8List(16);
  var crc32 = 0;

  late List<Uint8List?> saveGame = List.filled(4, null); //
  var saveGameLen = List.filled(4, 0); //读取内存的大小

  late Function power;
  late Function reset;
  late Function close;
}

class XCart {
  int mirroring = 0;
  int chrPages = 0, prgPages = 0;
  int chrSize = 0, prgSize = 0;
  late Uint8List chr, prg;

  void power() {}
}

class NROM with XCart {
  PPU ppu;

  List<Uint8List> page = List.filled(32, Uint8List(0));
  List<Uint8List> vpage = List.filled(8, Uint8List(0));
  late List<Uint8List> vpageR;
  List<Uint8List> vpageG = List.filled(8, Uint8List(0));
  List<Uint8List> mmc5SprVPage = List.filled(8, Uint8List(0));
  List<Uint8List> mmc5BgVPage = List.filled(8, Uint8List(0));

  List<Uint8List> prgIsRam = List.filled(32, Uint8List(0));

  Uint8List chrRam = Uint8List(32);
  Uint8List prgRam = Uint8List(32);

  NROM(this.ppu) {
    vpageR = vpage;
  }

  @override
  void power() {}
}
