import 'dart:math' as math;

const double bandPassLowHz = 0.5;
const double bandPassHighHz = 40.0;
const double notchHz = 50.0;
const double notchQ = 30.0;
const int butterworthOrder = 4;

List<double> filterSignalBandPass(
  List<double> samples, {
  double sampleRate = 500.0,
  double lowCutHz = bandPassLowHz,
  double highCutHz = bandPassHighHz,
}) {
  return filterEcgSignal(
    samples,
    sampleRate: sampleRate,
    highPassHz: lowCutHz,
    lowPassHz: highCutHz,
  );
}

List<double> filterEcgSignal(
  List<double> samples, {
  double sampleRate = 500.0,
  double highPassHz = bandPassLowHz,
  double notchFrequencyHz = notchHz,
  double notchQualityFactor = notchQ,
  double lowPassHz = bandPassHighHz,
}) {
  if (samples.isEmpty) return const [];
  if (highPassHz <= 0 ||
      lowPassHz <= highPassHz ||
      lowPassHz >= sampleRate / 2 ||
      notchFrequencyHz <= 0 ||
      notchFrequencyHz >= sampleRate / 2 ||
      notchQualityFactor <= 0) {
    throw ArgumentError('Invalid ECG filter settings.');
  }

  // Filter the full record before it is split into display rows.
  var output = _applyButterworth(
    samples,
    (q) => _Biquad.highPass(sampleRate: sampleRate, cutoffHz: highPassHz, q: q),
  );

  output = _Biquad.notch(
    sampleRate: sampleRate,
    frequencyHz: notchFrequencyHz,
    q: notchQualityFactor,
  ).process(output);

  output = _applyButterworth(
    output,
    (q) => _Biquad.lowPass(sampleRate: sampleRate, cutoffHz: lowPassHz, q: q),
  );

  return output;
}

List<double> _applyButterworth(
  List<double> samples,
  _Biquad Function(double q) createSection,
) {
  if (butterworthOrder <= 0 || butterworthOrder.isOdd) {
    throw StateError('Butterworth order must be a positive even number.');
  }

  var output = samples;
  for (final q in _butterworthSectionQs(butterworthOrder)) {
    output = createSection(q).process(output);
  }
  return output;
}

List<double> _butterworthSectionQs(int order) {
  // Even-order Butterworth filters are cascaded as second-order sections.
  return List<double>.generate(order ~/ 2, (index) {
    final angle = (2 * index + 1) * math.pi / (2 * order);
    return 1 / (2 * math.cos(angle));
  });
}

class _Biquad {
  _Biquad({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  factory _Biquad.lowPass({
    required double sampleRate,
    required double cutoffHz,
    double q = math.sqrt1_2,
  }) {
    final omega = 2 * math.pi * cutoffHz / sampleRate;
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    final alpha = sinOmega / (2 * q);
    final a0 = 1 + alpha;

    return _Biquad(
      b0: (1 - cosOmega) / 2 / a0,
      b1: (1 - cosOmega) / a0,
      b2: (1 - cosOmega) / 2 / a0,
      a1: -2 * cosOmega / a0,
      a2: (1 - alpha) / a0,
    );
  }

  factory _Biquad.highPass({
    required double sampleRate,
    required double cutoffHz,
    double q = math.sqrt1_2,
  }) {
    final omega = 2 * math.pi * cutoffHz / sampleRate;
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    final alpha = sinOmega / (2 * q);
    final a0 = 1 + alpha;

    return _Biquad(
      b0: (1 + cosOmega) / 2 / a0,
      b1: -(1 + cosOmega) / a0,
      b2: (1 + cosOmega) / 2 / a0,
      a1: -2 * cosOmega / a0,
      a2: (1 - alpha) / a0,
    );
  }

  factory _Biquad.notch({
    required double sampleRate,
    required double frequencyHz,
    required double q,
  }) {
    final omega = 2 * math.pi * frequencyHz / sampleRate;
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    final alpha = sinOmega / (2 * q);
    final a0 = 1 + alpha;

    return _Biquad(
      b0: 1 / a0,
      b1: -2 * cosOmega / a0,
      b2: 1 / a0,
      a1: -2 * cosOmega / a0,
      a2: (1 - alpha) / a0,
    );
  }

  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;

  List<double> process(List<double> input) {
    var x1 = 0.0;
    var x2 = 0.0;
    var y1 = 0.0;
    var y2 = 0.0;
    final output = List<double>.filled(input.length, 0);

    // Direct Form I biquad difference equation.
    for (var i = 0; i < input.length; i++) {
      final x0 = input[i];
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      output[i] = y0;

      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }

    return output;
  }
}
