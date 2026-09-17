import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/eatscript/eats_engine.dart';
import 'package:eatsbeats/eatscript/eats_preset_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Preset Upgrade & Non-Destructive Migration Tests', () {
    const olderEats303Code = '''
# @name: Eats 303
# @category: instrument
local Acid303 = {}

function Acid303.init()
  Param.add("Waveform", 0.0, 1.0, 0.0)
  Param.add("Cutoff", 100.0, 6500.0, 1600.0)
  Param.add("Resonance", 0.5, 16.0, 8.0)
  Param.add("EnvMod", 0.0, 1.0, 0.75)
  Param.add("Decay", 0.05, 1.2, 0.28)
  Param.add("Accent", 0.0, 1.0, 0.6)
  Param.add("Slide", 0.0, 1.0, 0.4)
  Param.add("Overdrive", 0.0, 1.0, 0.3)
end

function Acid303.process(time, freq, note, params)
  return 0.0
end

return Acid303
''';

    test('Detects upgrade available for older preset script without GUI', () {
      final isUpgrade = EatScriptLibrary.isUpgradeAvailable(olderEats303Code, trackName: 'Eats 303');
      expect(isUpgrade, isTrue);

      final latestPreset = EatScriptLibrary.getPresetById('jc_303')!;
      final isLatestUpgrade = EatScriptLibrary.isUpgradeAvailable(latestPreset.code, trackName: 'JC-303');
      expect(isLatestUpgrade, isFalse);
    });

    test('Upgrades track script while preserving user dialed-in parameter settings', () {
      final state = DawState();
      final track = state.activeTrack;
      track.name = 'Eats 303';
      track.type = TrackType.eatScript;
      track.eatScriptCode = olderEats303Code;
      track.eatScriptParams = {
        'Cutoff': 3456.0,
        'Resonance': 14.5,
        'Decay': 0.85,
        'Waveform': 1.0,
      };

      // Before upgrade: has no custom GUI layout
      final beforeComp = EatEngine.compile(track.eatScriptCode);
      expect(beforeComp.guiLayout, isNull);
      expect(state.isPresetUpgradeAvailable(track), isTrue);

      // Perform non-destructive upgrade
      state.upgradeTrackPreset(track);

      // After upgrade: has updated script code with custom GUI
      expect(state.isPresetUpgradeAvailable(track), isFalse);
      final afterComp = EatEngine.compile(track.eatScriptCode);
      expect(afterComp.guiLayout, isNotNull);
      expect(afterComp.guiLayout!.title, contains('303'));

      // Verify parameter preservation
      expect(track.eatScriptParams['Cutoff'], equals(3456.0));
      expect(track.eatScriptParams['Resonance'], equals(14.5));
      expect(track.eatScriptParams['Decay'], equals(0.85));
      expect(track.eatScriptParams['Waveform'], equals(1.0));

      // Verify newly defined parameter (Drive) was populated with default
      expect(track.eatScriptParams.containsKey('Drive'), isTrue);
      expect(track.eatScriptParams['Drive'], equals(0.25));
    });

    test('Batch upgrades all project tracks', () {
      final state = DawState();
      final t1 = state.activeTrack;
      t1.name = 'Eats 303';
      t1.type = TrackType.eatScript;
      t1.eatScriptCode = olderEats303Code;

      const olderKickCode = '''
# @name: FM Acoustic Kick
local FmAcousticKick = {}
function FmAcousticKick.init()
  Param.add("NearPitchStart", 100.0, 300.0, 180.0)
  Param.add("NearPitchEnd", 30.0, 80.0, 52.0)
end
function FmAcousticKick.process(time, freq, note, params) return 0.0 end
return FmAcousticKick
''';
      final t2 = TrackChannel(
        id: 'kick_tr',
        name: 'FM Acoustic Kick',
        type: TrackType.eatScript,
        color: const Color(0xFF00FF66),
        eatScriptCode: olderKickCode,
        eatScriptParams: {'NearPitchStart': 220.0},
      );
      state.activePattern.tracks.add(t2);

      expect(state.availablePresetUpgradeCount, greaterThanOrEqualTo(2));

      state.upgradeAllTrackPresets();

      expect(state.availablePresetUpgradeCount, equals(0));
      expect(t2.eatScriptParams['NearPitchStart'], equals(220.0));
      expect(t2.eatScriptParams.containsKey('NearPitchEnd'), isTrue);
    });
  });
}
