import 'dart:developer';

import 'package:flutter/services.dart';
import 'cartridge.dart';
import 'ines_file_header.dart';

import 'byte_array_input_stream.dart';

class INesFileParser {
  /// "NES\x1a".codeUnits
  static const inesFileMagic = [0x4e, 0x45, 0x53, 0x1a];
  static const padding = [0, 0, 0, 0, 0, 0, 0];

  static INesFileHeader? parseFileHeader(ByteArrayInputStream stream) {
    return INesFileHeader(
        List.generate(4, (index) => stream.read()),
        stream.read(),
        stream.read(),
        stream.read(),
        stream.read(),
        stream.read(),
        List.generate(7, (index) => stream.read()));
  }

  static Cartridge parseCartridge(ByteArrayInputStream stream) {
    var inesFileHeader = parseFileHeader(stream);
    if (inesFileHeader == null || !inesFileHeader.isValid) {
      throw Exception('Invalid INES file header');
    }

    // mapper state reference type
    int control1 = (inesFileHeader.control1).toInt();
    var mapper1 = control1 >> 4;
    var mapper2 = (inesFileHeader.control2) >> 4;
    var mapper = mapper1 | (mapper2 << 4);

    // mirror type
    var mirror1 = control1 & 0x1;
    var mirror2 = (control1 >> 3) & 0x1;
    var mirror = mirror1 | (mirror2 << 1);

    //battery-backed RAM
    var battery = (control1 >> 1) & 0x1;

    // read prg-rom bank(s)
    var prg = Uint8List((inesFileHeader.numPRG) * 0x4000); //16384
    if (stream.read(b: prg) != prg.length) {
      log('Could not load ${prg.length} bytes from the input');
    }
    // read chr-rom bank(s)
    var numCHR = inesFileHeader.numCHR;
    var chr = Uint8List(numCHR * 0x2000); //8192
    stream.read(b: chr);

    // provide chr-rom/ram if not in file
    if (chr.isEmpty) {
      chr = Uint8List.fromList(List.filled(0x2000, 0));
    }
    return Cartridge(prg, chr, mapper, mirror, battery);
  }
}
