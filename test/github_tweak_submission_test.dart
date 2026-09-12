import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/services/github_tweak_submission_service.dart';

void main() {
  group('GithubTweakSubmissionService Unit Tests', () {
    test('buildIssueBody contains markdown headers and payload delimiters', () {
      final body = GithubTweakSubmissionService.buildIssueBody(
        presetId: 'kick_channel_strip',
        presetName: 'Kick Channel Strip',
        eatCode: 'def gui():\n    return {}\n',
        description: 'Updated pitch dial styling',
        author: 'sound_designer_42',
      );

      expect(body, contains('### 🎛️ Eatsbeats GUI Tweak Submission'));
      expect(body, contains('<!-- EATSBEATS_PAYLOAD_START -->'));
      expect(body, contains('<!-- EATSBEATS_PAYLOAD_END -->'));
      expect(body, contains('preset_id: kick_channel_strip'));
      expect(body, contains('preset_name: "Kick Channel Strip"'));
      expect(body, contains('author: "sound_designer_42"'));
      expect(body, contains('Updated pitch dial styling'));
      expect(body, contains('def gui():'));
    });

    test('buildIssueUri produces valid GitHub issue URL with parameters', () {
      final uri = GithubTweakSubmissionService.buildIssueUri(
        presetId: 'moog_synth_bass',
        presetName: 'Moog Synth Bass',
        eatCode: 'def gui():\n    pass\n',
        description: 'Tighter layout',
      );

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('github.com'));
      expect(uri.path, equals('/maddestlabs/eatsbeats/issues/new'));
      expect(uri.queryParameters['labels'], equals('gui-patch'));
      expect(uri.queryParameters['title'], contains('[GUI Tweak] Moog Synth Bass (moog_synth_bass)'));
      expect(uri.queryParameters['body'], contains('preset_id: moog_synth_bass'));
    });

    test('inferPresetInfo resolves known presets and fallback names', () {
      final kick = GithubTweakSubmissionService.inferPresetInfo(
        code: '# @id: kick_channel_strip\nimport math',
        fallbackName: 'My Kick Track',
      );
      expect(kick.id, equals('kick_channel_strip'));
      expect(kick.name, equals('Kick Channel Strip'));

      final custom = GithubTweakSubmissionService.inferPresetInfo(
        code: 'def init(): pass',
        fallbackName: 'Acid Synth Lead',
      );
      expect(custom.id, equals('acid_synth_lead'));
      expect(custom.name, equals('Acid Synth Lead'));
    });

    test('isUrlTooLong and buildSafeIssueUri handle large payloads safely', () {
      final shortCode = 'def gui():\n    pass\n';
      expect(
        GithubTweakSubmissionService.isUrlTooLong(
          presetId: 'short_preset',
          presetName: 'Short Preset',
          eatCode: shortCode,
        ),
        isFalse,
      );

      final shortUri = GithubTweakSubmissionService.buildSafeIssueUri(
        presetId: 'short_preset',
        presetName: 'Short Preset',
        eatCode: shortCode,
      );
      expect(shortUri.queryParameters['body'], contains('def gui():'));

      // Generate a large payload (exceeding safe limit of 1800 chars)
      final largeCode = 'def gui():\n' + ('    # line of code here with details\n' * 80);
      expect(
        GithubTweakSubmissionService.isUrlTooLong(
          presetId: 'large_preset',
          presetName: 'Large Preset',
          eatCode: largeCode,
        ),
        isTrue,
      );

      final safeUri = GithubTweakSubmissionService.buildSafeIssueUri(
        presetId: 'large_preset',
        presetName: 'Large Preset',
        eatCode: largeCode,
      );

      expect(safeUri.toString().length, lessThan(1800));
      expect(safeUri.queryParameters['labels'], equals('gui-patch'));
      expect(safeUri.queryParameters['title'], contains('Large Preset'));
      expect(safeUri.queryParameters['body'], contains('Paste the copied'));
    });
  });
}
