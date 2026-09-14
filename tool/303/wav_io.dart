import 'dart:io';
import 'dart:typed_data';

/// Represents parsed multi-channel PCM audio.
class WavAudio {
  final int sampleRate;
  final int numChannels;
  final int bitDepth;
  final List<Float32List> channels;

  WavAudio({
    required this.sampleRate,
    required this.numChannels,
    required this.bitDepth,
    required this.channels,
  });

  /// Returns a mono mixdown of the channels.
  Float32List toMono() {
    if (channels.isEmpty) return Float32List(0);
    if (channels.length == 1) return channels[0];

    final length = channels[0].length;
    final mono = Float32List(length);
    final scale = 1.0 / channels.length;

    for (int i = 0; i < length; i++) {
      double sum = 0.0;
      for (int ch = 0; ch < channels.length; ch++) {
        sum += channels[ch][i];
      }
      mono[i] = (sum * scale).clamp(-1.0, 1.0);
    }
    return mono;
  }
}

/// Lightweight, zero-dependency pure-Dart WAV file reader and writer.
class WavIo {
  /// Reads a WAV file from [path] and decodes it to [WavAudio].
  static WavAudio readSync(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw ArgumentError('WAV file does not exist: $path');
    }
    final bytes = file.readAsBytesSync();
    return decode(bytes);
  }

  /// Decodes raw WAV byte buffer.
  static WavAudio decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);

    // Validate RIFF header
    final riffTag = String.fromCharCodes(bytes.sublist(0, 4));
    if (riffTag != 'RIFF') {
      throw FormatException('Not a valid RIFF file: $riffTag');
    }

    final waveTag = String.fromCharCodes(bytes.sublist(8, 12));
    if (waveTag != 'WAVE') {
      throw FormatException('Not a valid WAVE file: $waveTag');
    }

    int offset = 12;
    int audioFormat = 1;
    int numChannels = 1;
    int sampleRate = 44100;
    int bitsPerSample = 16;
    Uint8List? rawDataBytes;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      offset += 8;

      if (chunkId == 'fmt ') {
        audioFormat = data.getUint16(offset, Endian.little);
        numChannels = data.getUint16(offset + 2, Endian.little);
        sampleRate = data.getUint32(offset + 4, Endian.little);
        bitsPerSample = data.getUint16(offset + 14, Endian.little);
      } else if (chunkId == 'data') {
        final end = (offset + chunkSize).clamp(offset, bytes.length);
        rawDataBytes = bytes.sublist(offset, end);
      }

      offset += chunkSize;
      // Word alignment pad
      if (chunkSize % 2 != 0) {
        offset++;
      }
    }

    if (rawDataBytes == null) {
      throw const FormatException('No data chunk found in WAV');
    }

    final int bytesPerSample = bitsPerSample ~/ 8;
    final int totalSamples = rawDataBytes.length ~/ (bytesPerSample * numChannels);
    final List<Float32List> channels = List.generate(
      numChannels,
      (_) => Float32List(totalSamples),
    );

    final rawData = ByteData.sublistView(rawDataBytes);

    if (bitsPerSample == 16) {
      // 16-bit signed integer PCM
      int idx = 0;
      for (int i = 0; i < totalSamples; i++) {
        for (int ch = 0; ch < numChannels; ch++) {
          final s16 = rawData.getInt16(idx, Endian.little);
          channels[ch][i] = s16 / 32768.0;
          idx += 2;
        }
      }
    } else if (bitsPerSample == 24) {
      // 24-bit signed integer PCM
      int idx = 0;
      for (int i = 0; i < totalSamples; i++) {
        for (int ch = 0; ch < numChannels; ch++) {
          final b0 = rawDataBytes[idx];
          final b1 = rawDataBytes[idx + 1];
          final b2 = rawDataBytes[idx + 2];
          int val = (b2 << 16) | (b1 << 8) | b0;
          if (val & 0x800000 != 0) {
            val -= 0x1000000;
          }
          channels[ch][i] = val / 8388608.0;
          idx += 3;
        }
      }
    } else if (bitsPerSample == 32) {
      if (audioFormat == 3) {
        // 32-bit float
        int idx = 0;
        for (int i = 0; i < totalSamples; i++) {
          for (int ch = 0; ch < numChannels; ch++) {
            channels[ch][i] = rawData.getFloat32(idx, Endian.little);
            idx += 4;
          }
        }
      } else {
        // 32-bit integer PCM
        int idx = 0;
        for (int i = 0; i < totalSamples; i++) {
          for (int ch = 0; ch < numChannels; ch++) {
            final s32 = rawData.getInt32(idx, Endian.little);
            channels[ch][i] = s32 / 2147483648.0;
            idx += 4;
          }
        }
      }
    } else {
      throw UnsupportedError('Unsupported bit depth: $bitsPerSample-bit');
    }

    return WavAudio(
      sampleRate: sampleRate,
      numChannels: numChannels,
      bitDepth: bitsPerSample,
      channels: channels,
    );
  }

  /// Writes a mono or stereo Float32List buffer to a standard 16-bit PCM WAV file.
  static void writeSync(
    String path,
    Float32List samples, {
    int sampleRate = 44100,
    int numChannels = 1,
  }) {
    final numSamples = samples.length;
    final dataLength = numSamples * 2; // 16-bit = 2 bytes
    final totalSize = 36 + dataLength;

    final buffer = Uint8List(44 + dataLength);
    final bd = ByteData.sublistView(buffer);

    // RIFF chunk
    buffer.setRange(0, 4, 'RIFF'.codeUnits);
    bd.setUint32(4, totalSize, Endian.little);
    buffer.setRange(8, 12, 'WAVE'.codeUnits);

    // fmt subchunk
    buffer.setRange(12, 16, 'fmt '.codeUnits);
    bd.setUint32(16, 16, Endian.little); // Subchunk size (16 for PCM)
    bd.setUint16(20, 1, Endian.little);  // Audio format 1 = PCM
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * numChannels * 2, Endian.little); // ByteRate
    bd.setUint16(32, numChannels * 2, Endian.little); // BlockAlign
    bd.setUint16(34, 16, Endian.little); // BitsPerSample

    // data subchunk
    buffer.setRange(36, 40, 'data'.codeUnits);
    bd.setUint32(40, dataLength, Endian.little);

    int byteIdx = 44;
    for (int i = 0; i < numSamples; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final int s16 = (clamped * 32767.0).round();
      bd.setInt16(byteIdx, s16, Endian.little);
      byteIdx += 2;
    }

    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(buffer);
  }
}
