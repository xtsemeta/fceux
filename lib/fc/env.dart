import 'dart:io';

import 'package:path_provider/path_provider.dart';

Env _env = Env();

Env get env => _env;

class Env {
  String root = "";
  Env() {
    _init();
  }

  void _init() async {
    Directory rootDir = await getApplicationDocumentsDirectory();
    root = rootDir.path;
  }

  String getResumeState(String dir, String basename) {
    if (dir.isEmpty) dir = root;
    return "$dir/fcs/$basename-resume.fcs";
  }
}
