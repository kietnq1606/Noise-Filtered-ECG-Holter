import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/ecg/ecg_bin_parser.dart';

class EcgPdfStrip {
  const EcgPdfStrip({
    required this.startSample,
    required this.endSample,
    required this.yMin,
    required this.yMax,
  });

  final int startSample;
  final int endSample;
  final double yMin;
  final double yMax;
}

class EcgPdfExporter {
  const EcgPdfExporter();

  Future<void> exportChartImage({
    required String filePath,
    required Uint8List chartPngBytes,
  }) async {
    await exportStripImages(filePath: filePath, stripPngBytes: [chartPngBytes]);
  }

  Future<void> exportStripImages({
    required String filePath,
    required List<Uint8List> stripPngBytes,
  }) async {
    final document = pw.Document();
    const stripsPerPage = 3;

    for (var index = 0; index < stripPngBytes.length; index += stripsPerPage) {
      final pageImages = stripPngBytes
          .skip(index)
          .take(stripsPerPage)
          .map(pw.MemoryImage.new)
          .toList();

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(18),
          build: (context) => pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              for (final image in pageImages) ...[
                pw.Expanded(child: pw.Image(image, fit: pw.BoxFit.contain)),
                if (image != pageImages.last) pw.SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );
    }

    await File(filePath).writeAsBytes(await document.save());
  }

  Future<void> exportVectorRows({
    required String filePath,
    required List<double> samples,
    required List<EcgPdfStrip> rows,
  }) async {
    final document = pw.Document();
    const stripsPerPage = 3;
    final pageFormat = PdfPageFormat.a4.landscape;
    const pageMargin = 18.0;
    const stripGap = 10.0;
    final contentWidth = pageFormat.width - pageMargin * 2;
    final contentHeight = pageFormat.height - pageMargin * 2;
    final stripHeight =
        (contentHeight - stripGap * (stripsPerPage - 1)) / stripsPerPage;

    for (var index = 0; index < rows.length; index += stripsPerPage) {
      final pageRows = rows.skip(index).take(stripsPerPage).toList();

      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(pageMargin),
          build: (context) => pw.Column(
            children: [
              for (final row in pageRows) ...[
                pw.SizedBox(
                  width: contentWidth,
                  height: stripHeight,
                  child: pw.Stack(
                    children: [
                      pw.Positioned.fill(
                        child: pw.CustomPaint(
                          size: PdfPoint(contentWidth, stripHeight),
                          painter: (canvas, size) {
                            _paintVectorStrip(canvas, size, samples, row);
                          },
                        ),
                      ),
                      pw.Positioned(
                        left: 8,
                        top: 6,
                        child: _buildLeadLabel(row),
                      ),
                    ],
                  ),
                ),
                if (row != pageRows.last) pw.SizedBox(height: stripGap),
              ],
            ],
          ),
        ),
      );
    }

    await File(filePath).writeAsBytes(await document.save());
  }

  pw.Widget _buildLeadLabel(EcgPdfStrip row) {
    final startTime = row.startSample / fs;
    final endTime = row.endSample / fs;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xccfff7f7)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Modified Lead I',
            style: pw.TextStyle(
              color: const PdfColor.fromInt(0xff3f3030),
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '${startTime.toStringAsFixed(1)}s - ${endTime.toStringAsFixed(1)}s',
            style: const pw.TextStyle(
              color: PdfColor.fromInt(0xff5a4545),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  void _paintVectorStrip(
    PdfGraphics canvas,
    PdfPoint size,
    List<double> samples,
    EcgPdfStrip row,
  ) {
    final width = size.x;
    final height = size.y;
    final samplesPerPoint = rowSamples / width;

    canvas
      ..setFillColor(const PdfColor.fromInt(0xfffff7f7))
      ..drawRect(0, 0, width, height)
      ..fillPath();

    _drawGrid(canvas, width, height, row, samplesPerPoint);
    _drawWaveform(canvas, width, height, samples, row, samplesPerPoint);
  }

  void _drawGrid(
    PdfGraphics canvas,
    double width,
    double height,
    EcgPdfStrip row,
    double samplesPerPoint,
  ) {
    const minorTimeSeconds = 0.04;
    const majorTimeSeconds = 0.2;
    const minorYStep = 100.0;
    const majorYStep = 500.0;

    final visibleSeconds = width * samplesPerPoint / fs;
    final startSeconds = row.startSample / fs;
    final firstMinorSecond =
        (startSeconds / minorTimeSeconds).floor() * minorTimeSeconds;
    final lastSecond = startSeconds + visibleSeconds;

    for (
      var second = firstMinorSecond;
      second <= lastSecond + minorTimeSeconds;
      second += minorTimeSeconds
    ) {
      final x = (second * fs - row.startSample) / samplesPerPoint;
      final isMajor =
          ((second / majorTimeSeconds).roundToDouble() -
                  second / majorTimeSeconds)
              .abs() <
          0.001;
      _strokeLine(
        canvas,
        x,
        0,
        x,
        height,
        isMajor
            ? const PdfColor.fromInt(0x88dc6b6b)
            : const PdfColor.fromInt(0x44f3a7a7),
        isMajor ? 0.55 : 0.25,
      );
    }

    final firstY = (row.yMin / minorYStep).floor() * minorYStep;
    for (
      var value = firstY;
      value <= row.yMax + minorYStep;
      value += minorYStep
    ) {
      final y = _mapY(value, height, row.yMin, row.yMax);
      final isMajor =
          ((value / majorYStep).roundToDouble() - value / majorYStep).abs() <
          0.001;
      _strokeLine(
        canvas,
        0,
        y,
        width,
        y,
        isMajor
            ? const PdfColor.fromInt(0x88dc6b6b)
            : const PdfColor.fromInt(0x44f3a7a7),
        isMajor ? 0.55 : 0.25,
      );
    }
  }

  void _drawWaveform(
    PdfGraphics canvas,
    double width,
    double height,
    List<double> samples,
    EcgPdfStrip row,
    double samplesPerPoint,
  ) {
    final start = row.startSample.clamp(0, samples.length - 1);
    final end = math.min(samples.length, row.endSample);
    if (end <= start) return;

    canvas
      ..setStrokeColor(const PdfColor.fromInt(0xff111111))
      ..setLineWidth(0.55);

    for (var i = start; i < end; i++) {
      final x = (i - row.startSample) / samplesPerPoint;
      final y = _mapY(samples[i], height, row.yMin, row.yMax);
      if (i == start) {
        canvas.moveTo(x, y);
      } else {
        canvas.lineTo(x, y);
      }
    }
    canvas.strokePath();
  }

  void _strokeLine(
    PdfGraphics canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    PdfColor color,
    double width,
  ) {
    canvas
      ..setStrokeColor(color)
      ..setLineWidth(width)
      ..drawLine(x1, y1, x2, y2)
      ..strokePath();
  }

  double _mapY(double value, double height, double yMin, double yMax) {
    final range = math.max(1.0, yMax - yMin);
    final normalized = ((value - yMin) / range).clamp(0.0, 1.0);
    return normalized * height;
  }
}
