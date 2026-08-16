enum LuaPresetCategory {
  instrument,
  audioFx,
  midiFx,
  utility;

  String get displayName {
    switch (this) {
      case LuaPresetCategory.instrument:
        return 'INSTRUMENT';
      case LuaPresetCategory.audioFx:
        return 'AUDIO FX';
      case LuaPresetCategory.midiFx:
        return 'MIDI FX';
      case LuaPresetCategory.utility:
        return 'UTILITY';
    }
  }

  static LuaPresetCategory parse(String categoryStr) {
    final clean = categoryStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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
    // 0. Eatsbits.v1 Native Node & Automation API Showcase Preset
    LuaPreset(
      id: 'eatsbits_v1_acid_automation',
      name: 'Eatsbits.v1 Native TB-303 + Delay (v1 API)',
      category: LuaPresetCategory.instrument,
      description: 'Demonstrates eatsbits.v1 opaque handles (NodeHandle, ParamHandle), WebAudio graph routing, and sample-accurate parameter automation curves.',
      code: '''
-- @name: Eatsbits.v1 Native TB-303
-- @category: instrument
local EatsbitsAcidPreset = {}

function EatsbitsAcidPreset.onInit(config)
  local synth = eatsbits.v1.createNode("TB303", {
    waveform = 0,
    oversample = 2
  })

  local delay = eatsbits.v1.createNode("StereoDelayFX", {
    timeMs = 250.0,
    feedback = 0.45,
    mix = 0.4
  })

  local master = eatsbits.v1.getMasterBus()
  synth:connect(delay)
  delay:connect(master)

  local cutoff = synth:getParam("Cutoff")
  local now = Scheduler.currentTime()
  cutoff:setValueAtTime(200.0, now)
  cutoff:exponentialRampToValueAtTime(8000.0, now + Scheduler.beatsToSeconds(8.0))
end

function EatsbitsAcidPreset.onTransportStart(bar, beat)
  Scheduler.scheduleNote(36, 0.95, 0.0, 2.0)
  Scheduler.scheduleNote(48, 1.00, 2.0, 1.0)
  Scheduler.scheduleNote(39, 0.85, 3.0, 1.0)
end

function EatsbitsAcidPreset.getState()
  return {
    version = "v1",
    preset = "EatsbitsAcidPreset",
    cutoff = 2400.0
  }
end

return EatsbitsAcidPreset
''',
    ),

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
      description: 'Synthesized punchy sub kick drum with exponential pitch sweep and smooth edge fade.',
      code: '''
-- @name: Eats Kick
-- @category: instrument
local ProceduralKick = {}

function ProceduralKick.init()
  Param.add("StartFreq", 100.0, 300.0, 160.0)
  Param.add("EndFreq", 30.0, 60.0, 42.0)
  Param.add("PitchDecay", 0.01, 0.1, 0.035)
  Param.add("AmpDecay", 0.1, 0.6, 0.35)
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
  local env = math.exp(-time * 5.0 / math.max(0.01, aDecay))
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
      description: 'Synthesized snare drum combining a 180Hz tonal body oscillator and high-pass filtered noise wires.',
      code: '''
-- @name: Eats Snare
-- @category: instrument
local ProceduralSnare = {}

function ProceduralSnare.init()
  Param.add("ToneFreq", 100.0, 300.0, 185.0)
  Param.add("Snappy", 0.0, 1.0, 0.65)
  Param.add("Decay", 0.05, 0.5, 0.1)
end

function ProceduralSnare.process(time, freq, note, params)
  local toneFreq = params["ToneFreq"] or 185.0
  local snappy = params["Snappy"] or 0.65
  local decay = params["Decay"] or 0.1

  local sweepFreq = toneFreq * math.exp(-time * 40.0)
  local body = math.sin(2.0 * math.pi * sweepFreq * time) * math.exp(-time * 25.0)

  local noise = (math.random() * 2.0 - 1.0) * math.exp(-time / decay)
  local filteredNoise = DSP.highpass(noise, 1500.0, 1.0)

  local output = body * (1.0 - snappy) + filteredNoise * snappy
  return math.tanh(output * 1.2)
end

return ProceduralSnare
''',
    ),

    // 4. Eats Hats Preset
    LuaPreset(
      id: 'procedural_hihat',
      name: 'Eats Hats',
      category: LuaPresetCategory.instrument,
      description: 'Synthesized hi-hat dominated by high-pass filtered white noise with adjustable metallic sheen and decay.',
      code: '''
-- @name: Eats Hats
-- @category: instrument
local ProceduralHiHat = {}

function ProceduralHiHat.init()
  Param.add("Cutoff", 4000.0, 14000.0, 8500.0)
  Param.add("Decay", 0.01, 0.4, 0.05)
  Param.add("Metallic", 0.0, 1.0, 0.15)
end

function ProceduralHiHat.process(time, freq, note, params)
  local cutoff = params["Cutoff"] or 8500.0
  local decay = params["Decay"] or 0.05
  local metallic = params["Metallic"] or 0.15

  local env = math.exp(-time / math.max(0.005, decay))

  local ring1 = math.sin(2.0 * math.pi * 205.0 * time) > 0 and 1.0 or -1.0
  local ring2 = math.sin(2.0 * math.pi * 305.0 * time) > 0 and 1.0 or -1.0
  local ring3 = math.sin(2.0 * math.pi * 365.0 * time) > 0 and 1.0 or -1.0
  local ring4 = math.sin(2.0 * math.pi * 396.0 * time) > 0 and 1.0 or -1.0
  local ring5 = math.sin(2.0 * math.pi * 434.0 * time) > 0 and 1.0 or -1.0
  local ring6 = math.sin(2.0 * math.pi * 700.0 * time) > 0 and 1.0 or -1.0
  local metallicRing = (ring1 + ring2 + ring3 + ring4 + ring5 + ring6) / 6.0

  local noise = (math.random() * 2.0 - 1.0)
  local rawSignal = noise * (1.0 - metallic * 0.4) + metallicRing * (metallic * 0.4)
  local filtered = DSP.highpass(rawSignal, cutoff, 1.2)

  return filtered * env * 0.75
end

return ProceduralHiHat
''',
    ),

    // 5. Procedural Clap Preset
    LuaPreset(
      id: 'procedural_clap',
      name: 'Procedural Handclap',
      category: LuaPresetCategory.instrument,
      description: 'Multi-burst noise clap synthesizer simulating human handclap reverberation.',
      code: '''
-- @name: Procedural Handclap
-- @category: instrument
local ProceduralClap = {}

function ProceduralClap.init()
  Param.add("RoomDecay", 0.05, 0.4, 0.18)
  Param.add("Tone", 800.0, 4000.0, 2200.0)
end

function ProceduralClap.process(time, freq, note, params)
  local roomDecay = params["RoomDecay"] or 0.18
  local tone = params["Tone"] or 2200.0

  local burstEnv = 0.0
  if time < 0.01 then burstEnv = 1.0
  elseif time < 0.022 then burstEnv = 0.75
  elseif time < 0.035 then burstEnv = 0.85
  else burstEnv = math.exp(-(time - 0.035) / roomDecay)
  end

  local noise = (math.random() * 2.0 - 1.0)
  local filtered = DSP.bandpass(noise, tone, 2.0)

  return filtered * burstEnv * 0.8
end

return ProceduralClap
''',
    ),

    // 6. Poly Lead Synth Preset
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
  Param.add("AttackSec", 0.0, 1.0, 0.005)
  Param.add("ReleaseSec", 0.01, 2.0, 0.4)
  Param.add("FilterCutoff", 200.0, 12000.0, 8000.0)
end

function SamplerInstrument.process(time, freq, note, params)
  local rootKey = params["RootKey"] or 60.0
  local pitchOffset = note - rootKey

  local rawSample = Sampler.read(note, time, pitchOffset)
  local attack = params["AttackSec"] or 0.005
  local release = params["ReleaseSec"] or 0.4
  local cutoff = params["FilterCutoff"] or 8000.0

  local env = DSP.env(time, attack, release)
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
      description: 'Multi-sampled SoundFont 2 (.sf2) bank player with key-zone mapping, bank selection, and filter control.',
      code: '''
-- @name: SoundFont 2 Player
-- @category: instrument
local SoundFontSampler = {}

function SoundFontSampler.init()
  Param.add("PresetNum", 0, 127, 0, 1)
  Param.add("BankNum", 0, 128, 0, 1)
  Param.add("FilterCutoff", 200.0, 12000.0, 10000.0)
  Param.add("AttackSec", 0.0, 1.0, 0.005)
  Param.add("ReleaseSec", 0.01, 2.0, 0.4)
end

function SoundFontSampler.process(time, freq, note, params)
  local rawSample = SoundFont.readZone(note, time)
  local attack = params["AttackSec"] or 0.005
  local release = params["ReleaseSec"] or 0.4
  local cutoff = params["FilterCutoff"] or 10000.0

  local env = DSP.env(time, attack, release)
  local filtered = DSP.lowpass(rawSample, cutoff, 1.0)
  return filtered * env
end

return SoundFontSampler
''',
    ),

    // 14. Lua MIDI Arpeggiator FX
    LuaPreset(
      id: 'arpeggiator_midi_fx',
      name: 'Lua MIDI Arpeggiator FX',
      category: LuaPresetCategory.midiFx,
      description: 'MIDI pattern transformer generating up/down octave arpeggio note sequences.',
      code: '''
-- @name: Lua MIDI Arpeggiator FX
-- @category: midiFx
local ArpeggiatorMidiFX = {}

function ArpeggiatorMidiFX.transform_notes(notes, params, timeContext)
  local rate = params["Rate"] or 1.0
  local octaves = params["Octaves"] or 2.0
  return Midi.arpeggiate(notes, rate, octaves)
end

return ArpeggiatorMidiFX
''',
    ),
  ];
}
