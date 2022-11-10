import 'dart:ffi';
import 'dart:typed_data';

class INesHeader {
  var id = Uint8List(4); //0-3
  var romSize = 0; //4
  var vromSize = 0; //5
  var romType = 0; //6
  var romType2 = 0; //7
  var romType3 = 0; //8
  var upperRomVromSize = 0; //9
  var ramSize = 0; //10
  var vramSize = 0; //11
  var tvSystem = 0; //12
  var vsHardware = 0; //13
  var reserved = Uint8List(2); //14,15
}
