import 'dart:io';
import 'dart:typed_data';

const int fs = 500;
const int wordsPerPacket = 64;
const int metaWords = 14;
const int ecgWords = 50;
const int windowSeconds = 10;
const int windowSamples = fs * windowSeconds;
const double rowSeconds = 5.0;
const int rowSamples = 2500;

Future<List<int>> parseEcgBin(String filePath) async {
  final bytes = await File(filePath).readAsBytes();
  return parseEcgBinBytes(bytes);
}

List<int> parseEcgBinBytes(Uint8List bytes) {
  if (bytes.length < 2) {
    throw const FormatException(
      'Not enough data to form a complete ECG packet.',
    );
  }

  final wordCount = bytes.length ~/ 2;
  final words = List<int>.generate(
    wordCount,
    (index) => ByteData.sublistView(bytes).getUint16(index * 2, Endian.little),
  );

  final start = words.indexWhere((word) => word != 0);
  if (start < 0) {
    throw const FormatException('No ECG data found. File contains only zeros.');
  }

  final usableWords = wordCount - start;
  final packetCount = usableWords ~/ wordsPerPacket;
  if (packetCount <= 0) {
    throw const FormatException(
      'Not enough data to form a complete ECG packet.',
    );
  }

  final samples = <int>[];
  for (var packet = 0; packet < packetCount; packet++) {
    final packetStart = start + packet * wordsPerPacket;

    // Skip packet metadata and keep only the 50 real ECG samples.
    for (var i = 0; i < ecgWords; i++) {
      samples.add(words[packetStart + metaWords + i]);
    }
  }

  return samples;
}
