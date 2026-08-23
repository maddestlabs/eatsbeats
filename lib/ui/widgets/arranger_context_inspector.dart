import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import 'midi_fx_rack_widget.dart';
import 'modular_fx_rack_widget.dart';
import 'eats_color_picker_dialog.dart';

enum InspectorTab { track, clip }

class ArrangerContextInspector extends StatefulWidget {
  final DawState dawState;
  final VoidCallback onClose;
  final InspectorTab initialTab;
  final double? width;
  final ValueChanged<double>? onResize;

  const ArrangerContextInspector({
    super.key,
    required this.dawState,
    required this.onClose,
    this.initialTab = InspectorTab.track,
    this.width,
    this.onResize,
  });

  @override
  State<ArrangerContextInspector> createState() => _ArrangerContextInspectorState();
}

class _ArrangerContextInspectorState extends State<ArrangerContextInspector> {
  final TextEditingController _trackNameController = TextEditingController();
  final TextEditingController _clipNameController = TextEditingController();
  bool _isEditingTrackName = false;
  bool _isEditingClipName = false;
  String? _lastTrackId;
  String? _lastClipId;

  static const List<Color> _quickColorPalette = [
    Color(0xFF21F4E8), // Neon Cyan
    Color(0xFFFF007A), // Hot Pink
    Color(0xFF00FF66), // Acid Green
    Color(0xFFBD00FF), // Electric Purple
    Color(0xFFFF8C00), // Neon Amber
    Color(0xFFFFE600), // Yellow
    Color(0xFFFF3333), // Crimson Red
    Color(0xFF3399FF), // Sky Blue
  ];

  static const List<Color> _expandedColorPalette = [
    Color(0xFF21F4E8), Color(0xFFFF8C00), Color(0xFF00FF66), Color(0xFFFF007A),
    Color(0xFFBD00FF), Color(0xFFFF3333), Color(0xFFFFD700), Color(0xFF3399FF),
    Color(0xFF00E5FF), Color(0xFFFFAB00), Color(0xFF76FF03), Color(0xFFF50057),
    Color(0xFFD500F9), Color(0xFFFF1744), Color(0xFFFFEA00), Color(0xFF2979FF),
    Color(0xFF1DE9B6), Color(0xFFFF6D00), Color(0xFFAEEA00), Color(0xFFE040FB),
    Color(0xFF651FFF), Color(0xFFFF5252), Color(0xFFFFC400), Color(0xFF00B0FF),
  ];

  static const List<String> _musicEmojiPalette = [
    '🎹', '🎸', '🥁', '🎷', '🎺', '🎻', '🎙️', '🎛️',
    '🔊', '⚡', '🎧', '🎵', '🎶', '👾', '🔥', '✨',
  ];

  @override
  void initState() {
    super.initState();
    widget.dawState.addListener(_onDawStateChanged);
    final track = widget.dawState.activeTrack;
    _trackNameController.text = track.name;
    _lastTrackId = track.id;

    final clip = widget.dawState.activeClip;
    if (clip != null) {
      _clipNameController.text = clip.name;
      _lastClipId = clip.id;
    }
  }

  void _onDawStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ArrangerContextInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dawState != widget.dawState) {
      oldWidget.dawState.removeListener(_onDawStateChanged);
      widget.dawState.addListener(_onDawStateChanged);
    }
    final track = widget.dawState.activeTrack;
    if (track.id != _lastTrackId) {
      _trackNameController.text = track.name;
      _lastTrackId = track.id;
      _isEditingTrackName = false;
    }

    final clip = widget.dawState.activeClip;
    if (clip != null && clip.id != _lastClipId) {
      _clipNameController.text = clip.name;
      _lastClipId = clip.id;
      _isEditingClipName = false;
    } else if (clip == null) {
      _lastClipId = null;
      _isEditingClipName = false;
    }
  }

  @override
  void dispose() {
    widget.dawState.removeListener(_onDawStateChanged);
    _trackNameController.dispose();
    _clipNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.dawState.activeTrack;
    final clip = widget.dawState.activeClip;
    final currentWidth = widget.width ?? 290.0;

    return Container(
      width: currentWidth,
      decoration: BoxDecoration(
        color: EatsTheme.panelBackground,
        border: const Border(left: BorderSide(color: Color(0xFF2B3245), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(-3, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Context-Sensitive Sidebar Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: EatsTheme.panelHeader,
                  border: const Border(bottom: BorderSide(color: Color(0xFF2B3245), width: 1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      clip != null ? Icons.view_timeline : Icons.tune,
                      size: 14,
                      color: clip != null ? EatsTheme.accentGold : EatsTheme.primaryCyan,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'PROPERTIES',
                        style: EatsTheme.getPrimaryFontStyle(
                          color: clip != null ? EatsTheme.accentGold : EatsTheme.primaryCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (clip != null) ...[
                      InkWell(
                        onTap: () => widget.dawState.selectClip(null),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 85),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: EatsTheme.controlBackground,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: track.color.withOpacity(0.5), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back, size: 9, color: track.color),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  track.name,
                                  style: TextStyle(color: track.color, fontSize: 8, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      color: EatsTheme.textMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      tooltip: 'Close Inspector',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // Context-Sensitive Inspector Body (Track OR Clip)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (clip != null)
                      _buildClipSection(context, track, clip)
                    else
                      _buildTrackSection(context, track),
                  ],
                ),
              ),
            ],
          ),

          // Left-Edge Drag Resize Handle
          if (widget.onResize != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 8,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    widget.onResize?.call(details.delta.dx);
                  },
                  child: Container(
                    width: 8,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 2,
                        height: 24,
                        decoration: BoxDecoration(
                          color: EatsTheme.textMuted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackSection(BuildContext context, TrackChannel track) {
    final hasMidiFx = track.midiFXRack.isNotEmpty;
    final isMidiFxAllEnabled = track.midiFXRack.any((f) => f.enabled);
    final isSingleTrack = widget.dawState.activePattern.tracks.length <= 1;
    final trackIdx = widget.dawState.activePattern.tracks.indexOf(track);
    final isFirstTrack = trackIdx <= 0;
    final isLastTrack = trackIdx == -1 || trackIdx >= widget.dawState.activePattern.tracks.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track Header Label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: track.color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: track.color.withOpacity(0.6), blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'TRACK PROPERTIES',
                  style: TextStyle(color: track.color, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: EatsTheme.controlBackground,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: track.color.withOpacity(0.4), width: 0.8),
              ),
              child: Text(
                track.type.name.toUpperCase(),
                style: TextStyle(color: track.color, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Track Identity & Rename Card
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EatsTheme.panelHeader,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: track.color.withOpacity(0.6), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: track.color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: track.color.withOpacity(0.5), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('TRACK NAME', style: TextStyle(color: track.color, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_isEditingTrackName ? Icons.check : Icons.edit, size: 14, color: track.color),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: _isEditingTrackName ? 'Save Name' : 'Rename Track',
                    onPressed: () {
                      if (_isEditingTrackName) {
                        final trimmed = _trackNameController.text.trim();
                        if (trimmed.isNotEmpty) {
                          track.name = trimmed;
                          widget.dawState.recordHistory('Rename Track to "$trimmed"', icon: Icons.edit);
                          widget.dawState.notifyListeners();
                        }
                        setState(() => _isEditingTrackName = false);
                      } else {
                        _trackNameController.text = track.name;
                        _trackNameController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _trackNameController.text.length,
                        );
                        setState(() => _isEditingTrackName = true);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_isEditingTrackName) ...[
                TextField(
                  controller: _trackNameController,
                  autofocus: true,
                  style: TextStyle(color: EatsTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: EatsTheme.controlBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: track.color)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: track.color, width: 1.2)),
                  ),
                  onSubmitted: (val) {
                    final trimmed = val.trim();
                    if (trimmed.isNotEmpty) {
                      track.name = trimmed;
                      widget.dawState.recordHistory('Rename Track to "$trimmed"', icon: Icons.edit);
                      widget.dawState.notifyListeners();
                    }
                    setState(() => _isEditingTrackName = false);
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _musicEmojiPalette.map((emoji) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        final cur = _trackNameController.text;
                        if (cur.isEmpty) {
                          _trackNameController.text = '$emoji ';
                        } else if (!cur.startsWith(emoji)) {
                          _trackNameController.text = '$emoji $cur';
                        } else {
                          _trackNameController.text = '$cur $emoji';
                        }
                        _trackNameController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _trackNameController.text.length),
                        );
                        setState(() {});
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: EatsTheme.controlBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2B3245), width: 0.8),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
              ] else
                InkWell(
                  onTap: () {
                    _trackNameController.text = track.name;
                    _trackNameController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _trackNameController.text.length,
                    );
                    setState(() => _isEditingTrackName = true);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.name,
                          style: TextStyle(color: EatsTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasMidiFx)
                        IconButton(
                          tooltip: isMidiFxAllEnabled ? 'Bypass MIDI FX Rack' : 'Enable MIDI FX Rack',
                          icon: Icon(
                            Icons.bolt,
                            color: isMidiFxAllEnabled ? EatsTheme.accentGold : EatsTheme.textMuted,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => widget.dawState.toggleTrackMidiFXRack(track, !isMidiFxAllEnabled),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 1. Track Color Palette & Color Picker Dialog
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: EatsTheme.panelHeader,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2B3245)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('TRACK COLOR', style: TextStyle(color: EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      showEatsColorPickerDialog(
                        context,
                        currentColor: track.color,
                        onColorSelected: (newColor) {
                          widget.dawState.setTrackColor(track, newColor);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: EatsTheme.controlBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette, size: 11, color: EatsTheme.primaryCyan),
                          const SizedBox(width: 3),
                          Text(
                            'PALETTE...',
                            style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickColorPalette.map((color) {
                  final isSelected = color.value == track.color.value;
                  return GestureDetector(
                    onTap: () => widget.dawState.setTrackColor(track, color),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.black38,
                          width: isSelected ? 2.2 : 0.8,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.8), blurRadius: 6, spreadRadius: 1)]
                            : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.black) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. Track Quick Action Strip (Immediately after Track Color)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: EatsTheme.panelHeader,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2B3245)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TRACK ACTIONS', style: TextStyle(color: EatsTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ORDER', style: TextStyle(color: EatsTheme.textMuted, fontSize: 8.5, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: isFirstTrack ? null : () => widget.dawState.moveTrackUp(track),
                        borderRadius: BorderRadius.circular(3),
                        child: Tooltip(
                          message: 'Move Track Up',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: EatsTheme.controlBackground,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: const Color(0xFF2B3245), width: 0.8),
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_up,
                              size: 13,
                              color: isFirstTrack ? Colors.white12 : EatsTheme.primaryCyan,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      InkWell(
                        onTap: isLastTrack ? null : () => widget.dawState.moveTrackDown(track),
                        borderRadius: BorderRadius.circular(3),
                        child: Tooltip(
                          message: 'Move Track Down',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: EatsTheme.controlBackground,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: const Color(0xFF2B3245), width: 0.8),
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 13,
                              color: isLastTrack ? Colors.white12 : EatsTheme.primaryCyan,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.dawState.addClipToTrack(track, 0),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EatsTheme.primaryCyan,
                        side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      ),
                      icon: const Icon(Icons.add, size: 13),
                      label: const Text('Add Clip', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.dawState.duplicateTrack(track),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EatsTheme.textSecondary,
                        side: const BorderSide(color: Color(0xFF2B3245)),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      ),
                      icon: const Icon(Icons.copy, size: 12),
                      label: const Text('Duplicate', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSingleTrack ? null : () => widget.dawState.deleteTrack(track),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isSingleTrack ? EatsTheme.textMuted : const Color(0xFFFF4D6D),
                        side: BorderSide(color: isSingleTrack ? Colors.white10 : const Color(0xFFFF4D6D).withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 12),
                      label: const Text('Delete', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3. Pre-Instrument MIDI FX Rack
        MidiFxRackWidget(
          dawState: widget.dawState,
          track: track,
        ),

        const SizedBox(height: 10),

        // 4. Audio FX Insert Rack (After MIDI FX Rack)
        ModularFxRackWidget(
          dawState: widget.dawState,
          track: track,
        ),
      ],
    );
  }

  Widget _buildClipSection(BuildContext context, TrackChannel track, TrackClip? clip) {
    if (clip == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EatsTheme.panelHeader.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2B3245)),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 20, color: EatsTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Select a clip in the timeline to edit clip title, duplicate, or delete.',
                style: TextStyle(color: EatsTheme.textMuted, fontSize: 10.5),
              ),
            ),
          ],
        ),
      );
    }

    final hasTrackMidiFx = track.midiFXRack.any((f) => f.enabled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clip Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: EatsTheme.accentGold,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: EatsTheme.accentGold.withOpacity(0.6), blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'SELECTED CLIP',
                  style: TextStyle(color: EatsTheme.accentGold, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: EatsTheme.accentGold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EatsTheme.accentGold.withOpacity(0.5), width: 0.8),
              ),
              child: Text(
                'Bar ${clip.startBar + 1} (${clip.barLength}B)',
                style: TextStyle(color: EatsTheme.accentGold, fontSize: 8.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Editable Clip Title Card
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EatsTheme.panelHeader,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: EatsTheme.accentGold.withOpacity(0.6), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('CLIP TITLE', style: TextStyle(color: EatsTheme.accentGold, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_isEditingClipName ? Icons.check : Icons.edit, size: 14, color: EatsTheme.accentGold),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: _isEditingClipName ? 'Save Name' : 'Rename Clip',
                    onPressed: () {
                      if (_isEditingClipName) {
                        if (_clipNameController.text.trim().isNotEmpty) {
                          widget.dawState.renameClip(clip, _clipNameController.text.trim());
                        }
                        setState(() => _isEditingClipName = false);
                      } else {
                        _clipNameController.text = clip.name;
                        _clipNameController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _clipNameController.text.length,
                        );
                        setState(() => _isEditingClipName = true);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_isEditingClipName)
                TextField(
                  controller: _clipNameController,
                  autofocus: true,
                  style: TextStyle(color: EatsTheme.clipTextColor, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: EatsTheme.controlBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: EatsTheme.accentGold)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: EatsTheme.accentGold, width: 1.2)),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      widget.dawState.renameClip(clip, val.trim());
                    }
                    setState(() => _isEditingClipName = false);
                  },
                )
              else
                InkWell(
                  onTap: () {
                    _clipNameController.text = clip.name;
                    _clipNameController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _clipNameController.text.length,
                    );
                    setState(() => _isEditingClipName = true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      clip.name,
                      style: TextStyle(color: EatsTheme.clipTextColor, fontWeight: FontWeight.bold, fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Actions: Open in Piano Roll, Duplicate Clip, Delete Clip, Bake MIDI FX
        Column(
          children: [
            // Edit in Piano Roll
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.dawState.selectClip(clip);
                  widget.dawState.activeTabIndex = 1; // EDIT tab
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: EatsTheme.primaryCyan,
                  side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.piano, size: 15),
                label: const Text('OPEN IN PIANO ROLL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 8),

            // Duplicate Clip & Delete Clip Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.dawState.duplicateClip(track, clip),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EatsTheme.textSecondary,
                      side: const BorderSide(color: Color(0xFF2B3245)),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    ),
                    icon: const Icon(Icons.copy, size: 13),
                    label: const Text('DUPLICATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.dawState.deleteClip(track, clip),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF4D6D),
                      side: const BorderSide(color: Color(0xFFFF4D6D), width: 1.0),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text('DELETE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            if (hasTrackMidiFx) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.dawState.bakeMidiFXToClip(track, clip);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Baked MIDI FX to Clip "${clip.name}"'),
                        backgroundColor: EatsTheme.panelHeader,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EatsTheme.panelHeader,
                    foregroundColor: EatsTheme.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: EatsTheme.accentGold.withOpacity(0.6)),
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 14),
                  label: const Text('BAKE TRACK MIDI FX', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
