import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:nes/cartridge.dart';
import 'package:nes/ines_file_header.dart';

import 'byte_array_input_stream.dart';

class INesFileParser {
  /// "NES\x1a".codeUnits
  static const inesFileMagic = [0xe4, 0x45, 0x53, 0x1a];
  static const padding = [0, 0, 0, 0, 0, 0, 0];

  INesFileHeader? parseFileHeader(ByteArrayInputStream stream) {
    return INesFileHeader(
        Uint8List.fromList(List.generate(4, (index) => stream.read())),
        stream.read() as Uint8,
        stream.read() as Uint8,
        stream.read() as Uint8,
        stream.read() as Uint8,
        stream.read() as Uint8,
        Uint8List.fromList(List.generate(7, (index) => stream.read())));
  }

  Cartridge parseCartridge(ByteArrayInputStream stream) {
    var inesFileHeader = parseFileHeader(stream);
    if (inesFileHeader == null || !inesFileHeader.isValid) {
      throw Exception('Invalid INES file header');
    }

    // mapper state reference type
    int control1 = (inesFileHeader.control1 as int).toInt();
    var mapper1 = control1 >> 4;
    var mapper2 = (inesFileHeader.control2 as int) >> 4;
    var mapper = mapper1 | (mapper2 << 4);

    // mirror type
    var mirror1 = control1 & 0x1;
    var mirror2 = (control1 >> 3) & 0x1;
    var mirror = mirror1 | (mirror2 << 1);

    //battery-backed RAM
    var battery = (control1 >> 1) & 0x1;

    // read prg-rom bank(s)
    var prg = Uint8List((inesFileHeader.numPRG as int) * 0x4000); //16384
    if (stream.read(b: prg) != prg.length) {
      print('Could not load ${prg.length} bytes from the input');
    }
    // read chr-rom bank(s)
    var numCHR = inesFileHeader.numCHR as int;
    var chr = Uint8List(numCHR * 0x2000); //8192
    stream.read(b: chr);

    // provide chr-rom/ram if not in file
    if (chr.isEmpty) {
      chr = Uint8List.fromList(List.filled(0x2000, 0));
    }
    return Cartridge(prg, chr, mapper, mirror, battery);
  }
}
