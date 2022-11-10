import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

class EmuFile {
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

  Uint8List read(int size) {
    return Uint8List(size);
  }
}

class EmuFileFile with EmuFile {
  File? file;
  String? fname;

  EmuFileFile(String this.fname) {
    _open(fname!);
  }

  void _open(String fname) {
    file = File(fname);
    this.fname = fname;
  }
}

class EmuFileMemory with EmuFile {
  Uint8List? data;
  bool ownvec = false;
  int pos = 0;
  int len = 0;

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
}
