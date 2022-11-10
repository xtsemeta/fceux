import 'dart:ffi';
import 'dart:io';

import 'package:fc_flutter/fc/emufile.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart';

class FCFile {
  EmuFile? stream;
  String? filename;
  String? path;
  String? dir;
  int archiveCount = -1;
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

  static const supportExts = ['nes', 'fds', 'nsf'];

  static Future<FCFile?> open(String path, String? ipsfn,
      {List<String> extensions = supportExts}) async {
    File ipsfp = File(ipsfn ?? "");
    FCFile fcfp = FCFile();
    var ext = extension(path);
    var filename = basename(path);
    var dir = dirname(path);
    fcfp.path = path;
    fcfp.filename = filename;
    fcfp.dir = dir;
    var file = File(path);
    if (!(await file.exists())) {
      return null;
    }

    InputFileStream iStream;
    if (supportExts.contains(ext)) {
      var bytes = await file.readAsBytes();
      EmuFileMemory em = EmuFileMemory();
      em.data = bytes;
      em.len = bytes.length;
      fcfp.stream = em;
      fcfp.size = em.len;
    } else {
      final inputStream = InputFileStream(path);
      Archive decArchive = ZipDecoder().decodeBuffer(inputStream);
      try {
        ArchiveFile? af;
        EmuFileMemory em = EmuFileMemory();
        for (var item in decArchive.files) {
          fcfp.archiveCount++;
          if (!item.isFile) continue;
          var ext = extension(item.name);
          if (!extensions.contains(ext)) continue;
          af = item;
          em.data = item.rawContent?.toUint8List();
          em.len = em.data?.length ?? 0;
          break;
        }
        if (af == null) return null;
      } catch (e) {
        print('file can not decoded');
      }
    }

    if (!(await ipsfp.exists())) {
      var ipsFilename = "${withoutExtension(path)}.ips";
      ipsfp = File(ipsFilename);
    }

    fcfp.applyIps(ipsfp.absolute.path);

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
