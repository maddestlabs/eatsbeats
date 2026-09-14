// Pure-Dart model for Song Archetypes in Eatsbeats.
// Represents exemplar songs with embedded procgen metadata that inform
// procedural generation and Gemini AI arrangement.

import 'dart:convert';
import 'ensemble_blueprint.dart';

/// Rhythmic and melodic phrasing unit extracted from an exemplar track note.
class ArchetypeNotePhrase {
  final double relativeStep;
  final double durationSteps;
  final int pitch;
  final int pitchInterval; // Semitone offset relative to song root pitch class
  final double velocity;
  final bool isSlide;
  final bool isAccent;

  const ArchetypeNotePhrase({
    required this.relativeStep,
    required this.durationSteps,
    required this.pitch,
    required this.pitchInterval,
    this.velocity = 0.80,
    this.isSlide = false,
    this.isAccent = false,
  });

  Map<String, dynamic> toMap() => {
    'relativeStep': relativeStep,
    'durationSteps': durationSteps,
    'pitch': pitch,
    'pitchInterval': pitchInterval,
    'velocity': velocity,
    'isSlide': isSlide,
    'isAccent': isAccent,
  };
}

/// Track profile extracted from an exemplar song, capturing its functional role and phrasing.
class ArchetypeTrackProfile {
  final String trackId;
  final String name;
  final String presetId;
  final FunctionalRole role;
  final List<ArchetypeNotePhrase> phrases;

  const ArchetypeTrackProfile({
    required this.trackId,
    required this.name,
    this.presetId = '',
    required this.role,
    this.phrases = const [],
  });

  bool get hasPhrases => phrases.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'trackId': trackId,
    'name': name,
    'presetId': presetId,
    'role': role.name,
    'phraseCount': phrases.length,
  };
}

/// Lead instrument phrasing & ornamentation directives for an archetype.
class ArchetypeLeadDirectives {
  final List<String> preferredInstruments;
  final String phrasingStyle;
  final List<String> ornamentation;
  final double glissandoDensity;
  final double climaxPosition;
  final Map<String, dynamic> rawProperties;

  const ArchetypeLeadDirectives({
    this.preferredInstruments = const [],
    this.phrasingStyle = 'antecedentConsequent',
    this.ornamentation = const [],
    this.glissandoDensity = 0.0,
    this.climaxPosition = 0.65,
    this.rawProperties = const {},
  });

  factory ArchetypeLeadDirectives.fromMap(Map<String, dynamic> map) {
    final rawPref = map['preferredInstruments'];
    final List<String> preferred = [];
    if (rawPref is List) {
      preferred.addAll(rawPref.map((e) => e.toString()));
    }

    final rawOrn = map['ornamentation'];
    final List<String> ornaments = [];
    if (rawOrn is List) {
      ornaments.addAll(rawOrn.map((e) => e.toString()));
    }

    return ArchetypeLeadDirectives(
      preferredInstruments: preferred,
      phrasingStyle: map['phrasingStyle']?.toString() ?? 'antecedentConsequent',
      ornamentation: ornaments,
      glissandoDensity: ((map['glissandoDensity'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
      climaxPosition: ((map['climaxPosition'] as num?)?.toDouble() ?? 0.65).clamp(0.0, 1.0),
      rawProperties: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() => {
    'preferredInstruments': preferredInstruments,
    'phrasingStyle': phrasingStyle,
    'ornamentation': ornamentation,
    'glissandoDensity': glissandoDensity,
    'climaxPosition': climaxPosition,
    ...rawProperties,
  };
}

/// Creative guidance and articulation directives for a song section.
class ArchetypeSectionHint {
  final String sectionName;
  final String directive;
  final String? articulation;
  final double density;
  final String? transition;
  final Map<String, dynamic> rawProperties;

  const ArchetypeSectionHint({
    required this.sectionName,
    required this.directive,
    this.articulation,
    this.density = 0.70,
    this.transition,
    this.rawProperties = const {},
  });

  factory ArchetypeSectionHint.fromMap(String name, Map<String, dynamic> map) {
    return ArchetypeSectionHint(
      sectionName: name,
      directive: map['directive']?.toString() ?? '',
      articulation: map['articulation']?.toString(),
      density: ((map['density'] as num?)?.toDouble() ?? 0.70).clamp(0.0, 1.0),
      transition: map['transition']?.toString(),
      rawProperties: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() => {
    'directive': directive,
    if (articulation != null) 'articulation': articulation,
    'density': density,
    if (transition != null) 'transition': transition,
    ...rawProperties,
  };
}

/// Complete Song Archetype model holding procedural and contextual metadata.
class SongArchetype {
  final String archetypeId;
  final String category;
  final String title;
  final String author;
  final double bpm;
  final String meter;
  final String songKey;
  final List<String> tags;
  final List<String> compatibleWith;
  final double crossBreedWeight;
  final String arrangerNotes;
  final ArchetypeLeadDirectives leadDirectives;
  final Map<String, ArchetypeSectionHint> sectionHints;
  final List<ArchetypeTrackProfile> tracks;
  final SongStructureBlueprint? blueprint;
  final String? sourcePath;
  final Map<String, dynamic> rawProcgenMap;

  const SongArchetype({
    required this.archetypeId,
    required this.category,
    required this.title,
    this.author = 'Eatsbeats',
    this.bpm = 120.0,
    this.meter = '4/4',
    this.songKey = 'C Major',
    this.tags = const [],
    this.compatibleWith = const [],
    this.crossBreedWeight = 0.80,
    this.arrangerNotes = '',
    this.leadDirectives = const ArchetypeLeadDirectives(),
    this.sectionHints = const {},
    this.tracks = const [],
    this.blueprint,
    this.sourcePath,
    this.rawProcgenMap = const {},
  });

  /// Whether this archetype includes a designated lead/melody track with note phrases.
  bool get hasLeadTrack => tracks.any((t) => t.role == FunctionalRole.primaryMelody && t.hasPhrases);

  /// The primary melody track profile if present in this archetype.
  ArchetypeTrackProfile? get leadProfile {
    for (final t in tracks) {
      if (t.role == FunctionalRole.primaryMelody && t.hasPhrases) return t;
    }
    return null;
  }

  /// Instantiates a [SongArchetype] from a parsed `.eats` table map.
  factory SongArchetype.fromEatMap(Map<String, dynamic> eatMap, {String? sourcePath}) {
    final meta = eatMap['meta'] is Map ? Map<String, dynamic>.from(eatMap['meta']) : {};
    final procgen = eatMap['procgen'] is Map
        ? Map<String, dynamic>.from(eatMap['procgen'])
        : (eatMap['procgenMeta'] is Map ? Map<String, dynamic>.from(eatMap['procgenMeta']) : <String, dynamic>{});

    final title = (meta['title'] as String?) ?? 'Untitled Archetype';
    final author = (meta['author'] as String?) ?? 'Eatsbeats';
    final bpm = ((meta['bpm'] as num?)?.toDouble() ?? 120.0).clamp(40.0, 240.0);
    final songKey = (meta['songKey'] as String?) ?? 'C Major';

    // Tags
    final List<String> tags = [];
    final rawTags = procgen['tags'] ?? meta['tags'];
    if (rawTags is List) {
      tags.addAll(rawTags.map((e) => e.toString().toLowerCase().trim()));
    }

    // Blend profiles
    final blendMap = procgen['blendProfiles'] is Map ? Map<String, dynamic>.from(procgen['blendProfiles']) : {};
    final List<String> compatible = [];
    final rawCompat = blendMap['compatibleWith'] ?? procgen['compatibleWith'];
    if (rawCompat is List) {
      compatible.addAll(rawCompat.map((e) => e.toString().toLowerCase().trim()));
    }
    final crossWeight = ((blendMap['crossBreedWeight'] as num?)?.toDouble() ?? 0.80).clamp(0.0, 1.0);

    // Lead Directives
    final Map<String, dynamic> leadMap = procgen['leadDirectives'] is Map
        ? Map<String, dynamic>.from(procgen['leadDirectives'] as Map)
        : <String, dynamic>{};
    final leadDirectives = ArchetypeLeadDirectives.fromMap(leadMap);

    // Section Hints
    final Map<String, ArchetypeSectionHint> hints = {};
    final rawHints = procgen['sectionHints'];
    if (rawHints is Map) {
      for (final entry in rawHints.entries) {
        if (entry.value is Map) {
          hints[entry.key.toString()] = ArchetypeSectionHint.fromMap(
            entry.key.toString(),
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    // Extract Track Profiles and Phrasing from patterns
    final rawPatterns = eatMap['patterns'];
    final List<ArchetypeTrackProfile> extractedTracks = [];
    if (rawPatterns is List && rawPatterns.isNotEmpty) {
      final firstPat = rawPatterns[0];
      if (firstPat is Map && firstPat['tracks'] is List) {
        final rawTrackList = firstPat['tracks'] as List;
        for (final t in rawTrackList) {
          if (t is Map) {
            final tId = t['id']?.toString() ?? '';
            final tName = t['name']?.toString() ?? 'Track';
            final tPreset = t['presetId']?.toString() ?? '';
            final explicitRole = t['role']?.toString();
            FunctionalRole role;
            if (explicitRole != null && explicitRole.isNotEmpty) {
              role = FunctionalRole.fromString(explicitRole);
            } else if (leadDirectives.preferredInstruments.any((p) => tName.toLowerCase().contains(p.toLowerCase()))) {
              role = FunctionalRole.primaryMelody;
            } else {
              role = FunctionalRole.fromString(tName);
            }

            final List<ArchetypeNotePhrase> phrases = [];
            final rawNotes = t['notes'];
            if (rawNotes is List) {
              for (final n in rawNotes) {
                if (n is Map) {
                  final pitch = (n['pitch'] as num?)?.toInt() ?? 60;
                  final start = (n['startStep'] as num?)?.toDouble() ?? 0.0;
                  final dur = (n['durationSteps'] as num?)?.toDouble() ?? 1.0;
                  final vel = (n['velocity'] as num?)?.toDouble() ?? 0.8;
                  final isSlide = (n['isSlide'] as bool?) ?? false;
                  final isAccent = (n['isAccent'] as bool?) ?? false;

                  phrases.add(ArchetypeNotePhrase(
                    relativeStep: start,
                    durationSteps: dur,
                    pitch: pitch,
                    pitchInterval: pitch % 12,
                    velocity: vel,
                    isSlide: isSlide,
                    isAccent: isAccent,
                  ));
                }
              }
            }
            phrases.sort((a, b) => a.relativeStep.compareTo(b.relativeStep));

            extractedTracks.add(ArchetypeTrackProfile(
              trackId: tId,
              name: tName,
              presetId: tPreset,
              role: role,
              phrases: phrases,
            ));
          }
        }
      }
    }

    // Blueprint parsing if present
    SongStructureBlueprint? bp;
    final rawBp = eatMap['blueprint'] ?? meta['blueprint'];
    if (rawBp is Map) {
      final rawStruct = rawBp['structure'];
      if (rawStruct is String && rawStruct.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawStruct);
          if (decoded is Map<String, dynamic>) {
            bp = SongStructureBlueprint.fromJson(decoded);
          }
        } catch (_) {}
      } else if (rawStruct is Map) {
        bp = SongStructureBlueprint.fromJson(Map<String, dynamic>.from(rawStruct));
      }
    }

    final id = procgen['archetypeId']?.toString() ??
        title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    final category = procgen['category']?.toString() ?? 'General';
    final arrangerNotes = procgen['arrangerNotes']?.toString() ?? '';
    final meter = bp?.meter ?? (meta['meter']?.toString() ?? '4/4');

    return SongArchetype(
      archetypeId: id,
      category: category,
      title: title,
      author: author,
      bpm: bpm,
      meter: meter,
      songKey: songKey,
      tags: tags,
      compatibleWith: compatible,
      crossBreedWeight: crossWeight,
      arrangerNotes: arrangerNotes,
      leadDirectives: leadDirectives,
      sectionHints: hints,
      tracks: extractedTracks,
      blueprint: bp,
      sourcePath: sourcePath,
      rawProcgenMap: procgen,
    );
  }

  /// Converts the archetype procgen metadata back into a format suitable for `.eats` serialization.
  Map<String, dynamic> toProcgenMap() {
    final hintsMap = <String, dynamic>{};
    for (final entry in sectionHints.entries) {
      hintsMap[entry.key] = entry.value.toMap();
    }

    return {
      'category': category,
      'archetypeId': archetypeId,
      'tags': tags,
      'blendProfiles': {
        'compatibleWith': compatibleWith,
        'crossBreedWeight': crossBreedWeight,
      },
      'arrangerNotes': arrangerNotes,
      'leadDirectives': leadDirectives.toMap(),
      'sectionHints': hintsMap,
      'hasLeadTrack': hasLeadTrack,
      ...rawProcgenMap,
    };
  }

  Map<String, dynamic> toJson() => {
    'archetypeId': archetypeId,
    'category': category,
    'title': title,
    'author': author,
    'bpm': bpm,
    'meter': meter,
    'songKey': songKey,
    'tags': tags,
    'compatibleWith': compatibleWith,
    'crossBreedWeight': crossBreedWeight,
    'arrangerNotes': arrangerNotes,
    'leadDirectives': leadDirectives.toMap(),
    'sectionHints': sectionHints.map((k, v) => MapEntry(k, v.toMap())),
    'hasLeadTrack': hasLeadTrack,
    'tracks': tracks.map((t) => t.toMap()).toList(),
    if (blueprint != null) 'blueprint': blueprint!.toJson(),
    if (sourcePath != null) 'sourcePath': sourcePath,
  };
}
