import 'eat_script_library.dart';

/// Modular Drum Machine (`modular_drumpad_kit`) Preset.
///
/// Dedicated 32-pad interactive drum workstation featuring 16 Core MPC pads + 16 Latin percussion pads,
/// velocity-sensitive auditioning, kit macros, and drag-and-drop element swapping.
class ModularDrumpadKitPreset {
  static const LuaPreset preset = LuaPreset(
    id: 'modular_drumpad_kit',
    name: 'Modular Drum Machine',
    category: LuaPresetCategory.instrument,
    description: 'Dedicated 32-pad modular drum workstation. Features 16 Core MPC pads + 16 Latin percussion pads, velocity auditioning, kit macros, and drag-and-drop slot assignment allowing any synthesizer or drum preset to be loaded onto any pad.',
    code: '''
# @id: modular_drumpad_kit
# @name: Modular Drum Machine
# @category: instrument
# @description: Dedicated 32-pad modular drum workstation with visual pads, drag-and-drop pad slot customization, and kit macro controls.

def init():
    # Master Kit Bus & Tone: eat.param(name, min, max, default)
    eat.param("MasterTune", -12.0, 12.0, 0.0)
    eat.param("RoomLevel", 0.0, 1.0, 0.25)
    eat.param("KitDrive", 0.0, 1.0, 0.15)
    eat.param("Humanize", 0.0, 1.0, 0.20)
    eat.param("StrikeDrift", 0.0, 1.0, 0.15)
    eat.param("Dynamics", 0.0, 1.0, 0.80)

def process(time, freq, note, params):
    # Evaluated by GmDrumKitEngine in EatDspSynthesizer
    return eat.drum(note, time, params)

def gui():
    return {
        "panel": {
            "title": "MODULAR DRUM MACHINE",
            "subtitle": "32-Pad Performance Workstation & Custom Kit Studio",
            "background": "dark",
            "accent": "#FF8C00",
            "layout": [
                {
                    "type": "drumpads"
                },
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "MasterTune", "label": "PITCH", "size": 50},
                        {"type": "knob", "param": "KitDrive", "label": "DRIVE", "size": 50},
                        {"type": "knob", "param": "RoomLevel", "label": "ROOM", "size": 50},
                        {"type": "knob", "param": "Humanize", "label": "HUMANIZE", "size": 50},
                        {"type": "knob", "param": "StrikeDrift", "label": "DRIFT", "size": 50},
                        {"type": "knob", "param": "Dynamics", "label": "DYNAMICS", "size": 50}
                    ]
                }
            ]
        }
    }
''',
  );
}
