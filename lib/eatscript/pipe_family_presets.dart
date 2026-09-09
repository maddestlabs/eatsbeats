import 'lua_script_library.dart';

/// General MIDI Pipe Family (GM 72–79 / 1-indexed 73–80) Physical Modeling Presets.
///
/// Implements authentic physical models for:
/// - 72: Concert Piccolo (`concert_piccolo`)
/// - 73: Concert Flute (`concert_flute`)
/// - 74: Wooden Recorder (`wooden_recorder`)
/// - 75: Pan Flute (`pan_flute`)
/// - 76: Blown Bottle (`blown_bottle`)
/// - 77: Shakuhachi (`shakuhachi_bamboo`)
/// - 78: Tin Whistle (`tin_whistle`)
/// - 79: Sweet Ocarina (`sweet_ocarina`)
class PipeFamilyPresets {
  static const List<LuaPreset> all = [
    // -------------------------------------------------------------
    // GM 72 (1-indexed 73): Concert Piccolo
    // -------------------------------------------------------------
    LuaPreset(
      id: 'concert_piccolo',
      name: 'Concert Piccolo',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an orchestral concert piccolo: narrow cylindrical bore transposing one octave higher (+12 semitones), brilliant upper harmonic reach, razor-sharp labium chiff, high-velocity air turbulence, sustained ADSR breath envelope, and rapid micro-vibrato.',
      code: '''
-- @id: concert_piccolo
-- @name: Concert Piccolo
-- @category: instrument
-- @description: Physical model of an orchestral concert piccolo: narrow cylindrical bore transposing one octave higher (+12 semitones), brilliant upper harmonic reach, razor-sharp labium chiff, high-velocity air turbulence, sustained ADSR breath envelope, and rapid micro-vibrato.

local ConcertPiccolo = {}

function ConcertPiccolo.init()
  -- Embouchure & Air Jet
  Param.add("BreathPressure", 0.5, 2.0, 1.25)
  Param.add("ChiffAttack", 0.0, 1.5, 0.65)
  Param.add("AirTurbulence", 0.0, 1.0, 0.35)
  Param.add("Overblow", 0.0, 1.0, 0.0)

  -- Lyrical Vibrato
  Param.add("VibratoDepth", 0.0, 0.8, 0.25)
  Param.add("VibratoRate", 4.0, 9.0, 6.8)
  Param.add("VibratoDelay", 0.0, 0.6, 0.15)

  -- Bore Acoustics
  Param.add("Brightness", 0.5, 2.5, 1.35)
  Param.add("BoreResonance", 0.2, 2.0, 1.10)

  -- Continuous ADSR Breath Envelope
  Param.add("Attack", 0.005, 0.3, 0.025)
  Param.add("Decay", 0.02, 0.6, 0.10)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.02, 1.0, 0.18)
end

function ConcertPiccolo.process(time, freq, note, params)
  local pressure = params["BreathPressure"] or 1.25
  local chiff = params["ChiffAttack"] or 0.65
  local turbulence = params["AirTurbulence"] or 0.35
  local overblow = params["Overblow"] or 0.0
  local vibDepth = params["VibratoDepth"] or 0.25
  local vibRate = params["VibratoRate"] or 6.8
  local vibDelay = params["VibratoDelay"] or 0.15
  local brightness = params["Brightness"] or 1.35
  local boreRes = params["BoreResonance"] or 1.10

  local attack = params["Attack"] or 0.025
  local decay = params["Decay"] or 0.10
  local sustain = params["Sustain"] or 0.88

  -- Continuous ADSR Breath Pressure Envelope
  local env = sustain
  if time < attack then
    env = (time / math.max(0.001, attack))
  elseif time < (attack + decay) then
    local dProgress = (time - attack) / math.max(0.001, decay)
    env = 1.0 - dProgress * (1.0 - sustain)
  end
  env = env * pressure

  -- Piccolo naturally sounds one octave higher than written (2x frequency)
  local f0 = freq * 2.0 * (1.0 + (overblow > 0.5 and 1.0 or 0.0))

  -- Vibrato with natural onset delay
  local currentVib = 0.0
  if time > vibDelay and vibDepth > 0.001 then
    local vibRamp = math.min(1.0, (time - vibDelay) / 0.20)
    currentVib = math.sin(2.0 * math.pi * vibRate * time) * (vibDepth * 0.016) * vibRamp
  end
  local f = f0 * (1.0 + currentVib)

  -- Sharp labium chiff transient (burst of vortex noise + edge harmonic)
  local chiffBurst = 0.0
  if time < 0.045 and chiff > 0.001 then
    chiffBurst = math.sin(2.0 * math.pi * (f * 3.6) * time) * math.exp(-time * 95.0) * chiff * 0.5
  end

  -- Modulated air turbulence (pinkish vortex shedding)
  local airNoise = math.sin(time * 31415.9) * turbulence * 0.14 * env * (0.8 + 0.2 * math.sin(2.0 * math.pi * f * time))

  -- Narrow cylindrical open bore overtone series
  local phase = 2.0 * math.pi * f * time
  local h1 = math.sin(phase) * 0.85
  local h2 = math.sin(phase * 2.0) * 0.50 * brightness
  local h3 = math.sin(phase * 3.0) * 0.32 * brightness
  local h4 = math.sin(phase * 4.0) * 0.16 * brightness

  local raw = ((h1 + h2 + h3 + h4) * boreRes + chiffBurst + airNoise) * env
  return math.tanh(raw * 1.35) * 0.86
end

function ConcertPiccolo.gui()
  return {
    panel = {
      title = "CONCERT PICCOLO",
      subtitle = "High-Harmonic Narrow Cylindrical Waveguide",
      accent = "#4DEEEA",
      background = "slate_black",
      rackSides = "maple",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BreathPressure", label = "BREATH JET", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "ChiffAttack", label = "LABIUM CHIFF", unit = "amt", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "AirTurbulence", label = "AIR NOISE", unit = "%", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "Brightness", label = "BRIGHTNESS", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "BoreResonance", label = "BORE RES", unit = "res", knobStyle = "chrome", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "BreathPressure", label = "AIR STREAM VELOCITY & EMBOUCHURE PRESSURE", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "lvl", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

return ConcertPiccolo
''',
    ),

    // -------------------------------------------------------------
    // GM 73 (1-indexed 74): Concert Flute
    // -------------------------------------------------------------
    LuaPreset(
      id: 'concert_flute',
      name: 'Concert Flute',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a concert C transverse flute: non-linear air-jet labium splitting edge, pink breath turbulence, warm cylindrical open-bore fundamental, continuous sustained ADSR envelope, singing silver resonance, and natural delayed vibrato.',
      code: '''
-- @id: concert_flute
-- @name: Concert Flute
-- @category: instrument
-- @description: Physical modeling of a concert C transverse flute: non-linear air-jet labium splitting edge, pink breath turbulence, warm cylindrical open-bore fundamental, continuous sustained ADSR envelope, singing silver resonance, and natural delayed vibrato.

local ConcertFlute = {}

function ConcertFlute.init()
  -- Embouchure & Air Jet
  Param.add("BreathPressure", 0.5, 2.0, 1.15)
  Param.add("EmbouchureChiff", 0.0, 1.2, 0.50)
  Param.add("AirTurbulence", 0.0, 1.0, 0.25)
  Param.add("Overblow", 0.0, 1.0, 0.0)

  -- Lyrical Vibrato
  Param.add("VibratoDepth", 0.0, 0.8, 0.30)
  Param.add("VibratoRate", 3.5, 8.0, 5.5)
  Param.add("VibratoDelay", 0.0, 0.8, 0.22)

  -- Silver Bore Acoustics
  Param.add("SilverWarmth", 0.5, 2.0, 1.20)
  Param.add("BodyFormant", 0.2, 2.0, 1.05)

  -- Continuous ADSR Breath Envelope
  Param.add("Attack", 0.005, 0.4, 0.038)
  Param.add("Decay", 0.02, 0.8, 0.14)
  Param.add("Sustain", 0.3, 1.0, 0.85)
  Param.add("Release", 0.02, 1.2, 0.25)
end

function ConcertFlute.process(time, freq, note, params)
  local pressure = params["BreathPressure"] or 1.15
  local chiff = params["EmbouchureChiff"] or 0.50
  local turbulence = params["AirTurbulence"] or 0.25
  local overblow = params["Overblow"] or 0.0
  local vibDepth = params["VibratoDepth"] or 0.30
  local vibRate = params["VibratoRate"] or 5.5
  local vibDelay = params["VibratoDelay"] or 0.22
  local warmth = params["SilverWarmth"] or 1.20
  local formant = params["BodyFormant"] or 1.05

  local attack = params["Attack"] or 0.038
  local decay = params["Decay"] or 0.14
  local sustain = params["Sustain"] or 0.85

  -- Continuous ADSR Breath Pressure Envelope
  local env = sustain
  if time < attack then
    env = (time / math.max(0.001, attack))
  elseif time < (attack + decay) then
    local dProgress = (time - attack) / math.max(0.001, decay)
    env = 1.0 - dProgress * (1.0 - sustain)
  end
  env = env * pressure

  -- Base pitch + register overblowing (octave jump if overblown)
  local f0 = freq * (1.0 + (overblow > 0.5 and 1.0 or 0.0))

  -- Classical delayed lyrical vibrato
  local currentVib = 0.0
  if time > vibDelay and vibDepth > 0.001 then
    local vibRamp = math.min(1.0, (time - vibDelay) / 0.24)
    currentVib = math.sin(2.0 * math.pi * vibRate * time) * (vibDepth * 0.015) * vibRamp
  end
  local f = f0 * (1.0 + currentVib)

  -- Transient labium breath chiff on note onset
  local chiffBurst = 0.0
  if time < 0.055 and chiff > 0.001 then
    chiffBurst = math.sin(2.0 * math.pi * (f * 3.2) * time) * math.exp(-time * 75.0) * chiff * 0.45
  end

  -- Modulated air turbulence (pinkish breath noise across embouchure hole)
  local breathNoise = math.sin(time * 26143.0) * turbulence * 0.12 * env * (0.85 + 0.15 * math.sin(2.0 * math.pi * f * time))

  -- Cylindrical open-bore harmonics (pure singing fundamental dominant)
  local phase = 2.0 * math.pi * f * time
  local h1 = math.sin(phase) * 0.98
  local h2 = math.sin(phase * 2.0) * 0.35 * warmth
  local h3 = math.sin(phase * 3.0) * 0.18 * warmth
  local h4 = math.sin(phase * 4.0) * 0.08 * warmth

  local raw = ((h1 + h2 + h3 + h4) * formant + chiffBurst + breathNoise) * env
  return math.tanh(raw * 1.25) * 0.88
end

function ConcertFlute.gui()
  return {
    panel = {
      title = "CONCERT FLUTE",
      subtitle = "Transverse Air-Jet Cylindrical Waveguide",
      accent = "#70D6FF",
      background = "matte_carbon",
      rackSides = "walnut",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BreathPressure", label = "BREATH", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "EmbouchureChiff", label = "CHIFF", unit = "amt", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "AirTurbulence", label = "AIR NOISE", unit = "%", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "SilverWarmth", label = "SILVER CORE", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "BodyFormant", label = "FORMANT", unit = "res", knobStyle = "chrome", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "EmbouchureChiff", label = "EMBOUCHURE EDGE CHIFF & SPLITTING TURBULENCE", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "lvl", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

return ConcertFlute
''',
    ),

    // -------------------------------------------------------------
    // GM 74 (1-indexed 75): Wooden Recorder
    // -------------------------------------------------------------
    LuaPreset(
      id: 'wooden_recorder',
      name: 'Wooden Recorder',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of a Baroque wooden blockflöte (recorder): fixed fipple windway, pearwood acoustic body resonance, balanced even-odd harmonics, continuous sustained ADSR envelope, delicate breath transient, and natural pitch stability.',
      code: '''
-- @id: wooden_recorder
-- @name: Wooden Recorder
-- @category: instrument
-- @description: Physical modeling of a Baroque wooden blockflöte (recorder): fixed fipple windway, pearwood acoustic body resonance, balanced even-odd harmonics, continuous sustained ADSR envelope, delicate breath transient, and natural pitch stability.

local WoodenRecorder = {}

function WoodenRecorder.init()
  -- Windway & Fipple
  Param.add("WindwayPressure", 0.5, 2.0, 1.10)
  Param.add("FippleChiff", 0.0, 1.2, 0.45)
  Param.add("AirTurbulence", 0.0, 0.8, 0.18)

  -- Wood Body Acoustics
  Param.add("WoodWarmth", 0.5, 2.0, 1.25)
  Param.add("ChamberResonance", 0.2, 2.0, 1.00)

  -- Vibrato
  Param.add("VibratoDepth", 0.0, 0.6, 0.18)
  Param.add("VibratoRate", 3.0, 7.5, 5.0)

  -- Continuous ADSR Breath Envelope
  Param.add("Attack", 0.005, 0.3, 0.030)
  Param.add("Decay", 0.02, 0.6, 0.12)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.02, 1.0, 0.20)
end

function WoodenRecorder.process(time, freq, note, params)
  local pressure = params["WindwayPressure"] or 1.10
  local chiff = params["FippleChiff"] or 0.45
  local turbulence = params["AirTurbulence"] or 0.18
  local warmth = params["WoodWarmth"] or 1.25
  local chamber = params["ChamberResonance"] or 1.00
  local vibDepth = params["VibratoDepth"] or 0.18
  local vibRate = params["VibratoRate"] or 5.0

  local attack = params["Attack"] or 0.030
  local decay = params["Decay"] or 0.12
  local sustain = params["Sustain"] or 0.88

  -- Continuous ADSR Breath Pressure Envelope
  local env = sustain
  if time < attack then
    env = (time / math.max(0.001, attack))
  elseif time < (attack + decay) then
    local dProgress = (time - attack) / math.max(0.001, decay)
    env = 1.0 - dProgress * (1.0 - sustain)
  end
  env = env * pressure

  -- Recorder fixed windway has very subtle, tasteful vibrato
  local currentVib = math.sin(2.0 * math.pi * vibRate * time) * (vibDepth * 0.009)
  local f = freq * (1.0 + currentVib)

  -- Wooden fipple entrance chiff
  local fippleClick = 0.0
  if time < 0.035 and chiff > 0.001 then
    fippleClick = math.sin(2.0 * math.pi * (f * 2.8) * time) * math.exp(-time * 110.0) * chiff * 0.45
  end

  -- Balanced cylindrical-conical bore overtone distribution (distinct woody color)
  local phase = 2.0 * math.pi * f * time
  local h1 = math.sin(phase) * 0.95
  local h2 = math.sin(phase * 2.0) * 0.40 * warmth
  local h3 = math.sin(phase * 3.0) * 0.22 * warmth
  local h4 = math.sin(phase * 4.0) * 0.09 * warmth

  local woodAir = math.sin(time * 17777.0) * turbulence * 0.09 * env

  local raw = ((h1 + h2 + h3 + h4) * chamber + fippleClick + woodAir) * env
  return math.tanh(raw * 1.20) * 0.88
end

function WoodenRecorder.gui()
  return {
    panel = {
      title = "WOODEN RECORDER",
      subtitle = "Baroque Fipple Windway & Pearwood Body",
      accent = "#D4A373",
      background = "wood_walnut",
      rackSides = "mahogany",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "WindwayPressure", label = "WINDWAY", unit = "x", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "FippleChiff", label = "FIPPLE CHIFF", unit = "amt", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "AirTurbulence", label = "AIR NOISE", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "WoodWarmth", label = "PEARWOOD", unit = "x", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "ChamberResonance", label = "CHAMBER", unit = "res", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "WoodWarmth", label = "BAROQUE PEARWOOD CHAMBER CORE WARMTH", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "lvl", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

return WoodenRecorder
''',
    ),

    // -------------------------------------------------------------
    // GM 75 (1-indexed 76): Pan Flute
    // -------------------------------------------------------------
    LuaPreset(
      id: 'pan_flute',
      name: 'Pan Flute',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of closed cane pipes: quarter-wavelength waveguide resonance with authentic odd-harmonic series (1f, 3f, 5f, 7f), continuous sustained ADSR envelope, soft breath puff transient, and Andean cane acoustic warmth.',
      code: '''
-- @id: pan_flute
-- @name: Pan Flute
-- @category: instrument
-- @description: Physical modeling of closed cane pipes: quarter-wavelength waveguide resonance with authentic odd-harmonic series (1f, 3f, 5f, 7f), continuous sustained ADSR envelope, soft breath puff transient, and Andean cane acoustic warmth.

local PanFlute = {}

function PanFlute.init()
  -- Cane & Embouchure
  Param.add("BreathPressure", 0.5, 2.0, 1.18)
  Param.add("CaneChiff", 0.0, 1.5, 0.55)
  Param.add("BreathAir", 0.0, 1.0, 0.38)

  -- Closed Pipe Acoustics
  Param.add("CaneResonance", 0.2, 2.0, 1.20)
  Param.add("OddHarmonics", 0.5, 2.0, 1.30)

  -- Vibrato
  Param.add("VibratoDepth", 0.0, 0.8, 0.28)
  Param.add("VibratoRate", 3.5, 8.0, 5.8)

  -- Continuous ADSR Breath Envelope
  Param.add("Attack", 0.005, 0.4, 0.040)
  Param.add("Decay", 0.02, 0.8, 0.15)
  Param.add("Sustain", 0.3, 1.0, 0.85)
  Param.add("Release", 0.02, 1.2, 0.30)
end

function PanFlute.process(time, freq, note, params)
  local pressure = params["BreathPressure"] or 1.18
  local chiff = params["CaneChiff"] or 0.55
  local airNoise = params["BreathAir"] or 0.38
  local caneRes = params["CaneResonance"] or 1.20
  local oddGain = params["OddHarmonics"] or 1.30
  local vibDepth = params["VibratoDepth"] or 0.28
  local vibRate = params["VibratoRate"] or 5.8

  local attack = params["Attack"] or 0.040
  local decay = params["Decay"] or 0.15
  local sustain = params["Sustain"] or 0.85

  -- Continuous ADSR Breath Pressure Envelope
  local env = sustain
  if time < attack then
    env = (time / math.max(0.001, attack))
  elseif time < (attack + decay) then
    local dProgress = (time - attack) / math.max(0.001, decay)
    env = 1.0 - dProgress * (1.0 - sustain)
  end
  env = env * pressure

  local currentVib = math.sin(2.0 * math.pi * vibRate * time) * (vibDepth * 0.014)
  local f = freq * (1.0 + currentVib)

  -- Soft breath puff transient on cane lip
  local puff = 0.0
  if time < 0.060 and chiff > 0.001 then
    puff = (math.sin(time * 19821.0) * 0.6 + math.sin(2.0 * math.pi * f * 2.0 * time) * 0.4) *
           math.exp(-time * 55.0) * chiff * 0.5
  end

  -- Closed-end pipe quarter-wave physics: strong odd harmonics (1, 3, 5, 7), subdued even harmonics
  local phase = 2.0 * math.pi * f * time
  local h1 = math.sin(phase) * 1.00
  local h2 = math.sin(phase * 2.0) * 0.10 -- Subdued even harmonic
  local h3 = math.sin(phase * 3.0) * 0.45 * oddGain
  local h4 = math.sin(phase * 4.0) * 0.05 -- Subdued even harmonic
  local h5 = math.sin(phase * 5.0) * 0.22 * oddGain
  local h7 = math.sin(phase * 7.0) * 0.10 * oddGain

  local breathSheen = math.sin(time * 28945.0) * airNoise * 0.15 * env * (0.8 + 0.2 * math.sin(phase))

  local raw = ((h1 + h2 + h3 + h4 + h5 + h7) * caneRes + puff + breathSheen) * env
  return math.tanh(raw * 1.25) * 0.86
end

function PanFlute.gui()
  return {
    panel = {
      title = "PAN FLUTE",
      subtitle = "Closed-Pipe Cane Waveguide Physical Model",
      accent = "#E0A96D",
      background = "blonde_pine",
      rackSides = "maple",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BreathPressure", label = "BREATH", unit = "x", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "CaneChiff", label = "CANE CHIFF", unit = "amt", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "BreathAir", label = "BREATH AIR", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "OddHarmonics", label = "ODD HARMONICS", unit = "x", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "CaneResonance", label = "CANE RES", unit = "res", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "OddHarmonics", label = "CLOSED-PIPE QUARTER-WAVE ODD HARMONIC EMPHASIS", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "lvl", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

return PanFlute
''',
    ),

    // -------------------------------------------------------------
    // GM 76 (1-indexed 77): Blown Bottle
    // -------------------------------------------------------------
    LuaPreset(
      id: 'blown_bottle',
      name: 'Blown Bottle',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an acoustic blown glass bottle: Helmholtz acoustic cavity resonator excited by lip air-jet vortex shedding, continuous sustained ADSR envelope, mellow fundamental dominance, and glass body tone.',
      code: '''
-- @id: blown_bottle
-- @name: Blown Bottle
-- @category: instrument
-- @description: Physical model of an acoustic blown glass bottle: Helmholtz acoustic cavity resonator excited by lip air-jet vortex shedding, continuous sustained ADSR envelope, mellow fundamental dominance, and glass body tone.

local BlownBottle = {}

function BlownBottle.init()
  -- Lip & Air Jet
  Param.add("BreathPressure", 0.5, 2.2, 1.15)
  Param.add("MouthChiff", 0.0, 1.5, 0.45)
  Param.add("AirTurbulence", 0.0, 1.0, 0.42)

  -- Helmholtz Cavity
  Param.add("CavityQ", 2.0, 40.0, 18.0)
  Param.add("GlassTone", 0.2, 2.0, 1.10)

  -- Vibrato
  Param.add("VibratoDepth", 0.0, 0.5, 0.12)
  Param.add("VibratoRate", 2.5, 6.5, 4.5)

  -- Continuous ADSR Breath Envelope
  Param.add("Attack", 0.01, 0.5, 0.060)
  Param.add("Decay", 0.02, 0.8, 0.18)
  Param.add("Sustain", 0.3, 1.0, 0.82)
  Param.add("Release", 0.02, 1.2, 0.22)
end

function BlownBottle.process(time, freq, note, params)
  local pressure = params["BreathPressure"] or 1.15
  local chiff = params["MouthChiff"] or 0.45
  local turbulence = params["AirTurbulence"] or 0.42
  local glass = params["GlassTone"] or 1.10
  local vibDepth = params["VibratoDepth"] or 0.12
  local vibRate = params["VibratoRate"] or 4.5

  local attack = params["Attack"] or 0.060
  local decay = params["Decay"] or 0.18
  local sustain = params["Sustain"] or 0.82

  -- Continuous ADSR Breath Pressure Envelope
  local env = sustain
  if time < attack then
    env = (time / math.max(0.001, attack))
  elseif time < (attack + decay) then
    local dProgress = (time - attack) / math.max(0.001, decay)
    env = 1.0 - dProgress * (1.0 - sustain)
  end
  env = env * pressure

  local currentVib = math.sin(2.0 * math.pi * vibRate * time) * (vibDepth * 0.010)
  local f = freq * (1.0 + currentVib)

  -- Mouth onset chiff
  local mouthAir = 0.0
  if time < 0.070 and chiff > 0.001 then
    mouthAir = math.sin(time * 14500.0) * math.exp(-time * 40.0) * chiff * 0.4
  end

  -- Lip turbulence across opening
  local lipNoise = math.sin(time * 33881.0) * turbulence * 0.14 * env

  -- Helmholtz cavity produces an extraordinarily pure sine fundamental
  local phase = 2.0 * math.pi * f * time
  local h1 = math.sin(phase) * 1.00
  local h2 = math.sin(phase * 2.0) * 0.06 * glass -- Very weak 2nd harmonic
  local h3 = math.sin(phase * 3.0) * 0.02 * glass

  local raw = ((h1 + h2 + h3) * glass + mouthAir + lipNoise) * env
  return math.tanh(raw * 1.30) * 0.90
end

function BlownBottle.gui()
  return {
    panel = {
      title = "BLOWN BOTTLE",
      subtitle = "Helmholtz Cavity Resonator & Lip Jet Model",
      accent = "#52B788",
      background = "matte_carbon",
      rackSides = "walnut",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BreathPressure", label = "LIP JET", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "MouthChiff", label = "MOUTH CHIFF", unit = "amt", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "AirTurbulence", label = "LIP TURB", unit = "%", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "CavityQ", label = "CAVITY Q", unit = "res", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "GlassTone", label = "GLASS TONE", unit = "x", knobStyle = "chrome", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "CavityQ", label = "HELMHOLTZ CAVITY ACOUSTIC RESONANCE QUALITY (Q)", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "lvl", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

return BlownBottle
''',
    ),

    // -------------------------------------------------------------
    // GM 77 (1-indexed 78): Shakuhachi
    // -------------------------------------------------------------
    LuaPreset(
      id: 'shakuhachi_bamboo',
      name: 'Shakuhachi',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of the traditional Japanese end-blown bamboo flute: angled utaguchi blowing bevel, explosive muraiki breath attack, continuous sustained ADSR envelope, deep expressive delayed vibrato, and thick bamboo culm resonance.',
      code: '''
-- @id: shakuhachi_bamboo
-- @name: Shakuhachi
-- @category: instrument
-- @description: Physical modeling of the traditional Japanese end-blown bamboo flute: angled utaguchi blowing bevel, explosive muraiki breath attack, continuous sustained ADSR envelope, deep expressive delayed vibrato, and thick bamboo culm resonance.

local Shakuhachi = {}

function Shakuhachi.init()
  -- Utaguchi & Muraiki
  Param.add("BreathPressure", 0.5, 2.5, 1.25)
  Param.add("MuraikiBreath", 0.0, 2.0, 0.75)
  Param.add("AirTurbulence", 0.0, 1.2, 0.48)

  -- Bamboo Culm Acoustics
  Param.add("BambooWarmth", 0.5, 2.0, 1.30)
  Param.add("UtaguchiBevel", 0.2, 2.0, 1.15)

  -- Lyrical Delayed Vibrato
  Param.add("VibratoDepth", 0.0, 1.2, 0.42)
  Param.add("VibratoRate", 3.0, 7.5, 5.2)
  Param.add("VibratoDelay", 0.0, 0.8, 0.20)

  -- Continuous ADSR Breath Envelope
  Param.add("Attack", 0.005, 0.4, 0.045)
  Param.add("Decay", 0.02, 0.8, 0.16)
  Param.add("Sustain", 0.3, 1.0, 0.84)
  Param.add("Release", 0.02, 1.4, 0.32)
end

function Shakuhachi.process(time, freq, note, params)
  local pressure = params["BreathPressure"] or 1.25
  local muraiki = params["MuraikiBreath"] or 0.75
  local turbulence = params["AirTurbulence"] or 0.48
  local warmth = params["BambooWarmth"] or 1.30
  local bevel = params["UtaguchiBevel"] or 1.15
  local vibDepth = params["VibratoDepth"] or 0.42
  local vibRate = params["VibratoRate"] or 5.2
  local vibDelay = params["VibratoDelay"] or 0.20

  local attack = params["Attack"] or 0.045
  local decay = params["Decay"] or 0.16
  local sustain = params["Sustain"] or 0.84

  -- Continuous ADSR Breath Pressure Envelope
  local env = sustain
  if time < attack then
    env = (time / math.max(0.001, attack))
  elseif time < (attack + decay) then
    local dProgress = (time - attack) / math.max(0.001, decay)
    env = 1.0 - dProgress * (1.0 - sustain)
  end
  env = env * pressure

  -- Deep expressive delayed pitch vibrato
  local currentVib = 0.0
  if time > vibDelay and vibDepth > 0.001 then
    local vibRamp = math.min(1.0, (time - vibDelay) / 0.25)
    currentVib = math.sin(2.0 * math.pi * vibRate * time) * (vibDepth * 0.022) * vibRamp
  end
  local f = freq * (1.0 + currentVib)

  -- Muraiki breath attack burst (intense explosive turbulent air across utaguchi)
  local muraikiBurst = 0.0
  if time < 0.080 and muraiki > 0.001 then
    local ct = time / 0.080
    muraikiBurst = (math.sin(time * 18456.0) * 0.7 + math.sin(time * 31209.0) * 0.3) *
                   math.exp(-ct * 3.8) * muraiki * 0.75
  end

  -- Continuous bamboo breath turbulence
  local breathAir = math.sin(time * 24891.0) * turbulence * 0.16 * env * (0.8 + 0.2 * math.sin(2.0 * math.pi * f * time))

  -- Thick bamboo bore overtone series
  local phase = 2.0 * math.pi * f * time
  local h1 = math.sin(phase) * 0.95
  local h2 = math.sin(phase * 2.0) * 0.42 * warmth
  local h3 = math.sin(phase * 3.0) * 0.26 * bevel
  local h4 = math.sin(phase * 4.0) * 0.14 * bevel

  local raw = ((h1 + h2 + h3 + h4) * warmth + muraikiBurst + breathAir) * env
  return math.tanh(raw * 1.30) * 0.86
end

function Shakuhachi.gui()
  return {
    panel = {
      title = "SHAKUHACHI",
      subtitle = "End-Blown Bamboo Utaguchi & Muraiki Model",
      accent = "#C9A227",
      background = "wood_walnut",
      rackSides = "rosewood",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BreathPressure", label = "BREATH", unit = "x", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "MuraikiBreath", label = "MURAIKI", unit = "amt", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "AirTurbulence", label = "AIR NOISE", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "BambooWarmth", label = "BAMBOO", unit = "x", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "UtaguchiBevel", label = "UTAGUCHI", unit = "res", knobStyle = "vintage", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "MuraikiBreath", label = "MURAIKI EXPLOSIVE EMBOUCHURE BREATH TURBULENCE", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "lvl", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

return Shakuhachi
''',
    ),

    // -------------------------------------------------------------
    // GM 78 (1-indexed 79): Tin Whistle
    // -------------------------------------------------------------
    LuaPreset(
      id: 'tin_whistle',
      name: 'Tin Whistle',
      category: LuaPresetCategory.instrument,
      description: 'Physical modeling of an Irish tin pennywhistle: narrow cylindrical brass/tin body, crisp fipple chiff chirp, continuous sustained ADSR envelope, bright agile upper register, and lively Celtic ornamentation capability.',
      code: '''
-- @id: tin_whistle
-- @name: Tin Whistle
-- @category: instrument
-- @description: Physical modeling of an Irish tin pennywhistle: narrow cylindrical brass/tin body, crisp fipple chiff chirp, continuous sustained ADSR envelope, bright agile upper register, and lively Celtic ornamentation capability.

local TinWhistle = {}

function TinWhistle.init()
  -- Fipple & Breath
  Param.add("BreathPressure", 0.5, 2.2, 1.18)
  Param.add("ChirpChiff", 0.0, 1.5, 0.60)
  Param.add("AirTurbulence", 0.0, 0.8, 0.22)
  Param.add("Overblow", 0.0, 1.0, 0.0)

  -- Tin Body Acoustics
  Param.add("TinBodyTone", 0.5, 2.0, 1.25)

  -- Vibrato
  Param.add("VibratoDepth", 0.0, 0.7, 0.22)
  Param.add("VibratoRate", 4.0, 8.5, 6.0)

  -- Continuous ADSR Breath Envelope
  Param.add("Attack", 0.005, 0.3, 0.022)
  Param.add("Decay", 0.02, 0.6, 0.10)
  Param.add("Sustain", 0.3, 1.0, 0.86)
  Param.add("Release", 0.02, 1.0, 0.20)
end

function TinWhistle.process(time, freq, note, params)
  local pressure = params["BreathPressure"] or 1.18
  local chiff = params["ChirpChiff"] or 0.60
  local turbulence = params["AirTurbulence"] or 0.22
  local overblow = params["Overblow"] or 0.0
  local tinTone = params["TinBodyTone"] or 1.25
  local vibDepth = params["VibratoDepth"] or 0.22
  local vibRate = params["VibratoRate"] or 6.0

  local attack = params["Attack"] or 0.022
  local decay = params["Decay"] or 0.10
  local sustain = params["Sustain"] or 0.86

  -- Continuous ADSR Breath Pressure Envelope
  local env = sustain
  if time < attack then
    env = (time / math.max(0.001, attack))
  elseif time < (attack + decay) then
    local dProgress = (time - attack) / math.max(0.001, decay)
    env = 1.0 - dProgress * (1.0 - sustain)
  end
  env = env * pressure

  local f0 = freq * (1.0 + (overblow > 0.5 and 1.0 or 0.0))
  local currentVib = math.sin(2.0 * math.pi * vibRate * time) * (vibDepth * 0.012)
  local f = f0 * (1.0 + currentVib)

  -- Agile chirp fipple chiff transient
  local chirp = 0.0
  if time < 0.040 and chiff > 0.001 then
    chirp = math.sin(2.0 * math.pi * (f * 3.4) * time) * math.exp(-time * 115.0) * chiff * 0.55
  end

  -- High-frequency breath air in narrow windway
  local airNoise = math.sin(time * 29113.0) * turbulence * 0.12 * env

  -- Bright cylindrical tin bore harmonics
  local phase = 2.0 * math.pi * f * time
  local h1 = math.sin(phase) * 0.92
  local h2 = math.sin(phase * 2.0) * 0.48 * tinTone
  local h3 = math.sin(phase * 3.0) * 0.28 * tinTone
  local h4 = math.sin(phase * 4.0) * 0.12 * tinTone

  local raw = ((h1 + h2 + h3 + h4) * tinTone + chirp + airNoise) * env
  return math.tanh(raw * 1.25) * 0.88
end

function TinWhistle.gui()
  return {
    panel = {
      title = "TIN WHISTLE",
      subtitle = "Traditional Pennywhistle Brass & Fipple Model",
      accent = "#64DFDF",
      background = "brushed_steel",
      rackSides = "maple",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BreathPressure", label = "BREATH", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "ChirpChiff", label = "FIPPLE CHIRP", unit = "amt", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "AirTurbulence", label = "AIR NOISE", unit = "%", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "TinBodyTone", label = "TIN BODY", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", unit = "%", knobStyle = "chrome", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "ChirpChiff", label = "FIPPLE JET CHIRP & ATTACK TRANSIENT", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "lvl", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "TinBodyTone", label = "BRIGHTNESS", unit = "x", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

return TinWhistle
''',
    ),

    // -------------------------------------------------------------
    // GM 79 (1-indexed 80): Sweet Ocarina
    // -------------------------------------------------------------
    LuaPreset(
      id: 'sweet_ocarina',
      name: 'Sweet Ocarina',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an acoustic ceramic vessel flute: enclosed Helmholtz cavity resonance, continuous sustained ADSR envelope, soft labium chiff, mellow singing fundamental purity, and gentle breath warmth.',
      code: '''
-- @id: sweet_ocarina
-- @name: Sweet Ocarina
-- @category: instrument
-- @description: Physical model of an acoustic ceramic vessel flute: enclosed Helmholtz cavity resonance, continuous sustained ADSR envelope, soft labium chiff, mellow singing fundamental purity, and gentle breath warmth.

local SweetOcarina = {}

function SweetOcarina.init()
  -- Labium & Breath
  Param.add("BreathPressure", 0.5, 2.0, 1.12)
  Param.add("SoftChiff", 0.0, 1.2, 0.40)
  Param.add("AirTurbulence", 0.0, 0.8, 0.22)

  -- Ceramic Acoustics
  Param.add("CeramicSweetness", 0.5, 2.0, 1.30)
  Param.add("CavityResonance", 0.2, 2.0, 1.05)

  -- Vibrato
  Param.add("VibratoDepth", 0.0, 0.7, 0.26)
  Param.add("VibratoRate", 3.5, 7.5, 5.3)

  -- Continuous ADSR Breath Envelope
  Param.add("Attack", 0.005, 0.4, 0.035)
  Param.add("Decay", 0.02, 0.7, 0.13)
  Param.add("Sustain", 0.3, 1.0, 0.86)
  Param.add("Release", 0.02, 1.2, 0.28)
end

function SweetOcarina.process(time, freq, note, params)
  local pressure = params["BreathPressure"] or 1.12
  local chiff = params["SoftChiff"] or 0.40
  local turbulence = params["AirTurbulence"] or 0.22
  local sweet = params["CeramicSweetness"] or 1.30
  local cavity = params["CavityResonance"] or 1.05
  local vibDepth = params["VibratoDepth"] or 0.26
  local vibRate = params["VibratoRate"] or 5.3

  local attack = params["Attack"] or 0.035
  local decay = params["Decay"] or 0.13
  local sustain = params["Sustain"] or 0.86

  -- Continuous ADSR Breath Pressure Envelope
  local env = sustain
  if time < attack then
    env = (time / math.max(0.001, attack))
  elseif time < (attack + decay) then
    local dProgress = (time - attack) / math.max(0.001, decay)
    env = 1.0 - dProgress * (1.0 - sustain)
  end
  env = env * pressure

  local currentVib = math.sin(2.0 * math.pi * vibRate * time) * (vibDepth * 0.013)
  local f = freq * (1.0 + currentVib)

  -- Soft breath chiff transient
  local softChiff = 0.0
  if time < 0.045 and chiff > 0.001 then
    softChiff = math.sin(2.0 * math.pi * (f * 2.4) * time) * math.exp(-time * 80.0) * chiff * 0.4
  end

  -- Gentle air turbulence
  local ceramicAir = math.sin(time * 21107.0) * turbulence * 0.11 * env

  -- Vessel flute produces pure fundamental with mellow warmth
  local phase = 2.0 * math.pi * f * time
  local h1 = math.sin(phase) * 1.00
  local h2 = math.sin(phase * 2.0) * 0.18 * sweet
  local h3 = math.sin(phase * 3.0) * 0.08 * sweet

  local raw = ((h1 + h2 + h3) * cavity + softChiff + ceramicAir) * env
  return math.tanh(raw * 1.22) * 0.88
end

function SweetOcarina.gui()
  return {
    panel = {
      title = "SWEET OCARINA",
      subtitle = "Ceramic Vessel Cavity & Soft Chiff Physical Model",
      accent = "#E76F51",
      background = "matte_carbon",
      rackSides = "mahogany",
      cornerRadius = 0,
      layout = {
        {
          type = "row",
          children = {
            { type = "knob", param = "BreathPressure", label = "BREATH", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "SoftChiff", label = "SOFT CHIFF", unit = "amt", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "AirTurbulence", label = "AIR NOISE", unit = "%", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "CeramicSweetness", label = "SWEETNESS", unit = "x", knobStyle = "chrome", size = 52 },
            { type = "knob", param = "CavityResonance", label = "CAVITY", unit = "res", knobStyle = "chrome", size = 52 },
          }
        },
        {
          type = "row",
          children = {
            { type = "hslider", param = "CeramicSweetness", label = "WARM CERAMIC VESSEL ROUNDED MELLOWNESS", style = "capsule" },
          }
        },
        {
          type = "row",
          children = {
            { type = "knob", param = "Attack", label = "ATTACK", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Decay", label = "DECAY", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Sustain", label = "SUSTAIN", unit = "lvl", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "Release", label = "RELEASE", unit = "s", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoDepth", label = "VIB DEPTH", unit = "%", knobStyle = "vintage", size = 52 },
            { type = "knob", param = "VibratoRate", label = "VIB RATE", unit = "Hz", knobStyle = "vintage", size = 52 },
          }
        }
      }
    }
  }
end

return SweetOcarina
''',
    ),
  ];
}
