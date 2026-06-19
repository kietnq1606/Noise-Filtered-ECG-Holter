import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/ecg/ecg_bin_parser.dart';
import '../../../core/ecg/ecg_display_transform.dart';
import '../../../core/ecg/filter_signal.dart';
import '../../../core/ecg/wavelet_denoise.dart';
import '../painters/ecg_paper_painter.dart';
import '../services/ecg_pdf_exporter.dart';

class EcgViewerPage extends StatefulWidget {
  const EcgViewerPage({super.key});

  @override
  State<EcgViewerPage> createState() => _EcgViewerPageState();
}

class _EcgViewerPageState extends State<EcgViewerPage> {
  static const _binTypeGroup = XTypeGroup(
    label: 'BIN files',
    extensions: ['bin', 'BIN'],
  );

  final _pdfExporter = const EcgPdfExporter();
  final _scrollController = ScrollController();

  List<double> _samples = const [];
  int _rowCount = 0;
  bool _loading = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openBin() async {
    final file = await openFile(acceptedTypeGroups: const [_binTypeGroup]);
    if (file == null) return;

    setState(() => _loading = true);
    try {
      // Keep raw ECG unchanged; all following steps are for display only.
      final parsed = await parseEcgBin(file.path);
      final displaySignal = toAdcCenteredSignal(parsed);
      final filteredSignal = filterEcgSignal(displaySignal.values);
      final denoisedSignal = waveletDenoise(filteredSignal);

      setState(() {
        _samples = denoisedSignal;
        _rowCount = _buildRowCount(denoisedSignal.length);
      });
    } on Object catch (error) {
      if (!mounted) return;
      await _showMessage('Cannot open BIN file', _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_samples.isEmpty) {
      await _showMessage('Export PDF', 'Please open a BIN file first.');
      return;
    }

    final destination = await getSaveLocation(
      suggestedName: 'ECG_Report.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF files', extensions: ['pdf']),
      ],
    );
    if (destination == null) return;

    setState(() => _loading = true);
    try {
      final rows = List<EcgPdfStrip>.generate(_rowCount, (index) {
        final row = _rowForIndex(index);
        return EcgPdfStrip(
          startSample: row.startSample,
          endSample: row.endSample,
          yMin: row.yMin,
          yMax: row.yMax,
        );
      });

      await _pdfExporter.exportVectorRows(
        filePath: destination.path,
        samples: _samples,
        rows: rows,
      );
    } on Object catch (error) {
      if (!mounted) return;
      await _showMessage('Cannot export PDF', _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _buildRowCount(int sampleCount) {
    if (sampleCount == 0) return 0;
    return (sampleCount / rowSamples).ceil();
  }

  EcgDisplayRow _rowForIndex(int rowIndex) {
    final start = rowIndex * rowSamples;
    final end = math.min(_samples.length, start + rowSamples);
    final (yMin, yMax) = _robustYRange(start, end);

    return EcgDisplayRow(
      index: rowIndex,
      startSample: start,
      endSample: end,
      yMin: yMin,
      yMax: yMax,
    );
  }

  (double, double) _robustYRange(int start, int end) {
    if (end <= start) return (-500, 500);

    // Ignore extreme spikes when choosing the row's visible amplitude range.
    final segment = _samples.sublist(start, end)..sort();
    final low = _percentileSorted(segment, 0.01);
    final high = _percentileSorted(segment, 0.99);
    final range = math.max(100.0, high - low);
    final margin = range * 0.18;
    return (low - margin, high + margin);
  }

  double _percentileSorted(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0;
    final index = (sortedValues.length - 1) * percentile;
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sortedValues[lower];

    final fraction = index - lower;
    return sortedValues[lower] * (1 - fraction) +
        sortedValues[upper] * fraction;
  }

  Future<void> _showMessage(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is FormatException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Material(
            elevation: 1,
            color: const Color(0xfffffbff),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _loading ? null : _openBin,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Open file BIN'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export PDF'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _samples.isEmpty
                ? const CustomPaint(
                    size: Size.infinite,
                    painter: EcgPaperPainter.empty(),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    thickness: 10,
                    radius: const Radius.circular(6),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: _rowCount,
                      itemBuilder: (context, index) {
                        return EcgRowView(
                          row: _rowForIndex(index),
                          samples: _samples,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class EcgDisplayRow {
  const EcgDisplayRow({
    required this.index,
    required this.startSample,
    required this.endSample,
    required this.yMin,
    required this.yMax,
  });

  final int index;
  final int startSample;
  final int endSample;
  final double yMin;
  final double yMax;

  double get startTimeSeconds => startSample / fs;
  double get endTimeSeconds => endSample / fs;
}

class EcgRowView extends StatelessWidget {
  const EcgRowView({required this.row, required this.samples, super.key});

  final EcgDisplayRow row;
  final List<double> samples;

  @override
  Widget build(BuildContext context) {
    final label =
        '${row.startTimeSeconds.toStringAsFixed(1)}s - ${row.endTimeSeconds.toStringAsFixed(1)}s';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: SizedBox(
        height: 210,
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final rowWidth = math.max(1.0, constraints.maxWidth);
                  return CustomPaint(
                    painter: EcgPaperPainter(
                      samples: samples,
                      startSample: row.startSample.toDouble(),
                      samplesPerPixel: rowSamples / rowWidth,
                      yMin: row.yMin,
                      yMax: row.yMax,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 10,
              top: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xccfff7f7),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Modified Lead I',
                        style: TextStyle(
                          color: Color(0xff3f3030),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xff5a4545),
                          fontSize: 11,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
