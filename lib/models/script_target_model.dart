import 'package:flutter/material.dart';

enum ScriptTargetType {
  trackDsp,
  midiFx,
  clipScript,
}

class ScriptTarget {
  final String id;
  final ScriptTargetType type;
  final String title;
  final String subtitle;
  final String trackId;
  final String trackName;
  final Color trackColor;
  final String? secondaryId; // midiFX.id or clip.id
  final String? clipName;

  const ScriptTarget({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.trackId,
    required this.trackName,
    required this.trackColor,
    this.secondaryId,
    this.clipName,
  });

  String get typeBadge {
    switch (type) {
      case ScriptTargetType.trackDsp:
        return 'SYNTH DSP';
      case ScriptTargetType.midiFx:
        return 'MIDI FX';
      case ScriptTargetType.clipScript:
        return 'CLIP SCRIPT';
    }
  }

  IconData get iconData {
    switch (type) {
      case ScriptTargetType.trackDsp:
        return Icons.piano;
      case ScriptTargetType.midiFx:
        return Icons.bolt;
      case ScriptTargetType.clipScript:
        return Icons.view_timeline;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScriptTarget && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
