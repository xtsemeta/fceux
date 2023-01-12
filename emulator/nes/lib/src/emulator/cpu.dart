import 'ppu.dart';

import 'address_mode.dart';
import 'apu.dart';
import 'controller.dart';
import 'interrupt.dart';
import 'mapper.dart';

class CPU {
  Mapper mapper;
  PPU ppu;
  APU apu;
  Controller controller1;
  Controller controller2;
  List<int> ram = List.filled(2048, 0);
  CPUStepCallback? stepCallback;
  int stepAddress = 0;
  int stepPC = 0;
  int stepMode = 0;
  double cycles = 0.0; // number of cycles
  int PC = 0; // (Byte) Program counter
  int SP = 0xFF; // (Byte) Stack pointer
  int A = 0; // (Byte) Accumulator
  int X = 0; // (Byte) Register X
  int Y = 0; // (Byte) Register Y
  int C = 0; // (Byte) carry flag
  int Z = 0; // (Byte) zero flag
  int I = 0; // (Byte) interrupt disable flag
  int D = 0; // (Byte) decimal mode flag
  int B = 0; // (Byte) break command flag
  int U = 0; // (Byte) unused flag
  int V = 0; // (Byte) overflow flag
  int N = 0; // (Byte) negative flag
  int stall = 0; // number of cycles to stall
  var addressingModes = [
    AddressingMode.unused,
    AddressingMode.modeAbsolute,
    AddressingMode.modeAbsoluteX,
    AddressingMode.modeAbsoluteY,
    AddressingMode.modeAccumulator,
    AddressingMode.modeImmediate,
    AddressingMode.modeImplied,
    AddressingMode.modeIndexedIndirect,
    AddressingMode.modeIndirect,
    AddressingMode.modeIndirectIndexed,
    AddressingMode.modeRelative,
    AddressingMode.modeZeroPage,
    AddressingMode.modeZeroPageX,
    AddressingMode.modeZeroPageY,
  ];
  int interrupt = Interrupt.notSet;

  CPU(this.mapper, this.ppu, this.apu, this.controller1, this.controller2,
      this.ram,
      {this.stepCallback});

  int read16(int address) {
    return (read(address + 1) << 8) | read(address);
  }

  // read16bug emulates a 6502 bug that caused the low byte to wrap without
  // incrementing the high byte
  int read16bug(int address) {
    var b = (address & 0xFF00) | (address + 1);
    var lo = read(address);
    var hi = read(b);
    return (hi << 8) | lo;
  }

  /** returns Byte */
  int read(int address) {
    if (address < 2000) {
      return ram[address % 0x0800];
    }
    if (address < 0x4000) {
      return ppu.readRegister(0x2000 + address % 8);
    }
    if (address == 0x4014) {
      return ppu.readRegister(address);
    }
    if (address == 0x4015) {
      return apu.readRegister(address);
    }
    if (address == 0x4016) {
      return controller1.read();
    }
    if (address == 0x4017) {
      return controller2.read();
    }
    //address < 0x6000:TODO: I/O registers
    if (address >= 0x6000) {
      return mapper.read(address);
    }
    throw Exception("unhandled cpu memory read at address: $address");
  }

  void write(int address, int value /* Byte */) {
    if (address < 0x2000) {
      ram[address % 0x0800] = value;
    } else if (address < 0x4000) {
      ppu.writeRegister(0x2000 + address % 8, value);
    } else if (address < 0x4014) {
      apu.writeRegister(address, value);
    } else if (address == 0x4014) {
      ppu.writeRegister(address, value);
    } else if (address == 0x4015) {
      apu.writeRegister(address, value);
    } else if (address == 0x4016) {
      controller1.write(value);
      controller2.write(value);
    } else if (address == 0x4017) {
      apu.writeRegister(address, value);
    }
    //address < 0x6000 ->
    // TODO: I/O registers
    else if (address >= 0x6000) {
      mapper.write(address, value);
    } else {
      throw Exception("unhandled cpu memory write at address: $address");
    }
  }

  double step() {
//    stepCallback?.onStep(
//        cycles, PC, SP, A, X, Y, C, Z, I, D, B, U, V, N, interrupt, stall, null)
    if (stall > 0) {
      stall--;
      return 1.0;
    }
    var currCycles = cycles;
    // execute interrupt
    if (interrupt == Interrupt.nmi) {
      // nmi
      push16(PC);
      stepAddress = 0;
      stepPC = 0;
      stepMode = 0;
      php(stepAddress, stepPC, stepMode);
      PC = read16(0xfffa);
      I = 1;
      cycles += 7;
    } else if (interrupt == Interrupt.irq) {
      // irq
      push16(PC);
      stepAddress = 0;
      stepPC = 0;
      stepMode = 0;
      php(stepAddress, stepPC, stepMode);
      PC = read16(0xfffe);
      I = 1;
      cycles += 7;
    }
    interrupt = Interrupt.none;
    var opcode = read(PC);
    var mode = instructionModes[opcode];
    var addressingMode = addressingModes[mode];
    var address = 0;
    switch (addressingMode) {
      case AddressingMode.modeAbsolute:
        address = read16(PC + 1);
        break;
      case AddressingMode.modeAbsoluteX:
        address = read16(PC + 1) + X;
        break;
      case AddressingMode.modeAbsoluteY:
        address = read16(PC + 1) + Y;
        break;
      case AddressingMode.modeAccumulator:
        address = 0;
        break;
      case AddressingMode.modeImmediate:
        address = PC + 1;
        break;
      case AddressingMode.modeImplied:
        address = 0;
        break;
      case AddressingMode.modeIndexedIndirect:
        address = read16bug(read(PC + 1) + X);
        break;
      case AddressingMode.modeIndirect:
        address = read16bug(read16(PC + 1));
        break;
      case AddressingMode.modeIndirectIndexed:
        address = read16bug(read(PC + 1)) + Y;
        break;
      case AddressingMode.modeRelative:
        {
          var offset = read(PC + 1);
          address = (offset < 0x80) ? PC + 2 + offset : PC + 2 + offset - 0x100;
          break;
        }
      case AddressingMode.modeZeroPage:
        address = read(PC + 1);
        break;
      case AddressingMode.modeZeroPageX:
        address = (read(PC + 1) + X) & 0xff;
        break;
      case AddressingMode.modeZeroPageY:
        address = (read(PC + 1) + Y) & 0xff;
        break;
      default:
        throw Exception("Invarid addressing mode $addressingMode");
    }
    var pageCrossed = false;
    switch (addressingMode) {
      case AddressingMode.modeAbsolute:
        pageCrossed = false;
        break;
      case AddressingMode.modeAbsoluteX:
        pageCrossed = pagesDiffer(address - X, address);
        break;
      case AddressingMode.modeAbsoluteY:
        pageCrossed = pagesDiffer(address - Y, address);
        break;
      case AddressingMode.modeAccumulator:
      case AddressingMode.modeImmediate:
      case AddressingMode.modeImplied:
      case AddressingMode.modeIndexedIndirect:
      case AddressingMode.modeIndirect:
        pageCrossed = false;
        break;
      case AddressingMode.modeIndirectIndexed:
        address = read16bug(read(PC + 1)) + Y;
        break;
      case AddressingMode.modeRelative:
      case AddressingMode.modeZeroPage:
      case AddressingMode.modeZeroPageX:
      case AddressingMode.modeZeroPageY:
        pageCrossed = false;
        break;
      default:
        throw Exception("Invarid addressing mode $addressingMode");
    }
    PC += instructionSizes[opcode];
    cycles += instructionCycles[opcode];
    if (pageCrossed) {
      cycles += instructionPageCycles[opcode];
    }
    stepAddress = address;
    stepPC = PC;
    stepMode = mode;
    switch (opcode) {
      case 0:
        {
          // brk
          push16(PC);
          php(stepAddress, stepPC, stepMode);
          sei(stepAddress, stepPC, stepMode);
          PC = read16(0xFFFE);
          break;
        }
      case 1:
      case 5:
      case 9:
      case 13:
      case 17:
      case 21:
      case 25:
      case 29:
        {
          // ora
          A = A | (read(stepAddress) & 0xFF);
          setZN(A);
        }
        break;
      case 2:
      case 18:
      case 34:
      case 50:
      case 66:
      case 82:
      case 98:
      case 114:
      case 146:
      case 178:
      case 210:
      case 242:
        {
          // kil
        }
        break;
      case 3:
      case 7:
      case 15:
      case 19:
      case 23:
      case 27:
      case 31:
        {
          // slo
        }
        break;
      case 4:
      case 12:
      case 20:
      case 26:
      case 28:
      case 52:
      case 58:
      case 60:
      case 68:
      case 84:
      case 90:
      case 92:
      case 100:
      case 116:
      case 122:
      case 124:
      case 128:
      case 130:
      case 137:
      case 194:
      case 212:
      case 218:
      case 220:
      case 226:
      case 234:
      case 244:
      case 250:
      case 252:
        {
          // nop
        }
        break;
      case 6:
      case 10:
      case 14:
      case 22:
      case 30:
        {
          // asl
          if (stepMode == AddressingMode.modeAccumulator.index) {
            C = (A >> 7) & 1;
            A = A << 1 & 0xFF;
            setZN(A);
          } else {
            var varue = read(stepAddress);
            C = (varue >> 7) & 1;
            varue = varue << 1 & 0xFF;
            write(stepAddress, varue);
            setZN(varue);
          }
        }
        break;
      case 8:
        php(stepAddress, stepPC, stepMode);
        break;
      case 11:
      case 43:
        {
          // anc
        }
        break;
      case 16:
        {
          // bpl
          if (N == 0) {
            PC = stepAddress;
            addBranchCycles(stepAddress, stepPC, stepMode);
          }
        }
        break;
      case 24:
        {
          // clc
          C = 0;
        }
        break;
      case 32:
        {
          // jsr
          push16(PC - 1);
          PC = stepAddress;
        }
        break;
      case 33:
      case 37:
      case 41:
      case 45:
      case 49:
      case 53:
      case 57:
      case 61:
        {
          // and
          A = A & read(stepAddress);
          setZN(A);
        }
        break;
      case 35:
      case 39:
      case 47:
      case 51:
      case 55:
      case 59:
      case 63:
        {
          // rla
        }
        break;
      case 36:
      case 44:
        {
          // bit
          var varue = read(stepAddress);
          V = (varue >> 6) & 1;
          setZFlag(varue & A);
          setNFlag(varue);
        }
        break;
      case 38:
      case 42:
      case 46:
      case 54:
      case 62:
        {
          // rol
          if (stepMode == AddressingMode.modeAccumulator) {
            var c = C;
            C = (A >> 7) & 1;
            A = (A << 1) | c & 0xFF;
            setZN(A);
          } else {
            var c = C;
            var varue = read(stepAddress);
            C = (varue >> 7) & 1;
            varue = (varue << 1) | c & 0xFF;
            write(stepAddress, varue);
            setZN(varue & 0xFF);
          }
        }
        break;
      case 40:
        {
          // plp
          setFlags(pull() & 0xEF | 0x20);
        }
        break;
      case 48:
        {
          // bmi
          if (N != 0) {
            PC = stepAddress;
            addBranchCycles(stepAddress, stepPC, stepMode);
          }
        }
        break;
      case 56:
        {
          // sec
          C = 1;
        }
        break;
      case 64:
        {
          // rti
          setFlags(pull() & 0xEF | 0x20);
          PC = pull16();
        }
        break;
      case 65:
      case 69:
      case 73:
      case 77:
      case 81:
      case 85:
      case 89:
      case 93:
        {
          // eor
          A = A ^ read(stepAddress);
          setZN(A);
        }
        break;
      case 67:
      case 71:
      case 79:
      case 83:
      case 87:
      case 91:
      case 95:
        {
          // sre
        }
        break;
      case 70:
      case 74:
      case 78:
      case 86:
      case 94:
        {
          // lsr
          if (stepMode == AddressingMode.modeAccumulator) {
            C = A & 1;
            A = A >> 1;
            setZN(A);
          } else {
            var varue = read(stepAddress);
            C = varue & 1;
            varue = varue >> 1;
            write(stepAddress, varue);
            setZN(varue);
          }
        }
        break;
      case 72:
        {
          // pha
          push(A);
        }
        break;
      case 75:
        {
          // alr
        }
        break;
      case 76:
      case 108:
        {
          // jmp
          PC = stepAddress;
        }
        break;
      case 80:
        {
          // bvc
          if (V == 0) {
            PC = stepAddress;
            addBranchCycles(stepAddress, stepPC, stepMode);
          }
        }
        break;
      case 88:
        {
          // cli
          I = 0;
        }
        break;
      case 96:
        {
          // rts
          PC = pull16() + 1;
        }
        break;
      case 97:
      case 101:
      case 105:
      case 109:
      case 113:
      case 117:
      case 121:
      case 125:
        {
          // adc
          var a = A;
          var b = read(stepAddress);
          var c = C;
          A = (a + b + c) & 0xFF;
          setZN(A);
          C = (a + b + c > 0xFF) ? 1 : 0;
          V = ((a ^ b) & 0x80 == 0 && (a ^ A) & 0x80 != 0) ? 1 : 0;
        }
        break;
      case 99:
      case 103:
      case 111:
      case 115:
      case 119:
      case 123:
      case 127:
        {
          // rra
        }
        break;
      case 102:
      case 106:
      case 110:
      case 118:
      case 126:
        {
          // ror
          if (stepMode == AddressingMode.modeAccumulator) {
            var c = C;
            C = A & 1;
            A = (A >> 1) | (c << 7) & 0xFF;
            setZN(A);
          } else {
            var c = C;
            var varue = read(stepAddress);
            C = varue & 1;
            varue = (varue >> 1) | (c << 7);
            write(stepAddress, varue);
            setZN(varue);
          }
        }
        break;
      case 104:
        {
          // pla
          A = pull();
          setZN(A);
        }
        break;
      case 107:
        {
          // arr
        }
        break;
      case 112:
        {
          // bvs
          if (V != 0) {
            PC = stepAddress;
            addBranchCycles(stepAddress, stepPC, stepMode);
          }
        }
        break;
      case 120:
        {
          sei(stepAddress, stepPC, stepMode);
        }
        break;
      case 129:
      case 133:
      case 141:
      case 145:
      case 149:
      case 153:
      case 157:
        {
          // sta
          write(stepAddress, A);
        }
        break;
      case 131:
      case 135:
      case 143:
      case 151:
        {
          // sax
        }
        break;
      case 132:
      case 140:
      case 148:
        {
          // sty
          write(stepAddress, Y);
        }
        break;
      case 134:
      case 142:
      case 150:
        {
          // stx
          write(stepAddress, X);
        }
        break;
      case 136:
        {
          // dey
          Y = (Y - 1) & 0xFF;
          setZN(Y);
        }
        break;
      case 138:
        {
          // txa
          A = X;
          setZN(A);
        }
        break;
      case 139:
        {
          // xaa
        }
        break;
      case 144:
        {
          // bcc
          if (C == 0) {
            PC = stepAddress;
            addBranchCycles(stepAddress, stepPC, stepMode);
          }
        }
        break;
      case 147:
      case 159:
        {
          // ahx
        }
        break;
      case 152:
        {
          // tya
          A = Y;
          setZN(A);
        }
        break;
      case 154:
        {
          // txs
          SP = X;
        }
        break;
      case 155:
        {
          // tas
        }
        break;
      case 156:
        {
          // shy
        }
        break;
      case 158:
        {
          // shx
        }
        break;
      case 160:
      case 164:
      case 172:
      case 180:
      case 188:
        {
          // ldy
          Y = read(stepAddress) & 0xFF;
          setZN(Y);
        }
        break;
      case 161:
      case 165:
      case 169:
      case 173:
      case 177:
      case 181:
      case 185:
      case 189:
        {
          // lda
          A = read(stepAddress) & 0xFF;
          setZN(A);
        }
        break;
      case 162:
      case 166:
      case 174:
      case 182:
      case 190:
        {
          // ldx
          X = read(stepAddress) & 0xFF;
          setZN(X);
        }
        break;
      case 163:
      case 167:
      case 171:
      case 175:
      case 179:
      case 183:
      case 191:
        {
          // lax
        }
        break;
      case 168:
        {
          // tay
          Y = A;
          setZN(Y);
        }
        break;
      case 170:
        {
          // tax
          X = A;
          setZN(X);
        }
        break;
      case 176:
        {
          // bcs
          if (C != 0) {
            PC = stepAddress;
            addBranchCycles(stepAddress, stepPC, stepMode);
          }
        }
        break;
      case 184:
        {
          // clv
          V = 0;
        }
        break;
      case 186:
        {
          // tsx
          X = SP;
          setZN(X);
        }
        break;
      case 187:
        {
          // las
        }
        break;
      case 192:
      case 196:
      case 204:
        {
          // cpy
          var varue = read(stepAddress) & 0xFF;
          compare(Y, varue);
        }
        break;
      case 193:
      case 197:
      case 201:
      case 205:
      case 209:
      case 213:
      case 217:
      case 221:
        {
          // cmp
          var varue = read(stepAddress) & 0xFF;
          compare(A, varue);
        }
        break;
      case 195:
      case 199:
      case 207:
      case 211:
      case 215:
      case 219:
      case 223:
        {
          // dcp
        }
        break;
      case 198:
      case 206:
      case 214:
      case 222:
        {
          // dec
          var varue = read(stepAddress) - 1 & 0xFF;
          write(stepAddress, varue);
          setZN(varue);
        }
        break;
      case 200:
        {
          // iny
          Y = (Y + 1) & 0xFF;
          setZN(Y);
        }
        break;
      case 202:
        {
          // dex
          X = (X - 1) & 0xFF;
          setZN(X);
        }
        break;
      case 203:
        {
          // axs
        }
        break;
      case 208:
        {
          // bne
          if (Z == 0) {
            PC = stepAddress;
            addBranchCycles(stepAddress, stepPC, stepMode);
          }
        }
        break;
      case 216:
        {
          // cld
          D = 0;
        }
        break;
      case 224:
      case 228:
      case 236:
        {
          // cpx
          compare(X, read(stepAddress) & 0xFF);
        }
        break;
      case 225:
      case 229:
      case 233:
      case 235:
      case 237:
      case 241:
      case 245:
      case 249:
      case 253:
        {
          // sbc
          var a = A;
          var b = read(stepAddress);
          var c = C;
          A = (a - b - ((1 - c) & 0xFF)) & 0xFF;
          setZN(A);
          C = (a - b - ((1 - c) & 0xFF) >= 0) ? 1 : 0;
          V = ((a ^ b) & 0x80 != 0 && (a ^ A) & 0x80 != 0) ? 1 : 0;
        }
        break;
      case 227:
      case 231:
      case 239:
      case 243:
      case 247:
      case 251:
      case 255:
        {
          // isc
        }
        break;
      case 230:
      case 238:
      case 246:
      case 254:
        {
          // inc
          var varue = (read(stepAddress) + 1) & 0xFF;
          write(stepAddress, varue);
          setZN(varue);
        }
        break;
      case 232:
        {
          // inx
          X = (X + 1) & 0xFF;
          setZN(X);
        }
        break;
      case 240:
        {
          // beq
          if (Z != 0) {
            PC = stepAddress;
            addBranchCycles(stepAddress, stepPC, stepMode);
          }
        }
        break;
      case 248:
        {
          // sed
          D = 1;
        }
        break;
    }
    return cycles - currCycles;
  }

  String dumpState() {
    // return StatePersistence.dumpState(
    //     ram, cycles, PC, SP, A, X, Y, C, Z, I, D, B, U, V, N, interrupt, stall
    // ).also { println("CPU state saved") }
    return '';
  }

  restoreState(String serializedState) {
    // var state = StatePersistence.restoreState(serializedState)
    // ram = state.next()
    // cycles = state.next()
    // PC = state.next()
    // SP = state.next()
    // A = state.next()
    // X = state.next()
    // Y = state.next()
    // C = state.next()
    // Z = state.next()
    // I = state.next()
    // D = state.next()
    // B = state.next()
    // U = state.next()
    // V = state.next()
    // N = state.next()
    // interrupt = state.next()
    // stall = state.next()
    // println("CPU state restored")
  }

  bool pagesDiffer(int a, int b) => a & 0xFF00 != b & 0xFF00;

  void stop() {
    // TODO()
  }

  void reset() {
    PC = read16(0xFFFC);
    SP = 0xFD;
    setFlags(0x24);
  }

  // push pushes a byte onto the stack
  void push(int value) {
    write(0x100 | SP, value);
    SP = (SP - 1) & 0xFF;
  }

  // push16 pushes two bytes onto the stack
  void push16(int value) {
    push(value >> 8);
    push(value & 0xFF);
  }

  /** pull pops a byte from the stack. Returns Byte */
  int pull() {
    SP = (SP + 1) & 0xFF;
    return read(0x100 | SP);
  }

  int pull16() {
    var lo = pull();
    var hi = pull();
    return (hi << 8) | lo;
  }

  void addBranchCycles(int stepAddress, int stepPC, int stepMode) {
    cycles++;
    if (pagesDiffer(stepPC, stepAddress)) {
      cycles++;
    }
  }

  int flags() {
    var flags = 0;
    flags = flags | (C << 0);
    flags = flags | (Z << 1);
    flags = flags | (I << 2);
    flags = flags | (D << 3);
    flags = flags | (B << 4);
    flags = flags | (U << 5);
    flags = flags | (V << 6);
    flags = flags | (N << 7);
    return flags;
  }

  void setZN(int value) {
    setZFlag(value);
    setNFlag(value);
  }

  void setZFlag(int value) {
    Z = (value == 0) ? 1 : 0;
  }

  // setN sets the negative flag if the argument is negative (high bit is set)
  void setNFlag(int value) {
    N = (value & 0x80 != 0) ? 1 : 0;
  }

  void compare(int a, int b) {
    setZN(a - b);
    C = (a >= b) ? 1 : 0;
  }

  void setFlags(int flags) {
    C = (flags >> 0) & 1;
    Z = (flags >> 1) & 1;
    I = (flags >> 2) & 1;
    D = (flags >> 3) & 1;
    B = (flags >> 4) & 1;
    U = (flags >> 5) & 1;
    V = (flags >> 6) & 1;
    N = (flags >> 7) & 1;
  }

  // PHP - Push Processor Status
  void php(int stepAddress, int stepPC, int stepMode) {
    push(flags() | 0x10);
  }

  // SEI - Set Interrupt Disable
  void sei(int stepAddress, int stepPC, int stepMode) {
    I = 1;
  }

  /// 1.789773 MHz
  static const int frequencyHZ = 1789773; // 1.789773 MHz;
  /**
        6, 7, 6, 7, 11, 11, 11, 11, 6, 5, 4, 5, 1, 1, 1, 1,
        10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
        1, 7, 6, 7, 11, 11, 11, 11, 6, 5, 4, 5, 1, 1, 1, 1,
        10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
        6, 7, 6, 7, 11, 11, 11, 11, 6, 5, 4, 5, 1, 1, 1, 1,
        10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
        6, 7, 6, 7, 11, 11, 11, 11, 6, 5, 4, 5, 8, 1, 1, 1,
        10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
        5, 7, 5, 7, 11, 11, 11, 11, 6, 5, 6, 5, 1, 1, 1, 1,
        10, 9, 6, 9, 12, 12, 13, 13, 6, 3, 6, 3, 2, 2, 3, 3,
        5, 7, 5, 7, 11, 11, 11, 11, 6, 5, 6, 5, 1, 1, 1, 1,
        10, 9, 6, 9, 12, 12, 13, 13, 6, 3, 6, 3, 2, 2, 3, 3,
        5, 7, 5, 7, 11, 11, 11, 11, 6, 5, 6, 5, 1, 1, 1, 1,
        10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
        5, 7, 5, 7, 11, 11, 11, 11, 6, 5, 6, 5, 1, 1, 1, 1,
        10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2 */
  var instructionModes = [
    6,
    7,
    6,
    7,
    11,
    11,
    11,
    11,
    6,
    5,
    4,
    5,
    1,
    1,
    1,
    1,
    10,
    9,
    6,
    9,
    12,
    12,
    12,
    12,
    6,
    3,
    6,
    3,
    2,
    2,
    2,
    2,
    1,
    7,
    6,
    7,
    11,
    11,
    11,
    11,
    6,
    5,
    4,
    5,
    1,
    1,
    1,
    1,
    10,
    9,
    6,
    9,
    12,
    12,
    12,
    12,
    6,
    3,
    6,
    3,
    2,
    2,
    2,
    2,
    6,
    7,
    6,
    7,
    11,
    11,
    11,
    11,
    6,
    5,
    4,
    5,
    1,
    1,
    1,
    1,
    10,
    9,
    6,
    9,
    12,
    12,
    12,
    12,
    6,
    3,
    6,
    3,
    2,
    2,
    2,
    2,
    6,
    7,
    6,
    7,
    11,
    11,
    11,
    11,
    6,
    5,
    4,
    5,
    8,
    1,
    1,
    1,
    10,
    9,
    6,
    9,
    12,
    12,
    12,
    12,
    6,
    3,
    6,
    3,
    2,
    2,
    2,
    2,
    5,
    7,
    5,
    7,
    11,
    11,
    11,
    11,
    6,
    5,
    6,
    5,
    1,
    1,
    1,
    1,
    10,
    9,
    6,
    9,
    12,
    12,
    13,
    13,
    6,
    3,
    6,
    3,
    2,
    2,
    3,
    3,
    5,
    7,
    5,
    7,
    11,
    11,
    11,
    11,
    6,
    5,
    6,
    5,
    1,
    1,
    1,
    1,
    10,
    9,
    6,
    9,
    12,
    12,
    13,
    13,
    6,
    3,
    6,
    3,
    2,
    2,
    3,
    3,
    5,
    7,
    5,
    7,
    11,
    11,
    11,
    11,
    6,
    5,
    6,
    5,
    1,
    1,
    1,
    1,
    10,
    9,
    6,
    9,
    12,
    12,
    12,
    12,
    6,
    3,
    6,
    3,
    2,
    2,
    2,
    2,
    5,
    7,
    5,
    7,
    11,
    11,
    11,
    11,
    6,
    5,
    6,
    5,
    1,
    1,
    1,
    1,
    10,
    9,
    6,
    9,
    12,
    12,
    12,
    12,
    6,
    3,
    6,
    3,
    2,
    2,
    2,
    2
  ];
  /**
        1, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
        3, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
        1, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
        1, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 0, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 0, 3, 0, 0,
        2, 2, 2, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
        2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0 */
  var instructionSizes = [
    1,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    2,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    3,
    1,
    0,
    3,
    3,
    3,
    0,
    3,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    2,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    3,
    1,
    0,
    3,
    3,
    3,
    0,
    1,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    2,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    3,
    1,
    0,
    3,
    3,
    3,
    0,
    1,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    2,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    3,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    0,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    3,
    1,
    0,
    0,
    3,
    0,
    0,
    2,
    2,
    2,
    0,
    2,
    2,
    2,
    0,
    1,
    2,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    3,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    2,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    3,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    2,
    1,
    0,
    3,
    3,
    3,
    0,
    2,
    2,
    0,
    0,
    2,
    2,
    2,
    0,
    1,
    3,
    1,
    0,
    3,
    3,
    3,
    0
  ];
  /**
        7, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        6, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 3, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
        2, 6, 2, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5,
        2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
        2, 5, 2, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4,
        2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7 */
  var instructionCycles = [
    7,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    3,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    4,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    3,
    2,
    2,
    2,
    3,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    4,
    2,
    2,
    2,
    5,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    2,
    6,
    2,
    6,
    3,
    3,
    3,
    3,
    2,
    2,
    2,
    2,
    4,
    4,
    4,
    4,
    2,
    6,
    2,
    6,
    4,
    4,
    4,
    4,
    2,
    5,
    2,
    5,
    5,
    5,
    5,
    5,
    2,
    6,
    2,
    6,
    3,
    3,
    3,
    3,
    2,
    2,
    2,
    2,
    4,
    4,
    4,
    4,
    2,
    5,
    2,
    5,
    4,
    4,
    4,
    4,
    2,
    4,
    2,
    4,
    4,
    4,
    4,
    4,
    2,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    2,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    2,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    2,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7
  ];
  /**
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0 */
  var instructionPageCycles = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    1,
    1,
    1,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
    0,
    0
  ];
}

abstract class CPUStepCallback {
  void onStep(
    int cycles,
    int pc,
    int sp,
    int a,
    int x,
    int y,
    int c,
    int z,
    int i,
    int d,
    int b,
    int u,
    int v,
    int n,
    int interrupt,
    int stall,
    String? lastOpcode,
  );
}
