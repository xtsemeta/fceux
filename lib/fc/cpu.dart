import 'package:flutter/foundation.dart';

bool overclockEnabled = false;
bool overclocking = false;

class X6502 {
  var tcount = 0; //临时循环计数器

  var A = 0; //加速器
  var X = 0; //索引寄存器
  var Y = 0; //索引寄存器
  var PC = 0; //程序计数器
  var SP = 0; //堆栈指针
  /// 状态寄存器的每一位都用作分支指令中的标志。第5位不使用，始终设置为1。
  ///          7 6 5 4 3 2 1 0
  /// 状态标志  N V 1 B D I Z C
  var P = 0; //处理器状态寄存器

  var mooPI = 0;
  var jammed = 0;

  var count = 0;
  var IRQlow = 0;
  var DB = 0; //用于从某些区域读取的数据总线缓存
  var preexec = 0;

  var timestamp = 0;
  var soundtimestamp = 0;
  var scanline = 0;

  var isPal = false;

  static const N_FLAG = 0x80; // negative
  static const V_FLAG = 0x40; // overflow
  static const U_FLAG = 0x20; // reserved (always 1)
  static const B_FLAG = 0x10; // break
  static const D_FLAG = 0x08; // decimal
  static const I_FLAG = 0x04; // interrupt
  static const Z_FLAG = 0x02; // zero
  static const C_FLAG = 0x01; // carry

  static const dendy = false;
  static const NTSC_CPU = dendy ? 1773447.467 : 1789772.7272727272727272;
  static const PAL_CPU = 1662607.125;

  /// 中断包括RESET、NMI(non-maskable interrupt)、IRQ(interrupt request)、BRK(break)。
  /// 硬件中断中NMI IRQ低电平有效。BRK是软件中断。通过中断向量跳转到指定地址。
  static const IQEXT = 0x001;
  static const IQEXT2 = 0x002;
  static const IQRESET = 0x020;
  static const IQNMI2 = 0x040;
  static const IQNMI = 0x080;
  static const IQDPCM = 0x100;
  static const IQFCOUNT = 0x200;
  static const IQTEMP = 0x800;

  var ZNTable = Uint8List(256);
  int stackAddrBackup = -1;

  // 初始化6502CPU
  void init() {
    for (var i = 0; i < 256; i++) {
      if (i == 0)
        ZNTable[i] = Z_FLAG;
      else if (i & 0x80 > 0)
        ZNTable[i] = N_FLAG;
      else
        ZNTable[i] = 0;
    }
  }

  int getOpcodeCycles(int op) => cycTable[op];

  set setIRQBegin(int w) => IRQlow |= w;
  set setIRQEnd(int w) => IRQlow &= ~w;
  void triggerNMI() => IRQlow |= IQNMI;
  void triggerNMI2() => IRQlow |= IQNMI2;
  void reset() => IRQlow = IQRESET;

  void power() {
    count = 0;
    tcount = 0;
    IRQlow = 0;
    PC = 0;
    A = 0;
    X = 0;
    Y = 0;
    P = 0;
    mooPI = 0;
    DB = 0;
    jammed = 0;

    SP = 0xFD;
    timestamp = soundtimestamp = 0;
    reset();
    stackAddrBackup = -1;
  }

  void run(int cycles) {
    if (isPal) {
      cycles *= 15;
    } else {
      cycles *= 16;
    }

    count += cycles;

    while (count > 0) {
      var temp = 0;
      var b1 = 0;
    }
  }

  static var cycTable = Uint8List.fromList([
    7, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6, //0x00
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7, //0x10
    6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6, //0x20
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7, //0x30
    6, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 3, 4, 6, 6, //0x40
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7, //0x50
    6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6, //0x60
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7, //0x70
    2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4, //0x80
    2, 6, 2, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5, //0x90
    2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4, //0xA0
    2, 5, 2, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4, //0xB0
    2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6, //0xC0
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7, //0xD0
    2, 6, 3, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6, //0xE0
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7, //0xF0
  ]);

  /// 常用算法定义
  void _addcyc(int x) {
    X = x;
    tcount = x;
    count = x * 48;
    timestamp += X;
    if (!overclocking) {
      soundtimestamp += x;
    }
  }
}
