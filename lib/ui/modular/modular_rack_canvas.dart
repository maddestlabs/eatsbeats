import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../lua/lua_engine.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../widgets/glowing_nixie_display.dart';
import '../widgets/skeuomorphic_hardware_knob.dart';
import 'modular_theme.dart';
import 'modular_faceplate_widget.dart';
import 'modular_jack_widget.dart';
import 'patch_cable_painter.dart';

/// Module Model for Dynamic Modular Rack Editing
class DynamicModuleDefinition {
  final String id;
  final String title;
  final String subtitle;
  final int hpWidth;
  final Color accentColor;
  final String category; // 'VCO', 'VCF', 'MOD', 'FX', 'CORE', 'OUT'
  final List<String> inputJacks;
  final List<String> outputJacks;

  const DynamicModuleDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.hpWidth,
    required this.accentColor,
    required this.category,
    required this.inputJacks,
    required this.outputJacks,
  });
}

/// Identifies a physical jack on a module in the rack
class JackKey {
  final int row;
  final int moduleIndex;
  final int jackIndex;
  final String label;

  const JackKey({
    required this.row,
    required this.moduleIndex,
    required this.jackIndex,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JackKey &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          moduleIndex == other.moduleIndex &&
          jackIndex == other.jackIndex;

  @override
  int get hashCode => row.hashCode ^ moduleIndex.hashCode ^ jackIndex.hashCode;
}

/// Dynamic Connection between two jacks
class DynamicPatchConnection {
  final JackKey fromKey;
  final JackKey toKey;
  final Color color;
  final double tension;

  const DynamicPatchConnection({
    required this.fromKey,
    required this.toKey,
    this.color = ModularTheme.cableAudio,
    this.tension = 0.5,
  });

  DynamicPatchConnection copyWith({
    JackKey? fromKey,
    JackKey? toKey,
    Color? color,
    double? tension,
  }) {
    return DynamicPatchConnection(
      fromKey: fromKey ?? this.fromKey,
      toKey: toKey ?? this.toKey,
      color: color ?? this.color,
      tension: tension ?? this.tension,
    );
  }
}

/// Interactive Multi-Row Modular Synthesizer Canvas (VCV Rack-Style Infinite Studio).
/// Features:
/// - 100% mathematically exact subpixel socket alignment.
/// - 2D Smooth Panning & Zooming across infinite rails.
/// - Dynamic multi-row vertical expansion (`+ ADD ROW`).
/// - Interactive cable drag-and-drop patching, tap-to-disconnect, and color cycling.
/// - `[+ ADD MODULE]` library browser with dynamic hardware modules.
class ModularRackCanvas extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;

  const ModularRackCanvas({
    super.key,
    required this.dawState,
    required this.track,
  });

  /// Calculates mathematically exact subpixel socket coordinates inside the scrollable rack canvas.
  /// - `row`: 1-based row index (1, 2, 3...)
  /// - `previousHpList`: list of HP widths of all modules preceding this module in the row
  /// - `currentHp`: HP width of this module
  /// - `jackIndex`: 0-based index of the jack in this module's jack row
  /// - `totalJacks`: total number of jacks in this module's jack row
  static Offset computeJackCenter({
    required int row,
    required List<int> previousHpList,
    required int currentHp,
    required int jackIndex,
    required int totalJacks,
  }) {
    // 8px container padding + cumulative (hp * 16px + 4px margin)
    double moduleLeft = 8.0;
    for (final hp in previousHpList) {
      moduleLeft += (hp * ModularTheme.standardHpUnit) + 4.0;
    }

    final double moduleWidth = currentHp * ModularTheme.standardHpUnit;
    final double innerWidth = moduleWidth - 16.0; // 8px padding on each side

    double jackLocalX;
    if (totalJacks <= 1) {
      jackLocalX = moduleWidth * 0.5;
    } else {
      // Centered precisely inside each slot of width (innerWidth / totalJacks)
      final double slotWidth = innerWidth / totalJacks;
      jackLocalX = 8.0 + (slotWidth * (jackIndex + 0.5));
    }

    // Each row tier height = 18px (rail bar) + 185px (module) + 8px (gap) = 211px.
    // Module top = tierTop + 18px.
    // Jack socket center sits at exactly Y = 148.0px inside module.
    final double tierTop = (row - 1) * 211.0;
    final double jackY = tierTop + 18.0 + 148.0;

    return Offset(moduleLeft + jackLocalX, jackY);
  }

  @override
  State<ModularRackCanvas> createState() => _ModularRackCanvasState();
}

class _ModularRackCanvasState extends State<ModularRackCanvas> {
  final TransformationController _transformController = TransformationController();

  double _cableOpacity = 0.85;
  int _totalRowCount = 2;

  // Custom User Modules per row (indexed by row 1, 2, 3...)
  final Map<int, List<DynamicModuleDefinition>> _customModulesByRow = {
    1: [],
    2: [],
  };

  // Dynamic Connections
  final List<DynamicPatchConnection> _connections = [];

  // Interactive Drag-and-Drop Patching State
  JackKey? _dragSourceJack;
  Offset? _dragStartPos;
  Offset? _dragCurrentPos;
  Color _dragCableColor = ModularTheme.cableAudio;
  JackKey? _hoveredTargetJack;

  @override
  void initState() {
    super.initState();
    _rebuildDefaultConnections();
  }

  @override
  void didUpdateWidget(covariant ModularRackCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id || oldWidget.track.luaScriptCode != widget.track.luaScriptCode) {
      _rebuildDefaultConnections();
    }
  }

  double _getParam(String name, double defVal) {
    return widget.track.luaParams[name] ?? defVal;
  }

  void _setParam(String name, double value) {
    setState(() {
      widget.track.luaParams[name] = value;
      widget.dawState.updateLuaParam(name, value);
    });
  }

  String get _instrumentSignature {
    final code = widget.track.luaScriptCode;
    final name = widget.track.name.toLowerCase();

    if (code.contains('FmAcousticKick') || name.contains('acoustic kick')) return 'fm_acoustic_kick';
    if (code.contains('FmAcousticSnare') || name.contains('acoustic snare')) return 'fm_acoustic_snare';
    if (code.contains('FmAcousticTom') || name.contains('acoustic tom')) return 'fm_acoustic_tom';
    if (code.contains('FmAcousticHiHat') || name.contains('acoustic hi-hat') || name.contains('acoustic hihat')) return 'fm_acoustic_hihat';
    if (code.contains('Analog808Kick') || name.contains('808 kick')) return 'analog_808_kick';
    if (code.contains('Analog808Snare') || name.contains('808 snare')) return 'analog_808_snare';
    if (code.contains('Analog808HiHat') || name.contains('808 hi-hat') || name.contains('808 hihat')) return 'analog_808_hihat';
    if (code.contains('Analog808Cowbell') || name.contains('cowbell') || name.contains('808 cowbell')) return 'analog_808_cowbell';
    if (code.contains('Analog808Tom') || name.contains('808 tom')) return 'analog_808_tom';
    if (code.contains('Analog909Kick') || name.contains('909 kick')) return 'analog_909_kick';
    if (code.contains('Analog909Snare') || name.contains('909 snare')) return 'analog_909_snare';
    if (code.contains('Analog909ClosedHiHat') || name.contains('909 closed') || name.contains('909 hi-hat') || name.contains('909 hihat')) return 'analog_909_closed_hihat';
    if (code.contains('Analog909OpenHiHat') || name.contains('909 open')) return 'analog_909_open_hihat';
    if (code.contains('Analog909Clap') || name.contains('909 clap') || name.contains('clap')) return 'analog_909_clap';
    if (code.contains('Analog909Rimshot') || name.contains('909 rim') || name.contains('rimshot')) return 'analog_909_rimshot';
    if (code.contains('Acid303') || name.contains('303') || name.contains('acid')) return 'acid_303';
    if (code.contains('PolyLeadSynth') || name.contains('poly lead')) return 'poly_lead';
    if (code.contains('YM2612') || name.contains('genesis') || name.contains('ym2612')) return 'ym2612_synth';
    if (code.contains('OPL3') || name.contains('opl3') || name.contains('chiptune')) return 'opl3_retro';
    if (code.contains('SNESSFX') || code.contains('SFXR') || name.contains('sfxr')) return 'eats_sfxr';
    if (code.contains('SNESConsole') || name.contains('snes')) return 'snes_console_synth';
    if (code.contains('SoundFontSampler') || name.contains('soundfont') || name.contains('sf2')) return 'soundfont_sampler';
    if (code.contains('DrumKitSampler') || name.contains('drum sampler') || name.contains('drum kit')) return 'drum_kit_sampler';
    if (code.contains('SamplerInstrument') || name.contains('sampler') || widget.track.type == TrackType.sampler) return 'sampler_instrument';
    if (code.contains('StereoDelay') || name.contains('delay')) return 'lua_delay';
    if (code.contains('StereoChorus') || name.contains('chorus')) return 'lua_chorus';
    if (code.contains('Bitcrusher') || name.contains('crusher') || name.contains('bit')) return 'bitcrusher_fx';
    if (code.contains('TubeDistortion') || name.contains('tube') || name.contains('distortion')) return 'tube_distortion';
    return 'generic';
  }

  void _rebuildDefaultConnections() {
    _connections.clear();

    switch (_instrumentSignature) {
      case 'ym2612_synth':
        _connections.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 2, label: 'FM Out'),
            toKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 0, label: 'Carrier In'),
            color: ModularTheme.cableModulation,
            tension: 0.55,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 1, label: 'DAC Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 0, label: 'DAC In'),
            color: ModularTheme.cableAudio,
            tension: 0.45,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Analog Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'L In'),
            color: ModularTheme.cableAudio,
            tension: 0.65,
          ),
        ]);
        break;

      case 'eats_sfxr':
      case 'snes_console_synth':
        _connections.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 2, label: 'DSP Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 0, label: 'In'),
            color: ModularTheme.cableDigital,
            tension: 0.6,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Gaussian Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 0, label: 'In'),
            color: ModularTheme.cableAudio,
            tension: 0.45,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Echo Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'DSP In'),
            color: ModularTheme.cableAudio,
            tension: 0.65,
          ),
        ]);
        break;

      case 'acid_303':
        _connections.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Saw Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.6,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 2, label: 'VCF Out'),
            toKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 0, label: 'In'),
            color: ModularTheme.cableAudio,
            tension: 0.65,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Env Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Env In'),
            color: ModularTheme.cableModulation,
            tension: 0.45,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 1, label: 'Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.4,
          ),
        ]);
        break;

      case 'fm_acoustic_snare':
        _connections.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Tone Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Tone In'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Wire Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 0, label: 'Wire In'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
        ]);
        break;

      case 'fm_acoustic_kick':
      default:
        _connections.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'FM Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 0, label: 'FM In'),
            color: ModularTheme.cableModulation,
            tension: 0.6,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 2, label: 'Audio Out'),
            toKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.55,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 1, label: 'EQ Out'),
            toKey: JackKey(row: 2, moduleIndex: 2, jackIndex: 0, label: 'Near In'),
            color: ModularTheme.cableAudio,
            tension: 0.4,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Room Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'In'),
            color: ModularTheme.cablePitchCv,
            tension: 0.65,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 1, label: 'Delayed Out'),
            toKey: JackKey(row: 2, moduleIndex: 2, jackIndex: 1, label: 'Far In'),
            color: ModularTheme.cablePitchCv,
            tension: 0.5,
          ),
        ]);
        break;
    }
  }

  List<int> _getRowHpList(int row) {
    List<int> hpList = [];
    if (row == 1) {
      switch (_instrumentSignature) {
        case 'ym2612_synth':
          hpList = [15, 15, 15];
          break;
        case 'eats_sfxr':
        case 'snes_console_synth':
          hpList = [15, 12];
          break;
        case 'soundfont_sampler':
        case 'sampler_instrument':
        case 'drum_kit_sampler':
          hpList = [15, 12];
          break;
        case 'acid_303':
          hpList = [10, 15, 10];
          break;
        case 'fm_acoustic_snare':
          hpList = [11, 15];
          break;
        case 'fm_acoustic_kick':
        default:
          hpList = [11, 15, 11];
          break;
      }
    } else if (row == 2) {
      switch (_instrumentSignature) {
        case 'ym2612_synth':
          hpList = [15, 12];
          break;
        case 'eats_sfxr':
        case 'snes_console_synth':
          hpList = [15, 12];
          break;
        case 'soundfont_sampler':
        case 'sampler_instrument':
        case 'drum_kit_sampler':
          hpList = [15, 12];
          break;
        case 'acid_303':
          hpList = [15, 11];
          break;
        case 'fm_acoustic_snare':
          hpList = [14, 12];
          break;
        case 'fm_acoustic_kick':
        default:
          hpList = [11, 14, 15];
          break;
      }
    }

    // Add custom module HPs for this row
    final custom = _customModulesByRow[row] ?? [];
    for (final mod in custom) {
      hpList.add(mod.hpWidth);
    }
    return hpList;
  }

  int _getModuleJackCount(int row, int moduleIndex) {
    if (row == 1) {
      switch (_instrumentSignature) {
        case 'ym2612_synth':
          return [3, 2, 2][moduleIndex.clamp(0, 2)];
        case 'eats_sfxr':
        case 'snes_console_synth':
          return [3, 2][moduleIndex.clamp(0, 1)];
        case 'soundfont_sampler':
        case 'sampler_instrument':
        case 'drum_kit_sampler':
          return [2, 2][moduleIndex.clamp(0, 1)];
        case 'acid_303':
          return [2, 3, 2][moduleIndex.clamp(0, 2)];
        case 'fm_acoustic_snare':
          return [2, 2][moduleIndex.clamp(0, 1)];
        case 'fm_acoustic_kick':
        default:
          return [2, 3, 2][moduleIndex.clamp(0, 2)];
      }
    } else if (row == 2) {
      switch (_instrumentSignature) {
        case 'ym2612_synth':
          return [2, 3][moduleIndex.clamp(0, 1)];
        case 'eats_sfxr':
        case 'snes_console_synth':
          return [2, 2][moduleIndex.clamp(0, 1)];
        case 'soundfont_sampler':
        case 'sampler_instrument':
        case 'drum_kit_sampler':
          return [2, 2][moduleIndex.clamp(0, 1)];
        case 'acid_303':
          return [2, 2][moduleIndex.clamp(0, 1)];
        case 'fm_acoustic_snare':
          return [2, 2][moduleIndex.clamp(0, 1)];
        case 'fm_acoustic_kick':
        default:
          return [2, 2, 3][moduleIndex.clamp(0, 2)];
      }
    }
    // Custom modules
    final custom = _customModulesByRow[row] ?? [];
    if (moduleIndex < custom.length) {
      final mod = custom[moduleIndex];
      return mod.inputJacks.length + mod.outputJacks.length;
    }
    return 2;
  }

  Offset _resolveJackOffset(JackKey key) {
    final hpList = _getRowHpList(key.row);
    final previousHps = hpList.take(key.moduleIndex).toList();
    final currentHp = key.moduleIndex < hpList.length ? hpList[key.moduleIndex] : 10;
    final totalJacks = _getModuleJackCount(key.row, key.moduleIndex);

    return ModularRackCanvas.computeJackCenter(
      row: key.row,
      previousHpList: previousHps,
      currentHp: currentHp,
      jackIndex: key.jackIndex,
      totalJacks: totalJacks,
    );
  }

  /// Finds the closest jack socket to [canvasPos] within 36px threshold
  JackKey? _findClosestJack(Offset canvasPos) {
    JackKey? bestKey;
    double bestDist = 36.0;

    for (int r = 1; r <= _totalRowCount; r++) {
      final hpList = _getRowHpList(r);
      for (int m = 0; m < hpList.length; m++) {
        final totalJacks = _getModuleJackCount(r, m);
        for (int j = 0; j < totalJacks; j++) {
          final key = JackKey(row: r, moduleIndex: m, jackIndex: j, label: 'Jack');
          final jackPos = _resolveJackOffset(key);
          final dist = (jackPos - canvasPos).distance;
          if (dist < bestDist) {
            bestDist = dist;
            bestKey = key;
          }
        }
      }
    }
    return bestKey;
  }

  void _onJackTap(JackKey key) {
    // Check if this jack has existing connections
    final existingIdx = _connections.indexWhere((c) => c.fromKey == key || c.toKey == key);
    if (existingIdx != -1) {
      final conn = _connections[existingIdx];
      // Show Quick Jack Context Modal: Disconnect or Cycle Color
      showModalBottomSheet(
        context: context,
        backgroundColor: ModularTheme.faceplateDarkBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'JACK: ${key.label.toUpperCase()}',
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.cable, color: ModularTheme.cableAudio),
                  title: const Text('Cycle Cable Color', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      final currentIdx = ModularTheme.cablePalette.indexOf(conn.color);
                      final nextColor = ModularTheme.cablePalette[(currentIdx + 1) % ModularTheme.cablePalette.length];
                      _connections[existingIdx] = conn.copyWith(color: nextColor);
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link_off, color: Colors.redAccent),
                  title: const Text('Disconnect Patch Cable', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _connections.removeAt(existingIdx);
                    });
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _onJackDragStart(JackKey key, DragStartDetails details) {
    final startPos = _resolveJackOffset(key);
    setState(() {
      _dragSourceJack = key;
      _dragStartPos = startPos;
      _dragCurrentPos = startPos;
      _dragCableColor = ModularTheme.cablePalette[(_connections.length) % ModularTheme.cablePalette.length];
      _hoveredTargetJack = null;
    });
  }

  void _onJackDragUpdate(JackKey key, DragUpdateDetails details) {
    if (_dragSourceJack == null || _dragCurrentPos == null) return;

    // Get current zoom scale from InteractiveViewer transformation matrix
    double scale = _transformController.value.getMaxScaleOnAxis();
    if (scale <= 0.01) scale = 1.0;

    final updatedPos = _dragCurrentPos! + (details.delta / scale);
    final nearest = _findClosestJack(updatedPos);

    setState(() {
      _dragCurrentPos = updatedPos;
      if (nearest != null && nearest != _dragSourceJack) {
        _hoveredTargetJack = nearest;
      } else {
        _hoveredTargetJack = null;
      }
    });
  }

  void _onJackDragEnd(JackKey key, DragEndDetails details) {
    if (_dragSourceJack != null && _hoveredTargetJack != null && _hoveredTargetJack != _dragSourceJack) {
      // Connect new patch cable!
      setState(() {
        _connections.add(
          DynamicPatchConnection(
            fromKey: _dragSourceJack!,
            toKey: _hoveredTargetJack!,
            color: _dragCableColor,
            tension: 0.5,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected ${_dragSourceJack!.label} → ${_hoveredTargetJack!.label}'),
          backgroundColor: ModularTheme.railMetalColor,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    setState(() {
      _dragSourceJack = null;
      _dragStartPos = null;
      _dragCurrentPos = null;
      _hoveredTargetJack = null;
    });
  }

  void _openAddModuleDialog(int targetRow) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ModularTheme.caseBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          height: 380,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_circle, color: ModularTheme.cablePitchCv, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ADD MODULE TO ROW $targetRow',
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.8,
                  children: [
                    _buildModuleLibraryCard(
                      ctx,
                      title: 'ANALOG VCO',
                      subtitle: 'Saw/Square Core',
                      category: 'VCO',
                      color: const Color(0xFFFF5722),
                      onSelect: () => _addModuleToRow(
                        targetRow,
                        const DynamicModuleDefinition(
                          id: 'vco_saw_sqr',
                          title: 'ANALOG VCO',
                          subtitle: 'Saw/Square Core',
                          hpWidth: 10,
                          accentColor: Color(0xFFFF5722),
                          category: 'VCO',
                          inputJacks: ['1V/Oct', 'Sync In'],
                          outputJacks: ['Saw Out', 'Sqr Out'],
                        ),
                      ),
                    ),
                    _buildModuleLibraryCard(
                      ctx,
                      title: 'DIODE LADDER VCF',
                      subtitle: '24dB Resonant Filter',
                      category: 'VCF',
                      color: const Color(0xFFFF9800),
                      onSelect: () => _addModuleToRow(
                        targetRow,
                        const DynamicModuleDefinition(
                          id: 'vcf_ladder',
                          title: 'DIODE LADDER',
                          subtitle: '24dB Resonant',
                          hpWidth: 12,
                          accentColor: Color(0xFFFF9800),
                          category: 'VCF',
                          inputJacks: ['Audio In', 'Cutoff CV'],
                          outputJacks: ['VCF Out'],
                        ),
                      ),
                    ),
                    _buildModuleLibraryCard(
                      ctx,
                      title: 'ADSR ENVELOPE',
                      subtitle: '4-Stage Modulator',
                      category: 'MOD',
                      color: const Color(0xFF00E676),
                      onSelect: () => _addModuleToRow(
                        targetRow,
                        const DynamicModuleDefinition(
                          id: 'mod_adsr',
                          title: 'ADSR ENVELOPE',
                          subtitle: '4-Stage Mod',
                          hpWidth: 11,
                          accentColor: Color(0xFF00E676),
                          category: 'MOD',
                          inputJacks: ['Gate In', 'Retrig'],
                          outputJacks: ['Env Out', 'Inv Out'],
                        ),
                      ),
                    ),
                    _buildModuleLibraryCard(
                      ctx,
                      title: 'TAPE DELAY FX',
                      subtitle: 'Analog Bucket Echo',
                      category: 'FX',
                      color: const Color(0xFF00BCD4),
                      onSelect: () => _addModuleToRow(
                        targetRow,
                        const DynamicModuleDefinition(
                          id: 'fx_tape_delay',
                          title: 'TAPE DELAY',
                          subtitle: 'Bucket Echo',
                          hpWidth: 12,
                          accentColor: Color(0xFF00BCD4),
                          category: 'FX',
                          inputJacks: ['Audio In', 'Time CV'],
                          outputJacks: ['Wet Out', 'Direct'],
                        ),
                      ),
                    ),
                    _buildModuleLibraryCard(
                      ctx,
                      title: 'TANH OVERDRIVE',
                      subtitle: 'Tube Saturation VCA',
                      category: 'FX',
                      color: const Color(0xFFE91E63),
                      onSelect: () => _addModuleToRow(
                        targetRow,
                        const DynamicModuleDefinition(
                          id: 'fx_drive',
                          title: 'TANH DRIVE',
                          subtitle: 'Tube Saturation',
                          hpWidth: 10,
                          accentColor: Color(0xFFE91E63),
                          category: 'FX',
                          inputJacks: ['In', 'Drive CV'],
                          outputJacks: ['Clipped Out'],
                        ),
                      ),
                    ),
                    _buildModuleLibraryCard(
                      ctx,
                      title: 'STEREO OUT VCA',
                      subtitle: 'Master Summing Bus',
                      category: 'OUT',
                      color: const Color(0xFFFFD600),
                      onSelect: () => _addModuleToRow(
                        targetRow,
                        const DynamicModuleDefinition(
                          id: 'out_vca',
                          title: 'STEREO OUT',
                          subtitle: 'Master Bus',
                          hpWidth: 10,
                          accentColor: Color(0xFFFFD600),
                          category: 'OUT',
                          inputJacks: ['L In', 'R In'],
                          outputJacks: ['Out L', 'Out R'],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModuleLibraryCard(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required String category,
    required Color color,
    required VoidCallback onSelect,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        onSelect();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ModularTheme.faceplateDarkBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 8,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addModuleToRow(int row, DynamicModuleDefinition mod) {
    setState(() {
      _customModulesByRow.putIfAbsent(row, () => []).add(mod);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${mod.title} to Row $row'),
        backgroundColor: ModularTheme.railMetalColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double canvasWidth = 1050.0;
    final double canvasHeight = (_totalRowCount * 211.0) + 60.0;

    return Container(
      decoration: const BoxDecoration(
        color: ModularTheme.caseBackground,
      ),
      child: Column(
        children: [
          // --- TOP MODULAR RACK TOOLBAR ---
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: ModularTheme.railMetalColor,
            child: Row(
              children: [
                const Icon(Icons.cable, color: ModularTheme.cableAudio, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'MODULAR RACK: ${widget.track.name.toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFFCCCCCC),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),

                // Reset Camera Zoom/Pan
                IconButton(
                  icon: const Icon(Icons.center_focus_strong, size: 14, color: Colors.white70),
                  tooltip: 'Reset Viewport',
                  onPressed: () {
                    _transformController.value = Matrix4.identity();
                  },
                ),

                // Reset Patch Cables Button
                InkWell(
                  onTap: () {
                    setState(() {
                      _rebuildDefaultConnections();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: ModularTheme.faceplateDarkBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, size: 12, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          'RESET PATCH',
                          style: TextStyle(fontFamily: 'Courier', fontSize: 8.5, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),

                // Cable Opacity Control
                const Text(
                  'CABLES:',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 9,
                    color: Color(0xFF888888),
                  ),
                ),
                SizedBox(
                  width: 75,
                  child: SliderTheme(
                    data: SliderThemeData(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      trackHeight: 2,
                      activeTrackColor: ModularTheme.cableAudio,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: ModularTheme.cableAudio,
                    ),
                    child: Slider(
                      value: _cableOpacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setState(() => _cableOpacity = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- VCV RACK STYLE 2D PAN & ZOOM INFINITE MODULAR CANVAS ---
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(400),
              minScale: 0.6,
              maxScale: 1.6,
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  children: [
                    // --- ALL RACK ROWS ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int r = 1; r <= _totalRowCount; r++) ...[
                          _buildModularRailBar('ROW $r: ${_getRailDescription(r)}', canvasWidth),
                          Container(
                            height: ModularTheme.moduleHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                ..._buildRowModules(r),
                                ...(_customModulesByRow[r] ?? []).asMap().entries.map(
                                  (e) => _buildCustomModuleWidget(r, e.key + _getBaseModuleCount(r), e.value),
                                ),
                                _buildAddModuleBlankPlate(r),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // --- EXPAND RACK: + ADD ROW BUTTON ---
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _totalRowCount++;
                                _customModulesByRow[_totalRowCount] = [];
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: ModularTheme.railMetalColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ModularTheme.cablePitchCv.withOpacity(0.6)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, color: ModularTheme.cablePitchCv, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    '+ ADD RACK ROW (EXPAND MODULAR CASE)',
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: ModularTheme.cablePitchCv,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // --- PIXEL-PERFECT GRAVITATIONAL PATCH CABLES OVERLAY ---
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: PatchCablePainter(
                            opacity: _cableOpacity,
                            cables: [
                              for (final conn in _connections)
                                ModularPatchCable(
                                  from: _resolveJackOffset(conn.fromKey),
                                  to: _resolveJackOffset(conn.toKey),
                                  color: conn.color,
                                  tension: conn.tension,
                                ),
                              if (_dragStartPos != null && _dragCurrentPos != null)
                                ModularPatchCable(
                                  from: _dragStartPos!,
                                  to: _dragCurrentPos!,
                                  color: _dragCableColor,
                                  tension: 0.5,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRailDescription(int row) {
    if (row == 1) return 'AUDIO GENERATION, HARDWARE CORES & PRIMARY FILTERS';
    if (row == 2) return 'MODULATION ENVELOPES, DSP GLUE & MASTER OUT';
    return 'CUSTOM EXPANSION TIER & SIGNAL PROCESSORS';
  }

  int _getBaseModuleCount(int row) {
    if (row == 1) {
      switch (_instrumentSignature) {
        case 'ym2612_synth':
        case 'acid_303':
        case 'fm_acoustic_kick':
          return 3;
        default:
          return 2;
      }
    } else if (row == 2) {
      switch (_instrumentSignature) {
        case 'fm_acoustic_kick':
          return 3;
        default:
          return 2;
      }
    }
    return 0;
  }

  Widget _buildAddModuleBlankPlate(int row) {
    return Container(
      width: 72,
      height: ModularTheme.moduleHeight,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: ModularTheme.faceplateDarkBg.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 1.0),
      ),
      child: InkWell(
        onTap: () => _openAddModuleDialog(row),
        borderRadius: BorderRadius.circular(4),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, color: ModularTheme.cablePitchCv, size: 24),
              SizedBox(height: 4),
              Text(
                '+ ADD',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: ModularTheme.cablePitchCv,
                ),
              ),
              Text(
                'MODULE',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 7.5,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomModuleWidget(int row, int moduleIndex, DynamicModuleDefinition mod) {
    return ModularFaceplateWidget(
      title: mod.title,
      subtitle: mod.subtitle,
      hpWidth: mod.hpWidth,
      accentColor: mod.accentColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SkeuomorphicHardwareKnob(
                  label: 'PARAM 1',
                  value: 0.5,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.5,
                  size: 40,
                  accentColor: mod.accentColor,
                  onChanged: (v) {},
                ),
                SkeuomorphicHardwareKnob(
                  label: 'PARAM 2',
                  value: 0.5,
                  min: 0.0,
                  max: 1.0,
                  defaultValue: 0.5,
                  size: 40,
                  accentColor: mod.accentColor,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ...mod.inputJacks.asMap().entries.map(
                      (e) => _buildInteractiveJack(
                        row: row,
                        moduleIndex: moduleIndex,
                        jackIndex: e.key,
                        label: e.value,
                        type: JackType.input,
                      ),
                    ),
                ...mod.outputJacks.asMap().entries.map(
                      (e) => _buildInteractiveJack(
                        row: row,
                        moduleIndex: moduleIndex,
                        jackIndex: mod.inputJacks.length + e.key,
                        label: e.value,
                        type: JackType.output,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveJack({
    required int row,
    required int moduleIndex,
    required int jackIndex,
    required String label,
    JackType type = JackType.input,
    JackSignalType signalType = JackSignalType.audio,
  }) {
    final key = JackKey(row: row, moduleIndex: moduleIndex, jackIndex: jackIndex, label: label);
    final isConnected = _connections.any((c) => c.fromKey == key || c.toKey == key);

    return ModularJackWidget(
      label: label,
      jackId: '${row}_${moduleIndex}_$jackIndex',
      type: type,
      signalType: signalType,
      isConnected: isConnected,
      isHovered: _hoveredTargetJack == key,
      onTap: () => _onJackTap(key),
      onDragStart: (details) => _onJackDragStart(key, details),
      onDragUpdate: (details) => _onJackDragUpdate(key, details),
      onDragEnd: (details) => _onJackDragEnd(key, details),
    );
  }

  Widget _buildModularRailBar(String label, double width) {
    return Container(
      height: 18,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: ModularTheme.railMetalColor,
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Courier',
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6E727A),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  List<Widget> _buildRowModules(int row) {
    if (row == 1) return _buildRow1Modules();
    if (row == 2) return _buildRow2Modules();
    return [];
  }

  List<Widget> _buildRow1Modules() {
    switch (_instrumentSignature) {
      case 'ym2612_synth':
        return [
          ModularFaceplateWidget(
            title: 'YM2612 FM CORE',
            subtitle: '4-Op FM Chip ASIC',
            hpWidth: 15,
            accentColor: const Color(0xFF00E5FF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'ALGO',
                        value: _getParam('Algorithm', 4.0),
                        min: 0.0,
                        max: 7.0,
                        defaultValue: 4.0,
                        size: 40,
                        accentColor: const Color(0xFF00E5FF),
                        onChanged: (v) => _setParam('Algorithm', v),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'FEEDBACK',
                        value: _getParam('Feedback', 5.0),
                        min: 0.0,
                        max: 7.0,
                        defaultValue: 5.0,
                        size: 40,
                        accentColor: const Color(0xFF00E5FF),
                        onChanged: (v) => _setParam('Feedback', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 0, label: 'Gate In', signalType: JackSignalType.gate),
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Pitch In', signalType: JackSignalType.pitchCv),
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 2, label: 'FM Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Op 1 & 2 Operators',
            subtitle: 'Modulator Matrix',
            hpWidth: 15,
            accentColor: const Color(0xFF00E5FF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'OP1 MULT',
                        value: _getParam('Op1_Mult', 1.0),
                        min: 0.5,
                        max: 12.0,
                        defaultValue: 1.0,
                        size: 40,
                        accentColor: const Color(0xFF00E5FF),
                        onChanged: (v) => _setParam('Op1_Mult', v),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'OP1 TL',
                        value: _getParam('Op1_TL', 8.0),
                        min: 0.0,
                        max: 127.0,
                        defaultValue: 8.0,
                        size: 40,
                        accentColor: const Color(0xFF00E5FF),
                        onChanged: (v) => _setParam('Op1_TL', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 0, label: 'Op1 Out', type: JackType.output, signalType: JackSignalType.modulation),
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Op2 Out', type: JackType.output, signalType: JackSignalType.modulation),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Op 3 & 4 Operators',
            subtitle: 'Carrier Matrix',
            hpWidth: 15,
            accentColor: const Color(0xFF00E5FF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'OP4 MULT',
                        value: _getParam('Op4_Mult', 1.0),
                        min: 0.5,
                        max: 12.0,
                        defaultValue: 1.0,
                        size: 40,
                        accentColor: const Color(0xFF00E5FF),
                        onChanged: (v) => _setParam('Op4_Mult', v),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'OP4 TL',
                        value: _getParam('Op4_TL', 0.0),
                        min: 0.0,
                        max: 127.0,
                        defaultValue: 0.0,
                        size: 40,
                        accentColor: const Color(0xFF00E5FF),
                        onChanged: (v) => _setParam('Op4_TL', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 2, jackIndex: 0, label: 'Carrier In', type: JackType.input),
                      _buildInteractiveJack(row: 1, moduleIndex: 2, jackIndex: 1, label: 'DAC Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];

      case 'eats_sfxr':
      case 'snes_console_synth':
        return [
          ModularFaceplateWidget(
            title: '16-BIT S-DSP CORE',
            subtitle: '16-Bit SPC700 Chip',
            hpWidth: 15,
            accentColor: const Color(0xFFE040FB),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'ATTACK',
                        value: _getParam('Attack', 0.005),
                        min: 0.001,
                        max: 0.5,
                        defaultValue: 0.005,
                        size: 40,
                        accentColor: const Color(0xFFE040FB),
                        onChanged: (v) => _setParam('Attack', v),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'DECAY',
                        value: _getParam('Decay', 0.25),
                        min: 0.01,
                        max: 2.0,
                        defaultValue: 0.25,
                        size: 40,
                        accentColor: const Color(0xFFE040FB),
                        onChanged: (v) => _setParam('Decay', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 0, label: 'Gate In', signalType: JackSignalType.gate),
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 1, label: 'BRR Wav', signalType: JackSignalType.digital),
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 2, label: 'DSP Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Gaussian BRR Filter',
            subtitle: '4-Point Interpolator',
            hpWidth: 12,
            accentColor: const Color(0xFFE040FB),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: SkeuomorphicHardwareKnob(
                      label: 'SWEEP',
                      value: _getParam('PitchSweep', 0.0),
                      min: -2.0,
                      max: 2.0,
                      defaultValue: 0.0,
                      size: 42,
                      accentColor: const Color(0xFFE040FB),
                      onChanged: (v) => _setParam('PitchSweep', v),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 0, label: 'In', type: JackType.input),
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Gaussian Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];

      case 'acid_303':
        return [
          ModularFaceplateWidget(
            title: '303 VCO',
            subtitle: 'Saw/Square Core',
            hpWidth: 10,
            accentColor: const Color(0xFFFF8C00),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: SkeuomorphicHardwareKnob(
                      label: 'WAVE',
                      value: _getParam('Waveform', 0.0),
                      min: 0.0,
                      max: 1.0,
                      defaultValue: 0.0,
                      size: 40,
                      accentColor: const Color(0xFFFF8C00),
                      onChanged: (v) => _setParam('Waveform', v),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 0, label: '1V/Oct', signalType: JackSignalType.pitchCv),
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Saw Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: '24dB Diode VCF',
            subtitle: 'Ladder Filter',
            hpWidth: 15,
            accentColor: const Color(0xFFFF8C00),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'CUTOFF',
                        value: _getParam('Cutoff', 1600.0),
                        min: 100.0,
                        max: 6500.0,
                        defaultValue: 1600.0,
                        size: 40,
                        accentColor: const Color(0xFFFF8C00),
                        onChanged: (v) => _setParam('Cutoff', v),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'RES',
                        value: _getParam('Resonance', 8.0),
                        min: 0.5,
                        max: 16.0,
                        defaultValue: 8.0,
                        size: 40,
                        accentColor: const Color(0xFFFF8C00),
                        onChanged: (v) => _setParam('Resonance', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 0, label: 'Audio In', type: JackType.input),
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Env In', signalType: JackSignalType.modulation),
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 2, label: 'VCF Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Diode Saturation',
            subtitle: 'Overdrive',
            hpWidth: 10,
            accentColor: const Color(0xFFFF8C00),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: SkeuomorphicHardwareKnob(
                      label: 'DRIVE',
                      value: _getParam('Overdrive', 0.3),
                      min: 0.0,
                      max: 1.0,
                      defaultValue: 0.3,
                      size: 40,
                      accentColor: const Color(0xFFFF8C00),
                      onChanged: (v) => _setParam('Overdrive', v),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 2, jackIndex: 0, label: 'In', type: JackType.input),
                      _buildInteractiveJack(row: 1, moduleIndex: 2, jackIndex: 1, label: 'Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];

      case 'fm_acoustic_kick':
      default:
        return [
          ModularFaceplateWidget(
            title: 'Noise FM Exciter',
            subtitle: 'PRNG Transient',
            hpWidth: 11,
            accentColor: const Color(0xFFFF5722),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: SkeuomorphicHardwareKnob(
                      label: 'FM DEPTH',
                      value: _getParam('NearFmDepth', 600.0),
                      min: 0.0,
                      max: 1200.0,
                      defaultValue: 600.0,
                      size: 40,
                      accentColor: const Color(0xFFFF5722),
                      onChanged: (v) => _setParam('NearFmDepth', v),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 0, label: 'Gate In', signalType: JackSignalType.gate),
                      _buildInteractiveJack(row: 1, moduleIndex: 0, jackIndex: 1, label: 'FM Out', type: JackType.output, signalType: JackSignalType.modulation),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Batter Carrier VCO',
            subtitle: 'Swept Sine Core',
            hpWidth: 15,
            accentColor: const Color(0xFFFF5722),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'PUNCH',
                        value: _getParam('NearPitchStart', 180.0),
                        min: 100.0,
                        max: 300.0,
                        defaultValue: 180.0,
                        size: 40,
                        accentColor: const Color(0xFFFF5722),
                        onChanged: (v) => _setParam('NearPitchStart', v),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'SUB TUNE',
                        value: _getParam('NearPitchEnd', 52.0),
                        min: 30.0,
                        max: 80.0,
                        defaultValue: 52.0,
                        size: 40,
                        accentColor: const Color(0xFFFF5722),
                        onChanged: (v) => _setParam('NearPitchEnd', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 0, label: 'FM In', signalType: JackSignalType.modulation),
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Pitch In', signalType: JackSignalType.pitchCv),
                      _buildInteractiveJack(row: 1, moduleIndex: 1, jackIndex: 2, label: 'Audio Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: '3-Band Acoustic EQ',
            subtitle: 'Sub/Mid/Click',
            hpWidth: 11,
            accentColor: const Color(0xFFFF5722),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: SkeuomorphicHardwareKnob(
                      label: 'SUB GAIN',
                      value: _getParam('SubResoGain', 4.0),
                      min: 0.0,
                      max: 12.0,
                      defaultValue: 4.0,
                      size: 40,
                      accentColor: const Color(0xFFFF5722),
                      onChanged: (v) => _setParam('SubResoGain', v),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 1, moduleIndex: 2, jackIndex: 0, label: 'Audio In', type: JackType.input),
                      _buildInteractiveJack(row: 1, moduleIndex: 2, jackIndex: 1, label: 'EQ Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }

  List<Widget> _buildRow2Modules() {
    switch (_instrumentSignature) {
      case 'ym2612_synth':
        return [
          ModularFaceplateWidget(
            title: 'YM2612 DAC Glue',
            subtitle: 'Ladder Attenuator',
            hpWidth: 15,
            accentColor: const Color(0xFF00E5FF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Center(
                    child: Text(
                      'OPN2 9-BIT LADDER DAC\nLOGARITHMIC COMPRESSION',
                      style: TextStyle(fontFamily: 'Courier', fontSize: 7, color: Color(0xFF00E5FF)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 0, jackIndex: 0, label: 'DAC In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Analog Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Master Genesis Audio Out',
            subtitle: 'Stereo Line Bus',
            hpWidth: 12,
            accentColor: const Color(0xFF00E5FF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Center(
                    child: Text(
                      'YM2612 STEREO',
                      style: TextStyle(fontFamily: 'Courier', fontSize: 7.5, color: Color(0xFF00E5FF)),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 0, label: 'L In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 1, label: 'R In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 2, label: 'Out L/R', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];

      case 'eats_sfxr':
      case 'snes_console_synth':
        return [
          ModularFaceplateWidget(
            title: '8-Tap FIR Echo DSP',
            subtitle: 'SPC700 Ring Buffer',
            hpWidth: 15,
            accentColor: const Color(0xFFE040FB),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'ECHO MS',
                        value: _getParam('EchoDelay', 120.0),
                        min: 16.0,
                        max: 480.0,
                        defaultValue: 120.0,
                        size: 40,
                        accentColor: const Color(0xFFE040FB),
                        onChanged: (v) => _setParam('EchoDelay', v),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'ECHO VOL',
                        value: _getParam('EchoVolume', 0.35),
                        min: 0.0,
                        max: 1.0,
                        defaultValue: 0.35,
                        size: 40,
                        accentColor: const Color(0xFFE040FB),
                        onChanged: (v) => _setParam('EchoVolume', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 0, jackIndex: 0, label: 'In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Echo Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Master Console Out',
            subtitle: '32kHz DAC Filter',
            hpWidth: 12,
            accentColor: const Color(0xFFE040FB),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Center(
                    child: Text(
                      '16-BIT S-DSP STEREO',
                      style: TextStyle(fontFamily: 'Courier', fontSize: 7.5, color: Color(0xFFE040FB)),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 0, label: 'DSP In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 1, label: 'Out L/R', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];

      case 'acid_303':
        return [
          ModularFaceplateWidget(
            title: 'Accent & Slide VCA',
            subtitle: 'Envelope Modulator',
            hpWidth: 15,
            accentColor: const Color(0xFFFF8C00),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'DECAY',
                        value: _getParam('Decay', 0.28),
                        min: 0.05,
                        max: 1.2,
                        defaultValue: 0.28,
                        size: 40,
                        accentColor: const Color(0xFFFF8C00),
                        onChanged: (v) => _setParam('Decay', v),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'ACCENT',
                        value: _getParam('Accent', 0.6),
                        min: 0.0,
                        max: 1.0,
                        defaultValue: 0.6,
                        size: 40,
                        accentColor: const Color(0xFFFF8C00),
                        onChanged: (v) => _setParam('Accent', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 0, jackIndex: 0, label: 'Gate In', signalType: JackSignalType.gate),
                      _buildInteractiveJack(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Env Out', type: JackType.output, signalType: JackSignalType.modulation),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Master Audio Out',
            subtitle: 'Analog Summing',
            hpWidth: 11,
            accentColor: const Color(0xFFFF8C00),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Center(
                    child: Text(
                      'TB-303 ANALOG BUS',
                      style: TextStyle(fontFamily: 'Courier', fontSize: 7.5, color: Color(0xFFFF8C00)),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 0, label: 'Audio In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 1, label: 'Out L/R', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];

      case 'fm_acoustic_kick':
      default:
        return [
          ModularFaceplateWidget(
            title: 'Room Farfield VCO',
            subtitle: 'Air Displacement',
            hpWidth: 11,
            accentColor: const Color(0xFF00BCD4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: SkeuomorphicHardwareKnob(
                      label: 'ROOM FM',
                      value: _getParam('FarFmDepth', 250.0),
                      min: 0.0,
                      max: 600.0,
                      defaultValue: 250.0,
                      size: 40,
                      accentColor: const Color(0xFF00BCD4),
                      onChanged: (v) => _setParam('FarFmDepth', v),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 0, jackIndex: 0, label: 'FM In', signalType: JackSignalType.modulation),
                      _buildInteractiveJack(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Room Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Room Delay Line',
            subtitle: '2-20ms Reflection',
            hpWidth: 14,
            accentColor: const Color(0xFF00BCD4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SkeuomorphicHardwareKnob(
                        label: 'TIME',
                        value: _getParam('RoomDelaySec', 0.008) * 1000.0,
                        min: 2.0,
                        max: 20.0,
                        defaultValue: 8.0,
                        size: 40,
                        accentColor: const Color(0xFF00BCD4),
                        onChanged: (v) => _setParam('RoomDelaySec', v / 1000.0),
                      ),
                      SkeuomorphicHardwareKnob(
                        label: 'LEVEL',
                        value: _getParam('FarLevel', 0.35),
                        min: 0.0,
                        max: 1.0,
                        defaultValue: 0.35,
                        size: 40,
                        accentColor: const Color(0xFF00BCD4),
                        onChanged: (v) => _setParam('FarLevel', v),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 0, label: 'In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 1, jackIndex: 1, label: 'Delayed Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ModularFaceplateWidget(
            title: 'Master Summing',
            subtitle: 'Tanh Saturation',
            hpWidth: 15,
            accentColor: const Color(0xFFFF9800),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: SkeuomorphicHardwareKnob(
                      label: 'DECAY',
                      value: _getParam('NearAmpDecay', 0.28),
                      min: 0.05,
                      max: 0.8,
                      defaultValue: 0.28,
                      size: 40,
                      accentColor: const Color(0xFFFF9800),
                      onChanged: (v) => _setParam('NearAmpDecay', v),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInteractiveJack(row: 2, moduleIndex: 2, jackIndex: 0, label: 'Near In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 2, jackIndex: 1, label: 'Far In', type: JackType.input),
                      _buildInteractiveJack(row: 2, moduleIndex: 2, jackIndex: 2, label: 'Master Out', type: JackType.output),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }
}
