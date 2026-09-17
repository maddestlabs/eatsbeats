-- Eatsbeats Song File: "Yamaha DX7 — 1983 Tokyo Nights"
-- Showcasing the 6-Operator Yamaha DX7 FM Sound Engine (E.PIANO 1, BASS 1, TUB BELLS)

return eatsbeats.song {
  version = "1.0",
  meta = {
    title = "Yamaha DX7 — Tokyo Nights",
    author = "Eatsbeats FM Lab",
    songKey = "E Major",
    bpm = 116.00,
    masterVolume = 0.85,
    isSongMode = false,
    isLooping = true,
    loopStartBar = 0,
    loopEndBar = 4,
    masterLimiter = {
      enabled = true,
      ceilingDbfs = -0.30,
      driveDb = 1.00,
      targetLufs = -14.0,
    },
  },

  patterns = {
    {
      id = "pattern_dx7_0",
      name = "Tokyo Nights (Main Loop)",
      lengthSteps = 64,
      tracks = {
        -- TRACK 1: DX7 FULLTINES E-PIANO
        {
          id = "tr_dx7_epiano",
          name = "DX7 E-Piano 1",
          color = 0xff00e5ff,
          type = "luaScript",
          presetId = "dx7_epiano",
          volume = 0.88,
          pan = -0.10,
          isMuted = false,
          isSoloed = false,
          luaScriptCode = [[
-- @id: dx7_epiano
-- @name: Yamaha DX7 E-Piano
-- @category: instrument
-- @description: Authentic 1983 Yamaha DX7 6-Operator FM Electric Piano (Algorithm 5 FullTines).
local DX7EPiano = {}
function DX7EPiano.init()
  Param.add("TineBell", 0.0, 1.0, 0.72)
  Param.add("BodyWarmth", 0.0, 1.0, 0.65)
  Param.add("DynamicTouch", 0.0, 1.0, 0.80)
  Param.add("Feedback", 0.0, 7.0, 6.0)
  Param.add("Patch", 0.0, 5.0, 0.0)
  Param.add("Algorithm", 1.0, 32.0, 5.0)
  Param.add("ChorusSpeed", 0.1, 5.0, 0.85)
  Param.add("ChorusDepth", 0.0, 1.0, 0.55)
  Param.add("TrebleSparkle", -6.0, 12.0, 2.5)
  Param.add("Drive", 0.5, 3.0, 1.0)
end
function DX7EPiano.process(time, freq, note, params)
  local t = time
  local phase = 2.0 * math.pi * freq * t
  local c = math.sin(phase)
  local m = math.sin(phase * 14.0) * math.exp(-t * 8.0) * (params["TineBell"] or 0.7)
  local raw = math.sin(phase + m) * math.exp(-t * 1.5)
  return raw * 0.8
end
return DX7EPiano
          ]],
          luaParams = {
            ["TineBell"] = 0.75,
            ["BodyWarmth"] = 0.68,
            ["DynamicTouch"] = 0.85,
            ["Feedback"] = 6.0,
            ["Patch"] = 0.0, -- E.PIANO 1
            ["Algorithm"] = 5.0,
            ["ChorusSpeed"] = 0.85,
            ["ChorusDepth"] = 0.60,
            ["TrebleSparkle"] = 3.0,
            ["Drive"] = 1.0,
          },
          notes = {
            -- Bar 1: Emaj9 (E3, G#3, B3, D#4, F#4)
            { id = "dx_ep_0_1", pitch = 52, startStep = 0.0, durationSteps = 14.0, velocity = 0.82 },
            { id = "dx_ep_0_2", pitch = 56, startStep = 0.0, durationSteps = 14.0, velocity = 0.78 },
            { id = "dx_ep_0_3", pitch = 59, startStep = 0.0, durationSteps = 14.0, velocity = 0.85 },
            { id = "dx_ep_0_4", pitch = 63, startStep = 0.0, durationSteps = 14.0, velocity = 0.88 },
            { id = "dx_ep_0_5", pitch = 66, startStep = 0.0, durationSteps = 14.0, velocity = 0.90 },

            -- Bar 2: G#m7 (G#3, B3, D#4, F#4)
            { id = "dx_ep_1_1", pitch = 56, startStep = 16.0, durationSteps = 14.0, velocity = 0.80 },
            { id = "dx_ep_1_2", pitch = 59, startStep = 16.0, durationSteps = 14.0, velocity = 0.75 },
            { id = "dx_ep_1_3", pitch = 63, startStep = 16.0, durationSteps = 14.0, velocity = 0.82 },
            { id = "dx_ep_1_4", pitch = 66, startStep = 16.0, durationSteps = 14.0, velocity = 0.85 },

            -- Bar 3: C#m9 (C#3, G#3, B3, D#4, E4)
            { id = "dx_ep_2_1", pitch = 49, startStep = 32.0, durationSteps = 14.0, velocity = 0.85 },
            { id = "dx_ep_2_2", pitch = 56, startStep = 32.0, durationSteps = 14.0, velocity = 0.78 },
            { id = "dx_ep_2_3", pitch = 59, startStep = 32.0, durationSteps = 14.0, velocity = 0.82 },
            { id = "dx_ep_2_4", pitch = 63, startStep = 32.0, durationSteps = 14.0, velocity = 0.86 },
            { id = "dx_ep_2_5", pitch = 64, startStep = 32.0, durationSteps = 14.0, velocity = 0.88 },

            -- Bar 4: F#m7 to B13 (F#3, A3, C#4, E4 -> B2, A3, D#4, G#4)
            { id = "dx_ep_3_1", pitch = 54, startStep = 48.0, durationSteps = 7.0, velocity = 0.80 },
            { id = "dx_ep_3_2", pitch = 57, startStep = 48.0, durationSteps = 7.0, velocity = 0.75 },
            { id = "dx_ep_3_3", pitch = 61, startStep = 48.0, durationSteps = 7.0, velocity = 0.82 },
            { id = "dx_ep_3_4", pitch = 64, startStep = 48.0, durationSteps = 7.0, velocity = 0.85 },

            { id = "dx_ep_3_5", pitch = 47, startStep = 56.0, durationSteps = 7.0, velocity = 0.85 },
            { id = "dx_ep_3_6", pitch = 57, startStep = 56.0, durationSteps = 7.0, velocity = 0.78 },
            { id = "dx_ep_3_7", pitch = 63, startStep = 56.0, durationSteps = 7.0, velocity = 0.84 },
            { id = "dx_ep_3_8", pitch = 68, startStep = 56.0, durationSteps = 7.0, velocity = 0.90 },
          },
        },

        -- TRACK 2: DX7 BASS 1 (Iconic FM Slap Bass)
        {
          id = "tr_dx7_bass",
          name = "DX7 Bass 1",
          color = 0xff26a69a,
          type = "luaScript",
          presetId = "dx7_epiano",
          volume = 0.92,
          pan = 0.00,
          isMuted = false,
          isSoloed = false,
          luaScriptCode = [[
-- @name: DX7 Bass 1
-- @category: instrument
local DX7Bass = {}
function DX7Bass.init()
  Param.add("TineBell", 0.0, 1.0, 0.40)
  Param.add("BodyWarmth", 0.0, 1.0, 0.85)
  Param.add("Feedback", 0.0, 7.0, 5.0)
  Param.add("Patch", 0.0, 5.0, 1.0) -- BASS 1
  Param.add("Drive", 0.5, 3.0, 1.2)
end
function DX7Bass.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  return math.sin(phase + math.sin(phase * 2.0) * 1.5) * math.exp(-time * 4.0)
end
return DX7Bass
          ]],
          luaParams = {
            ["TineBell"] = 0.40,
            ["BodyWarmth"] = 0.90,
            ["Feedback"] = 5.0,
            ["Patch"] = 1.0, -- BASS 1 Factory ROM
            ["Drive"] = 1.25,
          },
          notes = {
            -- Bar 1: E root groove (E1/E2)
            { id = "dx_b_0_1", pitch = 28, startStep = 0.0, durationSteps = 2.5, velocity = 0.95 },
            { id = "dx_b_0_2", pitch = 28, startStep = 4.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "dx_b_0_3", pitch = 40, startStep = 6.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "dx_b_0_4", pitch = 28, startStep = 10.0, durationSteps = 2.0, velocity = 0.92 },
            { id = "dx_b_0_5", pitch = 38, startStep = 14.0, durationSteps = 1.8, velocity = 0.85 },

            -- Bar 2: G# groove
            { id = "dx_b_1_1", pitch = 32, startStep = 16.0, durationSteps = 2.5, velocity = 0.95 },
            { id = "dx_b_1_2", pitch = 32, startStep = 20.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "dx_b_1_3", pitch = 44, startStep = 22.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "dx_b_1_4", pitch = 32, startStep = 26.0, durationSteps = 2.0, velocity = 0.92 },
            { id = "dx_b_1_5", pitch = 35, startStep = 30.0, durationSteps = 1.8, velocity = 0.85 },

            -- Bar 3: C# groove
            { id = "dx_b_2_1", pitch = 25, startStep = 32.0, durationSteps = 2.5, velocity = 0.95 },
            { id = "dx_b_2_2", pitch = 25, startStep = 36.0, durationSteps = 1.5, velocity = 0.85 },
            { id = "dx_b_2_3", pitch = 37, startStep = 38.0, durationSteps = 1.5, velocity = 0.90 },
            { id = "dx_b_2_4", pitch = 25, startStep = 42.0, durationSteps = 2.0, velocity = 0.92 },
            { id = "dx_b_2_5", pitch = 35, startStep = 46.0, durationSteps = 1.8, velocity = 0.85 },

            -- Bar 4: F# to B turnaround
            { id = "dx_b_3_1", pitch = 30, startStep = 48.0, durationSteps = 2.5, velocity = 0.95 },
            { id = "dx_b_3_2", pitch = 42, startStep = 52.0, durationSteps = 2.0, velocity = 0.88 },
            { id = "dx_b_3_3", pitch = 23, startStep = 56.0, durationSteps = 3.5, velocity = 0.98 },
            { id = "dx_b_3_4", pitch = 35, startStep = 60.0, durationSteps = 2.5, velocity = 0.90 },
          },
        },

        -- TRACK 3: DX7 TUBULAR BELLS / CHIME ACCENTS
        {
          id = "tr_dx7_bells",
          name = "DX7 Tub Bells",
          color = 0xffffd700,
          type = "luaScript",
          presetId = "dx7_epiano",
          volume = 0.76,
          pan = 0.25,
          isMuted = false,
          isSoloed = false,
          luaScriptCode = [[
-- @name: DX7 Tub Bells
-- @category: instrument
local DX7Bells = {}
function DX7Bells.init()
  Param.add("TineBell", 0.0, 1.0, 0.95)
  Param.add("BodyWarmth", 0.0, 1.0, 0.50)
  Param.add("Feedback", 0.0, 7.0, 4.0)
  Param.add("Patch", 0.0, 5.0, 2.0) -- TUB BELLS
end
function DX7Bells.process(time, freq, note, params)
  local phase = 2.0 * math.pi * freq * time
  return math.sin(phase * 3.5) * math.exp(-time * 1.8) * 0.7
end
return DX7Bells
          ]],
          luaParams = {
            ["TineBell"] = 0.95,
            ["BodyWarmth"] = 0.50,
            ["Feedback"] = 4.0,
            ["Patch"] = 2.0, -- TUB BELLS Factory ROM
          },
          notes = {
            -- Pentatonic sparkling accents on bar downbeats & offbeats
            { id = "dx_bell_0", pitch = 75, startStep = 12.0, durationSteps = 8.0, velocity = 0.85 }, -- D#5
            { id = "dx_bell_1", pitch = 78, startStep = 14.0, durationSteps = 8.0, velocity = 0.90 }, -- F#5
            { id = "dx_bell_2", pitch = 83, startStep = 28.0, durationSteps = 10.0, velocity = 0.88 }, -- B5
            { id = "dx_bell_3", pitch = 80, startStep = 44.0, durationSteps = 8.0, velocity = 0.85 }, -- G#5
            { id = "dx_bell_4", pitch = 87, startStep = 60.0, durationSteps = 12.0, velocity = 0.95 }, -- D#6
          },
        },
      },
    },
  },
}
