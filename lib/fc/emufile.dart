import 'dart:ffi';
import 'dart:io';

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

  List<Uint8> readAllBytes(String fname) {
    return List.empty();
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
  List<int> data = List.empty();
  bool ownvec = false;
  int pos = 0;
  int len = 0;
}
