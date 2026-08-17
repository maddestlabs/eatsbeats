import 'dart:math' as math;
import 'dart:typed_data';

import 'package:wajuce/wajuce.dart';

const _kModuleId = 'acid303';

/// Register before calling ctx.audioWorklet.addModule('acid303').
void registerAcid303Module() {
  WAWorkletModules.define(_kModuleId, (registrar) {
    registrar.registerProcessor(
      _kModuleId,
      () => Acid303Processor(),
      parameterDescriptors: Acid303Processor.parameterDescriptors,
    );
  });
}

/// TB-303 diode ladder voice running on the wajuce audio-thread isolate.
/// On web it runs as a browser AudioWorklet via js_interop passthrough.
class Acid303Processor extends WAWorkletProcessor {
  Acid303Processor() : super(name: _kModuleId);

  static const parameterDescriptors = [
    WAWorkletParameterDescriptor(name: 'gate',       defaultValue: 0,      minValue: 0,    maxValue: 1,    automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'frequency',  defaultValue: 110.0,  minValue: 20,   maxValue: 4000, automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'targetFreq', defaultValue: 0,      minValue: 0,    maxValue: 4000, automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'cutoffHz',   defaultValue: 1600.0, minValue: 100,  maxValue: 8000, automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'resonance',  defaultValue: 8.0,    minValue: 0.5,  maxValue: 16,   automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'envMod',     defaultValue: 0.75,   minValue: 0,    maxValue: 1,    automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'decaySec',   defaultValue: 0.28,   minValue: 0.02, maxValue: 2.0,  automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'accentAmt',  defaultValue: 0.6,    minValue: 0,    maxValue: 1,    automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'accent',     defaultValue: 0,      minValue: 0,    maxValue: 1,    automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'waveform',   defaultValue: 0,      minValue: 0,    maxValue: 1,    automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'overdrive',  defaultValue: 0.3,    minValue: 0,    maxValue: 1,    automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'volume',     defaultValue: 0.8,    minValue: 0,    maxValue: 1.5,  automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'pan',        defaultValue: 0,      minValue: -1,   maxValue: 1,    automationRate: WAAutomationRate.kRate),
    WAWorkletParameterDescriptor(name: 'slideSecs',  defaultValue: 0,      minValue: 0,    maxValue: 2,    automationRate: WAAutomationRate.kRate),
  ];

  // DSP state
  double _phase = 0.0, _freq = 110.0, _freqTarget = 0.0;
  double _slideSamplesRemaining = 0.0;
  double _env = 0.0, _filterEnv = 0.0;
  bool _prevGate = false;
  double _s1 = 0, _s2 = 0, _s3 = 0, _s4 = 0; // ladder stages
  double _hpfX1 = 0, _hpfY1 = 0;
  double _sampleRate = 44100.0;

  @override
  void init([Map<String, double> options = const {}]) {
    _sampleRate = (options['sampleRate'] ?? 44100.0);
  }

  @override
  bool process(
    List<List<Float32List>> inputs,
    List<List<Float32List>> outputs,
    Map<String, Float32List> params,
  ) {
    final outBus = outputs[0];
    if (outBus.isEmpty) return true;
    final outL = outBus[0];
    final outR = outBus.length > 1 ? outBus[1] : outL;
    final n = outL.length;

    final gate       = _kp(params, 'gate');
    final freq       = _kp(params, 'frequency').clamp(20.0, 4000.0);
    final targetFreq = _kp(params, 'targetFreq');
    final cutoffHz   = _kp(params, 'cutoffHz').clamp(100.0, 8000.0);
    final resonance  = _kp(params, 'resonance').clamp(0.5, 16.0);
    final envMod     = _kp(params, 'envMod').clamp(0.0, 1.0);
    final decaySec   = _kp(params, 'decaySec').clamp(0.02, 2.0);
    final accentAmt  = _kp(params, 'accentAmt').clamp(0.0, 1.0);
    final isAccent   = _kp(params, 'accent') > 0.5;
    final waveform   = _kp(params, 'waveform');
    final drive      = _kp(params, 'overdrive').clamp(0.0, 1.0);
    final volume     = _kp(params, 'volume').clamp(0.0, 1.5);
    final pan        = _kp(params, 'pan').clamp(-1.0, 1.0);
    final slideSecs  = _kp(params, 'slideSecs').clamp(0.0, 2.0);

    final isGate = gate > 0.5;
    final sr = _sampleRate;

    if (isGate && !_prevGate) {
      final hasSlide = targetFreq > 1.0 && slideSecs > 0.0;
      if (hasSlide) {
        _freqTarget = targetFreq;
        _slideSamplesRemaining = slideSecs * sr;
      } else {
        _freq = freq;
        _freqTarget = 0;
        _slideSamplesRemaining = 0;
        _s1 = _s2 = _s3 = _s4 = 0;
      }
      _env = 1.0;
      _filterEnv = isAccent ? (1.0 + accentAmt).clamp(0.0, 2.0) : 1.0;
      if (isAccent) _env = (_env + accentAmt * 0.5).clamp(0.0, 1.5);
    }
    _prevGate = isGate;

    final ampDecay    = math.exp(-1.0 / ((isAccent ? decaySec * 0.5 : decaySec) * sr));
    final filterDecay = math.exp(-1.0 / ((isAccent ? decaySec * 0.3 : decaySec) * sr));

    final leftGain  = pan <= 0 ? volume : volume * (1.0 - pan);
    final rightGain = pan >= 0 ? volume : volume * (1.0 + pan);

    for (int i = 0; i < n; i++) {
      // Slide portamento
      if (_slideSamplesRemaining > 0 && _freqTarget > 1.0) {
        final totalSamples = slideSecs * sr;
        final t = 1.0 - (_slideSamplesRemaining / totalSamples);
        final ts = t * t * (3.0 - 2.0 * t); // smoothstep
        _freq = freq + (_freqTarget - freq) * ts;
        _slideSamplesRemaining -= 1.0;
        if (_slideSamplesRemaining <= 0) {
          _freq = _freqTarget;
          _slideSamplesRemaining = 0;
        }
      }

      // Oscillator
      _phase += _freq / sr;
      if (_phase >= 1.0) _phase -= 1.0;
      final osc = waveform < 0.5
          ? 1.0 - 2.0 * _phase                         // saw
          : (_phase < 0.5 ? 1.0 : -1.0);               // square

      // Filter envelope
      _filterEnv *= filterDecay;
      final envCutoff = (cutoffHz * (1.0 + envMod * 3.0 * _filterEnv)).clamp(100.0, 12000.0);

      // 4-pole diode ladder (Huovilainen approximation)
      final f = (envCutoff / sr) * math.pi;
      final k = resonance / 4.0; // 0..4 range
      final inp = osc - k * _s4;
      _s1 += f * (_tanh(inp) - _tanh(_s1));
      _s2 += f * (_s1 - _s2);
      _s3 += f * (_s2 - _s3);
      _s4 += f * (_s3 - _s4);
      double sig = _s4;

      // HPF at 30 Hz
      final hpAlpha = 1.0 - (2.0 * math.pi * 30.0 / sr);
      _hpfY1 = hpAlpha * (_hpfY1 + sig - _hpfX1);
      _hpfX1 = sig;
      sig = _hpfY1;

      // Amplitude envelope
      _env *= ampDecay;
      if (!isGate) _env *= 0.9998;

      // Overdrive
      if (drive > 0.01) {
        final d = 1.0 + drive * 19.0;
        sig = _tanh(sig * d) / _tanh(d);
      }

      final out = (sig * _env.clamp(0.0, 1.5)).clamp(-1.0, 1.0);
      outL[i] = (out * leftGain).toDouble();
      outR[i] = (out * rightGain).toDouble();
    }

    return isGate || _env > 0.001;
  }

  static double _kp(Map<String, Float32List> p, String k) {
    final a = p[k];
    return (a != null && a.isNotEmpty) ? a[0].toDouble() : 0.0;
  }

  static double _tanh(double x) {
    if (x > 3) return 1.0;
    if (x < -3) return -1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }
}
