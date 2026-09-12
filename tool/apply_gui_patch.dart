import 'dart:io';

/// Automated CLI tool for parsing a GitHub Issue body from an Eatsbeats GUI tweak
/// submission, locating the target `.eat` file, validating the payload, and updating the bundle.
///
/// Usage:
///   dart run tool/apply_gui_patch.dart <path_to_issue_body.md>
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/apply_gui_patch.dart <path_to_issue_body.md>');
    exit(1);
  }

  final issueFile = File(args[0]);
  if (!issueFile.existsSync()) {
    stderr.writeln('Error: Issue body file not found: ${args[0]}');
    exit(1);
  }

  final content = issueFile.readAsStringSync();
  print('Processing GUI tweak submission from ${args[0]}...');

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
  final codeMatch = RegExp(r'```(?:python|eatscript)?\s*\n([\s\S]*?)\n```').firstMatch(scanText);
  if (codeMatch == null) return null;
  final code = codeMatch.group(1)!.trim();

  return ExtractedPayload(
    presetId: presetId,
    presetName: presetName,
    code: code,
  );
}
