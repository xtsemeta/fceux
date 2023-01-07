import 'package:nes/buttons.dart';

class Controller {
  List<bool> buttons = List.generate(8, (index) => false);
  int index = 0; //byte
  int strobe = 0; //byte

  void onButtonUp(Buttons button) {
    buttons[button.index] = false;
  }

  void onButtonDown(Buttons button) {
    buttons[button.index] = true;
  }

  int read() {
    var value = 0;
    if (index < 8 && buttons[index]) {
      value = 1;
    }
    index = (index + 1) & 0xFF;
    if (strobe & 1 == 1) {
      index = 0;
    }
    return value;
  }

  void write(int value) {
    strobe = value;
    if (strobe & 1 == 1) {
      index = 0;
    }
  }
}
