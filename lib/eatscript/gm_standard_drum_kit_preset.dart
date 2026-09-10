import 'eat_script_library.dart';

/// General MIDI Standard Drum Kit (`gm_standard_drum_kit`) Preset.
///
/// Implements authentic physical/modal modeling for all 47 General MIDI drum sounds (Notes 35–81)
/// with a 6-zone interactive console, visual drum pad grid, choke groups, and procgen variation.
class GmStandardDrumKitPreset {
  static const LuaPreset preset = LuaPreset(
    id: 'gm_standard_drum_kit',
    name: 'GM Standard Drum Kit',
    category: LuaPresetCategory.instrument,
    description: 'Complete General MIDI Standard Drum Kit (Notes 35–81) featuring physical dual-mic kicks, acoustic snares, 6 toms, inharmonic metallic cymbals & hats, Latin percussion, choke groups, and procgen physical variation.',
    code: '''
# @id: gm_standard_drum_kit
# @name: GM Standard Drum Kit
# @category: instrument
# @description: Complete General MIDI Standard Drum Kit (Notes 35–81) with physical modeling, inharmonic metallic cymbals, Latin percussion, and procgen variation.

def init():
    # Master Kit Bus & Room Ambience: eat.param(name, min, max, default)
    eat.param("MasterTune", -12.0, 12.0, 0.0)
    eat.param("RoomLevel", 0.0, 1.0, 0.30)
    eat.param("KitDrive", 0.0, 1.0, 0.12)

    # Physical Variation & Humanize Engine
    eat.param("Humanize", 0.0, 1.0, 0.25)
    eat.param("StrikeDrift", 0.0, 1.0, 0.20)
    eat.param("Dynamics", 0.0, 1.0, 0.75)

    # Sectional Tone Shaping
    eat.param("KickPunch", 80.0, 320.0, 180.0)
    eat.param("SnareSnappy", 0.0, 1.0, 0.65)
    eat.param("TomDecay", 0.1, 1.2, 0.45)
    eat.param("CymbalDecay", 0.2, 2.5, 1.0)
    eat.param("PercLevel", 0.0, 1.5, 0.85)

def process(time, freq, note, params):
    # Evaluated by GmDrumKitEngine in EatDspSynthesizer
    return eat.drum(note, time, params)

def gui():
    return {
        "panel": {
            "title": "GM STANDARD DRUM KIT",
            "subtitle": "Physical Modeling & Multi-Zone Drum Engine",
            "background": "dark",
            "accent": "track",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "nixie", "param": "MasterTune", "label": "KIT TUNE"},
                        {"type": "nixie", "param": "RoomLevel", "label": "ROOM AIR"},
                        {"type": "nixie", "param": "Humanize", "label": "HUMANIZE"},
                        {"type": "nixie", "param": "StrikeDrift", "label": "DRIFT"},
                    ]
                },
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "MasterTune", "label": "PITCH", "size": 52},
                        {"type": "knob", "param": "KickPunch", "label": "KICK PUNCH", "size": 52},
                        {"type": "knob", "param": "SnareSnappy", "label": "SNAPPY", "size": 52},
                        {"type": "knob", "param": "TomDecay", "label": "TOM RING", "size": 52},
                        {"type": "knob", "param": "CymbalDecay", "label": "CYMBAL DEC", "size": 52},
                        {"type": "knob", "param": "PercLevel", "label": "PERC VOL", "size": 52},
                    ]
                },
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Humanize", "label": "HUMANIZE", "size": 52},
                        {"type": "knob", "param": "StrikeDrift", "label": "DRIFT", "size": 52},
                        {"type": "knob", "param": "Dynamics", "label": "DYNAMICS", "size": 52},
                        {"type": "knob", "param": "RoomLevel", "label": "ROOM MIC", "size": 52},
                        {"type": "knob", "param": "KitDrive", "label": "TAPE DRIVE", "size": 52},
                    ]
                }
            ]
        }
    }
''',
  );
}
