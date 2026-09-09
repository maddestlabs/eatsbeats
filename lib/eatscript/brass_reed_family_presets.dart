import 'lua_script_library.dart';

/// General MIDI Brass & Reed Family (GM 56–71) and Ethnic Sitar (GM 104)
/// Physical Modeling Presets for Eatsbeats.
///
/// Implements authentic physical models for:
/// - 56: Orchestral Trumpet (`orchestral_trumpet`)
/// - 57: Tenor Trombone (`tenor_trombone`)
/// - 58: Tuba (`tuba_brass`)
/// - 59: Muted Trumpet (`muted_trumpet`)
/// - 60: French Horn (`french_horn`)
/// - 61: Brass Section (`brass_section`)
/// - 64: Soprano Sax (`soprano_sax`)
/// - 65: Alto Sax (`alto_sax`)
/// - 66: Tenor Sax (`tenor_sax`)
/// - 67: Baritone Sax (`baritone_sax`)
/// - 68: Oboe (`oboe_woodwind`)
/// - 69: English Horn (`english_horn`)
/// - 70: Bassoon (`bassoon_woodwind`)
/// - 71: Clarinet (`clarinet_woodwind`)
/// - 104: Sitar (`sitar_jawari`)
class BrassReedFamilyPresets {
  static const List<LuaPreset> all = [
    // -------------------------------------------------------------
    // GM 56: Orchestral Trumpet
    // -------------------------------------------------------------
    LuaPreset(
      id: 'orchestral_trumpet',
      name: 'Orchestral Trumpet',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an orchestral B-flat trumpet: outward-striking lip reed oscillator, non-linear shock wave steepening in cylindrical leadpipe, bell flare radiation, and expressive lyrical vibrato.',
      code: '''
-- @id: orchestral_trumpet
-- @name: Orchestral Trumpet
-- @category: instrument
-- @description: Physical model of an orchestral B-flat trumpet: outward-striking lip reed oscillator, non-linear shock wave steepening in cylindrical leadpipe, bell flare radiation, and expressive lyrical vibrato.

local OrchestralTrumpet = {}

function OrchestralTrumpet.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.25)
  Param.add("LipTension", 0.6, 1.6, 1.0)
  Param.add("BellFlare", 0.2, 1.8, 0.82)
  Param.add("BrassBite", -6.0, 8.0, 2.2)
  Param.add("AirSheen", -6.0, 6.0, 1.5)
  Param.add("VibratoDepth", 0.0, 1.0, 0.22)
  Param.add("VibratoRate", 3.0, 8.0, 5.4)
  Param.add("Attack", 0.01, 0.3, 0.038)
  Param.add("Decay", 0.02, 0.6, 0.12)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.02, 0.8, 0.18)
end

function OrchestralTrumpet.process(time, freq, note, params)
  local p = params["BreathPressure"] or 1.25
  local bite = params["BrassBite"] or 2.2
  local env = 0.88
  if time < 0.038 then env = time / 0.038 end
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.6 * math.sin(phase * 2.0) + 0.4 * math.sin(phase * 3.0)
  return math.tanh(sig * p * env) * 0.95
end

function OrchestralTrumpet.gui()
  return {
    panel = {
      title = "ORCHESTRAL TRUMPET",
      subtitle = "Physical Lip-Reed & Bell Flare Waveguide",
      accent = "#FFD700",
      background = "brass_sheen",
      rackSides = "walnut",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "EMBOUCHURE & AIR PRESSURE",
          accent = "#FFD700",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", unit = "x", size = 52 },
                { type = "knob", param = "LipTension", label = "LIP TENSION", unit = "x", size = 52 },
                { type = "knob", param = "BellFlare", label = "BELL FLARE", unit = "x", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "ACOUSTIC PRESENCE & TONE",
          accent = "#FFA500",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BrassBite", label = "BRASS BITE", unit = "dB", size = 52 },
                { type = "knob", param = "AirSheen", label = "AIR SHEEN", unit = "dB", size = 52 },
                { type = "knob", param = "VibratoDepth", label = "VIBRATO", unit = "%", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return OrchestralTrumpet
''',
    ),

    // -------------------------------------------------------------
    // GM 57: Tenor Trombone
    // -------------------------------------------------------------
    LuaPreset(
      id: 'tenor_trombone',
      name: 'Tenor Trombone',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an orchestral tenor trombone: cylindrical slide tubing with conical bell expansion, warm brassy core resonance, and expressive low-register slide slide presence.',
      code: '''
-- @id: tenor_trombone
-- @name: Tenor Trombone
-- @category: instrument
-- @description: Physical model of an orchestral tenor trombone: cylindrical slide tubing with conical bell expansion, warm brassy core resonance, and expressive low-register slide slide presence.

local TenorTrombone = {}

function TenorTrombone.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.22)
  Param.add("LipTension", 0.6, 1.6, 0.98)
  Param.add("Warmth", -4.0, 8.0, 2.5)
  Param.add("SlidePresence", -6.0, 8.0, 1.8)
  Param.add("VibratoDepth", 0.0, 1.0, 0.20)
  Param.add("Attack", 0.01, 0.4, 0.052)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.02, 1.0, 0.24)
end

function TenorTrombone.process(time, freq, note, params)
  local p = params["BreathPressure"] or 1.22
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) * 0.9 + math.sin(phase * 2.0) * 0.5 + math.sin(phase * 3.0) * 0.3
  return math.tanh(sig * p) * 0.92
end

function TenorTrombone.gui()
  return {
    panel = {
      title = "TENOR TROMBONE",
      subtitle = "Cylindrical Slide & Conical Bell Waveguide",
      accent = "#E6B800",
      background = "brass_sheen",
      rackSides = "rosewood",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "SLIDE BORE & PRESSURE",
          accent = "#E6B800",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", unit = "x", size = 52 },
                { type = "knob", param = "Warmth", label = "WARMTH", unit = "dB", size = 52 },
                { type = "knob", param = "SlidePresence", label = "PRESENCE", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return TenorTrombone
''',
    ),

    // -------------------------------------------------------------
    // GM 58: Tuba
    // -------------------------------------------------------------
    LuaPreset(
      id: 'tuba_brass',
      name: 'Tuba',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of a deep bass tuba: massive conical bore waveguide, deep sub-chest fundamental resonance, slow lip inertia, and cavernous bell radiation.',
      code: '''
-- @id: tuba_brass
-- @name: Tuba
-- @category: instrument
-- @description: Physical model of a deep bass tuba: massive conical bore waveguide, deep sub-chest fundamental resonance, slow lip inertia, and cavernous bell radiation.

local Tuba = {}

function Tuba.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.30)
  Param.add("SubChest", 0.0, 8.0, 3.5)
  Param.add("TubaBody", -4.0, 8.0, 1.8)
  Param.add("Attack", 0.02, 0.4, 0.075)
  Param.add("Sustain", 0.3, 1.0, 0.90)
  Param.add("Release", 0.05, 1.5, 0.32)
end

function Tuba.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.45 * math.sin(phase * 2.0)
  return math.tanh(sig * 1.2) * 0.95
end

function Tuba.gui()
  return {
    panel = {
      title = "CONCERT TUBA",
      subtitle = "Deep Conical Brass Sub-Chest Waveguide",
      accent = "#C59B27",
      background = "brass_dark",
      rackSides = "walnut",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "SUB-CHEST & BORE",
          accent = "#C59B27",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "SubChest", label = "SUB CHEST", unit = "dB", size = 52 },
                { type = "knob", param = "TubaBody", label = "BODY", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return Tuba
''',
    ),

    // -------------------------------------------------------------
    // GM 59: Muted Trumpet
    // -------------------------------------------------------------
    LuaPreset(
      id: 'muted_trumpet',
      name: 'Muted Trumpet',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of a trumpet with Harmon mute: nasal acoustic cavity notch resonance, tight lip resistance, and distinctive vintage Miles Davis jazz timbre.',
      code: '''
-- @id: muted_trumpet
-- @name: Muted Trumpet
-- @category: instrument
-- @description: Physical model of a trumpet with Harmon mute: nasal acoustic cavity notch resonance, tight lip resistance, and distinctive vintage Miles Davis jazz timbre.

local MutedTrumpet = {}

function MutedTrumpet.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.18)
  Param.add("HarmonBite", 0.0, 10.0, 4.5)
  Param.add("StemDepth", -8.0, 2.0, -3.5)
  Param.add("VibratoDepth", 0.0, 1.0, 0.26)
  Param.add("Attack", 0.01, 0.2, 0.032)
  Param.add("Sustain", 0.3, 1.0, 0.85)
  Param.add("Release", 0.02, 0.6, 0.16)
end

function MutedTrumpet.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.8 * math.sin(phase * 3.0) + 0.5 * math.sin(phase * 5.0)
  return math.tanh(sig * 1.1) * 0.90
end

function MutedTrumpet.gui()
  return {
    panel = {
      title = "MUTED TRUMPET",
      subtitle = "Harmon Cavity Notch & Nasal Jazz Lip-Reed",
      accent = "#E5A93C",
      background = "slate_black",
      rackSides = "rosewood",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "HARMON MUTE CAVITY",
          accent = "#E5A93C",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "HarmonBite", label = "HARMON BITE", unit = "dB", size = 52 },
                { type = "knob", param = "StemDepth", label = "STEM NOTCH", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return MutedTrumpet
''',
    ),

    // -------------------------------------------------------------
    // GM 60: French Horn
    // -------------------------------------------------------------
    LuaPreset(
      id: 'french_horn',
      name: 'French Horn',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an orchestral French Horn: deep conical bell flare, mellow rotary valve impedance, warm velvety mid-range resonance, and heroic orchestral projection.',
      code: '''
-- @id: french_horn
-- @name: French Horn
-- @category: instrument
-- @description: Physical model of an orchestral French Horn: deep conical bell flare, mellow rotary valve impedance, warm velvety mid-range resonance, and heroic orchestral projection.

local FrenchHorn = {}

function FrenchHorn.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.16)
  Param.add("HornWarmth", 0.0, 8.0, 3.2)
  Param.add("BellMellow", 2000.0, 10000.0, 5500.0)
  Param.add("VibratoDepth", 0.0, 0.8, 0.18)
  Param.add("Attack", 0.02, 0.4, 0.065)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.05, 1.0, 0.28)
end

function FrenchHorn.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.5 * math.sin(phase * 2.0) + 0.25 * math.sin(phase * 3.0)
  return math.tanh(sig) * 0.92
end

function FrenchHorn.gui()
  return {
    panel = {
      title = "FRENCH HORN",
      subtitle = "Conical Bell Flare & Mellow Rotary Valve",
      accent = "#D4AF37",
      background = "brass_sheen",
      rackSides = "walnut",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "HORN ACOUSTICS",
          accent = "#D4AF37",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "HornWarmth", label = "WARMTH", unit = "dB", size = 52 },
                { type = "knob", param = "BellMellow", label = "MELLOW CUT", unit = "Hz", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return FrenchHorn
''',
    ),

    // -------------------------------------------------------------
    // GM 61: Brass Section
    // -------------------------------------------------------------
    LuaPreset(
      id: 'brass_section',
      name: 'Brass Section',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an orchestral brass section: multi-layer ensemble coupling trumpets, trombones, and horns with broad cinematic projection and expansive air sheen.',
      code: '''
-- @id: brass_section
-- @name: Brass Section
-- @category: instrument
-- @description: Physical model of an orchestral brass section: multi-layer ensemble coupling trumpets, trombones, and horns with broad cinematic projection and expansive air sheen.

local BrassSection = {}

function BrassSection.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.22)
  Param.add("EnsembleAir", 0.0, 8.0, 2.0)
  Param.add("Attack", 0.01, 0.3, 0.048)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.05, 1.0, 0.24)
end

function BrassSection.process(time, freq, note, params)
  local p1 = 2.0 * math.pi * freq * time
  local p2 = 2.0 * math.pi * (freq * 1.002) * time
  local sig = (math.sin(p1) + math.sin(p2)) * 0.55
  return math.tanh(sig * 1.2) * 0.95
end

function BrassSection.gui()
  return {
    panel = {
      title = "BRASS SECTION",
      subtitle = "Multi-Voice Coupled Orchestral Brass Ensemble",
      accent = "#FFD700",
      background = "brass_sheen",
      rackSides = "rosewood",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "ENSEMBLE DYNAMICS",
          accent = "#FFD700",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "EnsembleAir", label = "AIR SHEEN", unit = "dB", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return BrassSection
''',
    ),

    // -------------------------------------------------------------
    // GM 64: Soprano Sax
    // -------------------------------------------------------------
    LuaPreset(
      id: 'soprano_sax',
      name: 'Soprano Sax',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of a straight soprano saxophone: high-register conical woodwind bore, sharp cane reed non-linearity, and agile singing vibrato.',
      code: '''
-- @id: soprano_sax
-- @name: Soprano Sax
-- @category: instrument
-- @description: Physical model of a straight soprano saxophone: high-register conical woodwind bore, sharp cane reed non-linearity, and agile singing vibrato.

local SopranoSax = {}

function SopranoSax.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.18)
  Param.add("ReedStiffness", 0.2, 1.8, 0.60)
  Param.add("ReedBite", -4.0, 8.0, 2.2)
  Param.add("AirTurbulence", 0.0, 1.0, 0.20)
  Param.add("VibratoDepth", 0.0, 1.0, 0.32)
  Param.add("Attack", 0.01, 0.2, 0.032)
  Param.add("Sustain", 0.3, 1.0, 0.86)
  Param.add("Release", 0.02, 0.8, 0.20)
end

function SopranoSax.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.6 * math.sin(phase * 2.0) + 0.35 * math.sin(phase * 3.0)
  return math.tanh(sig * 1.1) * 0.90
end

function SopranoSax.gui()
  return {
    panel = {
      title = "SOPRANO SAX",
      subtitle = "Conical Woodwind & Cane Reed Non-Linearity",
      accent = "#F4D03F",
      background = "slate_black",
      rackSides = "maple",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "CANE REED & CONICAL BORE",
          accent = "#F4D03F",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "ReedStiffness", label = "REED STIFF", size = 52 },
                { type = "knob", param = "ReedBite", label = "REED BITE", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return SopranoSax
''',
    ),

    // -------------------------------------------------------------
    // GM 65: Alto Sax
    // -------------------------------------------------------------
    LuaPreset(
      id: 'alto_sax',
      name: 'Alto Sax',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an E-flat alto saxophone: curved conical brass body, inward-striking reed table with mouth pressure feedback, warm woodwind growl, and expressive jazz vibrato.',
      code: '''
-- @id: alto_sax
-- @name: Alto Sax
-- @category: instrument
-- @description: Physical model of an E-flat alto saxophone: curved conical brass body, inward-striking reed table with mouth pressure feedback, warm woodwind growl, and expressive jazz vibrato.

local AltoSax = {}

function AltoSax.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.20)
  Param.add("ReedStiffness", 0.2, 1.8, 0.55)
  Param.add("SaxBody", -4.0, 8.0, 2.5)
  Param.add("ReedBite", -4.0, 8.0, 2.0)
  Param.add("AirTurbulence", 0.0, 1.0, 0.22)
  Param.add("VibratoDepth", 0.0, 1.0, 0.30)
  Param.add("Attack", 0.01, 0.3, 0.038)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.02, 0.8, 0.22)
end

function AltoSax.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.7 * math.sin(phase * 2.0) + 0.4 * math.sin(phase * 3.0) + 0.2 * math.sin(phase * 4.0)
  return math.tanh(sig * 1.15) * 0.92
end

function AltoSax.gui()
  return {
    panel = {
      title = "ALTO SAXOPHONE",
      subtitle = "Curved Conical Bore & MSW Inward Reed Valve",
      accent = "#E5A93C",
      background = "brass_sheen",
      rackSides = "walnut",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "REED EMBOUCHURE & BODY",
          accent = "#E5A93C",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "SaxBody", label = "BODY WARMTH", unit = "dB", size = 52 },
                { type = "knob", param = "ReedBite", label = "REED BITE", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return AltoSax
''',
    ),

    // -------------------------------------------------------------
    // GM 66: Tenor Sax
    // -------------------------------------------------------------
    LuaPreset(
      id: 'tenor_sax',
      name: 'Tenor Sax',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of a B-flat tenor saxophone: smoky, resonant lower conical bore, breath turbulence noise, rich second harmonic reinforcement, and lush vibrato.',
      code: '''
-- @id: tenor_sax
-- @name: Tenor Sax
-- @category: instrument
-- @description: Physical model of a B-flat tenor saxophone: smoky, resonant lower conical bore, breath turbulence noise, rich second harmonic reinforcement, and lush vibrato.

local TenorSax = {}

function TenorSax.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.22)
  Param.add("ReedStiffness", 0.2, 1.8, 0.52)
  Param.add("SmokyWarmth", 0.0, 8.0, 2.8)
  Param.add("TenorPresence", -4.0, 8.0, 2.2)
  Param.add("AirTurbulence", 0.0, 1.0, 0.25)
  Param.add("VibratoDepth", 0.0, 1.0, 0.28)
  Param.add("Attack", 0.01, 0.3, 0.045)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.05, 1.0, 0.26)
end

function TenorSax.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.65 * math.sin(phase * 2.0) + 0.35 * math.sin(phase * 3.0)
  return math.tanh(sig * 1.2) * 0.94
end

function TenorSax.gui()
  return {
    panel = {
      title = "TENOR SAXOPHONE",
      subtitle = "Smoky Conical Bore & Breath Turbulence",
      accent = "#D4AC0D",
      background = "brass_dark",
      rackSides = "rosewood",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "SMOKY BORE & REED",
          accent = "#D4AC0D",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "SmokyWarmth", label = "SMOKY WARMTH", unit = "dB", size = 52 },
                { type = "knob", param = "TenorPresence", label = "PRESENCE", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return TenorSax
''',
    ),

    // -------------------------------------------------------------
    // GM 67: Baritone Sax
    // -------------------------------------------------------------
    LuaPreset(
      id: 'baritone_sax',
      name: 'Baritone Sax',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an E-flat baritone saxophone: massive low-frequency conical tubing, heavy cane reed bark, and gut-punch fundamental weight.',
      code: '''
-- @id: baritone_sax
-- @name: Baritone Sax
-- @category: instrument
-- @description: Physical model of an E-flat baritone saxophone: massive low-frequency conical tubing, heavy cane reed bark, and gut-punch fundamental weight.

local BaritoneSax = {}

function BaritoneSax.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.28)
  Param.add("ReedStiffness", 0.2, 1.8, 0.48)
  Param.add("BariWeight", 0.0, 10.0, 3.8)
  Param.add("BariBark", -4.0, 8.0, 2.0)
  Param.add("Attack", 0.02, 0.4, 0.058)
  Param.add("Sustain", 0.3, 1.0, 0.90)
  Param.add("Release", 0.05, 1.2, 0.30)
end

function BaritoneSax.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.5 * math.sin(phase * 2.0) + 0.4 * math.sin(phase * 3.0)
  return math.tanh(sig * 1.3) * 0.95
end

function BaritoneSax.gui()
  return {
    panel = {
      title = "BARITONE SAXOPHONE",
      subtitle = "Heavy Low-End Conical Reed Waveguide",
      accent = "#B7950B",
      background = "brass_dark",
      rackSides = "walnut",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "BARI WEIGHT & BARK",
          accent = "#B7950B",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "BariWeight", label = "LOW WEIGHT", unit = "dB", size = 52 },
                { type = "knob", param = "BariBark", label = "BARI BARK", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return BaritoneSax
''',
    ),

    // -------------------------------------------------------------
    // GM 68: Oboe
    // -------------------------------------------------------------
    LuaPreset(
      id: 'oboe_woodwind',
      name: 'Oboe',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an orchestral oboe: narrow conical wooden bore, double cane reed pressure non-linearity, and sharp dual-formant nasal focus (1.4kHz and 3.0kHz).',
      code: '''
-- @id: oboe_woodwind
-- @name: Oboe
-- @category: instrument
-- @description: Physical model of an orchestral oboe: narrow conical wooden bore, double cane reed pressure non-linearity, and sharp dual-formant nasal focus (1.4kHz and 3.0kHz).

local Oboe = {}

function Oboe.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.14)
  Param.add("ReedStiffness", 0.2, 1.8, 0.68)
  Param.add("NasalFormant1", 0.0, 8.0, 3.5)
  Param.add("NasalFormant2", 0.0, 8.0, 2.5)
  Param.add("VibratoDepth", 0.0, 1.0, 0.30)
  Param.add("Attack", 0.01, 0.2, 0.035)
  Param.add("Sustain", 0.3, 1.0, 0.85)
  Param.add("Release", 0.02, 0.8, 0.20)
end

function Oboe.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.8 * math.sin(phase * 2.0) + 0.6 * math.sin(phase * 3.0) + 0.4 * math.sin(phase * 4.0)
  return math.tanh(sig * 1.1) * 0.90
end

function Oboe.gui()
  return {
    panel = {
      title = "ORCHESTRAL OBOE",
      subtitle = "Conical Grenadilla & Dual Nasal Formant",
      accent = "#E67E22",
      background = "slate_black",
      rackSides = "rosewood",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "DOUBLE REED & FORMANTS",
          accent = "#E67E22",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "NasalFormant1", label = "FORMANT 1", unit = "dB", size = 52 },
                { type = "knob", param = "NasalFormant2", label = "FORMANT 2", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return Oboe
''',
    ),

    // -------------------------------------------------------------
    // GM 69: English Horn
    // -------------------------------------------------------------
    LuaPreset(
      id: 'english_horn',
      name: 'English Horn',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an English Horn (Cor Anglais): alto oboe pitch range with characteristic bulbous pear-shaped bell (*liebesfuss*) resonance and poignant double reed sweetness.',
      code: '''
-- @id: english_horn
-- @name: English Horn
-- @category: instrument
-- @description: Physical model of an English Horn (Cor Anglais): alto oboe pitch range with characteristic bulbous pear-shaped bell (*liebesfuss*) resonance and poignant double reed sweetness.

local EnglishHorn = {}

function EnglishHorn.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.15)
  Param.add("ReedStiffness", 0.2, 1.8, 0.62)
  Param.add("PearBellWarmth", 0.0, 8.0, 3.0)
  Param.add("DoubleReedSweetness", -4.0, 8.0, 1.8)
  Param.add("VibratoDepth", 0.0, 1.0, 0.26)
  Param.add("Attack", 0.01, 0.3, 0.042)
  Param.add("Sustain", 0.3, 1.0, 0.86)
  Param.add("Release", 0.02, 0.8, 0.24)
end

function EnglishHorn.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.7 * math.sin(phase * 2.0) + 0.45 * math.sin(phase * 3.0)
  return math.tanh(sig * 1.1) * 0.92
end

function EnglishHorn.gui()
  return {
    panel = {
      title = "ENGLISH HORN",
      subtitle = "Cor Anglais Pear Bell & Double Reed",
      accent = "#D35400",
      background = "slate_black",
      rackSides = "walnut",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "PEAR BELL & SWEETNESS",
          accent = "#D35400",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "PearBellWarmth", label = "PEAR BELL", unit = "dB", size = 52 },
                { type = "knob", param = "DoubleReedSweetness", label = "SWEETNESS", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return EnglishHorn
''',
    ),

    // -------------------------------------------------------------
    // GM 70: Bassoon
    // -------------------------------------------------------------
    LuaPreset(
      id: 'bassoon_woodwind',
      name: 'Bassoon',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of an orchestral bassoon: doubled-back conical maple tube, large flexible double cane reed, deep woody resonance, and characteristic staccato pop.',
      code: '''
-- @id: bassoon_woodwind
-- @name: Bassoon
-- @category: instrument
-- @description: Physical model of an orchestral bassoon: doubled-back conical maple tube, large flexible double cane reed, deep woody resonance, and characteristic staccato pop.

local Bassoon = {}

function Bassoon.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.20)
  Param.add("ReedStiffness", 0.2, 1.8, 0.54)
  Param.add("MapleBore", 0.0, 8.0, 3.2)
  Param.add("BassoonFormant", -4.0, 8.0, 2.2)
  Param.add("VibratoDepth", 0.0, 0.8, 0.22)
  Param.add("Attack", 0.01, 0.3, 0.048)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.05, 1.0, 0.26)
end

function Bassoon.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local sig = math.sin(phase) + 0.6 * math.sin(phase * 2.0) + 0.4 * math.sin(phase * 3.0) + 0.2 * math.sin(phase * 4.0)
  return math.tanh(sig * 1.15) * 0.94
end

function Bassoon.gui()
  return {
    panel = {
      title = "ORCHESTRAL BASSOON",
      subtitle = "Conical Maple Double-Bore & Low Reed",
      accent = "#A04000",
      background = "slate_black",
      rackSides = "walnut",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "MAPLE BORE & FORMANT",
          accent = "#A04000",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "MapleBore", label = "MAPLE BORE", unit = "dB", size = 52 },
                { type = "knob", param = "BassoonFormant", label = "FORMANT", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return Bassoon
''',
    ),

    // -------------------------------------------------------------
    // GM 71: Clarinet
    // -------------------------------------------------------------
    LuaPreset(
      id: 'clarinet_woodwind',
      name: 'Clarinet',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of a B-flat soprano clarinet: cylindrical closed-open acoustic bore generating strictly odd harmonics (1f0, 3f0, 5f0...), single cane reed closure, rich chalumeau lower register, and singing clarion register.',
      code: '''
-- @id: clarinet_woodwind
-- @name: Clarinet
-- @category: instrument
-- @description: Physical model of a B-flat soprano clarinet: cylindrical closed-open acoustic bore generating strictly odd harmonics (1f0, 3f0, 5f0...), single cane reed closure, rich chalumeau lower register, and singing clarion register.

local Clarinet = {}

function Clarinet.init()
  Param.add("BreathPressure", 0.5, 2.5, 1.15)
  Param.add("ReedStiffness", 0.2, 1.8, 0.58)
  Param.add("BlackwoodCore", -4.0, 8.0, 2.2)
  Param.add("ChalumeauWarmth", 0.0, 8.0, 1.8)
  Param.add("VibratoDepth", 0.0, 0.8, 0.20)
  Param.add("Attack", 0.01, 0.2, 0.036)
  Param.add("Sustain", 0.3, 1.0, 0.88)
  Param.add("Release", 0.02, 0.8, 0.20)
end

function Clarinet.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  -- Pure cylindrical closed tube: only odd harmonics!
  local sig = math.sin(phase) + 0.65 * math.sin(phase * 3.0) + 0.35 * math.sin(phase * 5.0) + 0.15 * math.sin(phase * 7.0)
  return math.tanh(sig * 1.1) * 0.90
end

function Clarinet.gui()
  return {
    panel = {
      title = "CONCERT CLARINET",
      subtitle = "Cylindrical Closed Bore & Odd-Harmonic Series",
      accent = "#2C3E50",
      background = "slate_black",
      rackSides = "ebony",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "CYLINDRICAL BORE & REED",
          accent = "#34495E",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "BreathPressure", label = "PRESSURE", size = 52 },
                { type = "knob", param = "BlackwoodCore", label = "BLACKWOOD", unit = "dB", size = 52 },
                { type = "knob", param = "ChalumeauWarmth", label = "CHALUMEAU", unit = "dB", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return Clarinet
''',
    ),

    // -------------------------------------------------------------
    // GM 104: Sitar
    // -------------------------------------------------------------
    LuaPreset(
      id: 'sitar_jawari',
      name: 'Sitar',
      category: LuaPresetCategory.instrument,
      description: 'Physical model of a classical Indian sitar: dynamic parabolic jawari bridge buzzing contact non-linearity, gourd resonator acoustic body cavity, and sympathetic drone string bank (*taraf*).',
      code: '''
-- @id: sitar_jawari
-- @name: Sitar
-- @category: instrument
-- @description: Physical model of a classical Indian sitar: dynamic parabolic jawari bridge buzzing contact non-linearity, gourd resonator acoustic body cavity, and sympathetic drone string bank (*taraf*).

local Sitar = {}

function Sitar.init()
  Param.add("JawariBuzz", 0.0, 1.0, 0.72)
  Param.add("SympatheticTaraf", 0.0, 1.0, 0.50)
  Param.add("MizrabHardness", 0.2, 2.0, 0.78)
  Param.add("TumbaResonance", 0.0, 8.0, 3.5)
  Param.add("JiwariShimmer", -4.0, 8.0, 2.2)
  Param.add("Sustain", 0.90, 0.999, 0.993)
end

function Sitar.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  local decay = math.exp(-time * 1.8)
  local sig = (math.sin(phase) + 0.6 * math.sin(phase * 2.0) + 0.5 * math.sin(phase * 3.0) + 0.4 * math.sin(phase * 5.0)) * decay
  return math.tanh(sig * 1.2) * 0.92
end

function Sitar.gui()
  return {
    panel = {
      title = "INDIAN SITAR",
      subtitle = "Dynamic Jawari Bridge & Sympathetic Taraf Bank",
      accent = "#D35400",
      background = "gourd_amber",
      rackSides = "teak",
      cornerRadius = 2,
      layout = {
        {
          type = "group",
          label = "JAWARI & SYMPATHETIC STRINGS",
          accent = "#D35400",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "JawariBuzz", label = "JAWARI BUZZ", size = 52 },
                { type = "knob", param = "SympatheticTaraf", label = "TARAF DRONE", size = 52 },
                { type = "knob", param = "MizrabHardness", label = "MIZRAB STRIKE", size = 52 },
              }
            }
          }
        },
        {
          type = "group",
          label = "GOURD RESONATOR & SHIMMER",
          accent = "#E67E22",
          children = {
            {
              type = "row",
              children = {
                { type = "knob", param = "TumbaResonance", label = "TUMBA GOURD", unit = "dB", size = 52 },
                { type = "knob", param = "JiwariShimmer", label = "AIR SHIMMER", unit = "dB", size = 52 },
                { type = "knob", param = "Sustain", label = "SUSTAIN", size = 52 },
              }
            }
          }
        }
      }
    }
  }
end

return Sitar
''',
    ),
  ];
}
