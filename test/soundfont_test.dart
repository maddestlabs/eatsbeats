import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/soundfont_decoder.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundFont 2 (.sf2) Decoder & Engine Tests', () {
    test('SoundFontDecoder gracefully rejects non-RIFF binary data', () {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
      final result = SoundFontDecoder.decode(invalidBytes);
      expect(result, isNull);
    });

    test('DawState handles .sf2 drag and drop auto track creation', () {
      final dawState = DawState();
      final dummySf2Bytes = Uint8List(100);

      final initialTrackCount = dawState.activePattern.tracks.length;
      dawState.addSampleTrackFromFile(fileName: 'vintage_piano.sf2', fileBytes: dummySf2Bytes);

      expect(dawState.activePattern.tracks.length, equals(initialTrackCount + 1));
      final newTrack = dawState.activePattern.tracks.last;
      expect(newTrack.name, equals('vintage_piano'));
      expect(newTrack.sampleName, equals('vintage_piano.sf2'));
    });

    test('Bundled super_small_font.sf2 asset decodes successfully with valid preset & bank numbers', () {
      final file = io.File('assets/soundfonts/super_small_font.sf2');
      expect(file.existsSync(), isTrue);
      final bytes = file.readAsBytesSync();
      final decoded = SoundFontDecoder.decode(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.presets.isNotEmpty, isTrue);
      expect(decoded.sampleHeaders.isNotEmpty, isTrue);

      for (final p in decoded.presets) {
        expect(p.presetNum, lessThanOrEqualTo(127), reason: 'Preset number ${p.presetNum} for "${p.name}" exceeds 127');
        expect(p.bankNum, lessThanOrEqualTo(128), reason: 'Bank number ${p.bankNum} for "${p.name}" exceeds 128');
      }
    });
  });
}
