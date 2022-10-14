class FCFILE {
  FCFILE? stream;
  String? filename;
  String? logicalPath;
  String? archiveFilename;
  String? fullFilename;
  int archiveCount = -1;
  int archiveIndex = 0;
  int size = 0;

  bool isArchive() => archiveCount > 0;

  void setStream(FCFILE newstream) {
    stream = newstream;
  }
}
