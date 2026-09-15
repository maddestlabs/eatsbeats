import 'dart:typed_data';
import 'multi_mode_filter.dart';

/// Single band settings for [ParametricEq].
class EqBandConfig {
  bool enabled;
  MultiModeFilterType type;
  double frequency;
  double q;
  double gainDb;

  EqBandConfig({
    this.enabled = true,
    required this.type,
    required this.frequency,
    this.q = 0.707,
    this.gainDb = 0.0,
  });
}

/// 5-band Studio Parametric Equalizer.
class ParametricEq {
  final double sampleRate;
  final List<MultiModeFilter> _filters = [];
  final List<bool> _bandEnabled = [];

  ParametricEq({this.sampleRate = 44100.0}) {
    // 1. High-Pass / Low-Cut (30 Hz default)
    _filters.add(MultiModeFilter(
      type: MultiModeFilterType.highpass,
      cutoff: 30.0,
      q: 0.707,
      sampleRate: sampleRate,
    ));
    _bandEnabled.add(true);

    // 2. Low Shelf (120 Hz, 0 dB)
    _filters.add(MultiModeFilter(
      type: MultiModeFilterType.lowShelf,
      cutoff: 120.0,
      q: 0.707,
      gainDb: 0.0,
      sampleRate: sampleRate,
    ));
    _bandEnabled.add(true);

    // 3. Low-Mid Bell (600 Hz, 0 dB)
    _filters.add(MultiModeFilter(
      type: MultiModeFilterType.peaking,
      cutoff: 600.0,
      q: 1.0,
      gainDb: 0.0,
      sampleRate: sampleRate,
    ));
    _bandEnabled.add(true);

    // 4. High-Mid Bell (2500 Hz, 0 dB)
    _filters.add(MultiModeFilter(
      type: MultiModeFilterType.peaking,
      cutoff: 2500.0,
      q: 1.0,
      gainDb: 0.0,
      sampleRate: sampleRate,
    ));
    _bandEnabled.add(true);

    // 5. High Shelf (8000 Hz, 0 dB)
    _filters.add(MultiModeFilter(
      type: MultiModeFilterType.highShelf,
      cutoff: 8000.0,
      q: 0.707,
      gainDb: 0.0,
      sampleRate: sampleRate,
    ));
    _bandEnabled.add(true);
  }

  void configureBand(int bandIndex, {
    bool? enabled,
    MultiModeFilterType? type,
    double? frequency,
    double? q,
    double? gainDb,
  }) {
    if (bandIndex < 0 || bandIndex >= _filters.length) return;
    if (enabled != null) _bandEnabled[bandIndex] = enabled;
    _filters[bandIndex].setParams(
      type: type,
      cutoff: frequency,
      q: q,
      gainDb: gainDb,
    );
  }

  void reset() {
    for (final f in _filters) {
      f.reset();
    }
  }

  /// Processes mono audio [buffer] in place.
  void processBuffer(Float32List buffer) {
    for (int b = 0; b < _filters.length; b++) {
      if (_bandEnabled[b]) {
        _filters[b].processBuffer(buffer);
      }
    }
  }

  /// Computes composite magnitude in dB at [freqHz] across all active bands.
  double getCompositeMagnitudeDbAt(double freqHz) {
    double totalDb = 0.0;
    for (int b = 0; b < _filters.length; b++) {
      if (_bandEnabled[b]) {
        totalDb += _filters[b].getMagnitudeDbAt(freqHz);
      }
    }
    return totalDb;
  }
}
