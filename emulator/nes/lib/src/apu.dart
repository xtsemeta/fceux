import 'audio_buffer.dart';
import 'cpu.dart';
import 'filter.dart';
import 'interrupt.dart';

class APU with _APUConst {
  APUStepCallback? stepCallback;
  AudioBuffer audioBuffer = AudioBuffer();
  // Convert samples per second to cpu steps per sample
  late double sampleRate = CPU.frequencyHZ / _APUConst.sampleRate;
  double cycle = 0.0;
  int framePeriod = 0; // Byte
  int frameValue = 0; // Byte
  bool frameIRQ = false;
  List<double> pulseTable = List.filled(31, 0.0);
  List<double> tndTable = List.filled(203, 0.0);
  late FilterChain filterChain = FilterChain([
    highPassFilter(sampleRate, 90.0),
    highPassFilter(sampleRate, 440.0),
    lowPassFilter(sampleRate, 14000.0)
  ]);

  APU({this.stepCallback}) {
    for (var i = 0; i < 31; i++) {
      pulseTable[i] = 95.52 / (8128 / i + 100);
    }
    for (var i = 0; i < 203; i++) {
      tndTable[i] = 163.67 / (24329 / i + 100);
    }
  }

  bool pulse1Enabled = false;
  int pulse1Channel = 1; // Byte
  bool pulse1LengthEnabled = false;
  int pulse1LengthValue = 0; // Byte
  int pulse1TimerPeriod = 0;
  int pulse1TimerValue = 0;
  int pulse1DutyMode = 0; // Byte
  int pulse1DutyValue = 0; // Byte
  bool pulse1SweepReload = false;
  bool pulse1SweepEnabled = false;
  bool pulse1SweepNegate = false;
  int pulse1SweepShift = 0; // Byte
  int pulse1SweepPeriod = 0; // Byte
  int pulse1SweepValue = 0; // Byte
  bool pulse1EnvelopeEnabled = false;
  bool pulse1EnvelopeLoop = false;
  bool pulse1EnvelopeStart = false;
  int pulse1EnvelopePeriod = 0; // Byte
  int pulse1EnvelopeValue = 0; // Byte
  int pulse1EnvelopeVolume = 0; // Byte
  int pulse1ConstantVolume = 0; // Byte

  bool pulse2Enabled = false;
  int pulse2Channel = 2; // Byte
  bool pulse2LengthEnabled = false;
  int pulse2LengthValue = 0; // Byte
  int pulse2TimerPeriod = 0;
  int pulse2TimerValue = 0;
  int pulse2DutyMode = 0; // Byte
  int pulse2DutyValue = 0; // Byte
  bool pulse2SweepReload = false;
  bool pulse2SweepEnabled = false;
  bool pulse2SweepNegate = false;
  int pulse2SweepShift = 0; // Byte
  int pulse2SweepPeriod = 0; // Byte
  int pulse2SweepValue = 0; // Byte
  bool pulse2EnvelopeEnabled = false;
  bool pulse2EnvelopeLoop = false;
  bool pulse2EnvelopeStart = false;
  int pulse2EnvelopePeriod = 0; // Byte
  int pulse2EnvelopeValue = 0; // Byte
  int pulse2EnvelopeVolume = 0; // Byte
  int pulse2ConstantVolume = 0; // Byte

  bool noiseEnabled = false;
  bool noiseMode = false;
  int noiseShiftRegister = 1;
  bool noiseLengthEnabled = false;
  int noiseLengthValue = 0; // Byte
  int noiseTimerPeriod = 0;
  int noiseTimerValue = 0;
  bool noiseEnvelopeEnabled = false;
  bool noiseEnvelopeLoop = false;
  bool noiseEnvelopeStart = false;
  int noiseEnvelopePeriod = 0; // Byte
  int noiseEnvelopeValue = 0; // Byte
  int noiseEnvelopeVolume = 0; // Byte
  int noiseConstantVolume = 0; // Byte

  bool triangleEnabled = false;
  bool triangleLengthEnabled = false;
  int triangleLengthValue = 0; // Byte
  int triangleTimerPeriod = 0;
  int triangleTimerValue = 0;
  int triangleDutyValue = 0; // Byte
  int triangleCounterPeriod = 0; // Byte
  int triangleCounterValue = 0; // Byte
  bool triangleCounterReload = false;

  bool dmcEnabled = false;
  int dmcValue = 0; // Byte
  int dmcSampleAddress = 0;
  int dmcSampleLength = 0;
  int dmcCurrentAddress = 0;
  int dmcCurrentLength = 0;
  int dmcShiftRegister = 0; // Byte
  int dmcBitCount = 0; // Byte
  int dmcTickPeriod = 0; // Byte
  int dmcTickValue = 0; // Byte
  bool dmcLoop = false;
  bool dmcIrq = false;
  late CPU cpu;

  int readRegister(int address) /* Byte */ {
    if (address == 0x4015) {
      // read status
      var result = 0;
      if (pulse1LengthValue > 0) result = result | 1;
      if (pulse2LengthValue > 0) result = result | 2;
      if (triangleLengthValue > 0) result = result | 4;
      if (noiseLengthValue > 0) result = result | 8;
      if (dmcCurrentLength > 0) result = result | 16;
      return result;
    }
    return 0;
  }

  void step() {
    var cycle1 = cycle;
    cycle++;
    var cycle2 = cycle;
    // step timer
    // JS workaround: Use Double modulo for a faster implementation
    if (cycle % 2.0 == 0.0) {
      // pulse 1 step timer
      if (pulse1TimerValue == 0) {
        pulse1TimerValue = pulse1TimerPeriod;
        pulse1DutyValue = (pulse1DutyValue + 1) % 8;
      } else {
        pulse1TimerValue--;
      }
      // pulse 2 step timer
      if (pulse2TimerValue == 0) {
        pulse2TimerValue = pulse2TimerPeriod;
        pulse2DutyValue = (pulse2DutyValue + 1) % 8;
      } else {
        pulse2TimerValue--;
      }
      // noise step timer
      if (noiseTimerValue == 0) {
        noiseTimerValue = noiseTimerPeriod;
        var shift = (noiseMode) ? 6 : 1;
        var b1 = noiseShiftRegister & 1;
        var b2 = (noiseShiftRegister >> shift) & 1;
        noiseShiftRegister = noiseShiftRegister >> 1;
        noiseShiftRegister = noiseShiftRegister | ((b1 ^ b2) << 14);
        noiseShiftRegister;
      } else {
        noiseTimerValue--;
      }
      // dmc step timer
      if (dmcEnabled) {
        // dmc step reader
        if (dmcCurrentLength > 0 && dmcBitCount == 0) {
          cpu.stall += 4;
          dmcShiftRegister = cpu.read(dmcCurrentAddress);
          dmcBitCount = 8;
          dmcCurrentAddress++;
          if (dmcCurrentAddress == 0) dmcCurrentAddress = 0x8000;
          dmcCurrentLength--;
          if (dmcCurrentLength == 0 && dmcLoop) {
            dmcCurrentAddress = dmcSampleAddress;
            dmcCurrentLength = dmcSampleLength;
          }
        }
        if (dmcTickValue == 0) {
          dmcTickValue = dmcTickPeriod;
          // dmc step shifter
          if (dmcBitCount != 0) {
            if (dmcShiftRegister & 1 == 1) {
              if (dmcValue <= 125) dmcValue += 2;
            } else {
              if (dmcValue >= 2) dmcValue -= 2;
            }
            dmcShiftRegister = (dmcShiftRegister >> 1) & 0xFF;
            dmcBitCount -= 1;
          }
        } else {
          dmcTickValue -= 1;
        }
      }
    }
    // triangle step timer
    if (triangleTimerValue == 0) {
      triangleTimerValue = triangleTimerPeriod;
      if (triangleLengthValue > 0 && triangleCounterValue > 0) {
        triangleDutyValue = (triangleDutyValue + 1) % 32;
      }
    } else {
      triangleTimerValue--;
    }
    if (cycle1 ~/ frameCounterRate != cycle2 ~/ frameCounterRate) {
      // step frame counter
      switch (framePeriod) {
        case 4:
          {
            frameValue = (frameValue + 1) % 4;
            switch (frameValue) {
              case 0:
              case 2:
                stepEnvelope();
                break;
              case 1:
                {
                  stepEnvelope();
                  stepSweep();
                  stepLength();
                }
                break;
              case 3:
                {
                  stepEnvelope();
                  stepSweep();
                  stepLength();
                  // fire irq
                  if (frameIRQ) cpu.interrupt = Interrupt.irq;
                }
                break;
            }
          }
          break;
        case 5:
          {
            frameValue = (frameValue + 1) % 5;
            switch (frameValue) {
              case 1:
              case 3:
                stepEnvelope();
                break;
              case 0:
              case 2:
                {
                  stepEnvelope();
                  stepSweep();
                  stepLength();
                }
                break;
            }
          }
          break;
      }
    }
    var output = 0.0;
    if (cycle1 ~/ sampleRate != cycle2 ~/ sampleRate) {
      // send sample
      var pulse1Output = 0;
      if (!pulse1Enabled ||
          pulse1LengthValue == 0 ||
          dutyTable[pulse1DutyMode][pulse1DutyValue] == 0 ||
          pulse1TimerPeriod < 8 ||
          pulse1TimerPeriod > 0x7FF) {
        pulse1Output = 0;
      } else {
        if (pulse1EnvelopeEnabled) {
          pulse1Output = pulse1EnvelopeVolume;
        } else {
          pulse1Output = pulse1ConstantVolume;
        }
      }
      var pulse2Output = 0;
      if (!pulse2Enabled ||
          pulse2LengthValue == 0 ||
          dutyTable[pulse2DutyMode][pulse2DutyValue] == 0 ||
          pulse2TimerPeriod < 8 ||
          pulse2TimerPeriod > 0x7FF) {
        pulse2Output = 0;
      } else {
        if (pulse2EnvelopeEnabled) {
          pulse2Output = pulse2EnvelopeVolume;
        } else {
          pulse2Output = pulse2ConstantVolume;
        }
      }
      var triangleOutput = 0;
      if (!triangleEnabled ||
          triangleLengthValue == 0 ||
          triangleCounterValue == 0) {
        triangleOutput = 0;
      } else {
        triangleOutput = triangleTable[triangleDutyValue];
      }
      var noiseOutput = 0;
      if (!noiseEnabled ||
          noiseLengthValue == 0 ||
          noiseShiftRegister & 1 == 1) {
        noiseOutput = 0;
      } else {
        if (noiseEnvelopeEnabled) {
          noiseOutput = noiseEnvelopeVolume;
        } else {
          noiseOutput = noiseConstantVolume;
        }
      }
      var finalOutput = filterChain.step(
          pulseTable[pulse1Output + pulse2Output] +
              tndTable[3 * triangleOutput + 2 * noiseOutput + dmcValue]);
      audioBuffer.write(finalOutput);
      output = finalOutput;
    }
//    stepCallback?.onStep(cycle,
//        framePeriod, frameValue, frameIRQ, pulse1Enabled, pulse1Channel, pulse1LengthEnabled,
//        pulse1LengthValue, pulse1TimerPeriod, pulse1TimerValue, pulse1DutyMode, pulse1DutyValue,
//        pulse1SweepReload, pulse1SweepEnabled, pulse1SweepNegate, pulse1SweepShift,
//        pulse1SweepPeriod, pulse1SweepValue, pulse1EnvelopeEnabled, pulse1EnvelopeLoop,
//        pulse1EnvelopeStart, pulse1EnvelopePeriod, pulse1EnvelopeValue, pulse1EnvelopeVolume,
//        pulse1ConstantVolume, pulse2Enabled, pulse2Channel, pulse2LengthEnabled, pulse2LengthValue,
//        pulse2TimerPeriod, pulse2TimerValue, pulse2DutyMode, pulse2DutyValue, pulse2SweepReload,
//        pulse2SweepEnabled, pulse2SweepNegate, pulse2SweepShift, pulse2SweepPeriod,
//        pulse2SweepValue, pulse2EnvelopeEnabled, pulse2EnvelopeLoop, pulse2EnvelopeStart,
//        pulse2EnvelopePeriod, pulse2EnvelopeValue, pulse2EnvelopeVolume, pulse2ConstantVolume,
//        triangleEnabled, triangleLengthEnabled, triangleLengthValue, triangleTimerPeriod,
//        triangleTimerValue, triangleDutyValue, triangleCounterPeriod, triangleCounterValue,
//        triangleCounterReload, noiseEnabled, noiseMode, noiseShiftRegister, noiseLengthEnabled,
//        noiseLengthValue, noiseTimerPeriod, noiseTimerValue, noiseEnvelopeEnabled,
//        noiseEnvelopeLoop, noiseEnvelopeStart, noiseEnvelopePeriod, noiseEnvelopeValue,
//        noiseEnvelopeVolume, noiseConstantVolume, dmcEnabled, dmcValue, dmcSampleAddress,
//        dmcSampleLength, dmcCurrentAddress, dmcCurrentLength, dmcShiftRegister, dmcBitCount,
//        dmcTickPeriod, dmcTickValue, dmcLoop, dmcIrq, output)
  }

  String dumpState() {
    // return StatePersistence.dumpState(
    //     cycle, framePeriod, frameValue, frameIRQ, pulse1Enabled, pulse1Channel,
    //     pulse1LengthEnabled, pulse1LengthValue, pulse1TimerPeriod, pulse1TimerValue,
    //     pulse1DutyMode, pulse1DutyValue, pulse1SweepReload, pulse1SweepEnabled,
    //     pulse1SweepNegate, pulse1SweepShift, pulse1SweepPeriod, pulse1SweepValue,
    //     pulse1EnvelopeEnabled, pulse1EnvelopeLoop, pulse1EnvelopeStart,
    //     pulse1EnvelopePeriod, pulse1EnvelopeValue, pulse1EnvelopeVolume,
    //     pulse1ConstantVolume, pulse2Enabled, pulse2Channel, pulse2LengthEnabled,
    //     pulse2LengthValue, pulse2TimerPeriod, pulse2TimerValue, pulse2DutyMode,
    //     pulse2DutyValue, pulse2SweepReload, pulse2SweepEnabled, pulse2SweepNegate,
    //     pulse2SweepShift, pulse2SweepPeriod, pulse2SweepValue, pulse2EnvelopeEnabled,
    //     pulse2EnvelopeLoop, pulse2EnvelopeStart, pulse2EnvelopePeriod,
    //     pulse2EnvelopeValue, pulse2EnvelopeVolume, pulse2ConstantVolume, triangleEnabled,
    //     triangleLengthEnabled, triangleLengthValue, triangleTimerPeriod, triangleTimerValue,
    //     triangleDutyValue, triangleCounterPeriod, triangleCounterValue, triangleCounterReload,
    //     noiseEnabled, noiseMode, noiseShiftRegister, noiseLengthEnabled, noiseLengthValue,
    //     noiseTimerPeriod, noiseTimerValue, noiseEnvelopeEnabled, noiseEnvelopeLoop,
    //     noiseEnvelopeStart, noiseEnvelopePeriod, noiseEnvelopeValue, noiseEnvelopeVolume,
    //     noiseConstantVolume, dmcEnabled, dmcValue, dmcSampleAddress, dmcSampleLength,
    //     dmcCurrentAddress, dmcCurrentLength, dmcShiftRegister, dmcBitCount, dmcTickPeriod,
    //     dmcTickValue, dmcLoop, dmcIrq
    // ).also { println("APU state saved") }
    return '';
  }

  void restoreState(String serializedState) {
    // var state = StatePersistence.restoreState(serializedState)
    // cycle = state.next()
    // framePeriod = state.next()
    // frameValue = state.next()
    // frameIRQ = state.next()
    // pulse1Enabled = state.next()
    // pulse1Channel = state.next()
    // pulse1LengthEnabled = state.next()
    // pulse1LengthValue = state.next()
    // pulse1TimerPeriod = state.next()
    // pulse1TimerValue = state.next()
    // pulse1DutyMode = state.next()
    // pulse1DutyValue = state.next()
    // pulse1SweepReload = state.next()
    // pulse1SweepEnabled = state.next()
    // pulse1SweepNegate = state.next()
    // pulse1SweepShift = state.next()
    // pulse1SweepPeriod = state.next()
    // pulse1SweepValue = state.next()
    // pulse1EnvelopeEnabled = state.next()
    // pulse1EnvelopeLoop = state.next()
    // pulse1EnvelopeStart = state.next()
    // pulse1EnvelopePeriod = state.next()
    // pulse1EnvelopeValue = state.next()
    // pulse1EnvelopeVolume = state.next()
    // pulse1ConstantVolume = state.next()
    // pulse2Enabled = state.next()
    // pulse2Channel = state.next()
    // pulse2LengthEnabled = state.next()
    // pulse2LengthValue = state.next()
    // pulse2TimerPeriod = state.next()
    // pulse2TimerValue = state.next()
    // pulse2DutyMode = state.next()
    // pulse2DutyValue = state.next()
    // pulse2SweepReload = state.next()
    // pulse2SweepEnabled = state.next()
    // pulse2SweepNegate = state.next()
    // pulse2SweepShift = state.next()
    // pulse2SweepPeriod = state.next()
    // pulse2SweepValue = state.next()
    // pulse2EnvelopeEnabled = state.next()
    // pulse2EnvelopeLoop = state.next()
    // pulse2EnvelopeStart = state.next()
    // pulse2EnvelopePeriod = state.next()
    // pulse2EnvelopeValue = state.next()
    // pulse2EnvelopeVolume = state.next()
    // pulse2ConstantVolume = state.next()
    // triangleEnabled = state.next()
    // triangleLengthEnabled = state.next()
    // triangleLengthValue = state.next()
    // triangleTimerPeriod = state.next()
    // triangleTimerValue = state.next()
    // triangleDutyValue = state.next()
    // triangleCounterPeriod = state.next()
    // triangleCounterValue = state.next()
    // triangleCounterReload = state.next()
    // noiseEnabled = state.next()
    // noiseMode = state.next()
    // noiseShiftRegister = state.next()
    // noiseLengthEnabled = state.next()
    // noiseLengthValue = state.next()
    // noiseTimerPeriod = state.next()
    // noiseTimerValue = state.next()
    // noiseEnvelopeEnabled = state.next()
    // noiseEnvelopeLoop = state.next()
    // noiseEnvelopeStart = state.next()
    // noiseEnvelopePeriod = state.next()
    // noiseEnvelopeValue = state.next()
    // noiseEnvelopeVolume = state.next()
    // noiseConstantVolume = state.next()
    // dmcEnabled = state.next()
    // dmcValue = state.next()
    // dmcSampleAddress = state.next()
    // dmcSampleLength = state.next()
    // dmcCurrentAddress = state.next()
    // dmcCurrentLength = state.next()
    // dmcShiftRegister = state.next()
    // dmcBitCount = state.next()
    // dmcTickPeriod = state.next()
    // dmcTickValue = state.next()
    // dmcLoop = state.next()
    // dmcIrq = state.next()
    // println("APU state restored")
  }

  void writeRegister(int address, int value /* Byte */) {
    switch (address) {
      case 0x4000:
        {
          // pulse 1 write control
          pulse1DutyMode = (value >> 6) & 3;
          pulse1LengthEnabled = value >> (5) & (1) == 0;
          pulse1EnvelopeLoop = value >> (5) & (1) == 1;
          pulse1EnvelopeEnabled = value >> (4) & (1) == 0;
          pulse1EnvelopePeriod = value & 15;
          pulse1ConstantVolume = value & 15;
          pulse1EnvelopeStart = true;
        }
        break;
      case 0x4001:
        {
          // pulse 1 write sweep
          pulse1SweepEnabled = value >> (7) & (1) == 1;
          pulse1SweepPeriod = value >> (4) & (7) + 1;
          pulse1SweepNegate = value >> (3) & (1) == 1;
          pulse1SweepShift = value & 7;
          pulse1SweepReload = true;
        }
        break;
      case 0x4002:
        pulse1TimerPeriod = (pulse1TimerPeriod & 0xFF00) | value;
        break;
      case 0x4003:
        {
          // pulse 1 write timer high
          pulse1LengthValue = lengthTable[value >> 3] & 0xFF;
          pulse1TimerPeriod = (pulse1TimerPeriod & 0x00FF) | ((value & 7) << 8);
          pulse1EnvelopeStart = true;
          pulse1DutyValue = 0;
        }
        break;
      case 0x4004:
        {
          // pulse 2 write control
          pulse2DutyMode = (value >> 6) & 3;
          pulse2LengthEnabled = (value >> 5) & 1 == 0;
          pulse2EnvelopeLoop = (value >> 5) & 1 == 1;
          pulse2EnvelopeEnabled = (value >> 4) & 1 == 0;
          pulse2EnvelopePeriod = value & 15;
          pulse2ConstantVolume = value & 15;
          pulse2EnvelopeStart = true;
        }
        break;
      case 0x4005:
        {
          // pulse 2 write sweep
          pulse2SweepEnabled = value >> (7) & (1) == 1;
          pulse2SweepPeriod = value >> (4) & (7) + 1;
          pulse2SweepNegate = value >> (3) & (1) == 1;
          pulse2SweepShift = value & 7;
          pulse2SweepReload = true;
        }
        break;
      case 0x4006:
        pulse2TimerPeriod = (pulse2TimerPeriod & 0xFF00) | value;
        break;
      case 0x4007:
        {
          // pulse 2 write timer high
          pulse2LengthValue = lengthTable[value >> 3];
          pulse2TimerPeriod = (pulse2TimerPeriod & 0x00FF) | ((value & 7) << 8);
          pulse2EnvelopeStart = true;
          pulse2DutyValue = 0;
        }
        break;
      case 0x4008:
        {
          // triangle write control
          triangleLengthEnabled = (value >> 7) & 1 == 0;
          triangleCounterPeriod = (value & 0x7F);
        }
        break;
      case 0x4009:
      case 0x4010:
        {
          // dmc write control
          dmcIrq = value & 0x80 == 0x80;
          dmcLoop = value & 0x40 == 0x40;
          dmcTickPeriod = dmcTable[value & 0x0F];
        }
        break;
      case 0x4011:
        {
          // dmc write value
          dmcValue = value & 0x7F;
        }
        break;
      case 0x4012:
        {
          // dmc write address
          // Sample address = %11AAAAAA.AA000000
          dmcSampleAddress = 0xC000 | (value << 6);
        }
        break;
      case 0x4013:
        {
          // dmc write length
          // Sample length = %0000LLLL.LLLL0001
          dmcSampleLength = (value << 4) | 1;
        }
        break;
      case 0x400A:
        {
          // triangle write timer low
          triangleTimerPeriod = (triangleTimerPeriod & 0xFF00) | value;
        }
        break;
      case 0x400B:
        {
          // triangle write timer high
          triangleLengthValue = lengthTable[value >> 3];
          triangleTimerPeriod =
              (triangleTimerPeriod & 0x00FF) | ((value & 7) << 8);
          triangleTimerValue = triangleTimerPeriod;
          triangleCounterReload = true;
        }
        break;
      case 0x400C:
        {
          // noise write control
          noiseLengthEnabled = (value >> 5) & 1 == 0;
          noiseEnvelopeLoop = (value >> 5) & 1 == 1;
          noiseEnvelopeEnabled = (value >> 4) & 1 == 0;
          noiseEnvelopePeriod = (value & 15);
          noiseConstantVolume = (value & 15);
          noiseEnvelopeStart = true;
        }
        break;
      case 0x400D:
      case 0x400E:
        {
          // noise write period
          noiseMode = value & 0x80 == 0x80;
          noiseTimerPeriod = noiseTable[value & 0x0F];
        }
        break;
      case 0x400F:
        {
          // noise write length
          noiseLengthValue = lengthTable[value >> 3];
          noiseEnvelopeStart = true;
        }
        break;
      case 0x4015:
        {
          // write control
          pulse1Enabled = value & 1 == 1;
          pulse2Enabled = value & 2 == 2;
          triangleEnabled = value & 4 == 4;
          noiseEnabled = value & 8 == 8;
          dmcEnabled = value & 16 == 16;
          if (!pulse1Enabled) pulse1LengthValue = 0;
          if (!pulse2Enabled) pulse2LengthValue = 0;
          if (!triangleEnabled) triangleLengthValue = 0;
          if (!noiseEnabled) noiseLengthValue = 0;
          if (!dmcEnabled) {
            dmcCurrentLength = 0;
          } else {
            if (dmcCurrentLength == 0) {
              dmcCurrentAddress = dmcSampleAddress;
              dmcCurrentLength = dmcSampleLength;
            }
          }
        }
        break;
      case 0x4017:
        {
          // write frame counter
          framePeriod = 4 + value >> (7) & (1);
          frameIRQ = (value >> 6) & 1 == 0;
          if (framePeriod == 5) {
            stepEnvelope();
            stepSweep();
            stepLength();
          }
        }
        break;
    }
  }

  void stepLength() {
    // pulse 1
    if (pulse1LengthEnabled && pulse1LengthValue > 0) pulse1LengthValue -= 1;
    // pulse 2
    if (pulse2LengthEnabled && pulse2LengthValue > 0) pulse2LengthValue -= 1;
    // triangle
    if (triangleLengthEnabled && triangleLengthValue > 0) {
      triangleLengthValue -= 1;
    }
    // noise
    if (noiseLengthEnabled && noiseLengthValue > 0) noiseLengthValue -= 1;
  }

  void pulse1Sweep() {
    var delta = pulse1TimerPeriod >> pulse1SweepShift;
    if (pulse1SweepNegate) {
      pulse1TimerPeriod -= delta;
      pulse1TimerPeriod;
      if (pulse1Channel == 1) pulse1TimerPeriod--;
    } else {
      pulse1TimerPeriod += delta;
    }
  }

  void pulse2Sweep() {
    var delta = pulse2TimerPeriod >> pulse2SweepShift;
    if (pulse2SweepNegate) {
      pulse2TimerPeriod -= delta;
      pulse2TimerPeriod;
      if (pulse2Channel == 1) pulse2TimerPeriod--;
    } else {
      pulse2TimerPeriod += delta;
    }
  }

  void stepSweep() {
    // pulse 1 step sweep
    if (pulse1SweepReload) {
      if (pulse1SweepEnabled && pulse1SweepValue == 0) pulse1Sweep();
      pulse1SweepValue = pulse1SweepPeriod;
      pulse1SweepReload = false;
    } else if (pulse1SweepValue > 0) {
      pulse1SweepValue -= 1;
    } else {
      if (pulse1SweepEnabled) pulse1Sweep();
      pulse1SweepValue = pulse1SweepPeriod;
    }
    // pulse 2 step sweep
    if (pulse2SweepReload) {
      if (pulse2SweepEnabled && pulse2SweepValue == 0) pulse2Sweep();
      pulse2SweepValue = pulse2SweepPeriod;
      pulse2SweepReload = false;
    } else if (pulse2SweepValue > 0) {
      pulse2SweepValue -= 1;
    } else {
      if (pulse2SweepEnabled) pulse2Sweep();
      pulse2SweepValue = pulse2SweepPeriod;
    }
  }

  void stepEnvelope() {
    // pulse 1 step envelope
    if (pulse1EnvelopeStart) {
      pulse1EnvelopeVolume = 15;
      pulse1EnvelopeValue = pulse1EnvelopePeriod;
      pulse1EnvelopeStart = false;
    } else if (pulse1EnvelopeValue > 0) {
      pulse1EnvelopeValue -= 1;
    } else {
      if (pulse1EnvelopeVolume > 0) {
        pulse1EnvelopeVolume -= 1;
      } else if (pulse1EnvelopeLoop) {
        pulse1EnvelopeVolume = 15;
      }
      pulse1EnvelopeValue = pulse1EnvelopePeriod;
    }
    // pulse 2 step envelope
    if (pulse2EnvelopeStart) {
      pulse2EnvelopeVolume = 15;
      pulse2EnvelopeValue = pulse2EnvelopePeriod;
      pulse2EnvelopeStart = false;
    } else if (pulse2EnvelopeValue > 0) {
      pulse2EnvelopeValue--;
    } else {
      if (pulse2EnvelopeVolume > 0) {
        pulse2EnvelopeVolume -= 1;
      } else if (pulse2EnvelopeLoop) {
        pulse2EnvelopeVolume = 15;
      }
      pulse2EnvelopeValue = pulse2EnvelopePeriod;
    }
    // triangle step counter
    if (triangleCounterReload) {
      triangleCounterValue = triangleCounterPeriod;
    } else if (triangleCounterValue > 0) {
      triangleCounterValue -= 1;
    }
    if (triangleLengthEnabled) triangleCounterReload = false;
    // noise step envelope
    if (noiseEnvelopeStart) {
      noiseEnvelopeVolume = 15;
      noiseEnvelopeValue = noiseEnvelopePeriod;
      noiseEnvelopeStart = false;
    } else if (noiseEnvelopeValue > 0) {
      noiseEnvelopeValue -= 1;
    } else {
      if (noiseEnvelopeVolume > 0) {
        noiseEnvelopeVolume -= 1;
        noiseEnvelopeVolume;
      } else if (noiseEnvelopeLoop) {
        noiseEnvelopeVolume = 15;
      }
      noiseEnvelopeValue = noiseEnvelopePeriod;
    }
  }
}

class _APUConst {
  static const sampleRate = 48000.0;
  final frameCounterRate = CPU.frequencyHZ / 240.0;
  final triangleTable = [
    15,
    14,
    13,
    12,
    11,
    10,
    9,
    8,
    7,
    6,
    5,
    4,
    3,
    2,
    1,
    0,
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15
  ];
  final noiseTable = [
    4,
    8,
    16,
    32,
    64,
    96,
    128,
    160,
    202,
    254,
    380,
    508,
    762,
    1016,
    2034,
    4068
  ];
  final lengthTable = [
    10,
    254,
    20,
    2,
    40,
    4,
    80,
    6,
    160,
    8,
    60,
    10,
    14,
    12,
    26,
    14,
    12,
    16,
    24,
    18,
    48,
    20,
    96,
    22,
    192,
    24,
    72,
    26,
    16,
    28,
    32,
    30
  ];
  final dmcTable = [
    214,
    190,
    170,
    160,
    143,
    127,
    113,
    107,
    95,
    80,
    71,
    64,
    53,
    42,
    36,
    27
  ];
  final dutyTable = [
    [0, 1, 0, 0, 0, 0, 0, 0],
    [0, 1, 1, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 0, 0, 0],
    [1, 0, 0, 1, 1, 1, 1, 1],
  ];
}

abstract class APUStepCallback {
  void onStep(
    int cycle,
    int framePeriod,
    int frameValue,
    bool frameIRQ,
    bool pulse1Enabled,
    int pulse1Channel,
    bool pulse1LengthEnabled,
    int pulse1LengthValue,
    int pulse1TimerPeriod,
    int pulse1TimerValue,
    int pulse1DutyMode,
    int pulse1DutyValue,
    bool pulse1SweepReload,
    bool pulse1SweepEnabled,
    bool pulse1SweepNegate,
    int pulse1SweepShift,
    int pulse1SweepPeriod,
    int pulse1SweepValue,
    bool pulse1EnvelopeEnabled,
    bool pulse1EnvelopeLoop,
    bool pulse1EnvelopeStart,
    int pulse1EnvelopePeriod,
    int pulse1EnvelopeValue,
    int pulse1EnvelopeVolume,
    int pulse1ConstantVolume,
    bool pulse2Enabled,
    int pulse2Channel,
    bool pulse2LengthEnabled,
    int pulse2LengthValue,
    int pulse2TimerPeriod,
    int pulse2TimerValue,
    int pulse2DutyMode,
    int pulse2DutyValue,
    bool pulse2SweepReload,
    bool pulse2SweepEnabled,
    bool pulse2SweepNegate,
    int pulse2SweepShift,
    int pulse2SweepPeriod,
    int pulse2SweepValue,
    bool pulse2EnvelopeEnabled,
    bool pulse2EnvelopeLoop,
    bool pulse2EnvelopeStart,
    int pulse2EnvelopePeriod,
    int pulse2EnvelopeValue,
    int pulse2EnvelopeVolume,
    int pulse2ConstantVolume,
    bool triangleEnabled,
    bool triangleLengthEnabled,
    int triangleLengthValue,
    int triangleTimerPeriod,
    int triangleTimerValue,
    int triangleDutyValue,
    int triangleCounterPeriod,
    int triangleCounterValue,
    bool triangleCounterReload,
    bool noiseEnabled,
    bool noiseMode,
    int noiseShiftRegister,
    bool noiseLengthEnabled,
    int noiseLengthValue,
    int noiseTimerPeriod,
    int noiseTimerValue,
    bool noiseEnvelopeEnabled,
    bool noiseEnvelopeLoop,
    bool noiseEnvelopeStart,
    int noiseEnvelopePeriod,
    int noiseEnvelopeValue,
    int noiseEnvelopeVolume,
    int noiseConstantVolume,
    bool dmcEnabled,
    int dmcValue,
    int dmcSampleAddress,
    int dmcSampleLength,
    int dmcCurrentAddress,
    int dmcCurrentLength,
    int dmcShiftRegister,
    int dmcBitCount,
    int dmcTickPeriod,
    int dmcTickValue,
    bool dmcLoop,
    bool dmcIrq,
    double output,
  );
}
