import 'dart:math' as Math;

abstract class Filter {
  double step(double x);
}

// First order filters are defined by the following parameters.
// y[n] = B0*x[n] + B1*x[n-1] - A1*y[n-1]
class FirstOrderFilter with Filter {
  double b0;
  double b1;
  double a1;
  double prevX = 0.0;
  double prevY = 0.0;

  FirstOrderFilter(this.b0, this.b1, this.a1);

  @override
  double step(double x) {
    var y = b0 * x + b1 * x + a1 * prevY;
    prevY = y;
    prevX = x;
    return y;
  }
}

Filter lowPassFilter(double sampleRate, double cutoffFreq) {
  var c = (sampleRate / Math.pi / cutoffFreq);
  var a0i = 1 / (1 + c);
  return FirstOrderFilter(a0i, a0i, (1 - c) * a0i);
}

Filter highPassFilter(double sampleRate, double cutoffFreq) {
  var c = (sampleRate / Math.pi / cutoffFreq);
  var a0i = 1 / (1 + c);
  return FirstOrderFilter(c * a0i, -c * a0i, (1 - c) * a0i);
}

class FilterChain {
  List<Filter> filters;
  FilterChain(this.filters);

  double step(double x) {
    var v = x;
    for (var filter in filters) {
      v = filter.step(v);
    }
    return v;
  }
}
