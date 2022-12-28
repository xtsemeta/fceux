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
    count = tcount = IRQlow = pc = a = x = y = p = mooPI = DB = jammed = 0;
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

      if (IRQlow != 0) {
        if (IRQlow & IQRESET != 0) {
          pc = rdmem(0xFFFC);
          pc |= rdmem(0xFFFD) << 8;
          jammed = 0;
          mooPI = p = FLAG_I;
          IRQlow &= ~IQRESET;
        } else if (IRQlow & IQNMI2 != 0) {
          IRQlow &= ~IQNMI2;
          IRQlow |= IQNMI;
        } else if (IRQlow & IQNMI != 0) {
          if (jammed == 0) {
            addcyc(7);
            push(pc >> 8);
            push(pc);
            push((p | FLAG_B) | FLAG_U);
            p |= FLAG_I;
            pc = rdmem(0xFFFA);
            pc |= rdmem(0xFFFB) << 8;
            IRQlow &= ~IQNMI;
          }
        } else {
          if ((mooPI & FLAG_I == 0 && jammed == 0)) {
            addcyc(7);
            push(pc >> 8);
            push(pc);
            push((p | FLAG_B) | FLAG_U);
            p |= FLAG_I;
            pc = rdmem(0xFFFF);
            pc |= rdmem(0xFFFF) << 8;
          }
        }

        IRQlow &= ~IQTEMP;
        if (count <= 0) {
          mooPI = p;
          return;
        } //应该在不影响速度的前提下提高准确度
      }

      mooPI = p;
      b1 = rdmem(pc);
      addcyc(cycTable[b1]);

      temp = tcount;
      tcount = 0;

      if (!overclocking) {
        //TODO: sound cpu hook
      }
      pc++;
      ops(b1);
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

  void ldx(int x) {
    this.x = x;
    zn(this.x);
  }

  void ldy(int x) {
    y = x;
    zn(y);
  }

  //算术操作
  //绝对寻址，指令中操作数部分为 操作数的绝对地址
  void and(x) {
    a &= x;
    zn(a);
  }

  void eor(x) {
    a ^= x;
    zn(a);
  }

  void ora(x) {
    a |= x;
    zn(a);
  }

  void bit(x) {
    p &= (FLAG_Z | FLAG_V | FLAG_N);
    p |= ZNTable[x & a] & FLAG_Z;
    p |= x & (FLAG_V | FLAG_N);
  }

  void adc(int x) {
    var l = a + x + (p & 1);
    p &= ~(FLAG_Z | FLAG_C | FLAG_N | FLAG_V);
    p |= ((((a ^ x) & 0x80) ^ 0x80) & ((a ^ l) & 0x80)) >> 1;
    p |= (l >> 8) & FLAG_C;
    a = l;
    znt(a);
  }

  void sbc(int x) {
    var l = a - x - ((p & 1) ^ 1);
    p &= ~(FLAG_Z | FLAG_C | FLAG_N | FLAG_V);
    p |= ((a ^ l) & (a ^ x) & 0x80) >> 1;
    p |= ((l >> 8) & FLAG_C) ^ FLAG_C;
    a = l;
    znt(a);
  }

  void cmpl(a1, a2) {
    var t = a1 - a2;
    zn(t & 0xFF);
    p &= ~FLAG_C;
    p |= ((t >> 8) & FLAG_C) ^ FLAG_C;
  }

  void axs(int x) {
    var t = (a & this.x) - x;
    zn(t & 0xFF);
    p &= ~FLAG_C;
    p |= ((t >> 8) & FLAG_C) ^ FLAG_C;
    this.x = t;
  }

  void cmp(int x) => cmpl(this.a, x);
  void cpx(int x) => cmpl(this.x, x);
  void cpy(int x) => cmpl(this.y, x);

  dec(x) {
    x--;
    zn(x);
    return x;
  }

  inc(x) {
    x++;
    zn(x);
    return x;
  }

  asl(x) {
    pc &= ~FLAG_C;
    p |= x >> 7;
    x <<= 1;
    zn(x);
    return x;
  }

  lsr(x) {
    pc &= ~(FLAG_C | FLAG_N | FLAG_Z);
    p |= x & 1;
    x >>= 1;
    zn(x);
    return x;
  }

  lsra() {
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
    return x;
  }

  ror(x) {
    var l = x & 1;
    x >>= 1;
    x |= (p & FLAG_C) << 7;
    p &= ~(FLAG_Z | FLAG_N | FLAG_C);
    p |= l;
    znt(x);
    return x;
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
    a = op(x);
  }

  rmwAB(op) {
    var a = getAB();
    var x = rdmem(a);
    wrmem(a, x);
    x = op(x);
    wrmem(a, x);
  }

  rmwABI(reg, op) {
    var a = getABIWR(reg);
    var x = rdmem(a);
    wrmem(a, x);
    x = op(x);
    wrmem(a, x);
  }

  rmwABX(op) {
    rmwABI(this.x, op);
  }

  rmwABY(op) {
    rmwABI(this.y, op);
  }

  rmwIX(op) {
    var a = getIX();
    var x = rdmem(a);
    wrmem(a, x);
    x = op(x);
    wrmem(a, x);
  }

  rmwIY(op) {
    var a = getIYWR();
    var x = rdmem(a);
    wrmem(a, x);
    x = op(x);
    wrmem(a, x);
  }

  rmwZP(op) {
    var a = getZP();
    var x = rdram(a);
    x = op(x);
    wrram(a, x);
  }

  rmwZPX(op) {
    var a = getZPI(this.x);
    var x = rdram(a);
    x = op(x);
    wrram(a, x);
  }

  ldIM(op) {
    var x = rdmem(pc);
    pc++;
    op(x);
  }

  ldZP(op) {
    var a = getZP();
    var x = rdram(a);
    op(x);
  }

  ldZPX(op) {
    var a = getZPI(this.x);
    var x = rdram(a);
    op(x);
  }

  ldZPY(op) {
    var a = getZPI(this.y);
    var x = rdram(a);
    op(x);
  }

  ldAB(op) {
    var a = getAB();
    var x = rdmem(a);
    op(x);
  }

  ldABI(reg, op) {
    var a = getABIRD(reg);
    var x = rdmem(a);
    op(x);
  }

  ldABX(op) {
    ldABI(this.x, op);
  }

  ldABY(op) {
    ldABI(this.y, op);
  }

  ldIX(op) {
    var a = getIX();
    var x = rdmem(a);
    op(x);
  }

  ldIY(op) {
    var a = getIYRD();
    var x = rdmem(a);
    op(x);
  }

  stZP(r) {
    var a = getZP();
    wrram(a, r);
  }

  stZPX(r) {
    var a = getZPI(this.x);
    wrram(a, r);
  }

  stZPY(r) {
    var a = getZPI(this.y);
    wrram(a, r);
  }

  stAB(r) {
    var a = getAB();
    wrmem(a, r);
  }

  stABI(reg, r) {
    var a = getABIWR(reg);
    wrmem(a, r(a));
  }

  stABX(r) {
    stABI(this.x, r);
  }

  stABY(r) {
    stABI(this.y, r);
  }

  stIX(r) {
    var a = getIX();
    wrmem(a, r);
  }

  stIY(r) {
    var a = getIYWR();
    wrmem(a, r(a));
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
      case 0x40: //RTI
        p = pop();
        mooPI = p;
        pc = pop();
        pc |= pop() << 8;
        break;
      case 0x60: //RTS
        pc = pop();
        pc |= pop() << 8;
        pc++;
        break;
      case 0x48: //PHA
        push(this.a);
        break;
      case 0x08: //PHP
        push(p | FLAG_U | FLAG_B);
        break;
      case 0x68: //PLA
        a = pop();
        zn(a);
        break;
      case 0x28: //PLP
        p = pop();
        break;
      case 0x4C:
        var ptmp = pc;
        var npc = rdmem(ptmp);
        ptmp++;
        npc |= rdmem(ptmp) << 8;
        pc = npc;
        break; //JMP ABOSOLUTE
      case 0x6C:
        var tmp = getAB();
        pc = rdmem(tmp);
        pc |= rdmem(((tmp + 1) & 0x00FF) | (tmp & 0xFF00)) << 8;
        break;
      case 0x20: /* JSR */
        {
          var npc;
          npc = rdmem(pc);
          pc++;
          push(pc >> 8);
          push(pc);
          pc = rdmem(pc) << 8;
          pc |= npc;
        }
        break;

      case 0xAA: /* TAX */
        this.x = this.a;
        zn(this.a);
        break;

      case 0x8A: /* TXA */
        this.a = this.x;
        zn(this.a);
        break;

      case 0xA8: /* TAY */
        this.y = this.a;
        zn(this.a);
        break;
      case 0x98: /* TYA */
        this.a = this.y;
        zn(this.a);
        break;

      case 0xBA: /* TSX */
        this.x = this.sp;
        zn(this.x);
        break;
      case 0x9A: /* TXS */
        this.sp = this.x;
        break;

      case 0xCA: /* DEX */
        this.x--;
        zn(this.x);
        break;
      case 0x88: /* DEY */
        this.y--;
        zn(this.y);
        break;

      case 0xE8: /* INX */
        this.x++;
        zn(this.x);
        break;
      case 0xC8: /* INY */
        this.y++;
        zn(this.y);
        break;

      case 0x18: /* CLC */
        this.p &= ~FLAG_C;
        break;
      case 0xD8: /* CLD */
        this.p &= ~FLAG_D;
        break;
      case 0x58: /* CLI */
        this.p &= ~FLAG_I;
        break;
      case 0xB8: /* CLV */
        this.p &= ~FLAG_V;
        break;

      case 0x38: /* SEC */
        this.p |= FLAG_C;
        break;
      case 0xF8: /* SED */
        this.p |= FLAG_D;
        break;
      case 0x78: /* SEI */
        this.p |= FLAG_I;
        break;

      case 0xEA: /* NOP */
        break;

      case 0x0A:
        rmwA(asl);
        break;
      case 0x06:
        rmwZP(asl);
        break;
      case 0x16:
        rmwZPX(asl);
        break;
      case 0x0E:
        rmwAB(asl);
        break;
      case 0x1E:
        rmwABX(asl);
        break;

      case 0xC6:
        rmwZP(dec);
        break;
      case 0xD6:
        rmwZPX(dec);
        break;
      case 0xCE:
        rmwAB(dec);
        break;
      case 0xDE:
        rmwABX(dec);
        break;

      case 0xE6:
        rmwZP(inc);
        break;
      case 0xF6:
        rmwZPX(inc);
        break;
      case 0xEE:
        rmwAB(inc);
        break;
      case 0xFE:
        rmwABX(inc);
        break;

      case 0x4A:
        rmwA(lsr);
        break;
      case 0x46:
        rmwZP(lsr);
        break;
      case 0x56:
        rmwZPX(lsr);
        break;
      case 0x4E:
        rmwAB(lsr);
        break;
      case 0x5E:
        rmwABX(lsr);
        break;

      case 0x2A:
        rmwA(rol);
        break;
      case 0x26:
        rmwZP(rol);
        break;
      case 0x36:
        rmwZPX(rol);
        break;
      case 0x2E:
        rmwAB(rol);
        break;
      case 0x3E:
        rmwABX(rol);
        break;

      case 0x6A:
        rmwA(ror);
        break;
      case 0x66:
        rmwZP(ror);
        break;
      case 0x76:
        rmwZPX(ror);
        break;
      case 0x6E:
        rmwAB(ror);
        break;
      case 0x7E:
        rmwABX(ror);
        break;

      case 0x69:
        ldIM(adc);
        break;
      case 0x65:
        ldZP(adc);
        break;
      case 0x75:
        ldZPX(adc);
        break;
      case 0x6D:
        ldAB(adc);
        break;
      case 0x7D:
        ldABX(adc);
        break;
      case 0x79:
        ldABY(adc);
        break;
      case 0x61:
        ldIX(adc);
        break;
      case 0x71:
        ldIY(adc);
        break;

      case 0x29:
        ldIM(and);
        break;
      case 0x25:
        ldZP(and);
        break;
      case 0x35:
        ldZPX(and);
        break;
      case 0x2D:
        ldAB(and);
        break;
      case 0x3D:
        ldABX(and);
        break;
      case 0x39:
        ldABY(and);
        break;
      case 0x21:
        ldIX(and);
        break;
      case 0x31:
        ldIY(and);
        break;

      case 0x24:
        ldZP(bit);
        break;
      case 0x2C:
        ldAB(bit);
        break;

      case 0xC9:
        ldIM(cmp);
        break;
      case 0xC5:
        ldZP(cmp);
        break;
      case 0xD5:
        ldZPX(cmp);
        break;
      case 0xCD:
        ldAB(cmp);
        break;
      case 0xDD:
        ldABX(cmp);
        break;
      case 0xD9:
        ldABY(cmp);
        break;
      case 0xC1:
        ldIX(cmp);
        break;
      case 0xD1:
        ldIY(cmp);
        break;

      case 0xE0:
        ldIM(cpx);
        break;
      case 0xE4:
        ldZP(cpx);
        break;
      case 0xEC:
        ldAB(cpx);
        break;

      case 0xC0:
        ldIM(cpy);
        break;
      case 0xC4:
        ldZP(cpy);
        break;
      case 0xCC:
        ldAB(cpy);
        break;

      case 0x49:
        ldIM(eor);
        break;
      case 0x45:
        ldZP(eor);
        break;
      case 0x55:
        ldZPX(eor);
        break;
      case 0x4D:
        ldAB(eor);
        break;
      case 0x5D:
        ldABX(eor);
        break;
      case 0x59:
        ldABY(eor);
        break;
      case 0x41:
        ldIX(eor);
        break;
      case 0x51:
        ldIY(eor);
        break;

      case 0xA9:
        ldIM(lda);
        break;
      case 0xA5:
        ldZP(lda);
        break;
      case 0xB5:
        ldZPX(lda);
        break;
      case 0xAD:
        ldAB(lda);
        break;
      case 0xBD:
        ldABX(lda);
        break;
      case 0xB9:
        ldABY(lda);
        break;
      case 0xA1:
        ldIX(lda);
        break;
      case 0xB1:
        ldIY(lda);
        break;

      case 0xA2:
        ldIM(ldx);
        break;
      case 0xA6:
        ldZP(ldx);
        break;
      case 0xB6:
        ldZPY(ldx);
        break;
      case 0xAE:
        ldAB(ldx);
        break;
      case 0xBE:
        ldABY(ldx);
        break;

      case 0xA0:
        ldIM(ldy);
        break;
      case 0xA4:
        ldZP(ldy);
        break;
      case 0xB4:
        ldZPX(ldy);
        break;
      case 0xAC:
        ldAB(ldy);
        break;
      case 0xBC:
        ldABX(ldy);
        break;

      case 0x09:
        ldIM(ora);
        break;
      case 0x05:
        ldZP(ora);
        break;
      case 0x15:
        ldZPX(ora);
        break;
      case 0x0D:
        ldAB(ora);
        break;
      case 0x1D:
        ldABX(ora);
        break;
      case 0x19:
        ldABY(ora);
        break;
      case 0x01:
        ldIX(ora);
        break;
      case 0x11:
        ldIY(ora);
        break;

      case 0xEB: /* (undocumented) */
      case 0xE9:
        ldIM(sbc);
        break;
      case 0xE5:
        ldZP(sbc);
        break;
      case 0xF5:
        ldZPX(sbc);
        break;
      case 0xED:
        ldAB(sbc);
        break;
      case 0xFD:
        ldABX(sbc);
        break;
      case 0xF9:
        ldABY(sbc);
        break;
      case 0xE1:
        ldIX(sbc);
        break;
      case 0xF1:
        ldIY(sbc);
        break;

      case 0x85:
        stZP(a);
        break;
      case 0x95:
        stZPX(a);
        break;
      case 0x8D:
        stAB(a);
        break;
      case 0x9D:
        stABX(this.a);
        break;
      case 0x99:
        stABY(this.a);
        break;
      case 0x81:
        stIX(this.a);
        break;
      case 0x91:
        stIY(this.a);
        break;

      case 0x86:
        stZP(this.x);
        break;
      case 0x96:
        stZPY(this.x);
        break;
      case 0x8E:
        stAB(this.x);
        break;

      case 0x84:
        stZP(this.y);
        break;
      case 0x94:
        stZPX(this.y);
        break;
      case 0x8C:
        stAB(this.y);
        break;

/* BCC */
      case 0x90:
        jr(!(this.p & FLAG_C != 0));
        break;

/* BCS */
      case 0xB0:
        jr(this.p & FLAG_C != 0);
        break;

/* BEQ */
      case 0xF0:
        jr(this.p & FLAG_Z != 0);
        break;

/* BNE */
      case 0xD0:
        jr(!(this.p & FLAG_Z != 0));
        break;

/* BMI */
      case 0x30:
        jr(this.p & FLAG_N != 0);
        break;

/* BPL */
      case 0x10:
        jr(!(this.p & FLAG_N != 0));
        break;

/* BVC */
      case 0x50:
        jr(!(this.p & FLAG_V != 0));
        break;

/* BVS */
      case 0x70:
        jr(this.p & FLAG_V != 0);
        break;

//default: printf("Bad %02x at $%04x\n",b1,X.PC);break;
//ifdef moo
/* Here comes the undocumented instructions block.  Note that this implementation
   may be "wrong".  If so, please tell me.
*/

/* AAC */
      case 0x2B:
      case 0x0B:
        ldIM((x) {
          and(x);
          this.p &= ~FLAG_C;
          this.p |= this.a >> 7;
        });
        break;

/* AAX */
      case 0x87:
        stZP(this.a & this.x);
        break;
      case 0x97:
        stZPY(this.a & this.x);
        break;
      case 0x8F:
        stAB(this.a & this.x);
        break;
      case 0x83:
        stIX(this.a & this.x);
        break;

/* ARR - ARGH, MATEY! */
      case 0x6B:
        {
          ldIM((x) {
            and(x);
            this.p &= ~FLAG_V;
            this.p |= (this.a ^ (this.a >> 1)) & 0x40;
            var arrtmp = this.a >> 7;
            this.a >>= 1;
            this.a |= (this.p & FLAG_C) << 7;
            this.p &= ~FLAG_C;
            this.p |= arrtmp;
            zn(this.a);
          });
          break;
        }
/* ASR */
      case 0x4B:
        ldIM((x) {
          and(x);
          lsra();
        });
        break;

/* ATX(OAL) Is this(OR with $EE) correct? Blargg did some test
   and found the constant to be OR with is $FF for NES */
      case 0xAB:
        ldIM((x) {
          this.a |= 0xFF;
          and(x);
          this.x = this.a;
        });
        break;

/* AXS */
      case 0xCB:
        ldIM(axs);
        break;

/* DCP */
      case 0xC7:
        rmwZP((x) {
          x = dec(x);
          cmp(x);
          return x;
        });
        break;
      case 0xD7:
        rmwZPX((x) {
          x = dec(x);
          cmp(x);
          return x;
        });
        break;
      case 0xCF:
        rmwAB((x) {
          x = dec(x);
          cmp(x);
          return x;
        });
        break;
      case 0xDF:
        rmwABX((x) {
          x = dec(x);
          cmp(x);
          return x;
        });
        break;
      case 0xDB:
        rmwABY((x) {
          x = dec(x);
          cmp(x);
          return x;
        });
        break;
      case 0xC3:
        rmwIX((x) {
          x = dec(x);
          cmp(x);
          return x;
        });
        break;
      case 0xD3:
        rmwIY((x) {
          x = dec(x);
          cmp(x);
          return x;
        });
        break;

/* ISB */
      case 0xE7:
        rmwZP((x) {
          x = inc(x);
          sbc(x);
          return x;
        });
        break;
      case 0xF7:
        rmwZPX((x) {
          x = inc(x);
          sbc(x);
          return x;
        });
        break;
      case 0xEF:
        rmwAB((x) {
          x = inc(x);
          sbc(x);
          return x;
        });
        break;
      case 0xFF:
        rmwABX((x) {
          x = inc(x);
          sbc(x);
          return x;
        });
        break;
      case 0xFB:
        rmwABY((x) {
          x = inc(x);
          sbc(x);
          return x;
        });
        break;
      case 0xE3:
        rmwIX((x) {
          x = inc(x);
          sbc(x);
          return x;
        });
        break;
      case 0xF3:
        rmwIY((x) {
          x = inc(x);
          sbc(x);
          return x;
        });
        break;

/* DOP */

      case 0x04:
        pc++;
        break;
      case 0x14:
        pc++;
        break;
      case 0x34:
        pc++;
        break;
      case 0x44:
        pc++;
        break;
      case 0x54:
        pc++;
        break;
      case 0x64:
        pc++;
        break;
      case 0x74:
        pc++;
        break;

      case 0x80:
        pc++;
        break;
      case 0x82:
        pc++;
        break;
      case 0x89:
        pc++;
        break;
      case 0xC2:
        pc++;
        break;
      case 0xD4:
        pc++;
        break;
      case 0xE2:
        pc++;
        break;
      case 0xF4:
        pc++;
        break;

/* KIL */

      case 0x02:
      case 0x12:
      case 0x22:
      case 0x32:
      case 0x42:
      case 0x52:
      case 0x62:
      case 0x72:
      case 0x92:
      case 0xB2:
      case 0xD2:
      case 0xF2:
        addcyc(0xFF);
        jammed = 1;
        pc--;
        break;

/* LAR */
      case 0xBB:
        rmwABY((x) {
          this.sp &= x;
          this.a = this.x = this.sp;
          zn(this.x);
        });
        break;

/* LAX */
      case 0xA7:
        ldZP((x) {
          lda(x);
          ldx(x);
        });
        break;
      case 0xB7:
        ldZPY((x) {
          lda(x);
          ldx(x);
        });
        break;
      case 0xAF:
        ldAB((x) {
          lda(x);
          ldx(x);
        });
        break;
      case 0xBF:
        ldABY((x) {
          lda(x);
          ldx(x);
        });
        break;
      case 0xA3:
        ldIX((x) {
          lda(x);
          ldx(x);
        });
        break;
      case 0xB3:
        ldIY((x) {
          lda(x);
          ldx(x);
        });
        break;

/* NOP */
      case 0x1A:
      case 0x3A:
      case 0x5A:
      case 0x7A:
      case 0xDA:
      case 0xFA:
        break;

/* RLA */
      case 0x27:
        rmwZP((x) {
          x = rol(x);
          and(x);
        });
        break;
      case 0x37:
        rmwZPX((x) {
          x = rol(x);
          and(x);
        });
        break;
      case 0x2F:
        rmwAB((x) {
          x = rol(x);
          and(x);
        });
        break;
      case 0x3F:
        rmwABX((x) {
          x = rol(x);
          and(x);
        });
        break;
      case 0x3B:
        rmwABY((x) {
          x = rol(x);
          and(x);
        });
        break;
      case 0x23:
        rmwIX((x) {
          x = rol(x);
          and(x);
        });
        break;
      case 0x33:
        rmwIY((x) {
          x = rol(x);
          and(x);
        });
        break;

/* RRA */
      case 0x67:
        rmwZP((x) {
          x = ror(x);
          adc(x);
        });
        break;
      case 0x77:
        rmwZPX((x) {
          x = ror(x);
          adc(x);
        });
        break;
      case 0x6F:
        rmwAB((x) {
          x = ror(x);
          adc(x);
        });
        break;
      case 0x7F:
        rmwABX((x) {
          x = ror(x);
          adc(x);
        });
        break;
      case 0x7B:
        rmwABY((x) {
          x = ror(x);
          adc(x);
        });
        break;
      case 0x63:
        rmwIX((x) {
          x = ror(x);
          adc(x);
        });
        break;
      case 0x73:
        rmwIY((x) {
          x = ror(x);
          adc(x);
        });
        break;

/* SLO */
      case 0x07:
        rmwZP((x) {
          x = asl(x);
          ora(x);
        });
        break;
      case 0x17:
        rmwZPX((x) {
          x = asl(x);
          ora(x);
        });
        break;
      case 0x0F:
        rmwAB((x) {
          x = asl(x);
          ora(x);
        });
        break;
      case 0x1F:
        rmwABX((x) {
          x = asl(x);
          ora(x);
        });
        break;
      case 0x1B:
        rmwABY((x) {
          x = asl(x);
          ora(x);
        });
        break;
      case 0x03:
        rmwIX((x) {
          x = asl(x);
          ora(x);
        });
        break;
      case 0x13:
        rmwIY((x) {
          x = asl(x);
          ora(x);
        });
        break;

/* SRE */
      case 0x47:
        rmwZP((x) {
          x = lsr(x);
          eor(x);
        });
        break;
      case 0x57:
        rmwZPX((x) {
          x = lsr(x);
          eor(x);
        });
        break;
      case 0x4F:
        rmwAB((x) {
          x = lsr(x);
          eor(x);
        });
        break;
      case 0x5F:
        rmwABX((x) {
          x = lsr(x);
          eor(x);
        });
        break;
      case 0x5B:
        rmwABY((x) {
          x = lsr(x);
          eor(x);
        });
        break;
      case 0x43:
        rmwIX((x) {
          x = lsr(x);
          eor(x);
        });
        break;
      case 0x53:
        rmwIY((x) {
          x = lsr(x);
          eor(x);
        });
        break;

/* AXA - SHA */
      case 0x93:
        stIY((a) {
          return this.a & this.x & (((a - this.y) >> 8) + 1);
        });
        break;
      case 0x9F:
        stABY((a) {
          return this.a & this.x & (((a - this.y) >> 8) + 1);
        });
        break;

/* SYA */
      case 0x9C: /* Can't reuse existing stABI macro here, due to addressing weirdness. */
        {
          var x = getABIWR(this.x);
          x = ((this.y & ((x >> 8) + 1)) << 8) | (x & 0xff);
          wrmem(x, x >> 8);
          break;
        }

/* SXA */
      case 0x9E: /* Can't reuse existing stABI macro here, due to addressing weirdness. */
        {
          var x = getABIWR(this.y);
          x = ((this.x & ((x >> 8) + 1)) << 8) | (x & 0xff);
          wrmem(x, x >> 8);
          break;
        }

/* XAS */
      case 0x9B:
        this.sp = this.a & this.x;
        stABY((a) {
          return this.sp & (((a - this.y) >> 8) + 1);
        });
        break;

/* TOP */
      case 0x0C:
        ldAB((x) {});
        break;
      case 0x1C:
      case 0x3C:
      case 0x5C:
      case 0x7C:
      case 0xDC:
      case 0xFC:
        ldABX((x) {});
        break;

/* XAA - BIG QUESTION MARK HERE */
      case 0x8B:
        this.a |= 0xEE;
        this.a &= this.x;
        ldIM(and);
//endif

        break;
    }
  }
}
