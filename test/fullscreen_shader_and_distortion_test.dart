import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eatsbeats/shaders/shader_model.dart';
import 'package:eatsbeats/shaders/shader_settings_manager.dart';
import 'package:eatsbeats/shaders/shader_distortion_remapper.dart';
import 'package:eatsbeats/ui/widgets/shader_picker_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shader Model & Catalog Tests', () {
    test('Built-in profiles are registered and valid', () {
      expect(BuiltInShaders.allProfiles.length, equals(3));

      final crt = BuiltInShaders.getProfileById(BuiltInShaders.apocalypseCrtId);
      expect(crt.name, equals('Apocalypse CRT'));
      expect(crt.isAnimated, isTrue);
      expect(crt.assetPath, equals('assets/shaders/apocalypse_crt.frag'));
      expect(crt.uniforms.isNotEmpty, isTrue);
      expect(crt.presets.containsKey('Default'), isTrue);
      expect(crt.presets.containsKey('Retro Arcade Bezel'), isTrue);
      expect(crt.presets.containsKey('Amber Terminal'), isTrue);
      expect(crt.presets.containsKey('Glitch Mode'), isTrue);
      expect(crt.curvatureMap, isNotNull);

      final access = BuiltInShaders.getProfileById(BuiltInShaders.accessibilityId);
      expect(access.name, equals('Color Profiles'));
      expect(access.presets.containsKey('Monochrome B&W'), isTrue);
      expect(access.presets.containsKey('Invert Colors'), isTrue);
      expect(access.presets.containsKey('Protanopia (Red-Weak)'), isTrue);
      expect(access.presets.containsKey('Deuteranopia (Green-Weak)'), isTrue);
      expect(access.presets.containsKey('Tritanopia (Blue-Weak)'), isTrue);
      expect(access.presets.containsKey('High Contrast'), isTrue);
    });

    test('Apocalypse CRT Curvature Math transforms points correctly', () {
      final crt = BuiltInShaders.getProfileById(BuiltInShaders.apocalypseCrtId);
      final curvatureFn = crt.curvatureMap!;

      // Center point (0.5, 0.5) should remain centered
      final center = const Offset(0.5, 0.5);
      final warpedCenter = curvatureFn(center, {'u_curve_strength': 0.35, 'u_frame_size': 0.0}, const Size(800, 600));
      expect(warpedCenter.dx, closeTo(0.5, 0.0001));
      expect(warpedCenter.dy, closeTo(0.5, 0.0001));

      // Corner point (0.0, 0.0) should bulge outward
      final corner = const Offset(0.0, 0.0);
      final warpedCorner = curvatureFn(corner, {'u_curve_strength': 0.35, 'u_frame_size': 0.0}, const Size(800, 600));
      expect(warpedCorner.dx, lessThan(0.0));
      expect(warpedCorner.dy, lessThan(0.0));
    });
  });

  group('ShaderSettingsManager Tests', () {
    test('Can switch active shader, apply presets, and update uniforms', () async {
      final manager = ShaderSettingsManager.instance;

      await manager.setActiveShader(BuiltInShaders.apocalypseCrtId);
      expect(manager.activeShaderId, equals(BuiltInShaders.apocalypseCrtId));
      expect(manager.hasActiveShader, isTrue);

      // Apply Retro preset
      await manager.applyPreset(BuiltInShaders.apocalypseCrtId, 'Retro Arcade Bezel');
      final retroCurve = manager.getUniformValue(BuiltInShaders.apocalypseCrtId, 'u_curve_strength');
      expect(retroCurve, equals(0.50));

      // Switch to Color Profiles and test Invert Colors preset
      await manager.setActiveShader(BuiltInShaders.accessibilityId);
      await manager.applyPreset(BuiltInShaders.accessibilityId, 'Invert Colors');
      final invertVal = manager.getUniformValue(BuiltInShaders.accessibilityId, 'u_invert');
      expect(invertVal, equals(1.0));

      // Switch back to none
      await manager.setActiveShader(BuiltInShaders.noneId);
      expect(manager.hasActiveShader, isFalse);
    });
  });

  group('ShaderDistortionPointerRemapper Widget Tests', () {
    testWidgets('Properly remaps pointer hit-testing coordinates', (tester) async {
      bool clicked = false;
      Offset? receivedTapOffset;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: ShaderDistortionPointerRemapper(
                  uvDistortionMap: (uv) {
                    // Identity map for center
                    return uv;
                  },
                  child: GestureDetector(
                    onTapDown: (details) {
                      clicked = true;
                      receivedTapOffset = details.localPosition;
                    },
                    child: Container(
                      color: Colors.blue,
                      child: const Center(child: Text('CRT Content')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('CRT Content'));
      await tester.pump();

      expect(clicked, isTrue);
      expect(receivedTapOffset, isNotNull);
    });
  });

  group('ShaderPickerDialog UI Tests', () {
    testWidgets('Renders shader selector and controls properly', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShaderPickerDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SCREEN SHADERS & CRT FX'), findsOneWidget);
      expect(find.text('SELECT SHADER EFFECT'), findsOneWidget);
      expect(find.text('Apocalypse CRT'), findsOneWidget);
      expect(find.text('Color Profiles'), findsOneWidget);

      // Select Apocalypse CRT
      await tester.tap(find.text('Apocalypse CRT'));
      await tester.pumpAndSettle();

      expect(find.text('FACTORY PRESETS'), findsOneWidget);

      // Scroll to verify Visual Effects section
      await tester.scrollUntilVisible(find.text('VISUAL EFFECTS'), 100);
      expect(find.text('VISUAL EFFECTS'), findsOneWidget);

      // Test preset button
      expect(find.text('RETRO ARCADE BEZEL'), findsOneWidget);
      await tester.tap(find.text('RETRO ARCADE BEZEL'));
      await tester.pumpAndSettle();

      // Reset to none for teardown
      await ShaderSettingsManager.instance.setActiveShader(BuiltInShaders.noneId);
    });
  });
}
