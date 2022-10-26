import 'dart:io';

import 'package:fc_flutter/fc/emufile.dart';

class FCFILE {
  EMUFILE? stream;
  String? filename;
  String? logicalPath;
  String? archiveFilename;
  String? fullFilename;
  int archiveCount = -1;
  int archiveIndex = 0;
  int size = 0;

  bool isArchive() => archiveCount > 0;

  void setStream(EMUFILE newstream) {
    stream = newstream;
  }

  static List<String> splitArchiveFilename(String src) {
    var pipe = src.indexOf('|');
    var archive = "", file = "", fileToOpen = "";

    if (pipe == -1) {
      file = src;
      fileToOpen = src;
    } else {
      archive = src.substring(0, pipe);
      file = src.substring(pipe + 1);
      fileToOpen = archive;
    }
    return [archive, file, fileToOpen];
  }

  void applyIps(String ipsfile) {}

  void close() {}

  static FCFILE? open(String path, String? ipsfn, List<String>? extensions) {
    File ipsfp = File(ipsfn ?? "");
    FCFILE? fcfp;
    var files = splitArchiveFilename(path);
    var archive = files[0];
    var fname = files[1];
    var fileToOpen = files[2];

    if (ipsfp.existsSync()) fcfp?.applyIps(ipsfp.absolute.path);

    return null;
  }
}

class ArchvieScanRecord {
  var type = -1;
  var numFilesInArchive = 0;

  List<FCArchvieFileInfo> files = [];

  bool get isArchive => type != -1;
}

class FCArchvieFileInfo {
  var name = "";
  var size = 0;
  var index = 0;
}
