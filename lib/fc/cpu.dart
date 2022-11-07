import 'dart:ffi';

import 'package:flutter/foundation.dart';

bool overclockEnabled = false;
bool overclocking = false;

typedef ARead = int Function(int address);
typedef BWrite = void Function(int address, int value);

class CpuRegister {
  /// 加速器
  var a = 0;

  /// 索引寄存器
  var x = 0;

  /// 索引寄存器
  var y = 0;

  /// 状态寄存器的每一位都用作分支指令中的标志。第5位不使用，始终设置为1。<br/><pre>
  ///         7 6 5 4 3 2 1 0<br/>
  /// 状态标志 N V 1 B D I Z C</pre>
  var p = 0;

  ///程序计数器
  var pc = 0;

  ///堆栈指针
  var sp = 0;

  /// negative，该位就是运算结果的最高位
  final FLAG_N = 0x80;

  /// overflow，进位标志（一般对于有符号数来说），上溢1，下溢0
  final FLAG_V = 0x40;

  /// reserved (always 1)
  final FLAG_U = 0x20;

  /// break，发出IRQ中断
  final FLAG_B = 0x10;

  /// decimal，BCD模式
  final FLAG_D = 0x08;

  /// interrupt disable，1使得系统忽略中断
  final FLAG_I = 0x04;

  /// zero，最近一条指令结果是否为0，1是、0不是
  final FLAG_Z = 0x02;

  /// carry，进位标志（一般对于无符号数来说），上溢1，下溢0
  final FLAG_C = 0x01;
}

class X6502 with CpuRegister {
  var tcount = 0; //临时循环计数器

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
        ZNTable[i] = FLAG_Z;
      else if (i & 0x80 > 0)
        ZNTable[i] = FLAG_N;
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
    pc = 0;
    a = 0;
    x = 0;
    y = 0;
    p = 0;
    mooPI = 0;
    DB = 0;
    jammed = 0;

    sp = 0xFD;
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
  void addcyc(int x) {
    this.x = x;
    tcount = x;
    count = x * 48;
    timestamp += this.x;
    if (!overclocking) {
      soundtimestamp += x;
    }
  }

  int rdmem(int a) {
    DB = aread[a](a);
    return DB;
  }

  void wrmem(int a, int v) {
    bwrite[a](a, v);
  }

  int rdram(int a) {
    return DB = aread[a](a);
    // return DB = RAM(a);
  }

  void wrram(int a, int v) {
    RAM[a] = v;
  }

  int dmr(int a) {
    addcyc(1);
    return DB = aread[a](a);
  }

  void dmw(int a, int v) {
    addcyc(1);
    bwrite[a](a, v);
  }

  void push(int v) {
    wrram(0x100 + sp, v);
    sp--;
  }

  pop() => rdram(0x100 + (++sp));

  zn(int zort) {
    p &= ~(FLAG_Z | FLAG_N);
    p |= ZNTable[zort];
  }

  znt(int zort) {
    p |= ZNTable[zort];
  }

  jr(bool cond) {
    if (cond) {
      var disp = rdmem(pc);
      pc++;
      addcyc(1);
      var tmp = pc;
      pc += disp;
      if (tmp ^ pc & 0x100 != 0) addcyc(1);
    } else {
      pc++;
    }
  }

  void lda(int x) {
    a = x;
    zn(a);
  }

  ldx(int x) {
    this.x = x;
    zn(this.x);
  }

  ldy(int x) {
    y = x;
    zn(y);
  }

  //算术操作
  //绝对寻址，指令中操作数部分为 操作数的绝对地址
  and(x) {
    a &= x;
    zn(a);
  }

  eor(x) {
    a ^= x;
    zn(a);
  }

  ora(x) {
    a |= x;
    zn(a);
  }

  bit(x) {
    p &= (FLAG_Z | FLAG_V | FLAG_N);
    p |= ZNTable[x & a] & FLAG_Z;
    p |= x & (FLAG_V | FLAG_N);
  }

  adc(int x) {
    var l = a + x + (p & 1);
    p &= ~(FLAG_Z | FLAG_C | FLAG_N | FLAG_V);
    p |= ((((a ^ x) & 0x80) ^ 0x80) & ((a ^ l) & 0x80)) >> 1;
    p |= (l >> 8) & FLAG_C;
    a = l;
    znt(a);
  }

  sbc(int x) {
    var l = a - x - ((p & 1) ^ 1);
    p &= ~(FLAG_Z | FLAG_C | FLAG_N | FLAG_V);
    p |= ((a ^ l) & (a ^ x) & 0x80) >> 1;
    p |= ((l >> 8) & FLAG_C) ^ FLAG_C;
    a = l;
    znt(a);
  }

  cmpl(a1, a2) {
    var t = a1 - a2;
    zn(t & 0xFF);
    p &= ~FLAG_C;
    p |= ((t >> 8) & FLAG_C) ^ FLAG_C;
  }

  axs(int x) {
    var t = (a & this.x) - x;
    zn(t & 0xFF);
    p &= ~FLAG_C;
    p |= ((t >> 8) & FLAG_C) ^ FLAG_C;
    this.x = t;
  }

  cmp(int x) => cmpl(this.a, x);
  cpx(int x) => cmpl(this.x, x);
  cpy(int x) => cmpl(this.y, x);

  dec(x) {
    x--;
    zn(x);
  }

  inc(x) {
    x++;
    zn(x);
  }

  asl(x) {
    pc &= ~FLAG_C;
    p |= x >> 7;
    x <<= 1;
    zn(x);
  }

  lsr(x) {
    pc &= ~(FLAG_C | FLAG_N | FLAG_Z);
    p |= x & 1;
    x >>= 1;
    zn(x);
  }

  lsra(x) {
    p &= ~(FLAG_C | FLAG_N | FLAG_Z);
    p |= a & 1;
    a >>= 1;
    znt(a);
  }

  rol(x) {
    var l = x >> 7;
    x |= p & FLAG_C;
    p &= ~(FLAG_Z | FLAG_N | FLAG_C);
    p |= l;
    znt(x);
  }

  ror(x) {
    var l = x & 1;
    x >>= 1;
    x |= (p & FLAG_C) << 7;
    p &= ~(FLAG_Z | FLAG_N | FLAG_C);
    p |= l;
    znt(x);
  }

  /// Absolute
  getAB() {
    var target = rdmem(pc);
    pc++;
    target |= rdmem(pc) << 8;
    pc++;
    return target;
  }
// Absolute Indexed(for reads) 
  getABIRD(int i) {
    var tmp = 0, target = 0;
    tmp = getAB();
    target = tmp;
    target += i;
    if ((target ^ tmp) & 0x100 != 0) {
      target &= 0xFFFF;
      addcyc(1);
    }
    return target;
  }
// Absolute Indexed(for writes and rmws)
  getABIWR(int i) {
    var rt = 0, target = 0;
    rt = getAB();
    target = rt;
    target += i;
    target &= 0xFFFF;
    rdmem((target & 0x00FF) | (rt & 0xFF00));
    return target;
  }
// Zero Page
  getZP() {
    var target = 0;
    target = rdmem(pc);
    pc++;
    return target;
  }
// Zero Page Indexed
  getZPI(int i) {
    var target = i + rdmem(pc);
    pc++;
  }
///Indexed Indirect
  getIX() {
    var target = 0, tmp = 0;
    tmp = rdmem(pc);
    pc++;
    tmp += x;
    target = rdram(tmp);
    tmp++;
    target |= rdram(tmp) << 8;
    return target;
  }
///Indirect Indexed(for reads)
  getIYRD() {
    var target = 0, tmp = 0, rt = 0;
    tmp = rdmem(pc);
    pc++;
    rt = rdram(tmp);
    tmp++;
    rt |= rdram(tmp) << 8;
    target = rt;
    target += y;
    if ((target ^ rt) & 0x100 != 0) {
      target &= 0xFFFF;
      rdmem(target ^ 0x100);
      addcyc(1);
    }
    return target;
  }

///Indirect Indexed(for writes and rmws)
  getIYWR() {
    var target = 0, tmp = 0, rt = 0;
    tmp = rdmem(pc);
    pc++;
    rt = rdram(tmp);
    tmp++;
    rt |= rdram(tmp) << 8;
    target = rt;
    target += y;
    target &= 0xFFFF;
    rdmem((target ^ 0x00FF) | (rt & 0xFF00));
    return target;
  }

  rmwA(op) {
    var x = a;
    a=op(x);
    break;
  }

  ops(op) {
    switch (op) {
      case 0x00: //BRK
        pc++;
        push(pc >> 8);
        push(pc);
        push(p | FLAG_U | FLAG_B);
        p |= FLAG_I;
        mooPI |= FLAG_I;
        pc = rdmem(0xFFFE);
        pc = rdmem(0xFFFF) << 8;
        break;
      default:
    }
  }
}
