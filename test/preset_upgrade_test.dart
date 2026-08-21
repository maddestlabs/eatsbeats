import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Preset Upgrade & Non-Destructive Migration Tests', () {
    const olderEats303Code = '''
-- @name: Eats 303
-- @category: instrument
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
      final isUpgrade = LuaPresetLibrary.isUpgradeAvailable(olderEats303Code, trackName: 'Eats 303');
      expect(isUpgrade, isTrue);

      final latestPreset = LuaPresetLibrary.presets.firstWhere((p) => p.id == 'acid_303');
      final isLatestUpgrade = LuaPresetLibrary.isUpgradeAvailable(latestPreset.code, trackName: 'Eats 303');
      expect(isLatestUpgrade, isFalse);
    });

    test('Upgrades track script while preserving user dialed-in parameter settings', () {
      final state = DawState();
      final track = state.activeTrack;
      track.name = 'Eats 303';
      track.type = TrackType.luaScript;
      track.luaScriptCode = olderEats303Code;
      track.luaParams = {
        'Cutoff': 3456.0,
        'Resonance': 14.5,
        'Decay': 0.85,
        'Waveform': 1.0,
      };

      // Before upgrade: has no custom GUI layout
      final beforeComp = LuaEngine.compile(track.luaScriptCode);
      expect(beforeComp.guiLayout, isNull);
      expect(state.isPresetUpgradeAvailable(track), isTrue);

      // Perform non-destructive upgrade
      state.upgradeTrackPreset(track);

      // After upgrade: has updated script code with custom GUI
      expect(state.isPresetUpgradeAvailable(track), isFalse);
      final afterComp = LuaEngine.compile(track.luaScriptCode);
      expect(afterComp.guiLayout, isNotNull);
      expect(afterComp.guiLayout!.title, contains('303'));

      // Verify parameter preservation
      expect(track.luaParams['Cutoff'], equals(3456.0));
      expect(track.luaParams['Resonance'], equals(14.5));
      expect(track.luaParams['Decay'], equals(0.85));
      expect(track.luaParams['Waveform'], equals(1.0));

      // Verify newly defined parameter (Overdrive) was populated with default
      expect(track.luaParams.containsKey('Overdrive'), isTrue);
      expect(track.luaParams['Overdrive'], equals(0.3));
    });

    test('Batch upgrades all project tracks', () {
      final state = DawState();
      final t1 = state.activeTrack;
      t1.name = 'Eats 303';
      t1.type = TrackType.luaScript;
      t1.luaScriptCode = olderEats303Code;

      const olderKickCode = '''
-- @name: Eats Kick
local ProceduralKick = {}
function ProceduralKick.init()
  Param.add("StartFreq", 100.0, 300.0, 160.0)
  Param.add("EndFreq", 30.0, 60.0, 42.0)
end
function ProceduralKick.process(time, freq, note, params) return 0.0 end
return ProceduralKick
''';
      final t2 = TrackChannel(
        id: 'kick_tr',
        name: 'Eats Kick',
        type: TrackType.luaScript,
        color: const Color(0xFF00FF66),
        luaScriptCode: olderKickCode,
        luaParams: {'StartFreq': 220.0},
      );
      state.activePattern.tracks.add(t2);

      expect(state.availablePresetUpgradeCount, greaterThanOrEqualTo(2));

      state.upgradeAllTrackPresets();

      expect(state.availablePresetUpgradeCount, equals(0));
      expect(t2.luaParams['StartFreq'], equals(220.0));
      expect(t2.luaParams.containsKey('EndFreq'), isTrue);
    });
  });
}
