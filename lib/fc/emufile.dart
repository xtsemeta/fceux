import 'dart:ffi';
import 'dart:io';

class EMUFILE {
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

class EMUFILE_FILE with EMUFILE {
  File? file;
  String? fname;

  EMUFILE_FILE(String this.fname) {
    _open(fname!);
  }

  void _open(String fname) {
    file = File(fname);
    this.fname = fname;
  }
}

class EMUFILE_MEMORY with EMUFILE {
  List<Uint8> vec = List.empty();
  bool ownvec = false;
  int pos = 0;
  int len = 0;
}
