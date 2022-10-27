import 'dart:ffi';

import 'package:flutter/foundation.dart';

bool overclockEnabled = false;
bool overclocking = false;

typedef ARead = int Function(int address);
typedef BWrite = void Function(int address, int value);

class CpuRegister {
  var a = 0;
  var x = 0;
  var y = 0;

  var p = 0;
  var pc = 0;
  var sp = 0;

  static const FLAG_N = 0x80;
  static const FLAG_V = 0x40;
  static const FLAG_U = 0x20;
  static const FLAG_B = 0x10;
  static const FLAG_D = 0x08;
  static const FLAG_I = 0x04;
  static const FLAG_Z = 0x02;
  static const FLAG_C = 0x01;

  late int Function(int a) rdmem;

  void test() {
    rdmem = (a) {
      return a + 10;
    };
    var a = rdmem(10);
  }
}

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

  static const N_FLAG = 0x80; // negative，该位就是运算结果的最高位
  static const V_FLAG = 0x40; // overflow，进位标志（一般对于有符号数来说），上溢1，下溢0
  static const U_FLAG = 0x20; // reserved (always 1)
  static const B_FLAG = 0x10; // break，发出IRQ中断
  static const D_FLAG = 0x08; // decimal，BCD模式
  static const I_FLAG = 0x04; // interrupt disable，1使得系统忽略中断
  static const Z_FLAG = 0x02; // zero，最近一条指令结果是否为0，1是、0不是
  static const C_FLAG = 0x01; // carry，进位标志（一般对于无符号数来说），上溢1，下溢0

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

  List<ARead> aread = List.filled(0x10000, ((a) => 0));
  List<BWrite> bwrite = List.filled(0x10000, ((a, b) {}));

  var RAM = <int>[];

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

  int rdMem(int a) {
    DB = aread[a](a);
    return DB;
  }

  void wrMem(int a, int v) {
    bwrite[a](a, v);
  }

  int rdRam(int a) {
    return DB = aread[a](a);
    // return DB = RAM(a);
  }

  void wrRam(int a, int v) {
    RAM[a] = v;
  }

  int _dmr(int a) {
    _addcyc(1);
    return DB = aread[a](a);
  }

  void _dmw(int a, int v) {
    _addcyc(1);
    bwrite[a](a, v);
  }

  void _push(int v) {
    wrRam(0x100 + SP, v);
    SP--;
  }

  _pop() => rdRam(0x100 + (++SP));

  _xZN(int zort) {
    P &= ~(Z_FLAG | N_FLAG);
    P |= ZNTable[zort];
  }

  _xZNT(int zort) {
    P |= ZNTable[zort];
  }

  _jr(bool cond) {
    if (cond) {
      var disp = rdMem(PC);
      PC++;
      _addcyc(1);
      var tmp = PC;
      PC += disp;
      if (tmp ^ PC & 0x100 != 0) _addcyc(1);
    } else {
      PC++;
    }
  }

  void _lda(int x) {
    A = x;
    _xZN(A);
  }

  _ldx(int x) {
    X = x;
    _xZN(X);
  }

  _ldy(int x) {
    Y = x;
    _xZN(Y);
  }

  //算术操作
  //绝对寻址，指令中操作数部分为 操作数的绝对地址
  _and(x) {
    A &= x;
    _xZN(A);
  }

  _eor(x) {
    A ^= x;
    _xZN(A);
  }

  _ora(x) {
    A |= x;
    _xZN(A);
  }

  _bit(x) {
    P &= (Z_FLAG | V_FLAG | N_FLAG);
    P |= ZNTable[x & A] & Z_FLAG;
    P |= x & (V_FLAG | N_FLAG);
  }

  _adc(int x) {
    var l = A + x + (P & 1);
    P &= ~(Z_FLAG | C_FLAG | N_FLAG | V_FLAG);
    P |= ((((A ^ x) & 0x80) ^ 0x80) & ((A ^ l) & 0x80)) >> 1;
    P |= (l >> 8) & C_FLAG;
    A = l;
    _xZNT(A);
  }

  _sbc(int x) {
    var l = A - x - ((P & 1) ^ 1);
    P &= ~(Z_FLAG | C_FLAG | N_FLAG | V_FLAG);
    P |= ((A ^ l) & (A ^ x) & 0x80) >> 1;
    P |= ((l >> 8) & C_FLAG) ^ C_FLAG;
    A = l;
    _xZNT(A);
  }

  _cmpl(a1, a2) {
    var t = a1 - a2;
    _xZN(t & 0xFF);
    P &= ~C_FLAG;
    P |= ((t >> 8) & C_FLAG) ^ C_FLAG;
  }

  _axs(int x) {
    var t = (A & X) - x;
    _xZN(t & 0xFF);
    P &= ~C_FLAG;
    P |= ((t >> 8) & C_FLAG) ^ C_FLAG;
    X = t;
  }

  _cmp(int x) => _cmpl(A, x);
  _cpx(int x) => _cmpl(X, x);
  _cpy(int x) => _cmpl(Y, x);

  _dec(x) {
    x--;
    _xZN(x);
  }

  _inc(x) {
    x++;
    _xZN(x);
  }

  _asl(x) {
    PC &= ~C_FLAG;
    P |= x >> 7;
    x <<= 1;
    _xZN(x);
  }

  _lsr(x) {
    PC &= ~(C_FLAG | N_FLAG | Z_FLAG);
    P |= x & 1;
    x >>= 1;
    _xZN(x);
  }

  _lsra(x) {
    P &= ~(C_FLAG | N_FLAG | Z_FLAG);
    P |= A & 1;
    A >>= 1;
    _xZNT(A);
  }

  _rol(x) {
    var l = x >> 7;
    x |= P & C_FLAG;
    P &= ~(Z_FLAG | N_FLAG | C_FLAG);
    P |= l;
    _xZNT(x);
  }

  _ror(x) {
    var l = x & 1;
    x >>= 1;
    x |= (P & C_FLAG) << 7;
    P &= ~(Z_FLAG | N_FLAG | C_FLAG);
    P |= l;
    _xZNT(x);
  }

  ops(op) {
    switch (op) {
      case 0x00: //BRK
        PC++;
        _push(PC >> 8);
        _push(PC);
        _push(P | U_FLAG | B_FLAG);
        P |= I_FLAG;
        mooPI |= I_FLAG;
        PC = rdMem(0xFFFE);
        PC = rdMem(0xFFFF) << 8;
        break;
      default:
    }
  }
}
