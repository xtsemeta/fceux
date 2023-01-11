class Cartridge {
  List<int> prg;
  List<int> chr;
  int mapper;
  int mirror;
  int battery;
  List<int> sram; //save ram

  Cartridge(
    this.prg,
    this.chr,
    this.mapper,
    this.mirror,
    this.battery, {
    this.sram = const [0],
  }) {
    sram = List.filled(0x2000, 0);
  }

  @override
  int get hashCode {
    var result = prg.hashCode;
    result = 31 * result + chr.hashCode;
    result = 31 * result + sram.hashCode;
    result = 31 * result + mapper;
    result = 31 * result + mirror;
    result = 31 * result + battery;
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (this == other) return true;
    if (other is! Cartridge) return false;
    if (prg != other.prg) return false;
    if (chr != other.chr) return false;
    if (sram != other.sram) return false;
    if (mapper != other.mapper) return false;
    if (mirror != other.mirror) return false;
    if (battery != other.battery) return false;
    return true;
  }
}
