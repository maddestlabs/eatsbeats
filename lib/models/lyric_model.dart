import 'dart:convert';

/// Represents a single time-synchronized lyric syllable, word, or phrase event.
class LyricCue {
  String id;
  double startStep; // Musical time in 16th steps relative to track/clip start
  double durationSteps; // Duration in 16th steps (default 1.0)
  String text; // Syllable or word text (e.g. "Wel-", "come", "to")
  String? phoneticOverride; // Optional SSML/IPA phonetic override for TTS
  double pitch; // Optional relative pitch multiplier (0.5 to 2.0, default 1.0)
  double rate; // Optional relative speech rate multiplier (0.5 to 2.0, default 1.0)

  LyricCue({
    required this.id,
    required this.startStep,
    this.durationSteps = 1.0,
    required this.text,
    this.phoneticOverride,
    this.pitch = 1.0,
    this.rate = 1.0,
  });

  LyricCue copyWith({
    String? id,
    double? startStep,
    double? durationSteps,
    String? text,
    String? phoneticOverride,
    double? pitch,
    double? rate,
  }) {
    return LyricCue(
      id: id ?? this.id,
      startStep: startStep ?? this.startStep,
      durationSteps: durationSteps ?? this.durationSteps,
      text: text ?? this.text,
      phoneticOverride: phoneticOverride ?? this.phoneticOverride,
      pitch: pitch ?? this.pitch,
      rate: rate ?? this.rate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startStep': startStep,
        'durationSteps': durationSteps,
        'text': text,
        if (phoneticOverride != null) 'phoneticOverride': phoneticOverride,
        'pitch': pitch,
        'rate': rate,
      };

  factory LyricCue.fromJson(Map<String, dynamic> json) {
    return LyricCue(
      id: json['id'] as String? ?? 'cue_${DateTime.now().microsecondsSinceEpoch}',
      startStep: (json['startStep'] as num?)?.toDouble() ?? 0.0,
      durationSteps: (json['durationSteps'] as num?)?.toDouble() ?? 1.0,
      text: json['text'] as String? ?? '',
      phoneticOverride: json['phoneticOverride'] as String?,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Helper parser and serializer for Enhanced LRC and plain time-synced lyrics.
class LrcParser {
  static final RegExp _lrcTimestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
  static final RegExp _enhancedWordRegex = RegExp(r'<(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?>\s*([^<]+)');

  /// Parses an LRC string into a list of [LyricCue]s using project [bpm].
  /// Supports standard line-synced LRC and Enhanced word-synced LRC.
  static List<LyricCue> parse(String lrcContent, {double bpm = 120.0}) {
    final List<LyricCue> cues = [];
    final lines = const LineSplitter().convert(lrcContent);

    // 16th step duration in seconds: (60.0 / bpm) / 4.0
    final stepDurationSec = (60.0 / bpm) / 4.0;
    if (stepDurationSec <= 0) return cues;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('[ti:') || line.startsWith('[ar:') || line.startsWith('[al:') || line.startsWith('[by:') || line.startsWith('[offset:')) {
        continue;
      }

      // Check for timestamp match at beginning of line
      final match = _lrcTimestampRegex.firstMatch(line);
      if (match == null) continue;

      final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
      final millisStr = match.group(3) ?? '0';
      final millis = int.tryParse(millisStr.padRight(3, '0').substring(0, 3)) ?? 0;

      final lineTimeSec = (minutes * 60.0) + seconds + (millis / 1000.0);
      final lineStartStep = lineTimeSec / stepDurationSec;

      final contentAfterTime = line.substring(match.end).trim();

      // Check for Enhanced LRC word timestamps: e.g. <00:01.20> word <00:02.10> word2
      final wordMatches = _enhancedWordRegex.allMatches(contentAfterTime).toList();
      if (wordMatches.isNotEmpty) {
        for (int i = 0; i < wordMatches.length; i++) {
          final wMatch = wordMatches[i];
          final wMin = int.tryParse(wMatch.group(1) ?? '0') ?? 0;
          final wSec = int.tryParse(wMatch.group(2) ?? '0') ?? 0;
          final wMilStr = wMatch.group(3) ?? '0';
          final wMil = int.tryParse(wMilStr.padRight(3, '0').substring(0, 3)) ?? 0;

          final wordTimeSec = (wMin * 60.0) + wSec + (wMil / 1000.0);
          final wordStep = wordTimeSec / stepDurationSec;
          final wordText = (wMatch.group(4) ?? '').trim();

          double wordDur = 1.0;
          if (i + 1 < wordMatches.length) {
            final nextMin = int.tryParse(wordMatches[i + 1].group(1) ?? '0') ?? 0;
            final nextSec = int.tryParse(wordMatches[i + 1].group(2) ?? '0') ?? 0;
            final nextMilStr = wordMatches[i + 1].group(3) ?? '0';
            final nextMil = int.tryParse(nextMilStr.padRight(3, '0').substring(0, 3)) ?? 0;
            final nextSecTime = (nextMin * 60.0) + nextSec + (nextMil / 1000.0);
            wordDur = ((nextSecTime - wordTimeSec) / stepDurationSec).clamp(0.5, 16.0);
          }

          if (wordText.isNotEmpty) {
            cues.add(LyricCue(
              id: 'cue_${cues.length}_${wordStep.toStringAsFixed(1)}',
              startStep: wordStep,
              durationSteps: wordDur,
              text: wordText,
            ));
          }
        }
      } else if (contentAfterTime.isNotEmpty) {
        // Line-level lyric: split words across the line or treat as whole phrase
        cues.add(LyricCue(
          id: 'cue_${cues.length}_${lineStartStep.toStringAsFixed(1)}',
          startStep: lineStartStep,
          durationSteps: 4.0, // default 1 beat duration
          text: contentAfterTime,
        ));
      }
    }

    cues.sort((a, b) => a.startStep.compareTo(b.startStep));
    return cues;
  }

  /// Exports [LyricCue]s to standard LRC string format at given [bpm].
  static String exportToLrc(List<LyricCue> cues, {double bpm = 120.0, String title = 'Untitled', String artist = 'EatsBeats'}) {
    final buffer = StringBuffer();
    buffer.writeln('[ti:$title]');
    buffer.writeln('[ar:$artist]');
    buffer.writeln('[by:EatsBeats Mobile DAW]');

    final stepDurationSec = (60.0 / bpm) / 4.0;
    for (final cue in cues) {
      final totalSec = cue.startStep * stepDurationSec;
      final minutes = (totalSec ~/ 60).toString().padLeft(2, '0');
      final seconds = (totalSec % 60).floor().toString().padLeft(2, '0');
      final hundredths = (((totalSec % 60) - (totalSec % 60).floor()) * 100).floor().toString().padLeft(2, '0');
      buffer.writeln('[$minutes:$seconds.$hundredths] ${cue.text}');
    }

    return buffer.toString();
  }
}
