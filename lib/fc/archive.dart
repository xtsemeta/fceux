import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';

import 'env.dart';

void scanArchive(String fname) async {
  var basenameWithoutExt = basenameWithoutExtension(fname);
  await extractFileToDisk(fname, "${env.root}/$basenameWithoutExt");
}
