import 'dart:io';

import 'package:path_provider/path_provider.dart';

late Env env;

class Env {
  String root = "";
  Env() {
    _init();
  }

  void _init() async {
    Directory rootDir = await getApplicationDocumentsDirectory();
    root = rootDir.path;
  }
}
