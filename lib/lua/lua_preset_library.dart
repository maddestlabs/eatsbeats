enum LuaPresetCategory {
  instrument,
  audioFx,
  midiFx,
  midiSeq,
  utility;

  String get displayName {
    switch (this) {
      case LuaPresetCategory.instrument:
        return 'INSTRUMENT';
      case LuaPresetCategory.audioFx:
        return 'AUDIO FX';
      case LuaPresetCategory.midiFx:
        return 'MIDI FX';
      case LuaPresetCategory.midiSeq:
        return 'MIDI SEQ';
      case LuaPresetCategory.utility:
        return 'UTILITY';
    }
  }

  static LuaPresetCategory parse(String categoryStr) {
    final clean = categoryStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.contains('midiseq') || clean.contains('seq') || clean.contains('pattern')) {
      return LuaPresetCategory.midiSeq;
    }
    if (clean.contains('audiofx') || clean.contains('effect') || clean.contains('fx')) {
      if (clean.contains('midi')) return LuaPresetCategory.midiFx;
      return LuaPresetCategory.audioFx;
    }
    if (clean.contains('midi')) return LuaPresetCategory.midiFx;
    if (clean.contains('util')) return LuaPresetCategory.utility;
    return LuaPresetCategory.instrument;
  }
}

class LuaPreset {
  final String id;
  final String name;
  final LuaPresetCategory category;
  final String description;
  final String code;

  const LuaPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.code,
  });

  bool get isInstrument => category == LuaPresetCategory.instrument;
  bool get isAudioFx => category == LuaPresetCategory.audioFx;
  bool get isMidiFx => category == LuaPresetCategory.midiFx;
  bool get isMidiSeq => category == LuaPresetCategory.midiSeq;
}

class LuaPresetLibrary {
  static final List<LuaPreset> _customPresets = [];

  static List<LuaPreset> get presets => [..._builtinPresets, ..._customPresets];

  static List<LuaPreset> getPresetsByCategory(LuaPresetCategory category) {
    return presets.where((p) => p.category == category).toList();
  }

  static void registerCustomPreset(LuaPreset preset) {
    _customPresets.removeWhere((p) => p.id == preset.id || p.name == preset.name);
    _customPresets.add(preset);
  }

  static LuaPreset parseFromLuaScript(String luaCode, {String fallbackName = 'Custom Script'}) {
    String name = fallbackName;
    LuaPresetCategory category = LuaPresetCategory.instrument;
    String description = 'User imported Lua script';

    final lines = luaCode.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-- @name:')) {
        name = trimmed.substring(9).trim();
      } else if (trimmed.startsWith('-- @category:')) {
        category = LuaPresetCategory.parse(trimmed.substring(13).trim());
      } else if (trimmed.startsWith('-- @description:')) {
        description = trimmed.substring(16).trim();
      }
    }

    if (!luaCode.contains('@category:')) {
      if (luaCode.contains('processSignal') || luaCode.contains('evaluateEffect')) {
        category = LuaPresetCategory.audioFx;
      } else if (luaCode.contains('transform_notes') || luaCode.contains('midi_fx')) {
        category = LuaPresetCategory.midiFx;
      }
    }

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    final preset = LuaPreset(
      id: id,
      name: name,
      category: category,
      description: description,
      code: luaCode,
    );

    registerCustomPreset(preset);
    return preset;
  }

  static const List<LuaPreset> _builtinPresets = [
    // 1. Eats 303 Acid Bass Synth (JC-303 based)
    LuaPreset(
      id: 'acid_303',
      name: 'Eats 303',
      category: LuaPresetCategory.instrument,
      description: 'Roland TB-303 emulation modelled after midilab/jc303 (Eats 303 custom implementation) with 24dB 4-Pole Diode Ladder filter, leaky integrator saw/square oscillators, Accent, Slide portamento, and Overdrive.',
      code: '''
-- @name: Eats 303
-- @category: instrument
local Acid303 = {}

function Acid303.init()
  Param.add("Waveform", 0.0, 1.0, 0.0)
  Param.add("Cutoff", 100.0, 6500.0, 1600.0)
  Param.add("Resonance", 0.5, 16.0, 8.0)
  Param.add("EnvMod", 0.0, 1.0, 0.75)
  Param.add("Decay", 0.05, 1.2, 0.28)
  Param.add("Accent", 0.0, 1.0, 0.6)
  Param.add("Slide", 0.0, 1.0, 0.4)
  Param.add("Overdrive", 0.0, 1.0, 0.3)
end

function Acid303.process(time, freq, note, params, targetNote, isSlide, isAccent)
  local waveType = params["Waveform"] or 0.0
  local cutoff = params["Cutoff"] or 1600.0
  local res = params["Resonance"] or 8.0
  local envMod = params["EnvMod"] or 0.75
  local decay = params["Decay"] or 0.28
  local accent = params["Accent"] or 0.6
  local drive = params["Overdrive"] or 0.3
  local slideParam = params["Slide"] or 0.4

  local currentFreq = freq
  if targetNote and targetNote > 0 then
    local targetFreq = 440.0 * (2.0 ^ ((targetNote - 69) / 12.0))
    currentFreq = targetFreq + (freq - targetFreq) * math.exp(-time / 0.060)
  elseif isSlide or slideParam > 0.5 then
    local targetFreq = targetNote and (440.0 * (2.0 ^ ((targetNote - 69) / 12.0))) or freq
    currentFreq = targetFreq + (freq - targetFreq) * math.exp(-time / 0.060)
  end

  local phase = time * currentFreq
  local normPhase = phase - math.floor(phase)
  local sawRaw = 2.0 * normPhase - 1.0
  local sawHP = sawRaw - 0.85 * math.exp(-time * 12.0)
  local sqrRaw = normPhase < 0.46 and 0.75 or -0.75
  local osc = waveType < 0.5 and sawHP or sqrRaw

  local hasAccent = isAccent or (accent > 0.7 and not isSlide)
  local envBoost = hasAccent and (1.0 + accent * 1.1) or 1.0
  local envDecay = decay / (hasAccent and (1.0 + accent * 0.9) or 1.0)
  local env = math.exp(-time / envDecay)
  local accentPulse = hasAccent and (accent * 0.4 * math.exp(-time / 0.035)) or 0.0

  local modCutoff = cutoff + (envMod * (env + accentPulse) * 6500.0 * envBoost)
  local filtered = DSP.lowpass(osc, modCutoff, res)

  local highpassed = filtered * 0.98
  local output = highpassed * (hasAccent and 1.35 or 1.0)
  if drive > 0.05 then
    output = math.tanh(output * (1.0 + drive * 4.0))
  end

  return output
end

return Acid303
''',
    ),

    // 2. Eats Kick Preset
    LuaPreset(
      id: 'procedural_kick',
      name: 'Eats Kick',
      category: LuaPresetCategory.instrument,
      description: 'Synthesized punchy sub kick drum with exponential pitch sweep, extended sub-bass decay, and smooth edge fade.',
      code: '''
-- @name: Eats Kick
-- @category: instrument
local ProceduralKick = {}

function ProceduralKick.init()
  Param.add("StartFreq", 100.0, 300.0, 160.0)
  Param.add("EndFreq", 30.0, 60.0, 42.0)
  Param.add("PitchDecay", 0.01, 0.2, 0.035)
  Param.add("AmpDecay", 0.05, 4.0, 0.35)
  Param.add("Click", 0.0, 1.0, 0.0)
end

function ProceduralKick.process(time, freq, note, params)
  local startF = params["StartFreq"] or 160.0
  local endF = params["EndFreq"] or 42.0
  local pDecay = params["PitchDecay"] or 0.035
  local aDecay = params["AmpDecay"] or 0.35
  local click = params["Click"] or 0.0

  local curFreq = endF + (startF - endF) * math.exp(-time / math.max(0.005, pDecay))
  local phase = 2.0 * math.pi * curFreq * time
  local subSine = math.sin(phase)

  local clickTransient = (math.random() * 2.0 - 1.0) * math.exp(-time * 150.0) * click
  local env = math.exp(-time * 4.0 / math.max(0.01, aDecay))
  local rawOutput = (subSine * 0.85 + clickTransient * 0.15) * env

  local maxDur = math.max(0.1, aDecay)
  local fadeStart = maxDur - 0.04
  local edgeFade = 1.0
  if time > fadeStart then
    local norm = math.max(0.0, math.min(1.0, (maxDur - time) / 0.04))
    edgeFade = 0.5 * (1.0 - math.cos(math.pi * norm))
  end
  if time >= maxDur then edgeFade = 0.0 end
  return math.tanh(rawOutput * edgeFade * 1.3)
end

return ProceduralKick
''',
    ),

    // 3. Eats Snare Preset
    LuaPreset(
      id: 'procedural_snare',
      name: 'Eats Snare',
      category: LuaPresetCategory.instrument,
      description: 'Synthesized snare drum combining swept fundamental dual-body oscillator, filtered noise wires, and subtle variation.',
      code: '''
-- @name: Eats Snare
-- @category: instrument
local ProceduralSnare = {}

function ProceduralSnare.init()
  Param.add("ToneFreq", 100.0, 320.0, 185.0)
  Param.add("Snappy", 0.0, 1.0, 0.65)
  Param.add("Decay", 0.05, 0.8, 0.18)
  Param.add("Variation", 0.0, 1.0, 0.0)
end

function ProceduralSnare.process(time, freq, note, params)
  local toneFreq = params["ToneFreq"] or 185.0
  local snappy = params["Snappy"] or 0.65
  local decay = params["Decay"] or 0.18
  local variation = params["Variation"] or 0.0

  if variation > 0.001 then
    local vOffset = (math.sin(note * 12.9898) * 0.5 + 0.5) * variation
    toneFreq = toneFreq * (1.0 + (vOffset - 0.5 * variation) * 0.08)
    decay = decay * (1.0 + (vOffset - 0.5 * variation) * 0.15)
  end

  local sweepFreq = toneFreq * (1.0 + 1.2 * math.exp(-time * 60.0))
  local body = math.sin(2.0 * math.pi * sweepFreq * time) * math.exp(-time * 22.0)
  local overtone = math.sin(2.0 * math.pi * (toneFreq * 1.75) * time) * math.exp(-time * 30.0) * 0.35
  local tonalCore = body + overtone

  local noise = (math.random() * 2.0 - 1.0) * math.exp(-time / math.max(0.01, decay))
  local filteredNoise = DSP.highpass(noise, 1800.0, 1.2)

  local click = (math.random() * 2.0 - 1.0) * math.exp(-time * 250.0) * 0.25

  local output = (tonalCore * (1.0 - snappy * 0.6) + filteredNoise * (snappy * 1.2) + click)
  return math.tanh(output * 1.3)
end

return ProceduralSnare
''',
    ),

    // 4. Eats Hats Preset
    LuaPreset(
      id: 'procedural_hihat',
      name: 'Eats Hats',
      category: LuaPresetCategory.instrument,
      description: 'Synthesized hi-hat dominated by high-pass filtered white noise with adjustable metallic sheen, decay, and variation.',
      code: '''
-- @name: Eats Hats
-- @category: instrument
local ProceduralHiHat = {}

function ProceduralHiHat.init()
  Param.add("Cutoff", 3000.0, 14000.0, 7500.0)
  Param.add("Decay", 0.01, 0.6, 0.06)
  Param.add("Metallic", 0.0, 1.0, 0.15)
  Param.add("Variation", 0.0, 1.0, 0.0)
end

function ProceduralHiHat.process(time, freq, note, params)
  local cutoff = params["Cutoff"] or 7500.0
  local decay = params["Decay"] or 0.06
  local metallic = params["Metallic"] or 0.15
  local variation = params["Variation"] or 0.0

  if variation > 0.001 then
    local vOffset = (math.sin(note * 78.233) * 0.5 + 0.5) * variation
    cutoff = cutoff * (1.0 + (vOffset - 0.5 * variation) * 0.12)
    decay = decay * (1.0 + (vOffset - 0.5 * variation) * 0.18)
  end

  local env = math.exp(-time / math.max(0.005, decay))

  local ring1 = math.sin(2.0 * math.pi * 320.0 * time)
  local ring2 = math.sin(2.0 * math.pi * 540.0 * time)
  local ring3 = math.sin(2.0 * math.pi * 890.0 * time)
  local metallicRing = (ring1 + ring2 + ring3) * 0.333

  local noise = (math.random() * 2.0 - 1.0)
  local rawSignal = noise * (1.0 - metallic * 0.3) + metallicRing * (metallic * 0.3)
  local filtered = DSP.highpass(rawSignal, cutoff, 1.4)

  return math.tanh(filtered * env * 1.1)
end

return ProceduralHiHat
''',
    ),

    // 5. Poly Lead Synth Preset
    LuaPreset(
      id: 'poly_lead',
      name: 'Poly Lead Synth',
      category: LuaPresetCategory.instrument,
      description: 'Dual oscillator sawtooth lead synthesizer with dynamic lowpass filter sweep.',
      code: '''
-- @name: Poly Lead Synth
-- @category: instrument
local PolyLeadSynth = {}

function PolyLeadSynth.init()
  Param.add("Cutoff", 400.0, 12000.0, 4500.0)
  Param.add("Resonance", 0.5, 8.0, 3.0)
  Param.add("Detune", 0.0, 10.0, 3.0)
  Param.add("Attack", 0.001, 0.1, 0.01)
  Param.add("Release", 0.05, 1.0, 0.35)
end

function PolyLeadSynth.process(time, freq, note, params)
  local cutoff = params["Cutoff"] or 4500.0
  local res = params["Resonance"] or 3.0
  local detune = params["Detune"] or 3.0
  local attack = params["Attack"] or 0.01
  local release = params["Release"] or 0.35

  local env = 1.0
  if time < attack then
    env = time / attack
  else
    env = math.exp(-(time - attack) / release)
  end

  local f1 = freq
  local f2 = freq + detune
  local phase1 = time * f1
  local phase2 = time * f2

  local saw1 = 2.0 * (phase1 - math.floor(phase1)) - 1.0
  local saw2 = 2.0 * (phase2 - math.floor(phase2)) - 1.0
  local rawOsc = (saw1 + saw2) * 0.5

  local filtered = DSP.lowpass(rawOsc, cutoff, res)
  return filtered * env * 0.8
end

return PolyLeadSynth
''',
    ),

    // 7. Lua Stereo Delay Effect
    LuaPreset(
      id: 'lua_delay',
      name: 'Lua Stereo Delay FX',
      category: LuaPresetCategory.audioFx,
      description: 'Feedback delay line effect module with dampening and dry/wet mix controls.',
      code: '''
-- @name: Lua Stereo Delay FX
-- @category: audioFx
local StereoDelayFX = {}

function StereoDelayFX.init()
  Param.add("TimeMs", 50.0, 800.0, 250.0)
  Param.add("Feedback", 0.0, 0.9, 0.45)
  Param.add("Dampening", 1000.0, 12000.0, 4500.0)
  Param.add("Mix", 0.0, 1.0, 0.4)
end

function StereoDelayFX.processSignal(inputSample, time, params)
  local timeMs = params["TimeMs"] or 250.0
  local fb = params["Feedback"] or 0.45
  local damp = params["Dampening"] or 4500.0
  local mix = params["Mix"] or 0.4

  local delayed = DSP.delay(inputSample, timeMs, fb)
  local dampened = DSP.lowpass(delayed, damp, 1.0)

  return (inputSample * (1.0 - mix)) + (dampened * mix)
end

return StereoDelayFX
''',
    ),

    // 8. Lua Stereo Chorus Effect
    LuaPreset(
      id: 'lua_chorus',
      name: 'Lua Stereo Chorus FX',
      category: LuaPresetCategory.audioFx,
      description: 'LFO modulated short delay lines creating lush stereo chorus and ensemble thickness.',
      code: '''
-- @name: Lua Stereo Chorus FX
-- @category: audioFx
local StereoChorusFX = {}

function StereoChorusFX.init()
  Param.add("RateHz", 0.1, 5.0, 1.2)
  Param.add("DepthMs", 1.0, 15.0, 6.0)
  Param.add("Mix", 0.0, 1.0, 0.5)
end

function StereoChorusFX.processSignal(inputSample, time, params)
  local rate = params["RateHz"] or 1.2
  local depth = params["DepthMs"] or 6.0
  local mix = params["Mix"] or 0.5

  local lfo = math.sin(2.0 * math.pi * rate * time)
  local modulatedTime = 12.0 + (lfo * depth)

  local wet = DSP.delay(inputSample, modulatedTime, 0.2)
  return (inputSample * (1.0 - mix)) + (wet * mix)
end

return StereoChorusFX
''',
    ),

    // 9. 8-Bit Retro Crusher FX
    LuaPreset(
      id: 'bitcrusher_fx',
      name: '8-Bit Retro Crusher FX',
      category: LuaPresetCategory.audioFx,
      description: 'Bit-depth and sample-rate reduction effect for lo-fi chiptune textures.',
      code: '''
-- @name: 8-Bit Retro Crusher FX
-- @category: audioFx
local BitcrusherFX = {}

function BitcrusherFX.init()
  Param.add("Bits", 2.0, 16.0, 6.0)
  Param.add("Downsample", 1.0, 16.0, 4.0)
  Param.add("Mix", 0.0, 1.0, 0.8)
end

function BitcrusherFX.processSignal(inputSample, time, params)
  local bits = params["Bits"] or 6.0
  local downsample = params["Downsample"] or 4.0
  local mix = params["Mix"] or 0.8

  local steps = math.pow(2.0, bits)
  local quantized = math.floor(inputSample * steps) / steps
  local crushed = DSP.sampleHold(quantized, downsample)

  return (inputSample * (1.0 - mix)) + (crushed * mix)
end

return BitcrusherFX
''',
    ),

    // 10. Warm Tube Distortion
    LuaPreset(
      id: 'tube_distortion',
      name: 'Warm Tube Distortion',
      category: LuaPresetCategory.audioFx,
      description: 'Non-linear soft-clipping saturation and warmth.',
      code: '''
-- @name: Warm Tube Distortion
-- @category: audioFx
local TubeDistortion = {}

function TubeDistortion.init()
  Param.add("Drive", 1.0, 20.0, 6.0)
  Param.add("Tone", 200.0, 8000.0, 3500.0)
  Param.add("OutGain", 0.1, 1.5, 0.7)
end

function TubeDistortion.processSignal(inputSample, time, params)
  local drive = params["Drive"] or 6.0
  local tone = params["Tone"] or 3500.0
  local outGain = params["OutGain"] or 0.7

  local driven = inputSample * drive
  local clipped = math.tanh(driven)
  local filtered = DSP.lowpass(clipped, tone, 1.0)
  return filtered * outGain
end

return TubeDistortion
''',
    ),

    // 11. Eatsbits Sampler Instrument (Melodic / One-Shot)
    LuaPreset(
      id: 'sampler_instrument',
      name: 'Sampler (Melodic / One-Shot)',
      category: LuaPresetCategory.instrument,
      description: 'Pitch-shifted sample player with ADSR envelope, filter cutoff, and root key tuning.',
      code: '''
-- @name: Sampler (Melodic / One-Shot)
-- @category: instrument
local SamplerInstrument = {}

function SamplerInstrument.init()
  Param.add("RootKey", 36.0, 84.0, 60.0)
  Param.add("AttackSec", 0.0, 1.0, 0.0)
  Param.add("DecaySec", 0.01, 1.0, 0.1)
  Param.add("Sustain", 0.0, 1.0, 0.8)
  Param.add("ReleaseSec", 0.01, 2.0, 0.4)
  Param.add("FilterCutoff", 200.0, 12000.0, 8000.0)
end

function SamplerInstrument.process(time, freq, note, params)
  local rootKey = params["RootKey"] or 60.0
  local pitchOffset = note - rootKey

  local rawSample = Sampler.read(note, time, pitchOffset)
  local attack = params["AttackSec"] or 0.0
  local decay = params["DecaySec"] or 0.1
  local sustain = params["Sustain"] or 0.8
  local release = params["ReleaseSec"] or 0.4
  local cutoff = params["FilterCutoff"] or 8000.0

  local env = DSP.adsr(time, attack, decay, sustain, release)
  local filtered = DSP.lowpass(rawSample, cutoff, 1.0)
  return filtered * env
end

return SamplerInstrument
''',
    ),

    // 12. Eatsbits Multi-Slot Drum Kit Sampler
    LuaPreset(
      id: 'drum_kit_sampler',
      name: 'Eats Multi-Slot Drum Sampler',
      category: LuaPresetCategory.instrument,
      description: 'Multi-slot drum sampler mapping notes (36=Kick, 38=Snare, 42=Hat, 39=Clap) to distinct audio sample slots.',
      code: '''
-- @name: Eats Multi-Slot Drum Sampler
-- @category: instrument
local DrumKitSampler = {}

function DrumKitSampler.init()
  Param.add("KickTune", -12.0, 12.0, 0.0)
  Param.add("SnareTune", -12.0, 12.0, 0.0)
  Param.add("Drive", 0.0, 1.0, 0.1)
end

function DrumKitSampler.process(time, freq, note, params)
  local sampleOut = 0.0
  if note == 36 then
    sampleOut = Sampler.readSample("kick", time, params["KickTune"] or 0.0)
  elseif note == 38 then
    sampleOut = Sampler.readSample("snare", time, params["SnareTune"] or 0.0)
  elseif note == 42 or note == 46 then
    sampleOut = Sampler.readSample("hihat", time, 0.0)
  elseif note == 39 then
    sampleOut = Sampler.readSample("clap", time, 0.0)
  else
    sampleOut = Sampler.read(note, time, 0.0)
  end

  local drive = params["Drive"] or 0.1
  if drive > 0.01 then
    sampleOut = math.tanh(sampleOut * (1.0 + drive * 4.0))
  end

  return sampleOut
end

return DrumKitSampler
''',
    ),

    // 13. SoundFont 2 Multi-Sample Instrument
    LuaPreset(
      id: 'soundfont_sampler',
      name: 'SoundFont 2 Player',
      category: LuaPresetCategory.instrument,
      description: 'Multi-sampled SoundFont 2 (.sf2) bank player with key-zone mapping, bank selection, and transient envelope control.',
      code: '''
-- @name: SoundFont 2 Player
-- @category: instrument
local SoundFontSampler = {}

function SoundFontSampler.init()
  Param.add("PresetNum", 0, 127, 0, 1)
  Param.add("BankNum", 0, 128, 0, 1)
  Param.add("AttackSec", 0.0, 1.0, 0.0)
  Param.add("ReleaseSec", 0.01, 2.0, 0.4)
end

function SoundFontSampler.process(time, freq, note, params)
  local rawSample = SoundFont.readZone(note, time)
  local attack = params["AttackSec"] or 0.0
  local release = params["ReleaseSec"] or 0.4

  local env = DSP.env(time, attack, release)
  return rawSample * env
end

return SoundFontSampler
''',
    ),

    // 14. Lua MIDI Arpeggiator FX
    LuaPreset(
      id: 'arpeggiator_midi_fx',
      name: 'Lua MIDI Arpeggiator FX',
      category: LuaPresetCategory.midiFx,
      description: 'Advanced MIDI arpeggiator with multi-octave cycling, rate dividers, gate, swing, and 8 pattern modes.',
      code: '''
-- @name: Lua MIDI Arpeggiator FX
-- @category: midiFx
-- @param: Rate = 1.0 (0.25: 1/64, 0.5: 1/32, 1.0: 1/16, 2.0: 1/8, 4.0: 1/4)
-- @param: Octaves = 2.0 (1 to 4 octaves)
-- @param: Pattern = 0.0 (0: Up, 1: Down, 2: UpDown, 3: DownUp, 4: Converge, 5: Diverge, 6: Random, 7: Chord, 8: AsPlayed)
-- @param: Gate = 0.85 (0.1: Staccato to 2.0: Legato)
-- @param: Swing = 0.0 (0.0 to 0.5 groove timing)
local ArpeggiatorMidiFX = {}

function ArpeggiatorMidiFX.transform_notes(notes, params, timeContext)
  return Midi.arpeggiate(notes, params, timeContext)
end

return ArpeggiatorMidiFX
''',
    ),

    // --- MIDI SEQUENCES (MIDI SEQ) ---

    // 15. 4-to-Floor Kick Pattern
    LuaPreset(
      id: 'seq_4_to_floor',
      name: '4-to-Floor Kick',
      category: LuaPresetCategory.midiSeq,
      description: 'Classic four-on-the-floor kick drum pattern hitting on every downbeat (1, 2, 3, 4).',
      code: '''
-- @name: 4-to-Floor Kick
-- @category: midiSeq
-- @description: Classic 4-on-the-floor kick pattern for house/techno/EDM

notes = {
  { pitch = 36, start = 0.00, duration = 1.00, vel = 0.95 },
  { pitch = 36, start = 4.00, duration = 1.00, vel = 0.90 },
  { pitch = 36, start = 8.00, duration = 1.00, vel = 0.95 },
  { pitch = 36, start = 12.00, duration = 1.00, vel = 0.90 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 16. Quarter Hats Pattern
    LuaPreset(
      id: 'seq_quarter_hats',
      name: 'Quarter Hats',
      category: LuaPresetCategory.midiSeq,
      description: 'Hi-hat pattern hitting on every quarter beat (1, 2, 3, 4).',
      code: '''
-- @name: Quarter Hats
-- @category: midiSeq
-- @description: Hi-hat hits on every quarter beat

notes = {
  { pitch = 42, start = 0.00, duration = 1.00, vel = 0.85 },
  { pitch = 42, start = 4.00, duration = 1.00, vel = 0.80 },
  { pitch = 42, start = 8.00, duration = 1.00, vel = 0.85 },
  { pitch = 42, start = 12.00, duration = 1.00, vel = 0.80 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 17. Eighth Hats Pattern
    LuaPreset(
      id: 'seq_eighth_hats',
      name: 'Eighth Hats',
      category: LuaPresetCategory.midiSeq,
      description: 'Driving 8th-note hi-hat groove hitting on the beat and between beats with dynamic accents.',
      code: '''
-- @name: Eighth Hats
-- @category: midiSeq
-- @description: Driving 8th-note hi-hat groove with alternating velocity accents

notes = {
  { pitch = 42, start = 0.00, duration = 1.00, vel = 0.85 },
  { pitch = 42, start = 2.00, duration = 1.00, vel = 0.70 },
  { pitch = 42, start = 4.00, duration = 1.00, vel = 0.80 },
  { pitch = 42, start = 6.00, duration = 1.00, vel = 0.70 },
  { pitch = 42, start = 8.00, duration = 1.00, vel = 0.85 },
  { pitch = 42, start = 10.00, duration = 1.00, vel = 0.70 },
  { pitch = 42, start = 12.00, duration = 1.00, vel = 0.80 },
  { pitch = 42, start = 14.00, duration = 1.00, vel = 0.70 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 18. Offbeat Open Hats
    LuaPreset(
      id: 'seq_offbeat_hats',
      name: 'Offbeat Open Hats',
      category: LuaPresetCategory.midiSeq,
      description: 'Classic house and garage offbeat open hi-hat groove hitting on the upbeat of every beat.',
      code: '''
-- @name: Offbeat Open Hats
-- @category: midiSeq
-- @description: Classic house and garage offbeat open hi-hat pattern

notes = {
  { pitch = 46, start = 2.00, duration = 1.50, vel = 0.88 },
  { pitch = 46, start = 6.00, duration = 1.50, vel = 0.85 },
  { pitch = 46, start = 10.00, duration = 1.50, vel = 0.88 },
  { pitch = 46, start = 14.00, duration = 1.50, vel = 0.85 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 19. Snares Backbeat
    LuaPreset(
      id: 'seq_snares',
      name: 'Snares (Backbeat)',
      category: LuaPresetCategory.midiSeq,
      description: 'Standard backbeat snare pattern hitting on beats 2 and 4.',
      code: '''
-- @name: Snares (Backbeat)
-- @category: midiSeq
-- @description: Standard snare backbeat on beats 2 and 4

notes = {
  { pitch = 38, start = 4.00, duration = 1.00, vel = 0.92 },
  { pitch = 38, start = 12.00, duration = 1.00, vel = 0.95 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 20. Trap / Half-time Snare
    LuaPreset(
      id: 'seq_trap_snare',
      name: 'Trap Snare (Half-Time)',
      category: LuaPresetCategory.midiSeq,
      description: 'Half-time hip-hop / trap snare pattern hitting firmly on beat 3.',
      code: '''
-- @name: Trap Snare (Half-Time)
-- @category: midiSeq
-- @description: Half-time hip-hop / trap snare hit on beat 3

notes = {
  { pitch = 38, start = 8.00, duration = 1.00, vel = 0.95 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 21. Bass Full
    LuaPreset(
      id: 'seq_bass_full',
      name: 'Bass Full',
      category: LuaPresetCategory.midiSeq,
      description: 'Single sustained full 1-bar root bass note (16 steps).',
      code: '''
-- @name: Bass Full
-- @category: midiSeq
-- @description: Sustained full-bar root bass note

notes = {
  { pitch = 36, start = 0.00, duration = 16.00, vel = 0.90 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 22. Bass Halves
    LuaPreset(
      id: 'seq_bass_halves',
      name: 'Bass Halves',
      category: LuaPresetCategory.midiSeq,
      description: 'Two half-bar sustained bass notes (8 steps each).',
      code: '''
-- @name: Bass Halves
-- @category: midiSeq
-- @description: Two half-bar sustained bass notes

notes = {
  { pitch = 36, start = 0.00, duration = 8.00, vel = 0.90 },
  { pitch = 36, start = 8.00, duration = 8.00, vel = 0.88 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 23. Offbeat Bass
    LuaPreset(
      id: 'seq_offbeat_bass',
      name: 'Offbeat Bass (Pump)',
      category: LuaPresetCategory.midiSeq,
      description: 'Pumping offbeat bass notes hitting between kick downbeats for EDM and house grooves.',
      code: '''
-- @name: Offbeat Bass (Pump)
-- @category: midiSeq
-- @description: Pumping offbeat bass pattern

notes = {
  { pitch = 36, start = 2.00, duration = 2.00, vel = 0.90 },
  { pitch = 36, start = 6.00, duration = 2.00, vel = 0.88 },
  { pitch = 36, start = 10.00, duration = 2.00, vel = 0.90 },
  { pitch = 36, start = 14.00, duration = 2.00, vel = 0.88 }
}

function process(notes, time_ctx)
  return notes
end
''',
    ),

    // 24. Harmonic Chord Follower MIDI FX
    LuaPreset(
      id: 'chord_follower_midi_fx',
      name: 'Harmonic Chord Follower FX',
      category: LuaPresetCategory.midiFx,
      description: 'Conforms incoming notes non-destructively to the active project Chord Track.',
      code: '''
-- @name: Harmonic Chord Follower FX
-- @category: midiFx
-- @param: Mode = 0 (0: Chord, 1: Bass, 2: Scale, 3: Color)
local ChordFollower = {}

function ChordFollower.transform_notes(notes, params, timeContext)
  -- Uses timeContext.chord / timeContext.chordTrack to conform notes
  return Midi.chord_follow(notes, params["Mode"] or 0, timeContext)
end

return ChordFollower
''',
    ),

    // 25. Chord Arpeggiator MIDI FX
    LuaPreset(
      id: 'chord_arp_midi_fx',
      name: 'Chord Arpeggiator FX',
      category: LuaPresetCategory.midiFx,
      description: 'Generates running arpeggio lines voiced directly from the active chord pitch classes.',
      code: '''
-- @name: Chord Arpeggiator FX
-- @category: midiFx
-- @param: Rate = 0.25 (0.25: 16th, 0.5: 8th, 1.0: Quarter)
-- @param: Octaves = 2 (1 to 3 octaves)
-- @param: Pattern = 0 (0: Up, 1: Down, 2: UpDown, 3: Random)
local ChordArp = {}

function ChordArp.transform_notes(notes, params, timeContext)
  return Midi.chord_arp(notes, params, timeContext)
end

return ChordArp
''',
    ),

    // 26. Chord Stabs & Voicings (MIDI SEQ)
    LuaPreset(
      id: 'seq_chord_stabs',
      name: 'Chord Stabs (Chord Track Follow)',
      category: LuaPresetCategory.midiSeq,
      description: 'Dynamic polyphonic chord stabs automatically voiced to the active project Chord Track progression.',
      code: '''
-- @name: Chord Stabs (Chord Track Follow)
-- @category: midiSeq
-- @description: Dynamic polyphonic chord stabs voiced to project Chord Track

notes = {
  { pitch = 60, start = 0.00, duration = 3.00, vel = 0.90 },
  { pitch = 60, start = 4.00, duration = 2.00, vel = 0.85 },
  { pitch = 60, start = 8.00, duration = 3.00, vel = 0.90 },
  { pitch = 60, start = 12.00, duration = 3.00, vel = 0.85 }
}

function process(notes, time_ctx)
  -- Automatically builds rich voicings using active Chord Track
  return Chord.generate_voicing(notes, time_ctx)
end
''',
    ),

    // 27. Dynamic Bassline (MIDI SEQ)
    LuaPreset(
      id: 'seq_dynamic_bassline',
      name: 'Dynamic Bassline (Chord Track Follow)',
      category: LuaPresetCategory.midiSeq,
      description: 'Rhythmic bass groove that tracks root and slash bass notes from the Chord Track.',
      code: '''
-- @name: Dynamic Bassline (Chord Track Follow)
-- @category: midiSeq
-- @description: Rhythmic bassline conforming to active Chord Track root/slash bass notes

notes = {
  { pitch = 36, start = 0.00, duration = 1.50, vel = 0.95 },
  { pitch = 36, start = 3.00, duration = 1.00, vel = 0.80 },
  { pitch = 36, start = 6.00, duration = 1.50, vel = 0.90 },
  { pitch = 36, start = 8.00, duration = 2.00, vel = 0.95 },
  { pitch = 36, start = 12.00, duration = 1.50, vel = 0.85 },
  { pitch = 36, start = 14.00, duration = 1.00, vel = 0.80 }
}

function process(notes, time_ctx)
  return Chord.snap_to_chord(notes, time_ctx, "bass")
end
''',
    ),
  ];
}
