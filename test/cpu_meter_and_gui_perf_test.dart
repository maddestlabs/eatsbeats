import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/audio_engine.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/ui/transport_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CPU Meter & GUI Performance Optimization Tests', () {
    test('LuaEngine caches compilation results for identical scripts', () {
      const script = '''
local TestSynth = {}
function TestSynth.init()
  Param.add("Cutoff", 100.0, 10000.0, 2500.0)
end
function TestSynth.process(time, freq, note, params)
  return 0.0
end
return TestSynth
''';

      LuaEngine.clearCompilationCache();
      final res1 = LuaEngine.compile(script);
      final res2 = LuaEngine.compile(script);

      expect(res1.isSuccess, isTrue);
      expect(identical(res1, res2), isTrue); // Same cached instance returned in O(1)
    });

    test('AudioEngine records DSP execution and computes cpuLoad & cpuPercentage', () {
      final engine = AudioEngine();
      expect(engine.cpuLoad, greaterThanOrEqualTo(0.0));
      expect(engine.cpuPercentage, greaterThanOrEqualTo(0.0));

      // Simulate heavy DSP processing (e.g. 50ms processing for 100ms audio)
      engine.recordDspExecution(50000, 0.1);
      expect(engine.cpuLoad, greaterThan(0.05));
      expect(engine.cpuPercentage, greaterThan(5.0));

      final snapshot = engine.getMeterSnapshot();
      expect(snapshot.containsKey('cpuLoad'), isTrue);
      expect(snapshot.containsKey('cpuPercentage'), isTrue);
    });

    testWidgets('DawState toggles CPU meter and TransportHeader switches display on double-tap', (tester) async {
      final state = DawState();
      expect(state.showCpuMeter, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: state,
              builder: (context, _) => TransportHeader(dawState: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows L and R labels
      expect(find.text('L'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('CPU'), findsNothing);

      // Double-tap master meter to toggle to CPU meter
      final meterFinder = find.byTooltip('L/R Master Peak Meter - Double-tap for DSP CPU Meter');
      expect(meterFinder, findsOneWidget);
      await tester.tap(meterFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(meterFinder);
      await tester.pumpAndSettle();

      expect(state.showCpuMeter, isTrue);
      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('L'), findsNothing);

      // Double-tap again to toggle back to L/R Master meter
      final cpuMeterFinder = find.byTooltip('DSP CPU Load (${state.audioEngine.cpuPercentage.toStringAsFixed(1)}%) - Double-tap for L/R Audio Meter');
      expect(cpuMeterFinder, findsOneWidget);
      await tester.tap(cpuMeterFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(cpuMeterFinder);
      await tester.pumpAndSettle();

      expect(state.showCpuMeter, isFalse);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
    });
  });
}
