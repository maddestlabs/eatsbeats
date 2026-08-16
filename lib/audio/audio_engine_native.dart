import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

typedef _NativeInit = ffi.Void Function();
typedef _DartInit = void Function();

typedef _NativeSetMasterVolume = ffi.Void Function(ffi.Float volume);
typedef _DartSetMasterVolume = void Function(double volume);

typedef _NativePlayBuffer = ffi.Void Function(
  ffi.Pointer<ffi.Float> samples,
  ffi.Int32 count,
  ffi.Float volume,
  ffi.Float pan,
  ffi.Pointer<ffi.Uint8> trackId,
  ffi.Int32 isMonophonic,
);
typedef _DartPlayBuffer = void Function(
  ffi.Pointer<ffi.Float> samples,
  int count,
  double volume,
  double pan,
  ffi.Pointer<ffi.Uint8> trackId,
  int isMonophonic,
);

typedef _NativeStopTrackNotes = ffi.Void Function(ffi.Pointer<ffi.Uint8> trackId);
typedef _DartStopTrackNotes = void Function(ffi.Pointer<ffi.Uint8> trackId);

typedef _NativeMalloc = ffi.Pointer<ffi.Uint8> Function(ffi.Size size);
typedef _DartMalloc = ffi.Pointer<ffi.Uint8> Function(int size);

typedef _NativeFree = ffi.Void Function(ffi.Pointer<ffi.Uint8> ptr);
typedef _DartFree = void Function(ffi.Pointer<ffi.Uint8> ptr);

/// Native WASAPI Sub-6ms Low Latency Windows Audio Engine Implementation
class AudioEngineWebImpl {
  final Stopwatch _stopwatch = Stopwatch()..start();
  bool _initialized = false;
  double _masterVolume = 1.0;
  int _nodeCounter = 0;

  _DartInit? _nativeInit;
  _DartSetMasterVolume? _nativeSetMasterVolume;
  _DartPlayBuffer? _nativePlayBuffer;
  _DartStopTrackNotes? _nativeStopTrackNotes;

  _DartMalloc? _malloc;
  _DartFree? _free;

  double _lastPeakL = 0.0;
  double _lastPeakR = 0.0;
  List<double>? _lastActiveSamples;

  bool get isInitialized => _initialized;
  double get currentTime => _stopwatch.elapsedMicroseconds / 1000000.0;

  AudioEngineWebImpl() {
    _initNativeWasapiAudio();
  }

  void _initNativeWasapiAudio() {
    if (kIsWeb) return;
    try {
      final ffi.DynamicLibrary ucrt = ffi.DynamicLibrary.open('ucrtbase.dll');
      _malloc = ucrt.lookupFunction<_NativeMalloc, _DartMalloc>('malloc');
      _free = ucrt.lookupFunction<_NativeFree, _DartFree>('free');

      final ffi.DynamicLibrary processLib = ffi.DynamicLibrary.process();

      _nativeInit = processLib.lookupFunction<_NativeInit, _DartInit>('EatsAudio_Init');
      _nativeSetMasterVolume = processLib.lookupFunction<_NativeSetMasterVolume, _DartSetMasterVolume>('EatsAudio_SetMasterVolume');
      _nativePlayBuffer = processLib.lookupFunction<_NativePlayBuffer, _DartPlayBuffer>('EatsAudio_PlayBuffer');
      _nativeStopTrackNotes = processLib.lookupFunction<_NativeStopTrackNotes, _DartStopTrackNotes>('EatsAudio_StopTrackNotes');

      _nativeInit?.call();
      _initialized = true;
      debugPrint('AudioEngineNative: Successfully bound to native WASAPI C++ audio engine (EatsAudio).');
    } catch (e) {
      debugPrint('AudioEngineNative binding warning (falling back to silent mode for tests/web): $e');
    }
  }

  ffi.Pointer<ffi.Uint8> _stringToUtf8(String str) {
    if (_malloc == null) return ffi.Pointer.fromAddress(0);
    final units = Uint8List.fromList([...str.codeUnits, 0]);
    final ptr = _malloc!(units.length);
    ptr.asTypedList(units.length).setAll(0, units);
    return ptr;
  }

  void ensureContextRunning() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
  }

  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.5);
    _nativeSetMasterVolume?.call(_masterVolume);
  }

  String createNode(String type, Map<String, dynamic> config) {
    return 'native_node_${type.toLowerCase()}_${++_nodeCounter}';
  }

  void connect(String sourceId, String targetId, [int outputIndex = 0, int inputIndex = 0]) {}

  void connectToParam(String sourceId, String targetNodeId, String paramName) {}

  void disconnect(String nodeId) {}

  void scheduleParamOp({
    required String nodeId,
    required String paramName,
    required String method,
    required double value,
    required double scheduledTime,
    double? timeConstant,
  }) {}

  void updateMeters(Uint8List timeData, Function(double l, double r) setPeaks) {
    // Smooth decay of peaks
    _lastPeakL *= 0.85;
    _lastPeakR *= 0.85;
    if (_lastPeakL < 0.001) _lastPeakL = 0.0;
    if (_lastPeakR < 0.001) _lastPeakR = 0.0;

    if (_lastActiveSamples != null && _lastActiveSamples!.isNotEmpty) {
      final samples = _lastActiveSamples!;
      final step = math.max(1, samples.length ~/ timeData.length);
      for (int i = 0; i < timeData.length; i++) {
        final sIdx = (i * step).clamp(0, samples.length - 1);
        final double sample = samples[sIdx] * _lastPeakL.clamp(0.1, 1.0);
        timeData[i] = (128 + (sample.clamp(-1.0, 1.0) * 127.0)).toInt();
      }
    } else {
      timeData.fillRange(0, timeData.length, 128);
    }

    setPeaks(_lastPeakL * _masterVolume, _lastPeakR * _masterVolume);
  }

  void playPcmBuffer(
    List<double> samples,
    double volume,
    double pan, [
    double? scheduledTime,
    String? trackId,
    bool isMonophonic = false,
    bool isSlide = false,
    bool loop = false,
    List<double>? convolutionIrBuffer,
    String? convolutionIrName,
    double convolutionMix = 0.0,
    List<dynamic>? fxRack,
  ]) {
    if (samples.isEmpty || _nativePlayBuffer == null || _malloc == null || _free == null) return;

    final double panVal = pan.clamp(-1.0, 1.0);
    final double lPan = panVal <= 0 ? 1.0 : (1.0 - panVal);
    final double rPan = panVal >= 0 ? 1.0 : (1.0 + panVal);

    _lastPeakL = math.max(_lastPeakL, (volume * lPan).clamp(0.0, 1.0));
    _lastPeakR = math.max(_lastPeakR, (volume * rPan).clamp(0.0, 1.0));
    _lastActiveSamples = samples;

    final int count = samples.length;
    final floatPtr = _malloc!(count * 4).cast<ffi.Float>();
    final Float32List floatList = floatPtr.asTypedList(count);

    for (int i = 0; i < count; i++) {
      floatList[i] = samples[i];
    }

    final trackIdPtr = (trackId != null && trackId.isNotEmpty) ? _stringToUtf8(trackId) : ffi.Pointer<ffi.Uint8>.fromAddress(0);

    _nativePlayBuffer!(
      floatPtr,
      count,
      volume,
      pan,
      trackIdPtr,
      isMonophonic ? 1 : 0,
    );

    _free!(floatPtr.cast<ffi.Uint8>());
    if (trackIdPtr.address != 0) {
      _free!(trackIdPtr);
    }
  }

  void stopTrackNotes(String trackId) {
    if (_nativeStopTrackNotes == null || _malloc == null || _free == null || trackId.isEmpty) return;
    final trackIdPtr = _stringToUtf8(trackId);
    _nativeStopTrackNotes!(trackIdPtr);
    _free!(trackIdPtr);
  }
}
