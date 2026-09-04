# Eatsbeats General MIDI 1 Specification & Native Coverage

This document tracks Eatsbeats' progress toward covering the entire General MIDI 1 (GM 1) specification with high-quality native DSP and physical models.

When users drag and drop Standard MIDI Files (.mid / .midi) into Eatsbeats, the import pipeline automatically routes each track using a **Fallback-First Progressive Enhancement** strategy:
- **Natively Modeled Instruments**: Instantly instantiate the dedicated physical model or synthesizer (e.g., Concert Grand Piano, Solo Cello, DX7 FM E-Piano, Clavinet D6, Vibraphone, 808/909 Drums).
- **Unmodeled Instruments**: Route to the built-in SoundFont Sampler (`soundfont_sampler`) loaded with the exact GM Program Change number.

---

## Current Progress Overview

- **Total General MIDI 1 Programs**: 128 Melodic Programs + GM Channel 10 Percussion
- **Natively Covered Programs**: **52 / 128 (40.6%)**
- **SoundFont Placeholder Fallbacks**: **76 / 128 (59.4%)**

---

## 1. Complete Specification & Coverage Table

### Piano Family (Programs 0 – 7) — 100% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **0** | Acoustic Grand Piano | ✅ Native | `concert_grand_piano` (Physical model) |
| **1** | Bright Acoustic Piano | ✅ Native | `felt_upright_piano` (Upright felt model) |
| **2** | Electric Grand Piano | ✅ Native | `felt_upright_piano` |
| **3** | Honky-tonk Piano | ✅ Native | `honky_tonk_piano` (Tack piano model) |
| **4** | Electric Piano 1 (Rhodes) | ✅ Native | `rhodes_epiano` (Stage 73 model) |
| **5** | Electric Piano 2 (DX7 FM) | ✅ Native | `dx7_epiano` (Yamaha DX7 6-Op FM) |
| **6** | Harpsichord | ✅ Native | `harpsichord_cembalo` (Cembalo pluck model) |
| **7** | Clavinet | ✅ Native | `clavinet_d6` (Hohner D6 physical model) |

### Chromatic Percussion Family (Programs 8 – 15) — 75% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **8** | Celesta | ✅ Native | `toy_piano` |
| **9** | Glockenspiel | ✅ Native | `glockenspiel` (Bell shimmer mallet) |
| **10** | Music Box | ✅ Native | `music_box` (Pin/tine model) |
| **11** | Vibraphone | ✅ Native | `vibraphone` (Tremolo & motor model) |
| **12** | Marimba | ✅ Native | `xylophone` (Wood mallet resonator) |
| **13** | Xylophone | ✅ Native | `xylophone` (Triple octave pop model) |
| **14** | Tubular Bells | ⏳ Fallback | *(SoundFont PC #14)* |
| **15** | Dulcimer | ⏳ Fallback | *(SoundFont PC #15)* |

### Organ Family (Programs 16 – 23) — 0% Covered *(High Priority Backlog)*
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **16** | Drawbar Organ | ⏳ Fallback | *(SoundFont PC #16 - Hammond B3)* |
| **17** | Percussive Organ | ⏳ Fallback | *(SoundFont PC #17)* |
| **18** | Rock Organ | ⏳ Fallback | *(SoundFont PC #18)* |
| **19** | Church Organ | ⏳ Fallback | *(SoundFont PC #19 - Pipe organ)* |
| **20** | Reed Organ | ⏳ Fallback | *(SoundFont PC #20)* |
| **21** | Accordion | ⏳ Fallback | *(SoundFont PC #21)* |
| **22** | Harmonica | ⏳ Fallback | *(SoundFont PC #22 - Blues harp)* |
| **23** | Tango Accordion | ⏳ Fallback | *(SoundFont PC #23 - Bandoneon)* |

### Guitar Family (Programs 24 – 31) — 50% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **24** | Acoustic Guitar (nylon) | ✅ Native | `spanish_guitar` (Classical nylon model) |
| **25** | Acoustic Guitar (steel) | ✅ Native | `acoustic_steel_guitar` (Bronze sparkle model) |
| **26** | Electric Guitar (jazz) | ✅ Native | `pedal_steel_guitar` |
| **27** | Electric Guitar (clean) | ✅ Native | `reggae_guitar` (Clean electric skank) |
| **28** | Electric Guitar (muted) | ⏳ Fallback | *(SoundFont PC #28)* |
| **29** | Overdriven Guitar | ⏳ Fallback | *(SoundFont PC #29)* |
| **30** | Distortion Guitar | ⏳ Fallback | *(SoundFont PC #30)* |
| **31** | Guitar Harmonics | ⏳ Fallback | *(SoundFont PC #31)* |

### Bass Family (Programs 32 – 39) — 50% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **32** | Acoustic Bass | ✅ Native | `acoustic_bass` (Upright acoustic model) |
| **33** | Electric Bass (finger) | ⏳ Fallback | *(SoundFont PC #33)* |
| **34** | Electric Bass (pick) | ⏳ Fallback | *(SoundFont PC #34)* |
| **35** | Fretless Bass | ✅ Native | `fretless_bass` (Warm mwah growl model) |
| **36** | Slap Bass 1 | ⏳ Fallback | *(SoundFont PC #36)* |
| **37** | Slap Bass 2 | ⏳ Fallback | *(SoundFont PC #37)* |
| **38** | Synth Bass 1 | ✅ Native | `moog_synth_bass` (Ladder filter analog bass) |
| **39** | Synth Bass 2 | ✅ Native | `eats_303` (TB-303 Acid bass model) |

### Solo Strings Family (Programs 40 – 47) — 62.5% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **40** | Violin | ✅ Native | `solo_violin` (Virtuoso solo violin model) |
| **41** | Viola | ✅ Native | `solo_viola` (Warm solo viola model) |
| **42** | Cello | ✅ Native | `solo_cello` (Deep solo cello model) |
| **43** | Contrabass | ✅ Native | `double_bass` (Orchestral double bass) |
| **44** | Tremolo Strings | ⏳ Fallback | *(SoundFont PC #44)* |
| **45** | Pizzicato Strings | ⏳ Fallback | *(SoundFont PC #45)* |
| **46** | Orchestral Harp | ✅ Native | `harp_guitar` |
| **47** | Timpani | ⏳ Fallback | *(SoundFont PC #47)* |

### Ensemble Family (Programs 48 – 55) — 50% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **48** | String Ensemble 1 | ✅ Native | `string_ensemble` (Symphonic ensemble) |
| **49** | String Ensemble 2 | ✅ Native | `string_ensemble` |
| **50** | Synth Strings 1 | ⏳ Fallback | *(SoundFont PC #50)* |
| **51** | Synth Strings 2 | ⏳ Fallback | *(SoundFont PC #51)* |
| **52** | Choir Aahs | ⏳ Fallback | *(SoundFont PC #52)* |
| **53** | Voice Oohs | ✅ Native | `tts_voice_synth` (Formant vocal synthesizer) |
| **54** | Synth Voice | ✅ Native | `tts_voice_synth` |
| **55** | Orchestra Hit | ⏳ Fallback | *(SoundFont PC #55)* |

### Brass Family (Programs 56 – 63) — 0% Covered *(High Priority Backlog)*
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **56** | Trumpet | ⏳ Fallback | *(SoundFont PC #56)* |
| **57** | Trombone | ⏳ Fallback | *(SoundFont PC #57)* |
| **58** | Tuba | ⏳ Fallback | *(SoundFont PC #58)* |
| **59** | Muted Trumpet | ⏳ Fallback | *(SoundFont PC #59)* |
| **60** | French Horn | ⏳ Fallback | *(SoundFont PC #60)* |
| **61** | Brass Section | ⏳ Fallback | *(SoundFont PC #61)* |
| **62** | Synth Brass 1 | ⏳ Fallback | *(SoundFont PC #62)* |
| **63** | Synth Brass 2 | ⏳ Fallback | *(SoundFont PC #63)* |

### Reed Family (Programs 64 – 71) — 0% Covered *(High Priority Backlog)*
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **64** | Soprano Sax | ⏳ Fallback | *(SoundFont PC #64)* |
| **65** | Alto Sax | ⏳ Fallback | *(SoundFont PC #65)* |
| **66** | Tenor Sax | ⏳ Fallback | *(SoundFont PC #66)* |
| **67** | Baritone Sax | ⏳ Fallback | *(SoundFont PC #67)* |
| **68** | Oboe | ⏳ Fallback | *(SoundFont PC #68)* |
| **69** | English Horn | ⏳ Fallback | *(SoundFont PC #69)* |
| **70** | Bassoon | ⏳ Fallback | *(SoundFont PC #70)* |
| **71** | Clarinet | ⏳ Fallback | *(SoundFont PC #71)* |

### Pipe Family (Programs 72 – 79) — 100% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **72** | Piccolo | ✅ Native | `concert_piccolo` (Narrow-bore +12st open pipe) |
| **73** | Flute | ✅ Native | `concert_flute` (Transverse air-jet C flute) |
| **74** | Recorder | ✅ Native | `wooden_recorder` (Baroque pearwood blockflöte) |
| **75** | Pan Flute | ✅ Native | `pan_flute` (Stopped cane odd-harmonic pipe) |
| **76** | Blown Bottle | ✅ Native | `blown_bottle` (Helmholtz glass cavity) |
| **77** | Shakuhachi | ✅ Native | `shakuhachi_bamboo` (Utaguchi bamboo air-jet) |
| **78** | Whistle | ✅ Native | `tin_whistle` (Pennywhistle fipple & nickel tube) |
| **79** | Ocarina | ✅ Native | `sweet_ocarina` (Ceramic vessel Helmholtz flute) |

### Synth Lead Family (Programs 80 – 87) — 50% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **80** | Lead 1 (square) | ✅ Native | `poly_lead` |
| **81** | Lead 2 (sawtooth) | ✅ Native | `poly_lead` |
| **82** | Lead 3 (calliope) | ⏳ Fallback | *(SoundFont PC #82)* |
| **83** | Lead 4 (chiff) | ⏳ Fallback | *(SoundFont PC #83)* |
| **84** | Lead 5 (charang) | ⏳ Fallback | *(SoundFont PC #84)* |
| **85** | Lead 6 (voice) | ✅ Native | `tts_voice_synth` |
| **86** | Lead 7 (fifths) | ⏳ Fallback | *(SoundFont PC #86)* |
| **87** | Lead 8 (bass + lead) | ✅ Native | `c64_sid_synth` (Commodore 64 SID lead) |

### Synth Pad Family (Programs 88 – 95) — 0% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **88** | Pad 1 (new age) | ⏳ Fallback | *(SoundFont PC #88)* |
| **89** | Pad 2 (warm) | ⏳ Fallback | *(SoundFont PC #89)* |
| **90** | Pad 3 (polysynth) | ⏳ Fallback | *(SoundFont PC #90)* |
| **91** | Pad 4 (choir) | ⏳ Fallback | *(SoundFont PC #91)* |
| **92** | Pad 5 (bowed) | ⏳ Fallback | *(SoundFont PC #92)* |
| **93** | Pad 6 (metallic) | ⏳ Fallback | *(SoundFont PC #93)* |
| **94** | Pad 7 (halo) | ⏳ Fallback | *(SoundFont PC #94)* |
| **95** | Pad 8 (sweep) | ⏳ Fallback | *(SoundFont PC #95)* |

### Synth Effects Family (Programs 96 – 103) — 25% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **96** | FX 1 (rain) | ✅ Native | `eats_water` (Hydraulophone physical model) |
| **97** | FX 2 (soundtrack) | ⏳ Fallback | *(SoundFont PC #97)* |
| **98** | FX 3 (crystal) | ⏳ Fallback | *(SoundFont PC #98)* |
| **99** | FX 4 (atmosphere) | ⏳ Fallback | *(SoundFont PC #99)* |
| **100** | FX 5 (brightness) | ⏳ Fallback | *(SoundFont PC #100)* |
| **101** | FX 6 (goblins) | ⏳ Fallback | *(SoundFont PC #101)* |
| **102** | FX 7 (echoes) | ⏳ Fallback | *(SoundFont PC #102)* |
| **103** | FX 8 (sci-fi) | ✅ Native | `eats_volts` (Voltaic plasma singing arc) |

### Ethnic Family (Programs 104 – 111) — 37.5% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **104** | Sitar | ⏳ Fallback | *(SoundFont PC #104)* |
| **105** | Banjo | ✅ Native | `bluegrass_banjo` (Head tension banjo model) |
| **106** | Shamisen | ⏳ Fallback | *(SoundFont PC #106)* |
| **107** | Koto | ⏳ Fallback | *(SoundFont PC #107)* |
| **108** | Kalimba | ✅ Native | `music_box` |
| **109** | Bag pipe | ⏳ Fallback | *(SoundFont PC #109)* |
| **110** | Fiddle | ✅ Native | `solo_violin` |
| **111** | Shanai | ⏳ Fallback | *(SoundFont PC #111)* |

*(Additional native ethnic plucked instruments supported via semantic track name: `hawaiian_ukulele`, `folk_mandolin`, `renaissance_lute`).*

### Percussive Family (Programs 112 – 119) — 25% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **112** | Tinkle Bell | ⏳ Fallback | *(SoundFont PC #112)* |
| **113** | Agogo | ⏳ Fallback | *(SoundFont PC #113)* |
| **114** | Steel Drums | ⏳ Fallback | *(SoundFont PC #114)* |
| **115** | Woodblock | ⏳ Fallback | *(SoundFont PC #115)* |
| **116** | Taiko Drum | ⏳ Fallback | *(SoundFont PC #116)* |
| **117** | Melodic Tom | ✅ Native | `fm_acoustic_tom` |
| **118** | Synth Drum | ✅ Native | `analog_808_kick` |
| **119** | Reverse Cymbal | ⏳ Fallback | *(SoundFont PC #119)* |

### Sound Effects Family (Programs 120 – 127) — 25% Covered
| GM # | Standard Instrument Name | Status | Native Preset ID / Implementation |
| :---: | :--- | :---: | :--- |
| **120** | Guitar Fret Noise | ⏳ Fallback | *(SoundFont PC #120)* |
| **121** | Breath Noise | ⏳ Fallback | *(SoundFont PC #121)* |
| **122** | Seashore | ✅ Native | `eats_water` |
| **123** | Bird Tweet | ⏳ Fallback | *(SoundFont PC #122)* |
| **124** | Telephone Ring | ⏳ Fallback | *(SoundFont PC #124)* |
| **125** | Helicopter | ⏳ Fallback | *(SoundFont PC #125)* |
| **126** | Applause | ⏳ Fallback | *(SoundFont PC #126)* |
| **127** | Gunshot | ✅ Native | `eats_sfxr` (Chiptune blast SFX engine) |

### Channel 10 Percussion (GM Drum Kit) — 100% Covered
- **Standard GM Drum Kit**: ✅ Native (`drum_kit_sampler` with fallback to soundfont bank 128)
- Additional analog and acoustic synthesis models available: `analog_808_...`, `analog_909_...`, `fm_acoustic_...`.

---

## 2. Priority Backlog for 100% GM Coverage

The following families currently represent the highest impact remaining additions:
1. **Brass Family (GM 56-63)**: Trumpet, Trombone, French Horn, Brass Section, Synth Brass.
2. **Reed Family (GM 64-71)**: Alto Sax, Tenor Sax, Oboe, Clarinet, Bassoon.
3. **Organ Family (GM 16-23)**: Drawbar Organ (Hammond B3), Church Organ, Accordion, Harmonica.
4. **Synth Pad Family (GM 88-95)**: Warm Pad, Choir Pad, Metallic Pad.

---

## 3. Programmatic API Reference

In Dart code, developers can query coverage and missing instruments directly via [gm_instrument_registry.dart](file:///c:/git/eatsbeats/lib/audio/gm/gm_instrument_registry.dart):

```dart
// Check coverage metrics
double coverage = GmInstrumentRegistry.nativeCoveragePercent; // 40.6%
int nativeCount = GmInstrumentRegistry.nativeCount;           // 52
int totalCount = GmInstrumentRegistry.totalCount;             // 128

// Get unmodeled instruments needing native implementations
List<GmInstrumentDef> missing = GmInstrumentRegistry.missingInstruments;

// Get unmodeled instruments grouped by GM family
Map<GmFamily, List<GmInstrumentDef>> backlog = GmInstrumentRegistry.missingByFamily;

// Resolve any incoming MIDI track
GmResolutionResult result = GmInstrumentRegistry.resolve(
  programNumber: track.programNumber,
  trackName: track.name,
  channel: track.channel,
);
```
