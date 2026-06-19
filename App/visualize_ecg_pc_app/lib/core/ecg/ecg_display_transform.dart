const int adcBits = 12;
const int adcMax = 4095;
const double defaultVref = 3.3;
const double defaultGain = 100;

class EcgCalibration {
  const EcgCalibration({this.vref = defaultVref, this.gain = defaultGain});

  final double vref;
  final double gain;

  double get countsPerMv => gain * adcMax / (vref * 1000);
}

class EcgDisplaySignal {
  const EcgDisplaySignal({required this.values, required this.offsetCount});

  final List<double> values;
  final double offsetCount;
}

EcgDisplaySignal toAdcCenteredSignal(List<int> ecgSamples) {
  final offsetCount = median(
    ecgSamples.map((sample) => sample.toDouble()).toList(),
  );
  return EcgDisplaySignal(
    values: ecgSamples.map((sample) => sample - offsetCount).toList(),
    offsetCount: offsetCount,
  );
}

List<double> toRelativeMvSignal(
  List<int> ecgSamples, {
  EcgCalibration calibration = const EcgCalibration(),
}) {
  final offsetCount = median(
    ecgSamples.map((sample) => sample.toDouble()).toList(),
  );

  // Prepared for future calibration; the UI keeps ADC-centered units by default.
  return ecgSamples
      .map((sample) => (sample - offsetCount) / calibration.countsPerMv)
      .toList();
}

double median(List<double> values) {
  values.sort();
  final middle = values.length ~/ 2;
  if (values.length.isOdd) return values[middle];
  return (values[middle - 1] + values[middle]) / 2;
}
