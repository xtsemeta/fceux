import 'dart:ffi';
import 'dart:io';

import 'package:fc_flutter/fc/emufile.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart';

class FCFile {
  EmuFile? stream;
  String? filename;
  String? logicalPath;
  String? archiveFilename;
  String? fullFilename;
  int archiveCount = -1;
  int archiveIndex = 0;
  int size = 0;

  bool isArchive() => archiveCount > 0;

  void setStream(EmuFile newstream) {
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

  static const support_exts = ['nes', 'fds', 'nsf'];

  static Future<FCFile?> open(String path, String? ipsfn,
      {List<String> extensions = support_exts}) async {
    File ipsfp = File(ipsfn ?? "");
    FCFile fcfp;
    var files = splitArchiveFilename(path);
    var archive = files[0];
    var fname = files[1];
    var fileToOpen = files[2];

    final inputStream = InputFileStream(fileToOpen);
    final decArchive = ZipDecoder().decodeBuffer(inputStream);

    ArchiveFile? af;
    EmuFileMemory em = EmuFileMemory();
    for (var item in decArchive.files) {
      if (!item.isFile) continue;
      var ext = extension(item.name);
      if (extensions.contains(ext)) {
        af = item;
        em.data = item.content as List<int>;
        em.len = em.data.length;
        break;
      }
    }
    if (af == null) return null;

    fcfp = FCFile();
    fcfp.filename = fileToOpen;
    fcfp.logicalPath = fileToOpen;
    fcfp.fullFilename = fileToOpen;
    fcfp.stream = em;
    fcfp.size = em.len;

    if (!ipsfp.existsSync()) {
      var ipsFilename = "$fileToOpen.ips";
      ipsfp = File(ipsFilename);
    }

    fcfp?.applyIps(ipsfp.absolute.path);

    return fcfp;
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
