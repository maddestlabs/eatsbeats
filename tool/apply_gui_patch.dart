import 'dart:convert';
import 'dart:io';

/// Automated CLI tool for parsing a GitHub Issue body from an Eatsbeats GUI tweak
/// submission, locating the target `.eat` file, validating the payload, and updating the bundle.
///
/// Usage:
///   dart run tool/apply_gui_patch.dart <issue_number | issue_url | path_to_issue_body.md>
/// Examples:
///   dart run tool/apply_gui_patch.dart 2
///   dart run tool/apply_gui_patch.dart https://github.com/maddestlabs/eatsbeats/issues/2
///   dart run tool/apply_gui_patch.dart /tmp/issue_body.md
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/apply_gui_patch.dart <issue_number | issue_url | path_to_issue_body.md>');
    exit(1);
  }

  final content = await resolveContent(args[0]);
  print('Processing GUI tweak submission from "${args[0]}"...');

  final payload = extractPayload(content);
  if (payload == null) {
    stderr.writeln('Error: No valid EATSBEATS_PAYLOAD block found in issue body.');
    exit(2);
  }

  print('Extracted preset ID: "${payload.presetId}"');

  // Search for the target preset file in presets/
  final presetsDir = Directory('presets');
  if (!presetsDir.existsSync()) {
    stderr.writeln('Error: presets/ directory not found.');
    exit(3);
  }

  File? targetFile;
  for (final file in presetsDir.listSync(recursive: true).whereType<File>()) {
    if (file.path.endsWith('${payload.presetId}.eat')) {
      targetFile = file;
      break;
    }
  }

  if (targetFile == null) {
    stderr.writeln('Error: Target preset file "${payload.presetId}.eat" not found in presets/ tree.');
    exit(4);
  }

  print('Found target preset file: ${targetFile.path}');

  // Basic sanity validation
  if (!payload.code.contains('def gui():') && !payload.code.contains('def gui(')) {
    stderr.writeln('Error: Payload does not contain a "def gui():" definition.');
    exit(5);
  }

  // Backup original content
  final backup = targetFile.readAsStringSync();

  // Write updated code
  targetFile.writeAsStringSync(payload.code.trim() + '\n');
  print('Wrote updated code to ${targetFile.path}.');

  // Run bundle_presets.dart
  print('Running bundle_presets.dart...');
  final bundleResult = Process.runSync(
    Platform.executable,
    ['run', 'tool/bundle_presets.dart'],
  );

  if (bundleResult.exitCode != 0) {
    stderr.writeln('Bundle failed:\n${bundleResult.stderr}\nReverting changes.');
    targetFile.writeAsStringSync(backup);
    exit(6);
  }

  print('Successfully applied patch and regenerated eat_builtin_presets.g.dart!');
  print('RESULT_PRESET_ID=${payload.presetId}');
  print('RESULT_PRESET_NAME=${payload.presetName}');
  print('RESULT_TARGET_FILE=${targetFile.path.replaceAll("\\", "/")}');
}

class ExtractedPayload {
  final String presetId;
  final String presetName;
  final String code;

  ExtractedPayload({
    required this.presetId,
    required this.presetName,
    required this.code,
  });
}

ExtractedPayload? extractPayload(String rawText) {
  // Extract payload between delimiters if present, or scan whole text
  String scanText = rawText;
  const startMarker = '<!-- EATSBEATS_PAYLOAD_START -->';
  const endMarker = '<!-- EATSBEATS_PAYLOAD_END -->';

  if (rawText.contains(startMarker) && rawText.contains(endMarker)) {
    final start = rawText.indexOf(startMarker) + startMarker.length;
    final end = rawText.indexOf(endMarker);
    scanText = rawText.substring(start, end);
  }

  // Extract preset_id
  final idMatch = RegExp(r'preset_id:\s*([a-zA-Z0-9_-]+)').firstMatch(scanText);
  if (idMatch == null) return null;
  final presetId = idMatch.group(1)!.trim();

  // Extract preset_name
  String presetName = presetId;
  final nameMatch = RegExp(r'''preset_name:\s*["']?([^"'\r\n]+)["']?''').firstMatch(scanText);
  if (nameMatch != null) {
    presetName = nameMatch.group(1)!.trim();
  }

  // Extract python/eatscript code block
  // 1. Explicitly match ```python or ```eatscript
  final codeMatch = RegExp(r'```(?:python|eatscript)\s*\r?\n([\s\S]*?)\r?\n```').firstMatch(scanText);

  String? rawCode;
  if (codeMatch != null) {
    rawCode = codeMatch.group(1);
  } else {
    // 2. Fallback: match any code block that contains Eatscript keywords
    final allBlocks = RegExp(r'```[a-zA-Z]*\s*\r?\n([\s\S]*?)\r?\n```').allMatches(scanText).toList();
    if (allBlocks.isNotEmpty) {
      for (final block in allBlocks.reversed) {
        final candidate = block.group(1) ?? '';
        if (candidate.contains('def gui') || candidate.contains('def init') || candidate.contains('# @name:')) {
          rawCode = candidate;
          break;
        }
      }
      rawCode ??= allBlocks.last.group(1);
    }
  }

  if (rawCode == null) return null;

  // Clean any accidental markdown code fences or backticks that might have leaked in
  var cleanCode = rawCode.trim();
  while (cleanCode.startsWith('```')) {
    cleanCode = cleanCode.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*\r?\n?'), '').trim();
  }
  while (cleanCode.endsWith('```')) {
    cleanCode = cleanCode.replaceFirst(RegExp(r'\r?\n?```\s*$'), '').trim();
  }

  return ExtractedPayload(
    presetId: presetId,
    presetName: presetName,
    code: cleanCode,
  );
}

Future<String> resolveContent(String input) async {
  final trimmed = input.trim();
  final isNumber = RegExp(r'^\d+$').hasMatch(trimmed);
  final isUrl = trimmed.startsWith('http://') || trimmed.startsWith('https://');

  if (isNumber || isUrl) {
    String issueNumber = trimmed;
    if (isUrl) {
      final match = RegExp(r'/issues/(\d+)').firstMatch(trimmed);
      if (match != null) {
        issueNumber = match.group(1)!;
      }
    }

    final apiUrl = 'https://api.github.com/repos/maddestlabs/eatsbeats/issues/$issueNumber';
    print('Fetching issue #$issueNumber from GitHub ($apiUrl)...');

    final client = HttpClient();
    client.userAgent = 'Eatsbeats-CLI';
    final request = await client.getUrl(Uri.parse(apiUrl));
    final response = await request.close();

    if (response.statusCode != 200) {
      stderr.writeln('Error: Failed to fetch issue #$issueNumber (HTTP ${response.statusCode})');
      exit(1);
    }

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final issueBody = json['body'] as String?;
    if (issueBody == null || issueBody.isEmpty) {
      stderr.writeln('Error: Issue #$issueNumber has no body content.');
      exit(1);
    }
    return issueBody;
  }

  final issueFile = File(input);
  if (!issueFile.existsSync()) {
    stderr.writeln('Error: Input file or issue not found: $input');
    exit(1);
  }
  return issueFile.readAsStringSync();
}
