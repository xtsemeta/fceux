class AudioBuffer {
  final bufferSize = 2048;
  late var buffer = List<double>.filled(bufferSize, 0.0);

  int pos = 0;

  void write(double value) {
    buffer[pos++ % bufferSize] = value;
  }

  List<double> drain() {
    pos = 0;
    return buffer;
  }
}
