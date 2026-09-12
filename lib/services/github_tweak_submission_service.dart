import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../eatscript/eat_script_library.dart';

/// Service for packaging and submitting mobile/desktop GUI tweaks and presets
/// directly to the GitHub repository without requiring authentication in-app.
class GithubTweakSubmissionService {
  static const String repoOwner = 'maddestlabs';
  static const String repoName = 'eatsbeats';
  static const String issueLabel = 'gui-patch';

  /// Safe maximum URL length for web browsers and GitHub proxy limits.
  /// GitHub's proxy returns HTTP 414 ("Your request URL is too long") for GET URLs
  /// over ~8,192 bytes, and mobile browser intents often limit to 2,000-4,000 bytes.
  static const int maxSafeUrlLength = 1800;

  /// Builds the structured markdown body for the GitHub Issue.
  static String buildIssueBody({
    required String presetId,
    required String presetName,
    required String eatCode,
    String? description,
    String? author,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('### 🎛️ Eatsbeats GUI Tweak Submission');
    buffer.writeln();
    if (description != null && description.trim().isNotEmpty) {
      buffer.writeln('**Description of Changes:**');
      buffer.writeln(description.trim());
      buffer.writeln();
    }
    buffer.writeln('<!-- EATSBEATS_PAYLOAD_START -->');
    buffer.writeln('```yaml');
    buffer.writeln('preset_id: $presetId');
    buffer.writeln('preset_name: "$presetName"');
    if (author != null && author.trim().isNotEmpty) {
      buffer.writeln('author: "$author"');
    }
    buffer.writeln('timestamp: ${DateTime.now().millisecondsSinceEpoch}');
    buffer.writeln('```');
    buffer.writeln();

    // Sanitize any accidental leading or trailing markdown fences in eatCode
    var cleanCode = eatCode.trim();
    while (cleanCode.startsWith('```')) {
      cleanCode = cleanCode.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*\r?\n?'), '').trim();
    }
    while (cleanCode.endsWith('```')) {
      cleanCode = cleanCode.replaceFirst(RegExp(r'\r?\n?```\s*$'), '').trim();
    }

    buffer.writeln('```python');
    buffer.writeln(cleanCode);
    buffer.writeln('```');
    buffer.writeln('<!-- EATSBEATS_PAYLOAD_END -->');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('*Submitted via Eatsbeats Visual Design Studio.*');

    return buffer.toString();
  }

  /// Builds a minimal instructional body used when the payload exceeds URL limits.
  static String buildMinimalInstructionBody() {
    final buffer = StringBuffer();
    buffer.writeln('### 🎛️ Eatsbeats GUI Tweak Submission');
    buffer.writeln();
    buffer.writeln('> 📋 **Paste the copied Eatscript GUI packet below:**');
    buffer.writeln();
    buffer.writeln('<!-- Paste your copied packet here -->');
    return buffer.toString();
  }

  /// Builds the pre-filled GitHub Issue URL with full payload.
  static Uri buildIssueUri({
    required String presetId,
    required String presetName,
    required String eatCode,
    String? description,
    String? author,
  }) {
    final title = '[GUI Tweak] $presetName ($presetId)';
    final body = buildIssueBody(
      presetId: presetId,
      presetName: presetName,
      eatCode: eatCode,
      description: description,
      author: author,
    );

    return Uri.https(
      'github.com',
      '/$repoOwner/$repoName/issues/new',
      {
        'title': title,
        'labels': issueLabel,
        'body': body,
      },
    );
  }

  /// Checks whether the full GitHub Issue URL exceeds the safe length limit.
  static bool isUrlTooLong({
    required String presetId,
    required String presetName,
    required String eatCode,
    String? description,
    String? author,
  }) {
    final uri = buildIssueUri(
      presetId: presetId,
      presetName: presetName,
      eatCode: eatCode,
      description: description,
      author: author,
    );
    return uri.toString().length > maxSafeUrlLength;
  }

  /// Builds a safe GitHub Issue URL, falling back to a minimal instructional body
  /// if the full payload would trigger GitHub's "Your request URL is too long" error.
  static Uri buildSafeIssueUri({
    required String presetId,
    required String presetName,
    required String eatCode,
    String? description,
    String? author,
  }) {
    final fullUri = buildIssueUri(
      presetId: presetId,
      presetName: presetName,
      eatCode: eatCode,
      description: description,
      author: author,
    );

    if (fullUri.toString().length <= maxSafeUrlLength) {
      return fullUri;
    }

    // Fallback to minimal URI that never exceeds HTTP URL limits
    final title = '[GUI Tweak] $presetName ($presetId)';
    return Uri.https(
      'github.com',
      '/$repoOwner/$repoName/issues/new',
      {
        'title': title,
        'labels': issueLabel,
        'body': buildMinimalInstructionBody(),
      },
    );
  }

  /// Copies the submission payload directly to the user clipboard.
  static Future<void> copyPayloadToClipboard({
    required String presetId,
    required String presetName,
    required String eatCode,
    String? description,
    String? author,
  }) async {
    final body = buildIssueBody(
      presetId: presetId,
      presetName: presetName,
      eatCode: eatCode,
      description: description,
      author: author,
    );
    await Clipboard.setData(ClipboardData(text: body));
  }

  /// Opens the user browser with the GitHub Issue.
  /// Automatically copies the full payload to the clipboard and uses the safe URI
  /// to prevent "URL is too long" HTTP 414 errors.
  ///
  /// Returns a record with `success` and `requiredClipboardPaste`.
  static Future<({bool success, bool requiredClipboardPaste})> openGitHubIssue({
    required String presetId,
    required String presetName,
    required String eatCode,
    String? description,
    String? author,
  }) async {
    // Always copy the payload to the clipboard first so it's immediately ready
    await copyPayloadToClipboard(
      presetId: presetId,
      presetName: presetName,
      eatCode: eatCode,
      description: description,
      author: author,
    );

    final isTooLong = isUrlTooLong(
      presetId: presetId,
      presetName: presetName,
      eatCode: eatCode,
      description: description,
      author: author,
    );

    final uri = buildSafeIssueUri(
      presetId: presetId,
      presetName: presetName,
      eatCode: eatCode,
      description: description,
      author: author,
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    return (
      success: launched,
      requiredClipboardPaste: isTooLong,
    );
  }

  /// Infers the best preset ID and name from current code or fallback name.
  static ({String id, String name}) inferPresetInfo({
    required String code,
    String? fallbackName,
    String? explicitId,
  }) {
    if (explicitId != null && explicitId.isNotEmpty) {
      final preset = EatScriptLibrary.getPresetById(explicitId);
      if (preset != null) {
        return (id: preset.id, name: preset.name);
      }
      return (
        id: explicitId,
        name: fallbackName ?? explicitId,
      );
    }

    final matched = EatScriptLibrary.findMatchingPreset(code, fallbackName: fallbackName);
    if (matched != null) {
      return (id: matched.id, name: matched.name);
    }

    final sanitizedId = (fallbackName ?? 'custom_preset')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return (
      id: sanitizedId,
      name: fallbackName ?? 'Custom Preset',
    );
  }
}
