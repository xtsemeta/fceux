enum EGIT {
  GIT_CART,
  GIT_VSUNI,
  GIT_FDS,
  GIT_NSF;
}

enum EGIV {
  GIV_NTSC,
  GIV_PAL,
  GIV_USER;
}

enum ESIS {
  SIS_NONE,
  SIS_DATACH,
  SIS_NWC,
  SIS_VSUNISYSTEM,
  SIS_NSF;
}

// 标准操纵杆端口的输入设备类型
enum ESI {
  SI_UNSET("<invalid ESI>", -1),
  SI_NONE("<none>", 0),
  SI_GAME_PAD("Gamepad", 1),
  SI_ZAPPER("Zapper", 2),
  SI_POWERPADA("Power Pad A", 3),
  SI_POWERPADB("Power Pad B", 4),
  SI_ARKANOID("Arkanoid Paddle", 5),
  SI_MOUSE("Subor Mouse", 6),
  SI_SNES("SNES Pad", 7),
  SI_SNES_MOUSE("SNES Mouse", 8),
  SI_VIRTUALBOY("Virtual Boy", 9),
  SI_LCDCOMP_ZAPPER("LCD Zapper (Advance)", 10);

  final String name;
  final int idx;

  const ESI(this.name, this.idx);

  int get count => SI_LCDCOMP_ZAPPER.idx;
}

// 扩展端口的输入设备类型
enum ESIFC {
  SIFC_UNSET("<invalid ESIFC>", -1),
  SIFC_NONE("<none>", 0),
  SIFC_ARKANOID("Arkanoid Paddle", 1),
  SIFC_SHADOW("Hyper Shot gun", 2),
  SIFC_4PLAYER("4-Player Adapter", 3),
  SIFC_FKB("Family Keyboard", 4),
  SIFC_SUBORKB("Subor Keyboard", 5),
  SIFC_PEC586KB("PEC586 Keyboard", 6),
  SIFC_HYPERSHOT("HyperShot Pads", 7),
  SIFC_MAHJONG("Mahjong", 8),
  SIFC_QUIZKING("Quiz King Buzzers", 9),
  SIFC_FTRAINERA("Family Trainer A", 10),
  SIFC_FTRAINERB("Family Trainer B", 11),
  SIFC_OEKAKIDS("Oeka Kids Tablet", 12),
  SIFC_BWORLD("Barcode World", 13),
  SIFC_TOPRIDER("Top Rider", 14),
  SIFC_FAMINETSYS("Famicom Network Controller", 15),
  SIFC_HORI4PLAYER("Hori 4-Player Adapter", 16);

  final String name;
  final int idx;

  const ESIFC(this.name, this.idx);

  int get count => SIFC_HORI4PLAYER.idx;
}

class FCGI {
  String name = "none";
  late String filename;
  int mappernum = 0;

  late EGIT type;
  late EGIV vidsys;
  List<ESI> input = <ESI>[ESI.SI_UNSET, ESI.SI_UNSET];
  late ESIFC inputfc;
  late ESIS cspecial;

  late String md5;

// ogg扩展声音支持。默认0
  int soundrate = 0;
  // 声音通道数
  late int soundchan;
}
