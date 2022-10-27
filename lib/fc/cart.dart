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
