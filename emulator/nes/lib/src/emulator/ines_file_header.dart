import 'package:flutter/foundation.dart';

import 'ines_file_parser.dart';
import 'package:collection/collection.dart';

class INesFileHeader {
  List<int> magic;
  int numPRG;
  int numCHR;
  int control1;
  int control2;
  int numRAM;
  List<int> padding;
  INesFileHeader(this.magic, this.numPRG, this.numCHR, this.control1,
      this.control2, this.numRAM, this.padding);

  @override
  int get hashCode {
    var result = magic.hashCode;
    result = 31 * result + (numPRG);
    result = 31 * result + (numCHR);
    result = 31 * result + (control1);
    result = 31 * result + (control2);
    result = 31 * result + (numRAM);
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

  bool get isValid => listEquals(magic, INesFileParser.inesFileMagic);
}
