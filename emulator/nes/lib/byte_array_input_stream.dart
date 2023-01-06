import 'package:flutter/services.dart';

class ByteArrayInputStream {
  final Uint8List _buf;
  var _pos = 0;
  var _mark = 0;
  var _count = 0;

  ByteArrayInputStream(this._buf) {
    _pos = 0;
    _count = _buf.length;
  }

  int get available => _count - _pos;
  reset() => _pos = _mark;

  int read({Uint8List? b, int off = 0, int len = 0}) {
    if (b == null) {
      return _pos < _count ? _buf[_pos++] & 0xff : -1;
    }
    if (len <= 0) {
      len = b.length;
    }

    var mutLen = len;
    if (off < 0 || mutLen < 0 || mutLen > b.length - off) {
      throw RangeError('index out of bounds');
    }

    if (_pos >= _count) {
      return -1;
    }

    var avail = _count - _pos;
    if (mutLen > avail) {
      mutLen = avail;
    }
    if (mutLen <= 0) {
      return 0;
    }
    b.setRange(off, off + mutLen, _buf.getRange(_pos, _pos + mutLen));
    _pos += mutLen;

    return mutLen;
  }
}
