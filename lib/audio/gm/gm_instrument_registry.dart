import '../../lua/lua_engine.dart';
import '../../lua/lua_script_library.dart';
import '../../models/track_model.dart';

/// General MIDI 1 instrument families (16 melodic families + GM percussion).
enum GmFamily {
  piano('Piano', 0, 7),
  chromaticPercussion('Chromatic Percussion', 8, 15),
  organ('Organ', 16, 23),
  guitar('Guitar', 24, 31),
  bass('Bass', 32, 39),
  soloStrings('Solo Strings', 40, 47),
  ensemble('Ensemble', 48, 55),
  brass('Brass', 56, 63),
  reed('Reed', 64, 71),
  pipe('Pipe', 72, 79),
  synthLead('Synth Lead', 80, 87),
  synthPad('Synth Pad', 88, 95),
  synthEffects('Synth Effects', 96, 103),
  ethnic('Ethnic', 104, 111),
  percussive('Percussive', 112, 119),
  soundEffects('Sound Effects', 120, 127),
  percussion('Percussion / Drum Kit', -1, -1);

  final String displayName;
  final int startProgram;
  final int endProgram;

  const GmFamily(this.displayName, this.startProgram, this.endProgram);
}

/// Metadata definition for a single General MIDI instrument.
class GmInstrumentDef {
  final int programNumber; // 0 to 127 (or -1 for percussion)
  final String gmName;
  final GmFamily family;
  final String? nativePresetId;
  final String iconName;
  final List<String> keywords;

  const GmInstrumentDef({
    required this.programNumber,
    required this.gmName,
    required this.family,
    this.nativePresetId,
    required this.iconName,
    this.keywords = const [],
  });

  bool get isNativeSupported => nativePresetId != null;
}

/// Result of resolving a MIDI track to an instrument in Eatsbeats.
class GmResolutionResult {
  final bool isNative;
  final String presetId;
  final String presetName;
  final String iconName;
  final TrackType trackType;
  final String sampleName;
  final double presetNum;
  final double bankNum;
  final String luaScriptCode;
  final Map<String, double> luaParams;
  final String matchReason;
  final GmInstrumentDef? matchedDef;

  const GmResolutionResult({
    required this.isNative,
    required this.presetId,
    required this.presetName,
    required this.iconName,
    required this.trackType,
    required this.sampleName,
    required this.presetNum,
    required this.bankNum,
    required this.luaScriptCode,
    required this.luaParams,
    required this.matchReason,
    this.matchedDef,
  });
}

/// Central registry for General MIDI 1 instruments in Eatsbeats.
/// Provides mapping from MIDI Program Change numbers & semantic track names
/// to custom native instruments, with automatic fallback to the SoundFont sampler.
/// Also provides audit utilities to track progress toward 100% native GM coverage.
class GmInstrumentRegistry {
  /// Complete definition of all 128 General MIDI 1 instruments.
  static const List<GmInstrumentDef> spec = [
    // -------------------------------------------------------------
    // Family 0: Piano (0 - 7)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 0,
      gmName: 'Acoustic Grand Piano',
      family: GmFamily.piano,
      nativePresetId: 'concert_grand_piano',
      iconName: 'piano',
      keywords: ['grand piano', 'acoustic piano', 'concert grand', 'piano'],
    ),
    GmInstrumentDef(
      programNumber: 1,
      gmName: 'Bright Acoustic Piano',
      family: GmFamily.piano,
      nativePresetId: 'felt_upright_piano',
      iconName: 'piano',
      keywords: ['bright piano', 'felt piano', 'upright piano', 'studio upright'],
    ),
    GmInstrumentDef(
      programNumber: 2,
      gmName: 'Electric Grand Piano',
      family: GmFamily.piano,
      nativePresetId: 'felt_upright_piano',
      iconName: 'piano',
      keywords: ['electric grand', 'cp80', 'cp70'],
    ),
    GmInstrumentDef(
      programNumber: 3,
      gmName: 'Honky-tonk Piano',
      family: GmFamily.piano,
      nativePresetId: 'honky_tonk_piano',
      iconName: 'piano',
      keywords: ['honky tonk', 'honkytonk', 'tack piano', 'saloon piano'],
    ),
    GmInstrumentDef(
      programNumber: 4,
      gmName: 'Electric Piano 1 (Rhodes)',
      family: GmFamily.piano,
      nativePresetId: 'rhodes_epiano',
      iconName: 'piano',
      keywords: ['rhodes', 'electric piano 1', 'stage 73', 'epiano 1', 'ep 1'],
    ),
    GmInstrumentDef(
      programNumber: 5,
      gmName: 'Electric Piano 2 (DX7 FM)',
      family: GmFamily.piano,
      nativePresetId: 'dx7_epiano',
      iconName: 'piano',
      keywords: ['dx7', 'electric piano 2', 'fm epiano', 'epiano 2', 'ep 2', 'fulltines'],
    ),
    GmInstrumentDef(
      programNumber: 6,
      gmName: 'Harpsichord',
      family: GmFamily.piano,
      nativePresetId: 'harpsichord_cembalo',
      iconName: 'piano',
      keywords: ['harpsichord', 'cembalo', 'virginal', 'clavecin'],
    ),
    GmInstrumentDef(
      programNumber: 7,
      gmName: 'Clavinet',
      family: GmFamily.piano,
      nativePresetId: 'clavinet_d6',
      iconName: 'piano',
      keywords: ['clavinet', 'clavinet d6', 'clav', 'hohner clav'],
    ),

    // -------------------------------------------------------------
    // Family 1: Chromatic Percussion (8 - 15)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 8,
      gmName: 'Celesta',
      family: GmFamily.chromaticPercussion,
      nativePresetId: 'toy_piano',
      iconName: 'synth',
      keywords: ['celesta', 'celeste'],
    ),
    GmInstrumentDef(
      programNumber: 9,
      gmName: 'Glockenspiel',
      family: GmFamily.chromaticPercussion,
      nativePresetId: 'glockenspiel',
      iconName: 'synth',
      keywords: ['glockenspiel', 'glock', 'bells'],
    ),
    GmInstrumentDef(
      programNumber: 10,
      gmName: 'Music Box',
      family: GmFamily.chromaticPercussion,
      nativePresetId: 'music_box',
      iconName: 'synth',
      keywords: ['music box', 'musicbox', 'carillon'],
    ),
    GmInstrumentDef(
      programNumber: 11,
      gmName: 'Vibraphone',
      family: GmFamily.chromaticPercussion,
      nativePresetId: 'vibraphone',
      iconName: 'synth',
      keywords: ['vibraphone', 'vibes'],
    ),
    GmInstrumentDef(
      programNumber: 12,
      gmName: 'Marimba',
      family: GmFamily.chromaticPercussion,
      nativePresetId: 'xylophone',
      iconName: 'synth',
      keywords: ['marimba'],
    ),
    GmInstrumentDef(
      programNumber: 13,
      gmName: 'Xylophone',
      family: GmFamily.chromaticPercussion,
      nativePresetId: 'xylophone',
      iconName: 'synth',
      keywords: ['xylophone', 'xylo'],
    ),
    GmInstrumentDef(
      programNumber: 14,
      gmName: 'Tubular Bells',
      family: GmFamily.chromaticPercussion,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['tubular bells', 'chimes', 'orchestral bells'],
    ),
    GmInstrumentDef(
      programNumber: 15,
      gmName: 'Dulcimer',
      family: GmFamily.chromaticPercussion,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['dulcimer', 'santur', 'cimbalom'],
    ),

    // -------------------------------------------------------------
    // Family 2: Organ (16 - 23)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 16,
      gmName: 'Drawbar Organ',
      family: GmFamily.organ,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['drawbar organ', 'hammond', 'b3 organ', 'tonewheel'],
    ),
    GmInstrumentDef(
      programNumber: 17,
      gmName: 'Percussive Organ',
      family: GmFamily.organ,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['percussive organ'],
    ),
    GmInstrumentDef(
      programNumber: 18,
      gmName: 'Rock Organ',
      family: GmFamily.organ,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['rock organ'],
    ),
    GmInstrumentDef(
      programNumber: 19,
      gmName: 'Church Organ',
      family: GmFamily.organ,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['church organ', 'pipe organ', 'cathedral organ'],
    ),
    GmInstrumentDef(
      programNumber: 20,
      gmName: 'Reed Organ',
      family: GmFamily.organ,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['reed organ', 'harmonium'],
    ),
    GmInstrumentDef(
      programNumber: 21,
      gmName: 'Accordion',
      family: GmFamily.organ,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['accordion', 'musette'],
    ),
    GmInstrumentDef(
      programNumber: 22,
      gmName: 'Harmonica',
      family: GmFamily.organ,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['harmonica', 'blues harp'],
    ),
    GmInstrumentDef(
      programNumber: 23,
      gmName: 'Tango Accordion',
      family: GmFamily.organ,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['tango accordion', 'bandoneon'],
    ),

    // -------------------------------------------------------------
    // Family 3: Guitar (24 - 31)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 24,
      gmName: 'Acoustic Guitar (nylon)',
      family: GmFamily.guitar,
      nativePresetId: 'spanish_guitar',
      iconName: 'guitar',
      keywords: ['nylon guitar', 'spanish guitar', 'classical guitar', 'acoustic guitar (nylon)'],
    ),
    GmInstrumentDef(
      programNumber: 25,
      gmName: 'Acoustic Guitar (steel)',
      family: GmFamily.guitar,
      nativePresetId: 'acoustic_steel_guitar',
      iconName: 'guitar',
      keywords: ['steel guitar', 'acoustic steel', 'acoustic guitar', 'folk guitar', 'steel string'],
    ),
    GmInstrumentDef(
      programNumber: 26,
      gmName: 'Electric Guitar (jazz)',
      family: GmFamily.guitar,
      nativePresetId: 'pedal_steel_guitar',
      iconName: 'guitar',
      keywords: ['jazz guitar', 'hollow body', 'archtop'],
    ),
    GmInstrumentDef(
      programNumber: 27,
      gmName: 'Electric Guitar (clean)',
      family: GmFamily.guitar,
      nativePresetId: 'reggae_guitar',
      iconName: 'guitar',
      keywords: ['clean guitar', 'electric guitar (clean)', 'skank guitar', 'reggae guitar', 'strat clean'],
    ),
    GmInstrumentDef(
      programNumber: 28,
      gmName: 'Electric Guitar (muted)',
      family: GmFamily.guitar,
      nativePresetId: null,
      iconName: 'guitar',
      keywords: ['muted guitar', 'palm mute'],
    ),
    GmInstrumentDef(
      programNumber: 29,
      gmName: 'Overdriven Guitar',
      family: GmFamily.guitar,
      nativePresetId: null,
      iconName: 'guitar',
      keywords: ['overdrive guitar', 'overdriven guitar', 'crunch guitar'],
    ),
    GmInstrumentDef(
      programNumber: 30,
      gmName: 'Distortion Guitar',
      family: GmFamily.guitar,
      nativePresetId: null,
      iconName: 'guitar',
      keywords: ['distortion guitar', 'dist guitar', 'heavy guitar', 'rock guitar'],
    ),
    GmInstrumentDef(
      programNumber: 31,
      gmName: 'Guitar Harmonics',
      family: GmFamily.guitar,
      nativePresetId: null,
      iconName: 'guitar',
      keywords: ['guitar harmonics'],
    ),

    // -------------------------------------------------------------
    // Family 4: Bass (32 - 39)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 32,
      gmName: 'Acoustic Bass',
      family: GmFamily.bass,
      nativePresetId: 'acoustic_bass',
      iconName: 'bass',
      keywords: ['acoustic bass', 'upright bass', 'acoustic upright bass'],
    ),
    GmInstrumentDef(
      programNumber: 33,
      gmName: 'Electric Bass (finger)',
      family: GmFamily.bass,
      nativePresetId: null,
      iconName: 'bass',
      keywords: ['finger bass', 'electric bass (finger)', 'fingered bass', 'precision bass'],
    ),
    GmInstrumentDef(
      programNumber: 34,
      gmName: 'Electric Bass (pick)',
      family: GmFamily.bass,
      nativePresetId: null,
      iconName: 'bass',
      keywords: ['pick bass', 'electric bass (pick)', 'picked bass'],
    ),
    GmInstrumentDef(
      programNumber: 35,
      gmName: 'Fretless Bass',
      family: GmFamily.bass,
      nativePresetId: 'fretless_bass',
      iconName: 'bass',
      keywords: ['fretless bass', 'fretless'],
    ),
    GmInstrumentDef(
      programNumber: 36,
      gmName: 'Slap Bass 1',
      family: GmFamily.bass,
      nativePresetId: null,
      iconName: 'bass',
      keywords: ['slap bass 1', 'slap bass'],
    ),
    GmInstrumentDef(
      programNumber: 37,
      gmName: 'Slap Bass 2',
      family: GmFamily.bass,
      nativePresetId: null,
      iconName: 'bass',
      keywords: ['slap bass 2', 'pop bass'],
    ),
    GmInstrumentDef(
      programNumber: 38,
      gmName: 'Synth Bass 1',
      family: GmFamily.bass,
      nativePresetId: 'moog_synth_bass',
      iconName: 'bass',
      keywords: ['synth bass 1', 'moog bass', 'analog bass', 'synth bass'],
    ),
    GmInstrumentDef(
      programNumber: 39,
      gmName: 'Synth Bass 2',
      family: GmFamily.bass,
      nativePresetId: 'eats_303',
      iconName: 'bass',
      keywords: ['synth bass 2', 'acid bass', '303 bass', 'tb303', 'eats 303'],
    ),

    // -------------------------------------------------------------
    // Family 5: Strings (40 - 47)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 40,
      gmName: 'Violin',
      family: GmFamily.soloStrings,
      nativePresetId: 'solo_violin',
      iconName: 'strings',
      keywords: ['violin', 'solo violin', 'fiddle'],
    ),
    GmInstrumentDef(
      programNumber: 41,
      gmName: 'Viola',
      family: GmFamily.soloStrings,
      nativePresetId: 'solo_viola',
      iconName: 'strings',
      keywords: ['viola', 'solo viola'],
    ),
    GmInstrumentDef(
      programNumber: 42,
      gmName: 'Cello',
      family: GmFamily.soloStrings,
      nativePresetId: 'solo_cello',
      iconName: 'strings',
      keywords: ['cello', 'solo cello', 'violoncello'],
    ),
    GmInstrumentDef(
      programNumber: 43,
      gmName: 'Contrabass',
      family: GmFamily.soloStrings,
      nativePresetId: 'double_bass',
      iconName: 'strings',
      keywords: ['contrabass', 'double bass', 'string bass'],
    ),
    GmInstrumentDef(
      programNumber: 44,
      gmName: 'Tremolo Strings',
      family: GmFamily.soloStrings,
      nativePresetId: null,
      iconName: 'strings',
      keywords: ['tremolo strings'],
    ),
    GmInstrumentDef(
      programNumber: 45,
      gmName: 'Pizzicato Strings',
      family: GmFamily.soloStrings,
      nativePresetId: null,
      iconName: 'strings',
      keywords: ['pizzicato', 'pizz strings'],
    ),
    GmInstrumentDef(
      programNumber: 46,
      gmName: 'Orchestral Harp',
      family: GmFamily.soloStrings,
      nativePresetId: 'harp_guitar',
      iconName: 'strings',
      keywords: ['harp', 'orchestral harp', 'harp guitar'],
    ),
    GmInstrumentDef(
      programNumber: 47,
      gmName: 'Timpani',
      family: GmFamily.soloStrings,
      nativePresetId: null,
      iconName: 'drums',
      keywords: ['timpani', 'kettle drums'],
    ),

    // -------------------------------------------------------------
    // Family 6: Ensemble (48 - 55)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 48,
      gmName: 'String Ensemble 1',
      family: GmFamily.ensemble,
      nativePresetId: 'string_ensemble',
      iconName: 'strings',
      keywords: ['string ensemble 1', 'string ensemble', 'strings', 'orchestral strings', 'symphonic strings'],
    ),
    GmInstrumentDef(
      programNumber: 49,
      gmName: 'String Ensemble 2',
      family: GmFamily.ensemble,
      nativePresetId: 'string_ensemble',
      iconName: 'strings',
      keywords: ['string ensemble 2', 'slow strings'],
    ),
    GmInstrumentDef(
      programNumber: 50,
      gmName: 'Synth Strings 1',
      family: GmFamily.ensemble,
      nativePresetId: null,
      iconName: 'strings',
      keywords: ['synth strings 1', 'synth strings'],
    ),
    GmInstrumentDef(
      programNumber: 51,
      gmName: 'Synth Strings 2',
      family: GmFamily.ensemble,
      nativePresetId: null,
      iconName: 'strings',
      keywords: ['synth strings 2'],
    ),
    GmInstrumentDef(
      programNumber: 52,
      gmName: 'Choir Aahs',
      family: GmFamily.ensemble,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['choir aahs', 'choir'],
    ),
    GmInstrumentDef(
      programNumber: 53,
      gmName: 'Voice Oohs',
      family: GmFamily.ensemble,
      nativePresetId: 'tts_voice_synth',
      iconName: 'synth',
      keywords: ['voice oohs', 'voice', 'vocal', 'tts voice'],
    ),
    GmInstrumentDef(
      programNumber: 54,
      gmName: 'Synth Voice',
      family: GmFamily.ensemble,
      nativePresetId: 'tts_voice_synth',
      iconName: 'synth',
      keywords: ['synth voice', 'formant synth', 'vocoder'],
    ),
    GmInstrumentDef(
      programNumber: 55,
      gmName: 'Orchestra Hit',
      family: GmFamily.ensemble,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['orchestra hit', 'orch hit'],
    ),

    // -------------------------------------------------------------
    // -------------------------------------------------------------
    // Family 7: Brass (56 - 63)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 56,
      gmName: 'Trumpet',
      family: GmFamily.brass,
      nativePresetId: 'orchestral_trumpet',
      iconName: 'synth',
      keywords: ['trumpet', 'orchestral trumpet'],
    ),
    GmInstrumentDef(
      programNumber: 57,
      gmName: 'Trombone',
      family: GmFamily.brass,
      nativePresetId: 'tenor_trombone',
      iconName: 'synth',
      keywords: ['trombone', 'tenor trombone'],
    ),
    GmInstrumentDef(
      programNumber: 58,
      gmName: 'Tuba',
      family: GmFamily.brass,
      nativePresetId: 'tuba_brass',
      iconName: 'synth',
      keywords: ['tuba', 'bass tuba'],
    ),
    GmInstrumentDef(
      programNumber: 59,
      gmName: 'Muted Trumpet',
      family: GmFamily.brass,
      nativePresetId: 'muted_trumpet',
      iconName: 'synth',
      keywords: ['muted trumpet', 'harmon trumpet'],
    ),
    GmInstrumentDef(
      programNumber: 60,
      gmName: 'French Horn',
      family: GmFamily.brass,
      nativePresetId: 'french_horn',
      iconName: 'synth',
      keywords: ['french horn', 'horn', 'cor'],
    ),
    GmInstrumentDef(
      programNumber: 61,
      gmName: 'Brass Section',
      family: GmFamily.brass,
      nativePresetId: 'brass_section',
      iconName: 'synth',
      keywords: ['brass section', 'brass', 'brass ensemble'],
    ),
    GmInstrumentDef(
      programNumber: 62,
      gmName: 'Synth Brass 1',
      family: GmFamily.brass,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['synth brass 1', 'synth brass'],
    ),
    GmInstrumentDef(
      programNumber: 63,
      gmName: 'Synth Brass 2',
      family: GmFamily.brass,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['synth brass 2'],
    ),

    // -------------------------------------------------------------
    // Family 8: Reed (64 - 71)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 64,
      gmName: 'Soprano Sax',
      family: GmFamily.reed,
      nativePresetId: 'soprano_sax',
      iconName: 'synth',
      keywords: ['soprano sax'],
    ),
    GmInstrumentDef(
      programNumber: 65,
      gmName: 'Alto Sax',
      family: GmFamily.reed,
      nativePresetId: 'alto_sax',
      iconName: 'synth',
      keywords: ['alto sax', 'saxophone', 'sax'],
    ),
    GmInstrumentDef(
      programNumber: 66,
      gmName: 'Tenor Sax',
      family: GmFamily.reed,
      nativePresetId: 'tenor_sax',
      iconName: 'synth',
      keywords: ['tenor sax'],
    ),
    GmInstrumentDef(
      programNumber: 67,
      gmName: 'Baritone Sax',
      family: GmFamily.reed,
      nativePresetId: 'baritone_sax',
      iconName: 'synth',
      keywords: ['baritone sax', 'bari sax'],
    ),
    GmInstrumentDef(
      programNumber: 68,
      gmName: 'Oboe',
      family: GmFamily.reed,
      nativePresetId: 'oboe_woodwind',
      iconName: 'synth',
      keywords: ['oboe'],
    ),
    GmInstrumentDef(
      programNumber: 69,
      gmName: 'English Horn',
      family: GmFamily.reed,
      nativePresetId: 'english_horn',
      iconName: 'synth',
      keywords: ['english horn', 'cor anglais'],
    ),
    GmInstrumentDef(
      programNumber: 70,
      gmName: 'Bassoon',
      family: GmFamily.reed,
      nativePresetId: 'bassoon_woodwind',
      iconName: 'synth',
      keywords: ['bassoon'],
    ),
    GmInstrumentDef(
      programNumber: 71,
      gmName: 'Clarinet',
      family: GmFamily.reed,
      nativePresetId: 'clarinet_woodwind',
      iconName: 'synth',
      keywords: ['clarinet'],
    ),

    // -------------------------------------------------------------
    // Family 9: Pipe (72 - 79)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 72,
      gmName: 'Piccolo',
      family: GmFamily.pipe,
      nativePresetId: 'concert_piccolo',
      iconName: 'synth',
      keywords: ['piccolo', 'concert piccolo', 'ottavino'],
    ),
    GmInstrumentDef(
      programNumber: 73,
      gmName: 'Flute',
      family: GmFamily.pipe,
      nativePresetId: 'concert_flute',
      iconName: 'synth',
      keywords: ['flute', 'concert flute', 'transverse flute', 'c flute'],
    ),
    GmInstrumentDef(
      programNumber: 74,
      gmName: 'Recorder',
      family: GmFamily.pipe,
      nativePresetId: 'wooden_recorder',
      iconName: 'synth',
      keywords: ['recorder', 'wooden recorder', 'blockflöte', 'flauto dolce'],
    ),
    GmInstrumentDef(
      programNumber: 75,
      gmName: 'Pan Flute',
      family: GmFamily.pipe,
      nativePresetId: 'pan_flute',
      iconName: 'synth',
      keywords: ['pan flute', 'panpipes', 'panpipe', 'zampona', 'zampoña', 'siku'],
    ),
    GmInstrumentDef(
      programNumber: 76,
      gmName: 'Blown Bottle',
      family: GmFamily.pipe,
      nativePresetId: 'blown_bottle',
      iconName: 'fx',
      keywords: ['blown bottle', 'bottle', 'glass bottle'],
    ),
    GmInstrumentDef(
      programNumber: 77,
      gmName: 'Shakuhachi',
      family: GmFamily.pipe,
      nativePresetId: 'shakuhachi_bamboo',
      iconName: 'synth',
      keywords: ['shakuhachi', 'bamboo flute', 'utaguchi', 'muraiki'],
    ),
    GmInstrumentDef(
      programNumber: 78,
      gmName: 'Whistle',
      family: GmFamily.pipe,
      nativePresetId: 'tin_whistle',
      iconName: 'synth',
      keywords: ['whistle', 'tin whistle', 'penny whistle', 'pennywhistle', 'irish whistle'],
    ),
    GmInstrumentDef(
      programNumber: 79,
      gmName: 'Ocarina',
      family: GmFamily.pipe,
      nativePresetId: 'sweet_ocarina',
      iconName: 'synth',
      keywords: ['ocarina', 'sweet ocarina', 'vessel flute'],
    ),

    // -------------------------------------------------------------
    // Family 10: Synth Lead (80 - 87)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 80,
      gmName: 'Lead 1 (square)',
      family: GmFamily.synthLead,
      nativePresetId: 'poly_lead',
      iconName: 'synth',
      keywords: ['lead 1', 'square lead', 'lead (square)', 'square wave'],
    ),
    GmInstrumentDef(
      programNumber: 81,
      gmName: 'Lead 2 (sawtooth)',
      family: GmFamily.synthLead,
      nativePresetId: 'poly_lead',
      iconName: 'synth',
      keywords: ['lead 2', 'saw lead', 'lead (sawtooth)', 'sawtooth lead'],
    ),
    GmInstrumentDef(
      programNumber: 82,
      gmName: 'Lead 3 (calliope)',
      family: GmFamily.synthLead,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['lead 3', 'calliope'],
    ),
    GmInstrumentDef(
      programNumber: 83,
      gmName: 'Lead 4 (chiff)',
      family: GmFamily.synthLead,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['lead 4', 'chiff'],
    ),
    GmInstrumentDef(
      programNumber: 84,
      gmName: 'Lead 5 (charang)',
      family: GmFamily.synthLead,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['lead 5', 'charang'],
    ),
    GmInstrumentDef(
      programNumber: 85,
      gmName: 'Lead 6 (voice)',
      family: GmFamily.synthLead,
      nativePresetId: 'tts_voice_synth',
      iconName: 'synth',
      keywords: ['lead 6', 'voice lead'],
    ),
    GmInstrumentDef(
      programNumber: 86,
      gmName: 'Lead 7 (fifths)',
      family: GmFamily.synthLead,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['lead 7', 'fifths lead'],
    ),
    GmInstrumentDef(
      programNumber: 87,
      gmName: 'Lead 8 (bass + lead)',
      family: GmFamily.synthLead,
      nativePresetId: 'c64_sid_synth',
      iconName: 'synth',
      keywords: ['lead 8', 'bass + lead', 'sid lead', 'chiptune lead'],
    ),

    // -------------------------------------------------------------
    // Family 11: Synth Pad (88 - 95)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 88,
      gmName: 'Pad 1 (new age)',
      family: GmFamily.synthPad,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['pad 1', 'new age pad'],
    ),
    GmInstrumentDef(
      programNumber: 89,
      gmName: 'Pad 2 (warm)',
      family: GmFamily.synthPad,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['pad 2', 'warm pad', 'analog pad'],
    ),
    GmInstrumentDef(
      programNumber: 90,
      gmName: 'Pad 3 (polysynth)',
      family: GmFamily.synthPad,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['pad 3', 'polysynth pad'],
    ),
    GmInstrumentDef(
      programNumber: 91,
      gmName: 'Pad 4 (choir)',
      family: GmFamily.synthPad,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['pad 4', 'choir pad'],
    ),
    GmInstrumentDef(
      programNumber: 92,
      gmName: 'Pad 5 (bowed)',
      family: GmFamily.synthPad,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['pad 5', 'bowed pad'],
    ),
    GmInstrumentDef(
      programNumber: 93,
      gmName: 'Pad 6 (metallic)',
      family: GmFamily.synthPad,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['pad 6', 'metallic pad'],
    ),
    GmInstrumentDef(
      programNumber: 94,
      gmName: 'Pad 7 (halo)',
      family: GmFamily.synthPad,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['pad 7', 'halo pad'],
    ),
    GmInstrumentDef(
      programNumber: 95,
      gmName: 'Pad 8 (sweep)',
      family: GmFamily.synthPad,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['pad 8', 'sweep pad'],
    ),

    // -------------------------------------------------------------
    // Family 12: Synth Effects (96 - 103)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 96,
      gmName: 'FX 1 (rain)',
      family: GmFamily.synthEffects,
      nativePresetId: 'eats_water',
      iconName: 'fx',
      keywords: ['fx 1', 'rain fx'],
    ),
    GmInstrumentDef(
      programNumber: 97,
      gmName: 'FX 2 (soundtrack)',
      family: GmFamily.synthEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['fx 2', 'soundtrack'],
    ),
    GmInstrumentDef(
      programNumber: 98,
      gmName: 'FX 3 (crystal)',
      family: GmFamily.synthEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['fx 3', 'crystal'],
    ),
    GmInstrumentDef(
      programNumber: 99,
      gmName: 'FX 4 (atmosphere)',
      family: GmFamily.synthEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['fx 4', 'atmosphere'],
    ),
    GmInstrumentDef(
      programNumber: 100,
      gmName: 'FX 5 (brightness)',
      family: GmFamily.synthEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['fx 5', 'brightness'],
    ),
    GmInstrumentDef(
      programNumber: 101,
      gmName: 'FX 6 (goblins)',
      family: GmFamily.synthEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['fx 6', 'goblins'],
    ),
    GmInstrumentDef(
      programNumber: 102,
      gmName: 'FX 7 (echoes)',
      family: GmFamily.synthEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['fx 7', 'echoes'],
    ),
    GmInstrumentDef(
      programNumber: 103,
      gmName: 'FX 8 (sci-fi)',
      family: GmFamily.synthEffects,
      nativePresetId: 'eats_volts',
      iconName: 'fx',
      keywords: ['fx 8', 'sci-fi', 'plasma'],
    ),

    // -------------------------------------------------------------
    // Family 13: Ethnic (104 - 111)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 104,
      gmName: 'Sitar',
      family: GmFamily.ethnic,
      nativePresetId: 'sitar_jawari',
      iconName: 'guitar',
      keywords: ['sitar', 'jawari', 'sitar drone'],
    ),
    GmInstrumentDef(
      programNumber: 105,
      gmName: 'Banjo',
      family: GmFamily.ethnic,
      nativePresetId: 'bluegrass_banjo',
      iconName: 'guitar',
      keywords: ['banjo', 'bluegrass banjo', '5-string banjo'],
    ),
    GmInstrumentDef(
      programNumber: 106,
      gmName: 'Shamisen',
      family: GmFamily.ethnic,
      nativePresetId: null,
      iconName: 'guitar',
      keywords: ['shamisen'],
    ),
    GmInstrumentDef(
      programNumber: 107,
      gmName: 'Koto',
      family: GmFamily.ethnic,
      nativePresetId: null,
      iconName: 'guitar',
      keywords: ['koto'],
    ),
    GmInstrumentDef(
      programNumber: 108,
      gmName: 'Kalimba',
      family: GmFamily.ethnic,
      nativePresetId: 'music_box',
      iconName: 'synth',
      keywords: ['kalimba', 'thumb piano', 'mbira'],
    ),
    GmInstrumentDef(
      programNumber: 109,
      gmName: 'Bag pipe',
      family: GmFamily.ethnic,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['bagpipe', 'bag pipe', 'pipes'],
    ),
    GmInstrumentDef(
      programNumber: 110,
      gmName: 'Fiddle',
      family: GmFamily.ethnic,
      nativePresetId: 'solo_violin',
      iconName: 'strings',
      keywords: ['fiddle'],
    ),
    GmInstrumentDef(
      programNumber: 111,
      gmName: 'Shanai',
      family: GmFamily.ethnic,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['shanai', 'shehnai'],
    ),

    // -------------------------------------------------------------
    // Family 14: Percussive (112 - 119)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 112,
      gmName: 'Tinkle Bell',
      family: GmFamily.percussive,
      nativePresetId: null,
      iconName: 'synth',
      keywords: ['tinkle bell'],
    ),
    GmInstrumentDef(
      programNumber: 113,
      gmName: 'Agogo',
      family: GmFamily.percussive,
      nativePresetId: null,
      iconName: 'drums',
      keywords: ['agogo', 'agogo bell'],
    ),
    GmInstrumentDef(
      programNumber: 114,
      gmName: 'Steel Drums',
      family: GmFamily.percussive,
      nativePresetId: null,
      iconName: 'drums',
      keywords: ['steel drums', 'steel pan', 'steelpan'],
    ),
    GmInstrumentDef(
      programNumber: 115,
      gmName: 'Woodblock',
      family: GmFamily.percussive,
      nativePresetId: null,
      iconName: 'drums',
      keywords: ['woodblock'],
    ),
    GmInstrumentDef(
      programNumber: 116,
      gmName: 'Taiko Drum',
      family: GmFamily.percussive,
      nativePresetId: null,
      iconName: 'drums',
      keywords: ['taiko', 'taiko drum'],
    ),
    GmInstrumentDef(
      programNumber: 117,
      gmName: 'Melodic Tom',
      family: GmFamily.percussive,
      nativePresetId: 'fm_acoustic_tom',
      iconName: 'drums',
      keywords: ['melodic tom', 'tom'],
    ),
    GmInstrumentDef(
      programNumber: 118,
      gmName: 'Synth Drum',
      family: GmFamily.percussive,
      nativePresetId: 'analog_808_kick',
      iconName: 'drums',
      keywords: ['synth drum', 'electronic drum'],
    ),
    GmInstrumentDef(
      programNumber: 119,
      gmName: 'Reverse Cymbal',
      family: GmFamily.percussive,
      nativePresetId: null,
      iconName: 'drums',
      keywords: ['reverse cymbal'],
    ),

    // -------------------------------------------------------------
    // Family 15: Sound Effects (120 - 127)
    // -------------------------------------------------------------
    GmInstrumentDef(
      programNumber: 120,
      gmName: 'Guitar Fret Noise',
      family: GmFamily.soundEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['guitar fret noise', 'fret noise'],
    ),
    GmInstrumentDef(
      programNumber: 121,
      gmName: 'Breath Noise',
      family: GmFamily.soundEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['breath noise'],
    ),
    GmInstrumentDef(
      programNumber: 122,
      gmName: 'Seashore',
      family: GmFamily.soundEffects,
      nativePresetId: 'eats_water',
      iconName: 'fx',
      keywords: ['seashore', 'ocean', 'waves'],
    ),
    GmInstrumentDef(
      programNumber: 123,
      gmName: 'Bird Tweet',
      family: GmFamily.soundEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['bird tweet', 'birds'],
    ),
    GmInstrumentDef(
      programNumber: 124,
      gmName: 'Telephone Ring',
      family: GmFamily.soundEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['telephone ring', 'telephone'],
    ),
    GmInstrumentDef(
      programNumber: 125,
      gmName: 'Helicopter',
      family: GmFamily.soundEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['helicopter'],
    ),
    GmInstrumentDef(
      programNumber: 126,
      gmName: 'Applause',
      family: GmFamily.soundEffects,
      nativePresetId: null,
      iconName: 'fx',
      keywords: ['applause', 'cheer'],
    ),
    GmInstrumentDef(
      programNumber: 127,
      gmName: 'Gunshot',
      family: GmFamily.soundEffects,
      nativePresetId: 'eats_sfxr',
      iconName: 'fx',
      keywords: ['gunshot', 'explosion'],
    ),
  ];

  /// Definition for General MIDI Channel 10 Percussion / Drum Kit.
  static const GmInstrumentDef gmDrumsDef = GmInstrumentDef(
    programNumber: -1,
    gmName: 'General MIDI Standard Drum Kit',
    family: GmFamily.percussion,
    nativePresetId: 'drum_kit_sampler',
    iconName: 'drums',
    keywords: ['drum', 'drums', 'drumkit', 'percussion', 'beat'],
  );

  // -------------------------------------------------------------
  // Audit & Progress Tracking APIs
  // -------------------------------------------------------------

  /// All 128 GM instruments.
  static List<GmInstrumentDef> get allInstruments => spec;

  /// All GM instruments that currently have a custom native physical model or synth implementation.
  static List<GmInstrumentDef> get nativeInstruments =>
      spec.where((item) => item.isNativeSupported).toList();

  /// All GM instruments that still require a custom native implementation (currently using SoundFont fallback).
  static List<GmInstrumentDef> get missingInstruments =>
      spec.where((item) => !item.isNativeSupported).toList();

  /// Total count of natively supported GM instruments.
  static int get nativeCount => nativeInstruments.length;

  /// Total count of instruments in the GM 1 spec (128).
  static int get totalCount => spec.length;

  /// Current percentage of General MIDI 1 covered natively (e.g. 26.5%).
  static double get nativeCoveragePercent => (nativeCount / totalCount.toDouble()) * 100.0;

  /// Missing instruments grouped by GM family.
  static Map<GmFamily, List<GmInstrumentDef>> get missingByFamily {
    final map = <GmFamily, List<GmInstrumentDef>>{};
    for (final family in GmFamily.values) {
      if (family == GmFamily.percussion) continue;
      final missingInFamily = spec.where((e) => e.family == family && !e.isNativeSupported).toList();
      if (missingInFamily.isNotEmpty) {
        map[family] = missingInFamily;
      }
    }
    return map;
  }

  /// Covered instruments grouped by GM family.
  static Map<GmFamily, List<GmInstrumentDef>> get coveredByFamily {
    final map = <GmFamily, List<GmInstrumentDef>>{};
    for (final family in GmFamily.values) {
      if (family == GmFamily.percussion) continue;
      final coveredInFamily = spec.where((e) => e.family == family && e.isNativeSupported).toList();
      if (coveredInFamily.isNotEmpty) {
        map[family] = coveredInFamily;
      }
    }
    return map;
  }

  // -------------------------------------------------------------
  // Track Resolution Engine
  // -------------------------------------------------------------

  /// Resolves a parsed MIDI track to either a native instrument or SoundFont fallback.
  /// 
  /// Priority:
  /// 1. Channel 9 (MIDI Ch 10) -> General MIDI Drums (`drum_kit_sampler`)
  /// 2. Explicit GM Program Number (if specified and has nativePresetId)
  /// 3. Track Name Semantic Keywords (matching custom models like 'cello', 'dx7', 'rhodes', 'piano')
  /// 4. Fallback -> SoundFont Sampler with exact Program Number or Default
  static GmResolutionResult resolve({
    int? programNumber,
    String? trackName,
    int? channel,
  }) {
    final cleanName = (trackName ?? '').toLowerCase().trim();

    // 1. Channel 10 / Drum Channel check
    if (channel == 9 || cleanName.contains('drum') || cleanName.contains('percussion')) {
      final drumPreset = LuaPresetLibrary.presets.firstWhere(
        (p) => p.id == 'drum_kit_sampler',
        orElse: () => LuaPresetLibrary.presets.firstWhere(
          (p) => p.id == 'soundfont_sampler',
          orElse: () => LuaPresetLibrary.presets.first,
        ),
      );

      final initialParams = _compileInitialParams(drumPreset.code);
      return GmResolutionResult(
        isNative: drumPreset.id != 'soundfont_sampler',
        presetId: drumPreset.id,
        presetName: drumPreset.name,
        iconName: 'drums',
        trackType: TrackType.sampler,
        sampleName: 'super_small_font.sf2',
        presetNum: 0.0,
        bankNum: 128.0,
        luaScriptCode: drumPreset.code,
        luaParams: initialParams.isEmpty
            ? {'PresetNum': 0.0, 'BankNum': 128.0}
            : initialParams,
        matchReason: 'gm_drum_channel',
        matchedDef: gmDrumsDef,
      );
    }

    // 2. If programNumber is missing or default 0 (Acoustic Grand Piano),
    // prioritize semantic track name if it matches another specific instrument
    // (e.g. track is named "Solo Cello" or "DX7 Keys", but MIDI file defaults PC to 0).
    final isProgramZeroOrDefault = programNumber == null || programNumber == 0;
    if (isProgramZeroOrDefault && cleanName.isNotEmpty) {
      GmInstrumentDef? bestDef;
      int longestMatch = 0;

      for (final def in spec) {
        if (!def.isNativeSupported || def.programNumber == 0) continue;
        for (final kw in def.keywords) {
          if (cleanName.contains(kw) && kw.length > longestMatch) {
            bestDef = def;
            longestMatch = kw.length;
          }
        }
      }

      if (bestDef != null) {
        final nativePreset = LuaPresetLibrary.getPresetById(bestDef.nativePresetId!);
        if (nativePreset != null) {
          return _buildNativeResult(
            preset: nativePreset,
            gmDef: bestDef,
            matchReason: 'semantic_keyword',
          );
        }
      }

      // Additional Eatsbeats-specific instruments matchable by track name
      if (cleanName.contains('ukulele')) {
        final p = LuaPresetLibrary.getPresetById('hawaiian_ukulele');
        if (p != null) return _buildDirectPresetResult(p, 'guitar', 'semantic_keyword');
      }
      if (cleanName.contains('mandolin')) {
        final p = LuaPresetLibrary.getPresetById('folk_mandolin');
        if (p != null) return _buildDirectPresetResult(p, 'guitar', 'semantic_keyword');
      }
      if (RegExp(r'\blute\b').hasMatch(cleanName)) {
        final p = LuaPresetLibrary.getPresetById('renaissance_lute');
        if (p != null) return _buildDirectPresetResult(p, 'guitar', 'semantic_keyword');
      }
      if (RegExp(r'\b(303|acid)\b').hasMatch(cleanName)) {
        final p = LuaPresetLibrary.getPresetById('eats_303');
        if (p != null) return _buildDirectPresetResult(p, 'bass', 'semantic_keyword');
      }
      if (cleanName.contains('rain') || cleanName.contains('downpour') || cleanName.contains('storm')) {
        final p = LuaPresetLibrary.getPresetById('eats_rain');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
      if (cleanName.contains('wind') || cleanName.contains('breeze') || cleanName.contains('gale')) {
        final p = LuaPresetLibrary.getPresetById('eats_wind');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
      if (cleanName.contains('campfire') || cleanName.contains('hearth') || cleanName.contains('fire')) {
        final p = LuaPresetLibrary.getPresetById('eats_fire');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
      if (cleanName.contains('thunder') || cleanName.contains('lightning')) {
        final p = LuaPresetLibrary.getPresetById('eats_thunder');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
      if (cleanName.contains('furnace') || cleanName.contains('pyrophone')) {
        final p = LuaPresetLibrary.getPresetById('eats_furnace');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
    }

    // 3. Lookup by explicit Program Number if valid
    GmInstrumentDef? programDef;
    if (programNumber != null && programNumber >= 0 && programNumber < spec.length) {
      programDef = spec[programNumber];
    }

    // Check if explicit program change maps to a native preset
    if (programDef != null && programDef.isNativeSupported) {
      final nativePreset = LuaPresetLibrary.getPresetById(programDef.nativePresetId!);
      if (nativePreset != null) {
        return _buildNativeResult(
          preset: nativePreset,
          gmDef: programDef,
          matchReason: 'program_change',
        );
      }
    }

    // 4. Semantic keyword search against track name for non-zero programs or general matching
    if (cleanName.isNotEmpty) {
      GmInstrumentDef? bestDef;
      int longestMatch = 0;

      for (final def in spec) {
        if (!def.isNativeSupported) continue;
        for (final kw in def.keywords) {
          if (cleanName.contains(kw) && kw.length > longestMatch) {
            bestDef = def;
            longestMatch = kw.length;
          }
        }
      }

      if (bestDef != null) {
        final nativePreset = LuaPresetLibrary.getPresetById(bestDef.nativePresetId!);
        if (nativePreset != null) {
          return _buildNativeResult(
            preset: nativePreset,
            gmDef: bestDef,
            matchReason: 'semantic_keyword',
          );
        }
      }

      if (cleanName.contains('rain') || cleanName.contains('downpour') || cleanName.contains('storm')) {
        final p = LuaPresetLibrary.getPresetById('eats_rain');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
      if (cleanName.contains('wind') || cleanName.contains('breeze') || cleanName.contains('gale')) {
        final p = LuaPresetLibrary.getPresetById('eats_wind');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
      if (cleanName.contains('campfire') || cleanName.contains('hearth') || cleanName.contains('fire')) {
        final p = LuaPresetLibrary.getPresetById('eats_fire');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
      if (cleanName.contains('thunder') || cleanName.contains('lightning')) {
        final p = LuaPresetLibrary.getPresetById('eats_thunder');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
      if (cleanName.contains('furnace') || cleanName.contains('pyrophone')) {
        final p = LuaPresetLibrary.getPresetById('eats_furnace');
        if (p != null) return _buildDirectPresetResult(p, 'fx', 'semantic_keyword');
      }
    }

    // 4. Fallback: SoundFont Sampler with exact Program Number
    final targetProgram = (programNumber != null && programNumber >= 0 && programNumber < 128)
        ? programNumber
        : 0;

    final sfDef = spec[targetProgram];
    final sfPreset = LuaPresetLibrary.presets.firstWhere(
      (p) => p.id == 'soundfont_sampler',
      orElse: () => LuaPresetLibrary.presets.first,
    );

    return GmResolutionResult(
      isNative: false,
      presetId: 'soundfont_sampler',
      presetName: '${sfDef.gmName} (SoundFont)',
      iconName: sfDef.iconName,
      trackType: TrackType.luaScript,
      sampleName: 'super_small_font.sf2',
      presetNum: targetProgram.toDouble(),
      bankNum: 0.0,
      luaScriptCode: sfPreset.code,
      luaParams: {
        'PresetNum': targetProgram.toDouble(),
        'BankNum': 0.0,
      },
      matchReason: 'soundfont_fallback',
      matchedDef: sfDef,
    );
  }

  static GmResolutionResult _buildNativeResult({
    required LuaScriptDef preset,
    required GmInstrumentDef gmDef,
    required String matchReason,
  }) {
    final params = _compileInitialParams(preset.code);
    return GmResolutionResult(
      isNative: true,
      presetId: preset.id,
      presetName: preset.name,
      iconName: gmDef.iconName,
      trackType: TrackType.luaScript,
      sampleName: '',
      presetNum: gmDef.programNumber.toDouble(),
      bankNum: 0.0,
      luaScriptCode: preset.code,
      luaParams: params,
      matchReason: matchReason,
      matchedDef: gmDef,
    );
  }

  static GmResolutionResult _buildDirectPresetResult(
    LuaScriptDef preset,
    String iconName,
    String matchReason,
  ) {
    final params = _compileInitialParams(preset.code);
    return GmResolutionResult(
      isNative: true,
      presetId: preset.id,
      presetName: preset.name,
      iconName: iconName,
      trackType: TrackType.luaScript,
      sampleName: '',
      presetNum: 0.0,
      bankNum: 0.0,
      luaScriptCode: preset.code,
      luaParams: params,
      matchReason: matchReason,
    );
  }

  static Map<String, double> _compileInitialParams(String luaCode) {
    try {
      final compiled = LuaEngine.compile(luaCode);
      final initialParams = <String, double>{};
      for (final p in compiled.params) {
        initialParams[p.name] = p.defaultValue;
      }
      return initialParams;
    } catch (_) {
      return {};
    }
  }

  /// Generates a markdown report showing current GM 1 coverage status.
  static String generateMarkdownCoverageReport() {
    final buf = StringBuffer();
    buf.writeln('# General MIDI Specification Coverage Report');
    buf.writeln();
    buf.writeln('**Current Native Coverage**: **$nativeCount / $totalCount** instruments (${nativeCoveragePercent.toStringAsFixed(1)}%)');
    buf.writeln('**SoundFont Placeholder Fallback**: **${missingInstruments.length}** instruments');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    for (final family in GmFamily.values) {
      if (family == GmFamily.percussion) continue;
      final familyInstruments = spec.where((e) => e.family == family).toList();
      final coveredCount = familyInstruments.where((e) => e.isNativeSupported).length;

      buf.writeln('### ${family.displayName} ($coveredCount / ${familyInstruments.length} covered)');
      buf.writeln();
      buf.writeln('| GM # | Instrument | Status | Native Implementation |');
      buf.writeln('| :---: | :--- | :---: | :--- |');

      for (final inst in familyInstruments) {
        final status = inst.isNativeSupported ? '✅ Native' : '⏳ SoundFont Fallback';
        final impl = inst.nativePresetId ?? '*(SoundFont PC #${inst.programNumber})*';
        buf.writeln('| ${inst.programNumber} | ${inst.gmName} | $status | `$impl` |');
      }
      buf.writeln();
    }

    buf.writeln('### Channel 10 Percussion');
    buf.writeln('- **Standard GM Drum Kit**: ✅ Native (`drum_kit_sampler` / `analog_808` / `analog_909`)');
    buf.writeln();
    return buf.toString();
  }
}
