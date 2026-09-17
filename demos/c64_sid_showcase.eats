-- Eatsbeats Song File: "Commodore 64 — Cyber Assault (MOS 6581)"
-- Showcasing the authentic Commodore 64 SID Sound Interface Device (50Hz Chiptune Arp, 12-bit PWM, 23-bit Galois LFSR Noise, 6581 FET Filter)

return eatsbeats.song {
  version = "1.0",
  meta = {
    title = "C64 — Cyber Assault",
    author = "Eatsbeats SID Chiptune Lab",
    songKey = "A Minor",
    bpm = 136.00,
    masterVolume = 0.85,
    isSongMode = false,
    isLooping = true,
    loopStartBar = 0,
    loopEndBar = 4,
    masterLimiter = {
      enabled = true,
      ceilingDbfs = -0.30,
      driveDb = 1.20,
      targetLufs = -13.5,
    },
  },

  patterns = {
    {
      id = "pattern_sid_0",
      name = "Cyber Assault (Main Loop)",
      lengthSteps = 64,
      tracks = {
        -- TRACK 1: SID 50Hz HARDWARE CHIPTUNE ARPEGGIO
        {
          id = "tr_sid_arp",
          name = "SID 50Hz Arp",
          color = 0xff6c5eb5, -- C64 Royal Indigo
          type = "luaScript",
          presetId = "c64_sid_synth",
          volume = 0.86,
          pan = -0.20,
          isMuted = false,
          isSoloed = false,
          luaScriptCode = [[
-- @id: c64_sid_synth
-- @name: Commodore 64 SID Synth
-- @category: instrument
-- @description: Authentic MOS 6581 / 8580 Commodore 64 Sound Interface Device.
local C64SID = {}
function C64SID.init()
  Param.add("Waveform", 0, 5, 0)
  Param.add("PulseWidth", 100, 4000, 2048)
  Param.add("PwmRate", 0.1, 10.0, 2.2)
  Param.add("PwmDepth", 0.0, 1.0, 0.50)
  Param.add("ArpMode", 0, 5, 1) -- 1: 50Hz PAL C64 V-Blank rate (~20ms/step)
  Param.add("GlideSpeed", 0.0, 0.5, 0.0)
  Param.add("ChipModel", 0, 1, 0) -- 0: MOS 6581 (Warm FET)
  Param.add("FilterMode", 0, 4, 0) -- 0: Lowpass
  Param.add("Cutoff", 100, 2047, 1400)
  Param.add("Resonance", 0, 15, 10)
  Param.add("Overdrive", 1.0, 3.0, 1.3)
  Param.add("Attack", 0, 15, 0)
  Param.add("Decay", 0, 15, 6)
  Param.add("Sustain", 0, 15, 12)
  Param.add("Release", 0, 15, 4)
end
function C64SID.process(time, freq, note, params)
  local phase = (time * freq) % 1.0
  return (phase < 0.5 and 1.0 or -1.0) * math.exp(-time * 2.5)
end
return C64SID
          ]],
          luaParams = {
            ["Waveform"] = 0.0, -- Pulse wave with PWM
            ["PulseWidth"] = 1800.0,
            ["PwmRate"] = 2.5,
            ["PwmDepth"] = 0.55,
            ["ArpMode"] = 1.0, -- 50Hz PAL Hardware Arpeggiator
            ["ChipModel"] = 0.0, -- MOS 6581
            ["FilterMode"] = 0.0, -- Lowpass
            ["Cutoff"] = 1450.0,
            ["Resonance"] = 10.0,
            ["Overdrive"] = 1.35,
            ["Attack"] = 0.0,
            ["Decay"] = 5.0,
            ["Sustain"] = 12.0,
            ["Release"] = 4.0,
          },
          notes = {
            -- Bar 1: Am (A3)
            { id = "sid_arp_0", pitch = 57, startStep = 0.0, durationSteps = 15.0, velocity = 0.88 },
            -- Bar 2: F (F3)
            { id = "sid_arp_1", pitch = 53, startStep = 16.0, durationSteps = 15.0, velocity = 0.88 },
            -- Bar 3: C (C4)
            { id = "sid_arp_2", pitch = 60, startStep = 32.0, durationSteps = 15.0, velocity = 0.88 },
            -- Bar 4: G to Em (G3 -> E3)
            { id = "sid_arp_3", pitch = 55, startStep = 48.0, durationSteps = 7.5, velocity = 0.88 },
            { id = "sid_arp_4", pitch = 52, startStep = 56.0, durationSteps = 7.5, velocity = 0.92 },
          },
        },

        -- TRACK 2: SID 12-BIT PWM LEAD (Rob Hubbard Style Melodic Lead)
        {
          id = "tr_sid_lead",
          name = "SID PWM Lead",
          color = 0xff00e5ff,
          type = "luaScript",
          presetId = "c64_sid_synth",
          volume = 0.90,
          pan = 0.15,
          isMuted = false,
          isSoloed = false,
          luaScriptCode = [[
-- @name: SID PWM Lead
-- @category: instrument
local SIDLead = {}
function SIDLead.init()
  Param.add("Waveform", 0, 5, 0)
  Param.add("PulseWidth", 100, 4000, 2048)
  Param.add("PwmRate", 0.1, 10.0, 3.2)
  Param.add("PwmDepth", 0.0, 1.0, 0.60)
  Param.add("ArpMode", 0, 5, 0) -- Off (melodic monophonic lead)
  Param.add("GlideSpeed", 0.0, 0.5, 0.04) -- 40ms portamento glide
  Param.add("ChipModel", 0, 1, 0)
  Param.add("FilterMode", 0, 4, 0)
  Param.add("Cutoff", 100, 2047, 1650)
  Param.add("Resonance", 0, 15, 6)
  Param.add("Overdrive", 1.0, 3.0, 1.4)
  Param.add("Attack", 0, 15, 1)
  Param.add("Decay", 0, 15, 7)
  Param.add("Sustain", 0, 15, 13)
  Param.add("Release", 0, 15, 5)
end
function SIDLead.process(time, freq, note, params)
  local phase = (time * freq) % 1.0
  return (phase < 0.5 and 1.0 or -1.0) * math.exp(-time * 1.8)
end
return SIDLead
          ]],
          luaParams = {
            ["Waveform"] = 0.0,
            ["PulseWidth"] = 2048.0,
            ["PwmRate"] = 3.2,
            ["PwmDepth"] = 0.60,
            ["ArpMode"] = 0.0,
            ["GlideSpeed"] = 0.04,
            ["ChipModel"] = 0.0,
            ["FilterMode"] = 0.0,
            ["Cutoff"] = 1650.0,
            ["Resonance"] = 6.0,
            ["Overdrive"] = 1.40,
            ["Attack"] = 1.0,
            ["Decay"] = 7.0,
            ["Sustain"] = 13.0,
            ["Release"] = 5.0,
          },
          notes = {
            -- Bar 1: A4 -> C5 -> B4 -> A4
            { id = "sid_ld_0", pitch = 69, startStep = 0.0, durationSteps = 3.5, velocity = 0.95 },
            { id = "sid_ld_1", pitch = 72, startStep = 4.0, durationSteps = 3.5, velocity = 0.92 },
            { id = "sid_ld_2", pitch = 71, startStep = 8.0, durationSteps = 3.5, velocity = 0.90 },
            { id = "sid_ld_3", pitch = 69, startStep = 12.0, durationSteps = 3.5, velocity = 0.95 },

            -- Bar 2: E5 -> D5 -> C5
            { id = "sid_ld_4", pitch = 76, startStep = 16.0, durationSteps = 5.5, velocity = 0.98 },
            { id = "sid_ld_5", pitch = 74, startStep = 22.0, durationSteps = 4.0, velocity = 0.90 },
            { id = "sid_ld_6", pitch = 72, startStep = 26.0, durationSteps = 5.5, velocity = 0.92 },

            -- Bar 3: G5 -> E5 -> C5 -> D5
            { id = "sid_ld_7", pitch = 79, startStep = 32.0, durationSteps = 3.5, velocity = 0.98 },
            { id = "sid_ld_8", pitch = 76, startStep = 36.0, durationSteps = 3.5, velocity = 0.92 },
            { id = "sid_ld_9", pitch = 72, startStep = 40.0, durationSteps = 3.5, velocity = 0.90 },
            { id = "sid_ld_10", pitch = 74, startStep = 44.0, durationSteps = 3.5, velocity = 0.92 },

            -- Bar 4: E5 -> D5 -> B4 -> G#4 -> A4
            { id = "sid_ld_11", pitch = 76, startStep = 48.0, durationSteps = 3.0, velocity = 0.95 },
            { id = "sid_ld_12", pitch = 74, startStep = 52.0, durationSteps = 3.0, velocity = 0.90 },
            { id = "sid_ld_13", pitch = 71, startStep = 56.0, durationSteps = 2.5, velocity = 0.88 },
            { id = "sid_ld_14", pitch = 68, startStep = 59.0, durationSteps = 2.0, velocity = 0.90 },
            { id = "sid_ld_15", pitch = 69, startStep = 61.5, durationSteps = 2.5, velocity = 0.95 },
          },
        },

        -- TRACK 3: SID SAWTOOTH CHIPTUNE BASS
        {
          id = "tr_sid_bass",
          name = "SID Saw Bass",
          color = 0xffa0864b, -- C64 Vintage Tan
          type = "luaScript",
          presetId = "c64_sid_synth",
          volume = 0.94,
          pan = 0.00,
          isMuted = false,
          isSoloed = false,
          luaScriptCode = [[
-- @name: SID Saw Bass
-- @category: instrument
local SIDBass = {}
function SIDBass.init()
  Param.add("Waveform", 0, 5, 1) -- 1: Sawtooth
  Param.add("ArpMode", 0, 5, 0)
  Param.add("ChipModel", 0, 1, 0) -- MOS 6581
  Param.add("FilterMode", 0, 4, 0)
  Param.add("Cutoff", 100, 2047, 950)
  Param.add("Resonance", 0, 15, 8)
  Param.add("Overdrive", 1.0, 3.0, 1.5)
  Param.add("Attack", 0, 15, 0)
  Param.add("Decay", 0, 15, 4)
  Param.add("Sustain", 0, 15, 6)
  Param.add("Release", 0, 15, 3)
end
function SIDBass.process(time, freq, note, params)
  local phase = (time * freq) % 1.0
  return (2.0 * phase - 1.0) * math.exp(-time * 5.0)
end
return SIDBass
          ]],
          luaParams = {
            ["Waveform"] = 1.0, -- Sawtooth
            ["ArpMode"] = 0.0,
            ["ChipModel"] = 0.0,
            ["FilterMode"] = 0.0,
            ["Cutoff"] = 950.0,
            ["Resonance"] = 8.0,
            ["Overdrive"] = 1.50,
            ["Attack"] = 0.0,
            ["Decay"] = 4.0,
            ["Sustain"] = 6.0,
            ["Release"] = 3.0,
          },
          notes = {
            -- Driving 16th note chiptune bassline
            -- Bar 1: A1 (pitch 33)
            { id = "sb_0_0", pitch = 33, startStep = 0.0, durationSteps = 1.5, velocity = 0.95 },
            { id = "sb_0_2", pitch = 33, startStep = 2.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_0_4", pitch = 45, startStep = 4.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "sb_0_6", pitch = 33, startStep = 6.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_0_8", pitch = 33, startStep = 8.0, durationSteps = 1.5, velocity = 0.95 },
            { id = "sb_0_10", pitch = 33, startStep = 10.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_0_12", pitch = 45, startStep = 12.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "sb_0_14", pitch = 33, startStep = 14.0, durationSteps = 1.5, velocity = 0.88 },

            -- Bar 2: F1 (pitch 29)
            { id = "sb_1_0", pitch = 29, startStep = 16.0, durationSteps = 1.5, velocity = 0.95 },
            { id = "sb_1_2", pitch = 29, startStep = 18.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_1_4", pitch = 41, startStep = 20.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "sb_1_6", pitch = 29, startStep = 22.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_1_8", pitch = 29, startStep = 24.0, durationSteps = 1.5, velocity = 0.95 },
            { id = "sb_1_10", pitch = 29, startStep = 26.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_1_12", pitch = 41, startStep = 28.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "sb_1_14", pitch = 31, startStep = 30.0, durationSteps = 1.5, velocity = 0.88 },

            -- Bar 3: C2 (pitch 36)
            { id = "sb_2_0", pitch = 36, startStep = 32.0, durationSteps = 1.5, velocity = 0.95 },
            { id = "sb_2_2", pitch = 36, startStep = 34.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_2_4", pitch = 48, startStep = 36.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "sb_2_6", pitch = 36, startStep = 38.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_2_8", pitch = 36, startStep = 40.0, durationSteps = 1.5, velocity = 0.95 },
            { id = "sb_2_10", pitch = 36, startStep = 42.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_2_12", pitch = 48, startStep = 44.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "sb_2_14", pitch = 36, startStep = 46.0, durationSteps = 1.5, velocity = 0.88 },

            -- Bar 4: G1 -> E1 (pitch 31 -> 28)
            { id = "sb_3_0", pitch = 31, startStep = 48.0, durationSteps = 1.5, velocity = 0.95 },
            { id = "sb_3_2", pitch = 31, startStep = 50.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_3_4", pitch = 43, startStep = 52.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "sb_3_6", pitch = 31, startStep = 54.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_3_8", pitch = 28, startStep = 56.0, durationSteps = 1.5, velocity = 0.95 },
            { id = "sb_3_10", pitch = 28, startStep = 58.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "sb_3_12", pitch = 40, startStep = 60.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "sb_3_14", pitch = 28, startStep = 62.0, durationSteps = 1.5, velocity = 0.92 },
          },
        },

        -- TRACK 4: SID 23-BIT NOISE DRUMS (Galois LFSR Percussion)
        {
          id = "tr_sid_drums",
          name = "SID Noise Drums",
          color = 0xff3e9b48, -- C64 Vintage Green
          type = "luaScript",
          presetId = "c64_sid_synth",
          volume = 0.80,
          pan = 0.05,
          isMuted = false,
          isSoloed = false,
          luaScriptCode = [[
-- @name: SID Noise Drums
-- @category: instrument
local SIDDrums = {}
function SIDDrums.init()
  Param.add("Waveform", 0, 5, 3) -- 3: 23-bit Galois LFSR Noise
  Param.add("ArpMode", 0, 5, 0)
  Param.add("ChipModel", 0, 1, 0)
  Param.add("FilterMode", 0, 4, 4) -- Bypass filter for raw chiptune snap
  Param.add("Attack", 0, 15, 0)
  Param.add("Decay", 0, 15, 2)
  Param.add("Sustain", 0, 15, 0)
  Param.add("Release", 0, 15, 2)
end
function SIDDrums.process(time, freq, note, params)
  return (math.random() * 2.0 - 1.0) * math.exp(-time * 18.0)
end
return SIDDrums
          ]],
          luaParams = {
            ["Waveform"] = 3.0, -- Noise
            ["ArpMode"] = 0.0,
            ["ChipModel"] = 0.0,
            ["FilterMode"] = 4.0, -- Bypass
            ["Attack"] = 0.0,
            ["Decay"] = 2.0,
            ["Sustain"] = 0.0,
            ["Release"] = 2.0,
          },
          notes = {
            -- Hi-Hats and Snares on 16th grid across all 4 bars
            -- Bar 1
            { id = "sd_0_4", pitch = 60, startStep = 4.0, durationSteps = 1.0, velocity = 0.95 }, -- Snare
            { id = "sd_0_12", pitch = 60, startStep = 12.0, durationSteps = 1.0, velocity = 0.95 }, -- Snare
            { id = "sd_0_2", pitch = 72, startStep = 2.0, durationSteps = 0.5, velocity = 0.70 }, -- Hat
            { id = "sd_0_6", pitch = 72, startStep = 6.0, durationSteps = 0.5, velocity = 0.70 }, -- Hat
            { id = "sd_0_10", pitch = 72, startStep = 10.0, durationSteps = 0.5, velocity = 0.70 }, -- Hat
            { id = "sd_0_14", pitch = 72, startStep = 14.0, durationSteps = 0.5, velocity = 0.70 }, -- Hat

            -- Bar 2
            { id = "sd_1_4", pitch = 60, startStep = 20.0, durationSteps = 1.0, velocity = 0.95 },
            { id = "sd_1_12", pitch = 60, startStep = 28.0, durationSteps = 1.0, velocity = 0.95 },
            { id = "sd_1_2", pitch = 72, startStep = 18.0, durationSteps = 0.5, velocity = 0.70 },
            { id = "sd_1_6", pitch = 72, startStep = 22.0, durationSteps = 0.5, velocity = 0.70 },
            { id = "sd_1_10", pitch = 72, startStep = 26.0, durationSteps = 0.5, velocity = 0.70 },
            { id = "sd_1_14", pitch = 72, startStep = 30.0, durationSteps = 0.5, velocity = 0.70 },

            -- Bar 3
            { id = "sd_2_4", pitch = 60, startStep = 36.0, durationSteps = 1.0, velocity = 0.95 },
            { id = "sd_2_12", pitch = 60, startStep = 44.0, durationSteps = 1.0, velocity = 0.95 },
            { id = "sd_2_2", pitch = 72, startStep = 34.0, durationSteps = 0.5, velocity = 0.70 },
            { id = "sd_2_6", pitch = 72, startStep = 38.0, durationSteps = 0.5, velocity = 0.70 },
            { id = "sd_2_10", pitch = 72, startStep = 42.0, durationSteps = 0.5, velocity = 0.70 },
            { id = "sd_2_14", pitch = 72, startStep = 46.0, durationSteps = 0.5, velocity = 0.70 },

            -- Bar 4: Fill
            { id = "sd_3_4", pitch = 60, startStep = 52.0, durationSteps = 1.0, velocity = 0.95 },
            { id = "sd_3_10", pitch = 60, startStep = 58.0, durationSteps = 0.8, velocity = 0.85 },
            { id = "sd_3_12", pitch = 60, startStep = 60.0, durationSteps = 0.8, velocity = 0.90 },
            { id = "sd_3_14", pitch = 60, startStep = 62.0, durationSteps = 0.8, velocity = 0.98 },
          },
        },
      },
    },
  },
}
