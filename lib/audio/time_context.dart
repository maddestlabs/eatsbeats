import 'dart:math' as math;
import '../models/chord_model.dart';

/// Represents a snapshot of the DAW's playback position and transport state.
/// This unified clock structure bridges real-time audio scheduling with
/// 60fps visual/video frame indexing and provides harmonic chord track context.
class TimeContext {
  final double bpm;
  final int timeSignatureNumerator;
  final int timeSignatureDenominator;
  final double currentBar; // Absolute bar position (e.g. 1.5 = Bar 1, Beat 3 in 4/4)
  final double currentBeat; // Absolute beat position from start (0.0, 1.0, 2.0...)
  final double audioTimeSeconds; // Absolute audio clock timestamp in seconds
  final double frameRate; // Target video/visual FPS (default 60.0)
  final ChordEvent? activeChord; // Active Chord on Chord Track at this moment
  final List<ChordEvent> chordTrack; // Full project chord track
  final String songKey; // Project key (e.g. 'C Major', 'A Minor')
  final int songKeyRoot; // 0..11
  final bool isSongKeyMinor;

  final Map<String, dynamic>? activeLyricWord;
  final Map<String, dynamic>? activeLyricLine;
  final List<Map<String, dynamic>> upcomingLyrics;
  final List<Map<String, dynamic>> allLyrics;

  const TimeContext({
    required this.bpm,
    this.timeSignatureNumerator = 4,
    this.timeSignatureDenominator = 4,
    required this.currentBar,
    required this.currentBeat,
    required this.audioTimeSeconds,
    this.frameRate = 60.0,
    this.activeChord,
    this.chordTrack = const [],
    this.songKey = 'C Major',
    this.songKeyRoot = 0,
    this.isSongKeyMinor = false,
    this.activeLyricWord,
    this.activeLyricLine,
    this.upcomingLyrics = const [],
    this.allLyrics = const [],
  });

  /// Derived 60fps video/visual frame index based on absolute audio time.
  int get frameIndex => (audioTimeSeconds * frameRate).floor();

  /// Sub-frame fractional progress (0.0 to 1.0) between current and next visual frame.
  double get frameFraction => (audioTimeSeconds * frameRate) - frameIndex;

  /// Duration of a single beat in seconds.
  double get secondsPerBeat => 60.0 / math.max(1.0, bpm);

  /// Duration of a single bar in seconds.
  double get secondsPerBar => secondsPerBeat * timeSignatureNumerator;

  /// Converts a musical beat offset to seconds.
  double beatsToSeconds(double beats) => beats * secondsPerBeat;

  /// Converts seconds to a musical beat count.
  double secondsToBeats(double seconds) => seconds / secondsPerBeat;

  /// Converts a musical bar position to seconds.
  double barsToSeconds(double bars) => bars * secondsPerBar;

  /// Creates a TimeContext from absolute beat position and transport state.
  factory TimeContext.fromBeat({
    required double beat,
    required double bpm,
    int numerator = 4,
    int denominator = 4,
    double frameRate = 60.0,
    ChordEvent? activeChord,
    List<ChordEvent> chordTrack = const [],
    String songKey = 'C Major',
    int songKeyRoot = 0,
    bool isSongKeyMinor = false,
    Map<String, dynamic>? activeLyricWord,
    Map<String, dynamic>? activeLyricLine,
    List<Map<String, dynamic>> upcomingLyrics = const [],
    List<Map<String, dynamic>> allLyrics = const [],
  }) {
    final secPerBeat = 60.0 / math.max(1.0, bpm);
    final audioSec = beat * secPerBeat;
    final bar = (beat / numerator) + 1.0;

    return TimeContext(
      bpm: bpm,
      timeSignatureNumerator: numerator,
      timeSignatureDenominator: denominator,
      currentBar: bar,
      currentBeat: beat,
      audioTimeSeconds: audioSec,
      frameRate: frameRate,
      activeChord: activeChord,
      chordTrack: chordTrack,
      songKey: songKey,
      songKeyRoot: songKeyRoot,
      isSongKeyMinor: isSongKeyMinor,
      activeLyricWord: activeLyricWord,
      activeLyricLine: activeLyricLine,
      upcomingLyrics: upcomingLyrics,
      allLyrics: allLyrics,
    );
  }

  /// Converts TimeContext state into a map for passing into Lua scripts.
  Map<String, dynamic> toLuaTable() {
    final map = <String, dynamic>{
      'bpm': bpm,
      'timeSignatureNumerator': timeSignatureNumerator,
      'timeSignatureDenominator': timeSignatureDenominator,
      'bar': currentBar,
      'beat': currentBeat,
      'seconds': audioTimeSeconds,
      'frameIndex': frameIndex,
      'frameFraction': frameFraction,
      'songKey': songKey,
      'songKeyRoot': songKeyRoot,
      'isSongKeyMinor': isSongKeyMinor,
      'activeLyricWord': activeLyricWord,
      'activeLyricLine': activeLyricLine,
      'upcomingLyrics': upcomingLyrics,
      'allLyrics': allLyrics,
      'lyrics': {
        'currentWord': activeLyricWord,
        'currentLine': activeLyricLine,
        'upcoming': upcomingLyrics,
        'all': allLyrics,
      },
    };

    if (activeChord != null) {
      map['chord'] = {
        'name': activeChord!.displayName,
        'root': activeChord!.rootPitchClass,
        'rootName': activeChord!.rootName,
        'quality': activeChord!.quality.name,
        'qualitySymbol': activeChord!.quality.symbol,
        'bass': activeChord!.bassPitchClass,
        'bassName': activeChord!.bassName,
        'pitches': activeChord!.pitchClasses,
        'startBar': activeChord!.startBar,
        'barLength': activeChord!.barLength,
      };
    } else {
      map['chord'] = null;
    }

    if (chordTrack.isNotEmpty) {
      map['chordTrack'] = chordTrack.map((c) => {
        'name': c.displayName,
        'root': c.rootPitchClass,
        'rootName': c.rootName,
        'quality': c.quality.name,
        'qualitySymbol': c.quality.symbol,
        'bass': c.bassPitchClass,
        'bassName': c.bassName,
        'pitches': c.pitchClasses,
        'startBar': c.startBar,
        'barLength': c.barLength,
      }).toList();
    } else {
      map['chordTrack'] = [];
    }

    return map;
  }

  TimeContext copyWith({
    double? bpm,
    int? timeSignatureNumerator,
    int? timeSignatureDenominator,
    double? currentBar,
    double? currentBeat,
    double? audioTimeSeconds,
    double? frameRate,
    ChordEvent? activeChord,
    List<ChordEvent>? chordTrack,
    String? songKey,
    int? songKeyRoot,
    bool? isSongKeyMinor,
    Map<String, dynamic>? activeLyricWord,
    Map<String, dynamic>? activeLyricLine,
    List<Map<String, dynamic>>? upcomingLyrics,
    List<Map<String, dynamic>>? allLyrics,
  }) {
    return TimeContext(
      bpm: bpm ?? this.bpm,
      timeSignatureNumerator: timeSignatureNumerator ?? this.timeSignatureNumerator,
      timeSignatureDenominator: timeSignatureDenominator ?? this.timeSignatureDenominator,
      currentBar: currentBar ?? this.currentBar,
      currentBeat: currentBeat ?? this.currentBeat,
      audioTimeSeconds: audioTimeSeconds ?? this.audioTimeSeconds,
      frameRate: frameRate ?? this.frameRate,
      activeChord: activeChord ?? this.activeChord,
      chordTrack: chordTrack ?? this.chordTrack,
      songKey: songKey ?? this.songKey,
      songKeyRoot: songKeyRoot ?? this.songKeyRoot,
      isSongKeyMinor: isSongKeyMinor ?? this.isSongKeyMinor,
      activeLyricWord: activeLyricWord ?? this.activeLyricWord,
      activeLyricLine: activeLyricLine ?? this.activeLyricLine,
      upcomingLyrics: upcomingLyrics ?? this.upcomingLyrics,
      allLyrics: allLyrics ?? this.allLyrics,
    );
  }
}
