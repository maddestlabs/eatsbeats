import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/procgen/song_archetype.dart';
import 'package:eatsbeats/audio/procgen/song_archetype_registry.dart';
import 'package:eatsbeats/eatscript/eat_project_parser.dart';
import 'package:eatsbeats/eatscript/eat_project_serializer.dart';
import 'package:eatsbeats/models/daw_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SongArchetype & Registry Tests', () {
    late String exemplarContent;

    setUpAll(() {
      final file = File('assets/archetypes/fantasy_rpg_midnight_bites.eat');
      expect(file.existsSync(), isTrue, reason: 'Exemplar asset must exist at assets/archetypes/');
      exemplarContent = file.readAsStringSync();
    });

    setUp(() {
      SongArchetypeRegistry.clear();
    });

    test('Parses archetype procgen metadata from .eat exemplar file', () {
      final archetype = SongArchetypeRegistry.registerFromEatString(exemplarContent);
      expect(archetype, isNotNull);

      // Identity & Category
      expect(archetype!.archetypeId, equals('fantasy_rpg_midnight_bites'));
      expect(archetype.category, equals('Medieval Fantasy Adventure'));
      expect(archetype.title, equals('Midnight Bites (Ultima VI)'));
      expect(archetype.bpm, equals(120.0));
      expect(archetype.songKey, equals('C Major'));

      // Tags & Compatibility
      expect(archetype.tags, containsAll(['fantasy', 'rpg', 'medieval', 'acoustic_ensemble']));
      expect(archetype.compatibleWith, containsAll(['folk_ballad', 'celtic_jig', 'baroque_chamber']));
      expect(archetype.crossBreedWeight, closeTo(0.85, 0.001));

      // Lead Directives
      expect(archetype.leadDirectives.phrasingStyle, equals('antecedentConsequent'));
      expect(archetype.leadDirectives.preferredInstruments, contains('vibraphone'));
      expect(archetype.leadDirectives.glissandoDensity, closeTo(0.35, 0.001));
      expect(archetype.leadDirectives.ornamentation, contains('glissando'));

      // Section Hints & Articulations
      expect(archetype.sectionHints.containsKey('Intro'), isTrue);
      expect(archetype.sectionHints['Intro']!.articulation, equals('tirando_fingerpick'));
      expect(archetype.sectionHints['Intro']!.density, closeTo(0.40, 0.001));

      expect(archetype.sectionHints.containsKey('Theme B'), isTrue);
      expect(archetype.sectionHints['Theme B']!.articulation, equals('motor_tremolo'));

      expect(archetype.sectionHints.containsKey('Climax / Run'), isTrue);
      expect(archetype.sectionHints['Climax / Run']!.articulation, equals('glissando_run'));
    });

    test('Registry queries by ID, category, tag, and compatibility', () {
      SongArchetypeRegistry.registerFromEatString(exemplarContent);

      // Query by ID
      final byId = SongArchetypeRegistry.getById('fantasy_rpg_midnight_bites');
      expect(byId, isNotNull);
      expect(byId!.title, contains('Midnight Bites'));

      // Query by Category
      final byCat = SongArchetypeRegistry.findByCategory('Fantasy');
      expect(byCat.length, equals(1));

      // Query by Tag
      final byTag = SongArchetypeRegistry.findByTag('acoustic');
      expect(byTag.length, equals(1));

      // Query compatible (registering a companion archetype)
      final companion = SongArchetype(
        archetypeId: 'celtic_jig_greenwood',
        category: 'Celtic Folk',
        title: 'Greenwood Jig',
        tags: ['folk_ballad', 'celtic_jig'],
        compatibleWith: ['fantasy_rpg_midnight_bites'],
      );
      SongArchetypeRegistry.registerArchetype(companion);

      final compatible = SongArchetypeRegistry.findCompatible('fantasy_rpg_midnight_bites');
      expect(compatible.any((a) => a.archetypeId == 'celtic_jig_greenwood'), isTrue);
    });

    test('Generates compact AI prompt exemplar summary', () {
      SongArchetypeRegistry.registerFromEatString(exemplarContent);

      final summary = SongArchetypeRegistry.generateGeminiExemplarSummary('fantasy_rpg_midnight_bites');
      expect(summary, isNotEmpty);
      expect(summary, contains('Midnight Bites'));
      expect(summary, contains('Medieval Fantasy Adventure'));
      expect(summary, contains('tirando_fingerpick'));
      expect(summary, contains('motor_tremolo'));
      expect(summary, contains('glissando'));
    });

    test('DawState round-trip serialization preserves procgen metadata', () {
      final dawState1 = DawState(enableMeterTimer: false);
      final title = EatProjectParser.populateDawState(dawState1, exemplarContent);

      expect(title, contains('Midnight Bites'));
      expect(dawState1.songProcgenMeta, isNotNull);
      expect(dawState1.songArchetype, isNotNull);
      expect(dawState1.songArchetype!.archetypeId, equals('fantasy_rpg_midnight_bites'));
      expect(dawState1.songArchetype!.leadDirectives.glissandoDensity, closeTo(0.35, 0.001));

      // Serialize to .eat format
      final serialized = EatProjectSerializer.serialize(dawState1);
      expect(serialized, contains('procgen = {'));
      expect(serialized, contains('archetypeId = "fantasy_rpg_midnight_bites"'));
      expect(serialized, contains('tirando_fingerpick'));

      // Deserialize into second DawState
      final dawState2 = DawState(enableMeterTimer: false);
      EatProjectParser.populateDawState(dawState2, serialized);

      expect(dawState2.songProcgenMeta, isNotNull);
      expect(dawState2.songArchetype, isNotNull);
      expect(dawState2.songArchetype!.archetypeId, equals('fantasy_rpg_midnight_bites'));
      expect(dawState2.songArchetype!.category, equals('Medieval Fantasy Adventure'));
      expect(dawState2.songArchetype!.sectionHints['Intro']!.articulation, equals('tirando_fingerpick'));
    });
  });
}
