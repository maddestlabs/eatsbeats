import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service singleton managing text-to-speech vocal synthesis in EatsBeats.
class TtsEngine {
  static final TtsEngine _instance = TtsEngine._internal();
  factory TtsEngine() => _instance;

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isAvailable = true;

  List<dynamic> _availableVoices = [];
  List<dynamic> get availableVoices => _availableVoices;

  List<dynamic> _availableLanguages = [];
  List<dynamic> get availableLanguages => _availableLanguages;

  TtsEngine._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _flutterTts = FlutterTts();
      if (_flutterTts != null) {
        await _flutterTts!.awaitSpeakCompletion(false);
        try {
          final voices = await _flutterTts!.getVoices;
          if (voices is List) {
            _availableVoices = voices;
          }
          final languages = await _flutterTts!.getLanguages;
          if (languages is List) {
            _availableLanguages = languages;
          }
        } catch (e) {
          debugPrint('TtsEngine: Voice query note: $e');
        }
      }
      _isInitialized = true;
      _isAvailable = true;
    } catch (e) {
      debugPrint('TtsEngine: initialization warning (TTS disabled): $e');
      _isAvailable = false;
      _isInitialized = true;
    }
  }

  /// Triggers synthesized speech for a word or phrase with pitch and rate controls.
  Future<void> speak(
    String text, {
    String? voice,
    double pitch = 1.0,
    double rate = 1.0,
    double volume = 1.0,
  }) async {
    if (!_isInitialized) {
      await init();
    }
    if (!_isAvailable || _flutterTts == null || text.trim().isEmpty) return;

    try {
      // Normal range mappings for flutter_tts:
      // pitch: 0.5 to 2.0 (1.0 = normal)
      // speech rate: 0.0 to 1.0 (0.5 = normal on iOS/Android, clamped safely)
      final effectivePitch = pitch.clamp(0.5, 2.0);
      final effectiveRate = (rate * 0.5).clamp(0.1, 1.0);
      final effectiveVolume = volume.clamp(0.0, 1.0);

      await _flutterTts!.setPitch(effectivePitch);
      await _flutterTts!.setSpeechRate(effectiveRate);
      await _flutterTts!.setVolume(effectiveVolume);

      if (voice != null && voice.isNotEmpty) {
        if (voice.contains('-')) {
          await _flutterTts!.setLanguage(voice);
        } else {
          try {
            await _flutterTts!.setVoice({'name': voice, 'locale': 'en-US'});
          } catch (_) {
            // Ignore voice map format fallback
          }
        }
      }

      await _flutterTts!.speak(text);
    } catch (e) {
      debugPrint('TtsEngine.speak error: $e');
    }
  }

  /// Immediately halts speech synthesis (e.g., transport stop, panic button).
  Future<void> stop() async {
    if (!_isAvailable || _flutterTts == null) return;
    try {
      await _flutterTts!.stop();
    } catch (e) {
      debugPrint('TtsEngine.stop error: $e');
    }
  }
}
