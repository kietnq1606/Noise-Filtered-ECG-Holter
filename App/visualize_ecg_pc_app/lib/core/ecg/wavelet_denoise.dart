import 'dart:math' as math;

enum WaveletFamily { db4, sym4 }

const int waveletDenoiseLevels = 5;
const double waveletThresholdScale = 1.0;
const List<double> waveletDetailThresholdScales = [
  0.75, // D1: strong threshold for high-frequency noise.
  0.75, // D2: strong threshold for high-frequency noise.
  0.25, // D3: light threshold to preserve ECG shape.
  0.0, // D4: keep low-frequency ECG morphology.
  0.0, // D5: keep low-frequency ECG morphology.
];

List<double> waveletDenoise(
  List<double> samples, {
  WaveletFamily family = WaveletFamily.sym4,
  int levels = waveletDenoiseLevels,
  double thresholdScale = waveletThresholdScale,
}) {
  if (samples.length < 16 || levels <= 0) return List<double>.from(samples);

  final filters = _WaveletFilters.forFamily(family);
  final paddedLength = _nextPowerOfTwo(samples.length);
  final padded = _symmetricPad(samples, paddedLength);
  final coefficients = List<double>.from(padded);
  final detailBands = <_DetailBand>[];

  // Decompose into approximation and detail bands.
  var length = coefficients.length;
  for (var level = 0; level < levels; level++) {
    if (length < filters.lowPassDecomposition.length * 2) break;

    _forwardStep(coefficients, length, filters);
    final half = length ~/ 2;
    detailBands.add(_DetailBand(start: half, length: half));
    length = half;
  }

  if (detailBands.isEmpty) return List<double>.from(samples);

  // Estimate noise from the finest detail band using MAD.
  final sigma = _estimateNoiseSigma(coefficients, detailBands.first);
  final baseThreshold =
      thresholdScale * sigma * math.sqrt(2 * math.log(samples.length));
  if (baseThreshold.isFinite && baseThreshold > 0) {
    for (var index = 0; index < detailBands.length; index++) {
      final bandScale = _detailThresholdScale(index);
      if (bandScale <= 0) continue;

      _softThreshold(
        coefficients,
        detailBands[index],
        baseThreshold * bandScale,
      );
    }
  }

  // Reconstruct the denoised signal back to the original length.
  for (var level = detailBands.length - 1; level >= 0; level--) {
    final band = detailBands[level];
    _inverseStep(coefficients, band.length * 2, filters);
  }

  return coefficients.take(samples.length).toList();
}

double _detailThresholdScale(int detailIndex) {
  if (detailIndex >= waveletDetailThresholdScales.length) return 0;
  return waveletDetailThresholdScales[detailIndex];
}

void _forwardStep(List<double> data, int length, _WaveletFilters filters) {
  final half = length ~/ 2;
  final temp = List<double>.filled(length, 0);
  final filterLength = filters.lowPassDecomposition.length;

  for (var i = 0; i < half; i++) {
    var approximation = 0.0;
    var detail = 0.0;
    for (var k = 0; k < filterLength; k++) {
      final index = (2 * i + k) % length;
      approximation += filters.lowPassDecomposition[k] * data[index];
      detail += filters.highPassDecomposition[k] * data[index];
    }
    temp[i] = approximation;
    temp[half + i] = detail;
  }

  for (var i = 0; i < length; i++) {
    data[i] = temp[i];
  }
}

void _inverseStep(List<double> data, int length, _WaveletFilters filters) {
  final half = length ~/ 2;
  final temp = List<double>.filled(length, 0);
  final filterLength = filters.lowPassReconstruction.length;

  for (var i = 0; i < half; i++) {
    for (var k = 0; k < filterLength; k++) {
      final index = (2 * i + k) % length;
      temp[index] += filters.lowPassReconstruction[k] * data[i];
      temp[index] += filters.highPassReconstruction[k] * data[half + i];
    }
  }

  for (var i = 0; i < length; i++) {
    data[i] = temp[i];
  }
}

double _estimateNoiseSigma(List<double> coefficients, _DetailBand band) {
  final absoluteDetails =
      coefficients
          .skip(band.start)
          .take(band.length)
          .map((value) => value.abs())
          .toList()
        ..sort();
  if (absoluteDetails.isEmpty) return 0;

  final medianAbs = _medianSorted(absoluteDetails);
  return medianAbs / 0.6745;
}

void _softThreshold(
  List<double> coefficients,
  _DetailBand band,
  double threshold,
) {
  for (var i = band.start; i < band.start + band.length; i++) {
    final value = coefficients[i];
    final magnitude = value.abs() - threshold;
    coefficients[i] = magnitude <= 0 ? 0 : value.sign * magnitude;
  }
}

double _medianSorted(List<double> sortedValues) {
  final middle = sortedValues.length ~/ 2;
  if (sortedValues.length.isOdd) return sortedValues[middle];
  return (sortedValues[middle - 1] + sortedValues[middle]) / 2;
}

int _nextPowerOfTwo(int value) {
  var result = 1;
  while (result < value) {
    result <<= 1;
  }
  return result;
}

List<double> _symmetricPad(List<double> input, int length) {
  if (input.length == length) return List<double>.from(input);
  final output = List<double>.filled(length, 0);
  for (var i = 0; i < length; i++) {
    output[i] = input[_symmetricIndex(i, input.length)];
  }
  return output;
}

int _symmetricIndex(int index, int length) {
  if (length <= 1) return 0;
  final period = 2 * length - 2;
  final wrapped = index % period;
  return wrapped < length ? wrapped : period - wrapped;
}

class _DetailBand {
  const _DetailBand({required this.start, required this.length});

  final int start;
  final int length;
}

class _WaveletFilters {
  const _WaveletFilters({
    required this.lowPassDecomposition,
    required this.highPassDecomposition,
  }) : lowPassReconstruction = lowPassDecomposition,
       highPassReconstruction = highPassDecomposition;

  factory _WaveletFilters.forFamily(WaveletFamily family) {
    return switch (family) {
      WaveletFamily.db4 => const _WaveletFilters(
        lowPassDecomposition: [
          0.2303778133088964,
          0.7148465705529154,
          0.6308807679298587,
          -0.0279837694168599,
          -0.1870348117190931,
          0.0308413818355607,
          0.0328830116668852,
          -0.0105974017850690,
        ],
        highPassDecomposition: [
          -0.0105974017850690,
          -0.0328830116668852,
          0.0308413818355607,
          0.1870348117190931,
          -0.0279837694168599,
          -0.6308807679298587,
          0.7148465705529154,
          -0.2303778133088964,
        ],
      ),
      WaveletFamily.sym4 => const _WaveletFilters(
        lowPassDecomposition: [
          -0.0757657147892733,
          -0.0296355276459985,
          0.4976186676320155,
          0.8037387518059161,
          0.2978577956052774,
          -0.0992195435768472,
          -0.0126039672620378,
          0.0322231006040427,
        ],
        highPassDecomposition: [
          0.0322231006040427,
          0.0126039672620378,
          -0.0992195435768472,
          -0.2978577956052774,
          0.8037387518059161,
          -0.4976186676320155,
          -0.0296355276459985,
          0.0757657147892733,
        ],
      ),
    };
  }

  final List<double> lowPassDecomposition;
  final List<double> highPassDecomposition;
  final List<double> lowPassReconstruction;
  final List<double> highPassReconstruction;
}
