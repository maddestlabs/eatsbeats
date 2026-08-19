import 'package:flutter/material.dart';
import '../../lua/lua_preset_library.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'eatsbits_slider.dart';
import 'skeuomorphic_hardware_switch.dart';

class MidiFxRackWidget extends StatelessWidget {
  final DawState dawState;
  final TrackChannel track;

  const MidiFxRackWidget({
    super.key,
    required this.dawState,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<LuaPreset>(
      onWillAcceptWithDetails: (details) => details.data.isMidiFx,
      onAcceptWithDetails: (details) {
        final preset = details.data;
        dawState.applyPreset(preset, targetTrack: track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added MIDI FX "${preset.name}" to ${track.name}'),
            backgroundColor: EatsTheme.panelHeader,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovering ? EatsTheme.primaryCyan.withOpacity(0.15) : EatsTheme.panelBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHovering ? EatsTheme.primaryCyan : EatsTheme.primaryCyan.withOpacity(0.4),
              width: isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: EatsTheme.primaryCyan.withOpacity(isHovering ? 0.25 : 0.08),
                blurRadius: isHovering ? 12 : 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.bolt, color: EatsTheme.accentGold, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'MIDI FX RACK (${track.midiFXRack.length})',
                      overflow: TextOverflow.ellipsis,
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.primaryCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (track.midiFXRack.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        dawState.bakeTrackMidiFX(track);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Baked MIDI FX notes into clips for "${track.name}"'),
                            backgroundColor: EatsTheme.panelHeader,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: EatsTheme.accentGold,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.auto_fix_high, size: 14),
                      label: const Text('Bake to MIDI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Add MIDI FX Module',
                    color: EatsTheme.panelHeader,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: EatsTheme.panelHeader,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EatsTheme.primaryCyan),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, color: EatsTheme.primaryCyan, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '+ ADD MIDI FX',
                            style: EatsTheme.getPrimaryFontStyle(
                              color: EatsTheme.primaryCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'arp',
                        child: Row(
                          children: [
                            Icon(Icons.stairs, color: EatsTheme.primaryCyan, size: 16),
                            const SizedBox(width: 8),
                            const Text('Arpeggiator FX', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'chord_arp',
                        child: Row(
                          children: [
                            Icon(Icons.queue_music, color: EatsTheme.accentGold, size: 16),
                            SizedBox(width: 8),
                            Text('Chord Arpeggiator (Chord Track)', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'scale_snap',
                        child: Row(
                          children: [
                            Icon(Icons.music_note, color: EatsTheme.accentGreen, size: 16),
                            const SizedBox(width: 8),
                            const Text('Scale Snap FX', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'humanize',
                        child: Row(
                          children: [
                            Icon(Icons.grain, color: EatsTheme.secondaryMagenta, size: 16),
                            const SizedBox(width: 8),
                            const Text('Humanize & Groove', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'arp') {
                        dawState.addMidiFXInsert(
                          track,
                          name: 'Arpeggiator FX',
                          luaScriptCode: 'arpeggiator',
                          params: {'Rate': 1.0, 'Octaves': 2.0, 'Pattern': 0.0, 'Gate': 0.85, 'Swing': 0.0},
                        );
                      } else if (val == 'chord_arp') {
                        dawState.addMidiFXInsert(
                          track,
                          name: 'Chord Arpeggiator FX',
                          luaScriptCode: 'chord_arp',
                          params: {'Rate': 1.0, 'Octaves': 2.0, 'Pattern': 0.0, 'Gate': 0.85, 'Swing': 0.0},
                        );
                      } else if (val == 'scale_snap') {
                        dawState.addMidiFXInsert(
                          track,
                          name: 'Scale Snap FX',
                          luaScriptCode: 'scale_snap',
                          params: {'Key': dawState.songKeyRoot.toDouble(), 'Minor': dawState.isSongKeyMinor ? 1.0 : 0.0},
                        );
                      } else if (val == 'humanize') {
                        dawState.addMidiFXInsert(
                          track,
                          name: 'Humanize FX',
                          luaScriptCode: 'humanize',
                          params: {'Timing': 0.04, 'Velocity': 0.15},
                        );
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (track.midiFXRack.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'No MIDI FX on this track. Notes flow straight to instrument.\nClick "+ ADD MIDI FX" to add Arpeggiator, Chord Arp, Scale Snap, or Humanize.',
                      textAlign: TextAlign.center,
                      style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 11),
                    ),
                  ),
                )
              else
                ...track.midiFXRack.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final fx = entry.value;
                  final isFirst = idx == 0;
                  final isLast = idx == track.midiFXRack.length - 1;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EatsTheme.panelHeader,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: fx.enabled ? EatsTheme.primaryCyan.withOpacity(0.7) : const Color(0xFF2B3245),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Module Header
                        Row(
                          children: [
                            SkeuomorphicHardwareSwitch(
                              value: fx.enabled,
                              activeColor: EatsTheme.primaryCyan,
                              tooltip: 'Toggle ${fx.name} (Bypass / Active)',
                              onChanged: (val) => dawState.toggleMidiFXInsert(track, fx.id, val),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                fx.name.toUpperCase(),
                                style: EatsTheme.getPrimaryFontStyle(
                                  color: fx.enabled ? EatsTheme.accentGold : EatsTheme.textMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Move Up',
                              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                              color: isFirst ? Colors.white12 : EatsTheme.primaryCyan,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: isFirst ? null : () => dawState.moveMidiFXUp(track, idx),
                            ),
                            IconButton(
                              tooltip: 'Move Down',
                              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                              color: isLast ? Colors.white12 : EatsTheme.primaryCyan,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: isLast ? null : () => dawState.moveMidiFXDown(track, idx),
                            ),
                            IconButton(
                              tooltip: 'Remove MIDI FX',
                              icon: Icon(Icons.delete_outline, color: EatsTheme.textMuted, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: () => dawState.removeMidiFXInsert(track, fx.id),
                            ),
                          ],
                        ),

                        if (fx.enabled) ...[
                          const SizedBox(height: 10),
                          _buildMidiFxControls(context, fx),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMidiFxControls(BuildContext context, MidiFXInsert fx) {
    final code = fx.luaScriptCode.toLowerCase();
    final nameLower = fx.name.toLowerCase();

    if (code.contains('arp') || nameLower.contains('arp')) {
      return _buildArpeggiatorControls(context, fx);
    } else if (code.contains('scale') || nameLower.contains('scale')) {
      return _buildScaleSnapControls(context, fx);
    } else if (code.contains('humanize') || nameLower.contains('humanize')) {
      return _buildHumanizeControls(context, fx);
    } else {
      return _buildGenericLuaControls(context, fx);
    }
  }

  Widget _buildArpeggiatorControls(BuildContext context, MidiFXInsert fx) {
    final double rawPattern = fx.luaParams['Pattern'] ?? fx.luaParams['pattern'] ?? 0.0;
    final double rawRate = fx.luaParams['Rate'] ?? fx.luaParams['rate'] ?? 1.0;
    final double rawOctaves = fx.luaParams['Octaves'] ?? fx.luaParams['octaves'] ?? 2.0;
    final double rawGate = fx.luaParams['Gate'] ?? fx.luaParams['gate'] ?? 0.85;
    final double rawSwing = fx.luaParams['Swing'] ?? fx.luaParams['swing'] ?? 0.0;

    const patternOptions = [
      {'val': 0.0, 'label': 'Up (Ascending)'},
      {'val': 1.0, 'label': 'Down (Descending)'},
      {'val': 2.0, 'label': 'Up / Down'},
      {'val': 3.0, 'label': 'Down / Up'},
      {'val': 4.0, 'label': 'Converge (Outside-In)'},
      {'val': 5.0, 'label': 'Diverge (Inside-Out)'},
      {'val': 6.0, 'label': 'Random Acid'},
      {'val': 7.0, 'label': 'Chord Strum'},
      {'val': 8.0, 'label': 'As-Played Order'},
    ];

    const rateOptions = [
      {'val': 4.0, 'label': '1/4 Note (Slow)'},
      {'val': 2.0, 'label': '1/8 Note'},
      {'val': 1.333, 'label': '1/8 Triplet (1/8T)'},
      {'val': 1.0, 'label': '1/16 Note (Standard)'},
      {'val': 0.667, 'label': '1/16 Triplet (1/16T)'},
      {'val': 0.5, 'label': '1/32 Note (Fast)'},
      {'val': 0.333, 'label': '1/32 Triplet (1/32T)'},
      {'val': 0.25, 'label': '1/64 Note (Hyper)'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pattern & Rate Dropdowns Row
        Row(
          children: [
            // Pattern Dropdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PATTERN MODE', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 9.5)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: EatsTheme.controlBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        value: patternOptions.any((p) => p['val'] == rawPattern) ? rawPattern : 0.0,
                        isExpanded: true,
                        dropdownColor: EatsTheme.panelHeader,
                        style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                        items: patternOptions.map((p) {
                          return DropdownMenuItem<double>(
                            value: p['val'] as double,
                            child: Text(p['label'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) dawState.updateMidiFXParam(track, fx.id, 'Pattern', val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Rate Dropdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RATE / SYNC', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 9.5)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: EatsTheme.controlBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        value: rateOptions.any((r) => ((r['val'] as double) - rawRate).abs() < 0.05) ? rawRate : 1.0,
                        isExpanded: true,
                        dropdownColor: EatsTheme.panelHeader,
                        style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.accentGold, fontSize: 11, fontWeight: FontWeight.bold),
                        items: rateOptions.map((r) {
                          return DropdownMenuItem<double>(
                            value: r['val'] as double,
                            child: Text(r['label'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) dawState.updateMidiFXParam(track, fx.id, 'Rate', val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Octaves, Gate, Swing Sliders
        Row(
          children: [
            Expanded(
              child: EatsBitsSlider(
                label: 'Octaves: ${rawOctaves.round()} Oct',
                value: rawOctaves,
                defaultValue: 2.0,
                min: 1.0,
                max: 4.0,
                divisions: 3,
                activeColor: EatsTheme.primaryCyan,
                onChanged: (val) => dawState.updateMidiFXParam(track, fx.id, 'Octaves', val.roundToDouble()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EatsBitsSlider(
                label: 'Gate: ${(rawGate * 100).round()}%',
                value: rawGate,
                defaultValue: 0.85,
                min: 0.1,
                max: 2.0,
                activeColor: EatsTheme.accentGreen,
                onChanged: (val) => dawState.updateMidiFXParam(track, fx.id, 'Gate', val),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EatsBitsSlider(
                label: 'Swing: ${(rawSwing * 100).round()}%',
                value: rawSwing,
                defaultValue: 0.0,
                min: 0.0,
                max: 0.5,
                activeColor: EatsTheme.secondaryMagenta,
                onChanged: (val) => dawState.updateMidiFXParam(track, fx.id, 'Swing', val),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScaleSnapControls(BuildContext context, MidiFXInsert fx) {
    final double rawKey = fx.luaParams['Key'] ?? fx.luaParams['key'] ?? dawState.songKeyRoot.toDouble();
    final bool isMinor = (fx.luaParams['Minor'] ?? (dawState.isSongKeyMinor ? 1.0 : 0.0)) > 0.5;

    const keyNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ROOT KEY', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 9.5)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: EatsTheme.controlBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EatsTheme.accentGreen.withOpacity(0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: rawKey.round() % 12,
                    isExpanded: true,
                    dropdownColor: EatsTheme.panelHeader,
                    style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    items: List.generate(12, (i) {
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(keyNames[i]),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) dawState.updateMidiFXParam(track, fx.id, 'Key', val.toDouble());
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SCALE TYPE', style: EatsTheme.getPrimaryFontStyle(color: EatsTheme.textMuted, fontSize: 9.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Major', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: !isMinor,
                    selectedColor: EatsTheme.accentGreen,
                    backgroundColor: EatsTheme.controlBackground,
                    onSelected: (_) => dawState.updateMidiFXParam(track, fx.id, 'Minor', 0.0),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Minor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: isMinor,
                    selectedColor: EatsTheme.accentGreen,
                    backgroundColor: EatsTheme.controlBackground,
                    onSelected: (_) => dawState.updateMidiFXParam(track, fx.id, 'Minor', 1.0),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHumanizeControls(BuildContext context, MidiFXInsert fx) {
    final double rawTiming = fx.luaParams['Timing'] ?? fx.luaParams['timing'] ?? 0.04;
    final double rawVel = fx.luaParams['Velocity'] ?? fx.luaParams['velocity'] ?? 0.15;

    return Row(
      children: [
        Expanded(
          child: EatsBitsSlider(
            label: 'Timing Jitter: ${(rawTiming * 100).round()}%',
            value: rawTiming,
            defaultValue: 0.04,
            min: 0.0,
            max: 0.15,
            activeColor: EatsTheme.secondaryMagenta,
            onChanged: (val) => dawState.updateMidiFXParam(track, fx.id, 'Timing', val),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EatsBitsSlider(
            label: 'Velocity Jitter: ${(rawVel * 100).round()}%',
            value: rawVel,
            defaultValue: 0.15,
            min: 0.0,
            max: 0.4,
            activeColor: EatsTheme.accentGold,
            onChanged: (val) => dawState.updateMidiFXParam(track, fx.id, 'Velocity', val),
          ),
        ),
      ],
    );
  }

  Widget _buildGenericLuaControls(BuildContext context, MidiFXInsert fx) {
    if (fx.luaParams.isEmpty) {
      return Text(
        'Custom Lua MIDI Script Active.',
        style: TextStyle(color: EatsTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      children: fx.luaParams.entries.map((param) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EatsBitsSlider(
            label: '${param.key}: ${param.value.toStringAsFixed(2)}',
            value: param.value,
            defaultValue: param.value,
            min: 0.0,
            max: 10.0,
            activeColor: EatsTheme.primaryCyan,
            onChanged: (val) => dawState.updateMidiFXParam(track, fx.id, param.key, val),
          ),
        );
      }).toList(),
    );
  }
}
