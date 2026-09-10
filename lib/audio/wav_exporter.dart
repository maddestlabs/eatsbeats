import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'wav_exporter_stub.dart'
    if (dart.library.html) 'wav_exporter_web.dart';

class WavExporter {
  // Encodes stereo 16-bit PCM WAV audio file from Float32 sample lists
  static Uint8List encodeWav({
    required List<double> leftSamples,
    required List<double> rightSamples,
    int sampleRate = 44100,
  }) {
    final int numSamples = mathMin(leftSamples.length, rightSamples.length);
    final int numChannels = 2;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final int chunkSize = 36 + dataSize;

    final ByteData byteData = ByteData(44 + dataSize);

    // RIFF chunk descriptor
    _writeString(byteData, 0, 'RIFF');
    byteData.setUint32(4, chunkSize, Endian.little);
    _writeString(byteData, 8, 'WAVE');

    // fmt sub-chunk
    _writeString(byteData, 12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    // data sub-chunk
    _writeString(byteData, 36, 'data');
    byteData.setUint32(40, dataSize, Endian.little);

    // Write interleaved 16-bit audio samples
    int offset = 44;
    for (int i = 0; i < numSamples; i++) {
      final double l = leftSamples[i].clamp(-1.0, 1.0);
      final double r = rightSamples[i].clamp(-1.0, 1.0);

      final int sampleL = (l < 0 ? l * 32768 : l * 32767).toInt();
      final int sampleR = (r < 0 ? r * 32768 : r * 32767).toInt();

      byteData.setInt16(offset, sampleL, Endian.little);
      offset += 2;
      byteData.setInt16(offset, sampleR, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  static int mathMin(int a, int b) => a < b ? a : b;

  static void _writeString(ByteData data, int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  // Trigger file save / download of WAV file across Web and Desktop
  static Future<void> saveWavFile(Uint8List wavBytes, String filename) async {
    await saveWavFileImpl(wavBytes, filename);
  }
}
