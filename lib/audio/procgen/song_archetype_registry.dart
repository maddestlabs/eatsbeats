// Pure-Dart registry for Song Archetypes in Eatsbeats.
// Discovers, caches, and indexes exemplar songs from bundled assets and user storage.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../eatscript/eats_project_parser.dart';
import 'song_archetype.dart';

class SongArchetypeRegistry {
  static final Map<String, SongArchetype> _archetypes = {};
  static bool _initialized = false;

  /// Known bundled exemplar song asset paths.
  static const List<String> bundledAssetPaths = [
    'assets/archetypes/fantasy_rpg_midnight_bites.eats',
  ];

  /// Returns an unmodifiable list of all registered archetypes.
  static List<SongArchetype> get allArchetypes => List.unmodifiable(_archetypes.values);

  /// Returns all unique category names.
  static List<String> get categories =>
      _archetypes.values.map((a) => a.category).toSet().toList()..sort();

  /// Returns all unique tag names across all archetypes.
  static List<String> get allTags {
    final tags = <String>{};
    for (final a in _archetypes.values) {
      tags.addAll(a.tags);
    }
    return tags.toList()..sort();
  }

  /// Initializes the registry by scanning and parsing bundled archetype assets.
  static Future<void> initialize({AssetBundle? bundle}) async {
    if (_initialized && _archetypes.isNotEmpty) return;
    final activeBundle = bundle ?? rootBundle;

    for (final path in bundledAssetPaths) {
      try {
        final content = await activeBundle.loadString(path);
        registerFromEatString(content, sourcePath: path);
      } catch (e) {
        debugPrint('SongArchetypeRegistry: Note - could not load bundled asset $path: $e');
      }
    }
    _initialized = true;
  }

  /// Registers an archetype directly into the registry.
  static void registerArchetype(SongArchetype archetype) {
    _archetypes[archetype.archetypeId] = archetype;
  }

  /// Parses an `.eats` song string and registers it as an archetype if valid.
  static SongArchetype? registerFromEatString(String eatContent, {String? sourcePath}) {
    try {
      final map = EatProjectParser.parseLuaTableToMap(eatContent);
      if (map.isEmpty) return null;

      final archetype = SongArchetype.fromEatMap(map, sourcePath: sourcePath);
      _archetypes[archetype.archetypeId] = archetype;
      return archetype;
    } catch (e) {
      debugPrint('SongArchetypeRegistry: Failed to parse archetype from string: $e');
      return null;
    }
  }

  /// Look up an archetype by its unique ID.
  static SongArchetype? getById(String id) {
    final cleanId = id.toLowerCase().trim();
    if (_archetypes.containsKey(cleanId)) return _archetypes[cleanId];

    for (final entry in _archetypes.entries) {
      if (entry.key.toLowerCase() == cleanId) return entry.value;
    }
    return null;
  }

  /// Finds all archetypes belonging to a given category.
  static List<SongArchetype> findByCategory(String category) {
    final clean = category.toLowerCase().trim();
    return _archetypes.values
        .where((a) => a.category.toLowerCase().contains(clean))
        .toList();
  }

  /// Finds all archetypes matching a given search tag.
  static List<SongArchetype> findByTag(String tag) {
    final clean = tag.toLowerCase().trim();
    return _archetypes.values
        .where((a) => a.tags.any((t) => t.contains(clean)))
        .toList();
  }

  /// Finds archetypes that can cross-breed / blend well with the target archetype.
  static List<SongArchetype> findCompatible(String archetypeIdOrTag) {
    final clean = archetypeIdOrTag.toLowerCase().trim();
    final target = getById(clean);

    if (target != null) {
      return _archetypes.values.where((candidate) {
        if (candidate.archetypeId == target.archetypeId) return false;
        // Check mutual compatibility
        final directMatch = target.compatibleWith.any((c) =>
            candidate.archetypeId.toLowerCase().contains(c) ||
            candidate.tags.any((t) => t.toLowerCase().contains(c)) ||
            candidate.category.toLowerCase().contains(c));
        final reverseMatch = candidate.compatibleWith.any((c) =>
            target.archetypeId.toLowerCase().contains(c) ||
            target.tags.any((t) => t.toLowerCase().contains(c)));
        return directMatch || reverseMatch;
      }).toList();
    }

    // Fallback: match by tag or category
    return _archetypes.values
        .where((a) => a.tags.contains(clean) || a.compatibleWith.contains(clean))
        .toList();
  }

  /// Clears the registry (useful in unit testing).
  static void clear() {
    _archetypes.clear();
    _initialized = false;
  }

  /// Generates a compact, semantic summary of an archetype (200-400 tokens)
  /// designed for injection into Gemini AI Song Architect prompts as an exemplar.
  static String generateGeminiExemplarSummary(String archetypeId) {
    final a = getById(archetypeId);
    if (a == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('ARCHETYPE: "${a.title}" (ID: ${a.archetypeId})');
    buffer.writeln('- Category: ${a.category} | Key: ${a.songKey} | BPM: ${a.bpm.toStringAsFixed(1)} | Meter: ${a.meter}');
    buffer.writeln('- Tags: ${a.tags.join(', ')}');
    if (a.arrangerNotes.isNotEmpty) {
      buffer.writeln('- Arranger Notes: ${a.arrangerNotes}');
    }
    if (a.compatibleWith.isNotEmpty) {
      buffer.writeln('- Blends Well With: ${a.compatibleWith.join(', ')}');
    }
    buffer.writeln('- Lead Directives: Phrasing="${a.leadDirectives.phrasingStyle}", Ornaments=[${a.leadDirectives.ornamentation.join(', ')}], GlissandoDensity=${a.leadDirectives.glissandoDensity}');
    if (a.sectionHints.isNotEmpty) {
      buffer.writeln('- Section Directives:');
      for (final s in a.sectionHints.values) {
        final art = s.articulation != null ? ' (Artic: ${s.articulation})' : '';
        buffer.writeln('  * [${s.sectionName}]: ${s.directive}$art, Density: ${s.density}');
      }
    }
    return buffer.toString();
  }

  /// Generates a catalog summary of all available archetypes for AI context.
  static String generateAllExemplarSummaries() {
    if (_archetypes.isEmpty) return 'No local song archetypes registered.';
    final buffer = StringBuffer();
    buffer.writeln('AVAILABLE LOCAL SONG ARCHETYPES & EXEMPLARS:');
    for (final id in _archetypes.keys) {
      buffer.writeln('---');
      buffer.write(generateGeminiExemplarSummary(id));
    }
    return buffer.toString();
  }
}
