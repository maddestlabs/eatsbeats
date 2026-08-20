import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/easing.dart';
import 'package:mobile_wren_daw/audio/time_context.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/models/automation_model.dart';
import 'package:mobile_wren_daw/models/track_model.dart';

void main() {
  group('Easing Engine Tests', () {
    test('Linear interpolation produces correct midpoint', () {
      final v = Easing.interpolate(0.5, 100.0, 200.0, EasingType.linear);
      expect(v, closeTo(150.0, 1e-4));
    });

    test('Step / Hold holds start value until progress is 1.0', () {
      expect(Easing.interpolate(0.0, 10.0, 20.0, EasingType.step), equals(10.0));
      expect(Easing.interpolate(0.49, 10.0, 20.0, EasingType.step), equals(10.0));
      expect(Easing.interpolate(0.99, 10.0, 20.0, EasingType.step), equals(10.0));
      expect(Easing.interpolate(1.0, 10.0, 20.0, EasingType.step), equals(20.0));
    });

    test('Exponential interpolation scales smoothly between frequencies', () {
      final v = Easing.interpolate(0.5, 100.0, 10000.0, EasingType.exponential);
      expect(v, greaterThan(100.0));
      expect(v, lessThan(10000.0));
    });

    test('Smoothstep and Cubic Bezier stay within bounds', () {
      for (double t = 0.0; t <= 1.0; t += 0.1) {
        final sm = Easing.evaluateProgress(t, EasingType.smoothstep);
        expect(sm, greaterThanOrEqualTo(0.0));
        expect(sm, lessThanOrEqualTo(1.0));

        final cb = Easing.evaluateProgress(t, EasingType.cubicBezier);
        expect(cb, greaterThanOrEqualTo(0.0));
        expect(cb, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('Automation Model & Lane Evaluation Tests', () {
    test('AutomationLane evaluates continuous curve across multiple points', () {
      final lane = AutomationLane(
        id: 'test_lane',
        name: 'Filter Cutoff',
        target: AutomationTarget.cutoff,
        points: [
          AutomationPoint(id: 'p0', step: 0.0, value: 500.0, easing: EasingType.linear),
          AutomationPoint(id: 'p1', step: 16.0, value: 2500.0, easing: EasingType.linear),
          AutomationPoint(id: 'p2', step: 32.0, value: 500.0, easing: EasingType.linear),
        ],
      );

      expect(lane.evaluateAtStep(0.0), closeTo(500.0, 1e-2));
      expect(lane.evaluateAtStep(8.0), closeTo(1500.0, 1e-2));
      expect(lane.evaluateAtStep(16.0), closeTo(2500.0, 1e-2));
      expect(lane.evaluateAtStep(24.0), closeTo(1500.0, 1e-2));
      expect(lane.evaluateAtStep(32.0), closeTo(500.0, 1e-2));
    });

    test('Discrete target automatically enforces integer rounding and step hold', () {
      final regTarget = AutomationTarget.ymfmRegister('YM2612', 0x28, customName: 'Key On/Off');
      final lane = AutomationLane(
        id: 'reg_lane',
        name: 'YM2612 Register',
        target: regTarget,
        points: [
          AutomationPoint(id: 'p0', step: 0.0, value: 0.0),
          AutomationPoint(id: 'p1', step: 8.0, value: 240.0),
        ],
      );

      expect(lane.evaluateAtStep(0.0), equals(0.0));
      expect(lane.evaluateAtStep(4.0), equals(0.0)); // Holds at 0
      expect(lane.evaluateAtStep(8.0), equals(240.0)); // Jumps to 240
    });

    test('AutomationLane generates valid Lua script code', () {
      final lane = AutomationLane(
        id: 'test_lane',
        name: 'Volume',
        target: AutomationTarget.volume,
        points: [
          AutomationPoint(id: 'p0', step: 0.0, value: 0.2, easing: EasingType.linear),
          AutomationPoint(id: 'p1', step: 16.0, value: 0.8, easing: EasingType.sineInOut),
        ],
      );

      final lua = lane.generateLuaScript();
      expect(lua, contains('eatsbits.automation.evaluatePoints'));
      expect(lua, contains('target = "track.volume"'));
      expect(lua, contains('step = 0.00'));
      expect(lua, contains('step = 16.00'));
    });

    test('AutomationLane JSON serialization round-trip', () {
      final original = AutomationLane(
        id: 'lane_123',
        name: 'Track Volume',
        target: AutomationTarget.volume,
        enabled: true,
        points: [
          AutomationPoint(id: 'p0', step: 0.0, value: 0.5, easing: EasingType.cubicInOut, tension: 0.3),
          AutomationPoint(id: 'p1', step: 16.0, value: 1.2, easing: EasingType.smoothstep),
        ],
      );

      final json = original.toJson();
      final restored = AutomationLane.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.target.id, equals(original.target.id));
      expect(restored.points.length, equals(2));
      expect(restored.points[0].easing, equals(EasingType.cubicInOut));
      expect(restored.points[0].tension, equals(0.3));
      expect(restored.points[1].easing, equals(EasingType.smoothstep));
    });
  });

  group('Lua Engine Procedural Automation Evaluation Tests', () {
    test('LuaEngine evaluates procedural LFO script with TimeContext', () {
      final lane = AutomationLane(
        id: 'lfo_lane',
        name: 'LFO Cutoff',
        target: AutomationTarget.cutoff,
        isCustomLua: true,
        luaScriptCode: 'rate = 1.0\ndepth = 1000.0\ncenter = 2000.0\n-- lfo generator',
      );

      final timeCtx = TimeContext(
        bpm: 120.0,
        currentBar: 0.0,
        currentBeat: 0.0,
        audioTimeSeconds: 0.0,
      );

      final val0 = LuaEngine.evaluateAutomation(lane: lane, step: 0.0, timeCtx: timeCtx);
      expect(val0, closeTo(2000.0, 1e-2));

      final timeCtx1 = TimeContext(
        bpm: 120.0,
        currentBar: 0.0,
        currentBeat: 1.0, // Quarter wave (pi/2)
        audioTimeSeconds: 0.5,
      );
      final val1 = LuaEngine.evaluateAutomation(lane: lane, step: 4.0, timeCtx: timeCtx1);
      expect(val1, closeTo(3000.0, 1e-2)); // 2000 + 1000 * sin(pi/2) = 3000
    });
  });

  group('Track Model Automation Integration Tests', () {
    test('TrackChannel preserves automation lanes in JSON round-trip', () {
      final track = TrackChannel(
        id: 'tr_synth',
        name: 'Acid Bass',
        color: const Color(0xFFFF9800),
        type: TrackType.synth,
        automationLanes: [
          AutomationLane(
            id: 'auto_vol',
            name: 'Acid Bass Volume',
            target: AutomationTarget.volume,
            points: [
              AutomationPoint(id: 'p0', step: 0.0, value: 0.8),
              AutomationPoint(id: 'p1', step: 32.0, value: 1.2),
            ],
          ),
        ],
      );

      final json = track.toJson();
      final restored = TrackChannel.fromJson(json);

      expect(restored.automationLanes.length, equals(1));
      expect(restored.automationLanes.first.name, equals('Acid Bass Volume'));
      expect(restored.automationLanes.first.points.length, equals(2));
    });
  });
}
