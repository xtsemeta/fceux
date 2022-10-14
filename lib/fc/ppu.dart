import 'dart:typed_data';

var ppulut1 = Uint32List(256);
var ppulut2 = Uint32List(256);
var ppulut3 = Uint32List(256);

// ppu look-up-table
void makeppulut() {
  for (int x = 0; x < 256; x++) {
    ppulut1[x] = 0;
    for (var y = 0; y < 8; y++) {
      ppulut1[x] |= ((x >> (7 - y)) & 1) << (y * 4);
    }
    ppulut2[x] = ppulut1[x] << 1;
  }

  for (var cc = 0; cc < 16; cc++) {
    for (var xo = 0; xo < 8; xo++) {
      ppulut3[xo | (cc << 3)] = 0;
      for (var pixel = 0; pixel < 8; pixel++) {
        var shiftr = (pixel + xo) ~/ 8;
        shiftr *= 2;
        ppulut3[xo | (cc << 3)] |= ((cc >> shiftr) & 3) << (2 + pixel * 4);
      }
    }
  }
}
