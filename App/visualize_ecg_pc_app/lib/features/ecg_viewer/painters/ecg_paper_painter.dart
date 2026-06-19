import 'dart:math' as math;

import 'package:flutter/material.dart';

class EcgPaperPainter extends CustomPainter {
  const EcgPaperPainter({
    required this.samples,
    required this.startSample,
    required this.samplesPerPixel,
    required this.yMin,
    required this.yMax,
  });

  const EcgPaperPainter.empty()
    : samples = const [],
      startSample = 0,
      samplesPerPixel = 1,
      yMin = -500,
      yMax = 500;

  final List<double> samples;
  final double startSample;
  final double samplesPerPixel;
  final double yMin;
  final double yMax;

  static const int _fs = 500;
  static const double _minorTimeSeconds = 0.04;
  static const double _majorTimeSeconds = 0.2;
  static const double _minorYStep = 100;
  static const double _majorYStep = 500;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xfffff7f7);
    canvas.drawRect(Offset.zero & size, background);
    _drawGrid(canvas, size);

    if (samples.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    _drawWaveform(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = const Color(0x44f3a7a7)
      ..strokeWidth = 0.6;
    final majorPaint = Paint()
      ..color = const Color(0x88dc6b6b)
      ..strokeWidth = 1.1;

    // ECG paper timing: small boxes are 0.04s, bold boxes are 0.2s.
    final visibleSeconds = size.width * samplesPerPixel / _fs;
    final startSeconds = startSample / _fs;
    final firstMinorSecond =
        (startSeconds / _minorTimeSeconds).floor() * _minorTimeSeconds;
    final lastSecond = startSeconds + visibleSeconds;

    for (
      var second = firstMinorSecond;
      second <= lastSecond + _minorTimeSeconds;
      second += _minorTimeSeconds
    ) {
      final x = (second * _fs - startSample) / samplesPerPixel;
      final isMajor =
          ((second / _majorTimeSeconds).roundToDouble() -
                  second / _majorTimeSeconds)
              .abs() <
          0.001;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // Y grid uses ADC-centered units because mV calibration is not final yet.
    final firstY = (yMin / _minorYStep).floor() * _minorYStep;
    for (
      var value = firstY;
      value <= yMax + _minorYStep;
      value += _minorYStep
    ) {
      final y = _mapY(value, size);
      final isMajor =
          ((value / _majorYStep).roundToDouble() - value / _majorYStep).abs() <
          0.001;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorPaint : minorPaint,
      );
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    const title = 'ECG PAPER VIEWER';
    final titlePainter = TextPainter(
      text: const TextSpan(
        text: title,
        style: TextStyle(
          color: Color(0xff3f3030),
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final center = Offset(size.width / 2, size.height / 2);
    titlePainter.paint(
      canvas,
      center - Offset(titlePainter.width / 2, titlePainter.height + 8),
    );
  }

  void _drawWaveform(Canvas canvas, Size size) {
    final visibleStart = startSample.floor().clamp(0, samples.length - 1);
    final visibleEnd = math.min(
      samples.length,
      (startSample + size.width * samplesPerPixel).ceil() + 1,
    );
    if (visibleEnd <= visibleStart) return;

    final wavePaint = Paint()
      ..color = const Color(0xff111111)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw a continuous path so app rendering matches vector PDF export.
    canvas.drawPath(_buildWavePath(visibleStart, visibleEnd, size), wavePaint);
  }

  Path _buildWavePath(int start, int end, Size size) {
    final path = Path();
    for (var i = start; i < end; i++) {
      final x = (i - startSample) / samplesPerPixel;
      final y = _mapY(samples[i], size);
      if (i == start) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  double _mapY(double value, Size size) {
    final range = math.max(1.0, yMax - yMin);
    final normalized = ((value - yMin) / range).clamp(0.0, 1.0);
    return size.height - normalized * size.height;
  }

  @override
  bool shouldRepaint(covariant EcgPaperPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.startSample != startSample ||
        oldDelegate.samplesPerPixel != samplesPerPixel ||
        oldDelegate.yMin != yMin ||
        oldDelegate.yMax != yMax;
  }
}
