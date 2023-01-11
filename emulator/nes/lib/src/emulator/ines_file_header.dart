import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'ines_file_parser.dart';

class INesFileHeader {
  Uint8List magic;
  Uint8 numPRG;
  Uint8 numCHR;
  Uint8 control1;
  Uint8 control2;
  Uint8 numRAM;
  Uint8List padding;
  INesFileHeader(this.magic, this.numPRG, this.numCHR, this.control1,
      this.control2, this.numRAM, this.padding);

  @override
  int get hashCode {
    var result = magic.hashCode;
    result = 31 * result + (numPRG as int);
    result = 31 * result + (numCHR as int);
    result = 31 * result + (control1 as int);
    result = 31 * result + (control2 as int);
    result = 31 * result + (numRAM as int);
    result = 31 * result + padding.hashCode;
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (other is! INesFileHeader) {
      return false;
    }

    if (magic != other.magic) return false;
    if (numPRG != other.numPRG) return false;
    if (numCHR != other.numCHR) return false;
    if (control1 != other.control1) return false;
    if (control2 != other.control2) return false;
    if (numRAM != other.numRAM) return false;
    if (padding != other.padding) return false;

    return super == other;
  }

  bool get isValid =>
      (magic == INesFileParser.inesFileMagic) &&
      (padding == INesFileParser.padding);
}
