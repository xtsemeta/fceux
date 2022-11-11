import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

class EmuFile {
  Uint8List? data;
  bool ownvec = false;
  int pos = 0;
  int len = 0;

  bool _failbit = false;

  bool fail({bool unset = false}) {
    bool ret = _failbit;
    if (unset) unfail();
    return ret;
  }

  void unfail() {
    _failbit = false;
  }

  Future<Uint8List> readAllBytes(String fname) async {
    var file = File(fname);
    var bytes = await file.readAsBytes();
    return bytes;
  }

  @override
  Uint8List read(int size) {
    int remain = len - pos;
    int todo = min(remain, size);
    if (len == 0 || data == null) {
      _failbit = true;
      return Uint8List(size);
    }
    Uint8List ret = Uint8List(size);
    var range = data!.getRange(pos, remain);
    ret.setRange(0, size, range);
    pos += todo;
    if (todo < size) {
      _failbit = true;
    }
    return ret;
  }

  int tell() => pos;
  int size() => len;
  void setLen(int length) {
    len = length;
    if (pos > length) pos = length;
  }

  static const SEEK_SET = 0;
  static const SEEK_CUR = 1;
  static const SEEK_END = 2;
  seek(int offset, {int origin = SEEK_CUR}) {
    switch (origin) {
      case SEEK_SET:
        pos = offset;
        break;
      case SEEK_CUR:
        pos += offset;
        break;
      case SEEK_END:
        pos = size() + offset;
        break;
    }
    reserve(pos);
  }

  void reserve(int size) {
    // 跟resize唯一不同的区别是，声明的内存空间大于size的部分不清空
    data ??= Uint8List(size);

    if (data!.length < size) {
      data!.addAll(Uint8List(size - data!.length));
    }
  }

  void resize(int size) {
    data ??= Uint8List(size);

    if (data!.length < size) {
      data!.addAll(Uint8List(size - data!.length));
    } else {
      data = data!.sublist(0, size);
    }
  }
}

class EmuFileMemory with EmuFile {}
