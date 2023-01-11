class EmulatorMessageIn {
  EmulatorMessageInType type;
  dynamic data;
  EmulatorMessageIn(this.type, this.data);
}

class EmulatorMessageOut {
  EmulatorMessageOutType type;
  dynamic data;
  EmulatorMessageOut(this.type, this.data);
}

enum EmulatorMessageInType {
  start,
  setDebugCpuLog,
}

enum EmulatorMessageOutType {
  initialize,
  updateFrame,
}
