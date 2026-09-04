import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/daw_state.dart';
import '../theme/eats_theme.dart';
import '../utils/eats_file_helper.dart';
import '../utils/url_script_helper.dart';
import '../lua/default_song.dart';
import 'widgets/skeuomorphic_hardware_button.dart';
import 'widgets/skeuomorphic_hardware_switch.dart';
import 'widgets/glowing_nixie_display.dart';
import 'widgets/compact_value_dialog.dart';
import 'widgets/ui_scale_dialog.dart';
import 'widgets/shader_picker_dialog.dart';
import 'widgets/theme_picker_dialog.dart';
import 'widgets/ai_assistant_dialog.dart';
import 'widgets/ai_task_status_bar.dart';
import '../shaders/shader_settings_manager.dart';


class TransportHeader extends StatelessWidget {
  final DawState dawState;

  const TransportHeader({super.key, required this.dawState});

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;

    return RepaintBoundary(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
        color: isGrungy ? const Color(0xFF24201C) : EatsTheme.panelHeader,
        border: Border(
          bottom: BorderSide(
            color: isGrungy ? const Color(0xFF4A423A) : const Color(0xFF2B3245),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // EatsBeats Monster Icon drawn directly on background (Theme Accent Recolorable)
          Tooltip(
            message: 'Eatsbeats Settings',
            child: InkWell(
              onTap: () => _showSettingsDialog(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: EatsBeatsMonsterIcon(size: 28, color: EatsTheme.primaryCyan),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Attached 3-Button Mechanical Transport Control Row (Play/Pause, Stop, Record)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Play / Pause Button (▶ when stopped/paused, ⏸ when playing)
              Tooltip(
                message: dawState.isPlaying ? 'Pause' : 'Play',
                child: SkeuomorphicHardwareButton(
                  customChild: TransportSymbolWidget(
                    symbol: dawState.isPlaying ? TransportSymbol.pause : TransportSymbol.play,
                    color: dawState.isPlaying
                        ? const Color(0xFF0B0E14)
                        : (EatsTheme.isLight ? const Color(0xFF0F172A) : EatsTheme.textSecondary),
                    size: 13,
                  ),
                  isActive: dawState.isPlaying,
                  activeColor: const Color(0xFF00FF66), // Green backlight
                  onTap: dawState.togglePlay,
                  height: 34,
                  width: 34,
                  padding: EdgeInsets.zero,
                  showLed: false,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                ),
              ),

              // 2. Stop Button (⏹ - Stop / Panic: stops all audio, voices, effects & resets position)
              Tooltip(
                message: 'Stop / Panic (Stops all audio & effects)',
                child: SkeuomorphicHardwareButton(
                  customChild: TransportSymbolWidget(
                    symbol: TransportSymbol.stop,
                    color: EatsTheme.isLight ? const Color(0xFF0F172A) : EatsTheme.textSecondary,
                    size: 12,
                  ),
                  isActive: false,
                  activeColor: EatsTheme.primaryCyan,
                  onTap: dawState.stop,
                  height: 34,
                  width: 34,
                  padding: EdgeInsets.zero,
                  showLed: false,
                  borderRadius: BorderRadius.zero,
                ),
              ),

              // 3. Record Button (⏺ - future use)
              Tooltip(
                message: 'Record (Arm)',
                child: SkeuomorphicHardwareButton(
                  customChild: TransportSymbolWidget(
                    symbol: TransportSymbol.record,
                    color: dawState.isRecording
                        ? const Color(0xFF0B0E14)
                        : (EatsTheme.isLight ? const Color(0xFF0F172A) : const Color(0xFFFF3B30)),
                    size: 12,
                  ),
                  isActive: dawState.isRecording,
                  activeColor: const Color(0xFFFF3B30), // Red backlight
                  onTap: dawState.toggleRecord,
                  height: 34,
                  width: 34,
                  padding: EdgeInsets.zero,
                  showLed: false,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ],
          ),

          const SizedBox(width: 10),

          // BPM Glowing Nixie Display with Direct Tap Tempo & LongPress/Right-Click Edit
          Tooltip(
            message: 'Tap tempo | Right-click or long press to edit BPM',
            child: GestureDetector(
              onTap: dawState.tapTempo,
              onLongPress: () => _showBpmEditDialog(context),
              onDoubleTap: () => _showBpmEditDialog(context),
              onSecondaryTap: () => _showBpmEditDialog(context),
              onSecondaryTapDown: (_) => _showBpmEditDialog(context),
              child: GlowingNixieDisplay(
                label: '',
                valueText: dawState.bpm.toStringAsFixed(0),
                unit: 'BPM',
                fontSize: 14,
                glowColor: EatsTheme.accentGold,
              ),
            ),
          ),

          const Spacer(),

          // Undo & Redo Transport Controls
          ListenableBuilder(
            listenable: dawState.history,
            builder: (context, _) {
              final canUndo = dawState.history.canUndo;
              final canRedo = dawState.history.canRedo;
              final undoTip = dawState.history.nextUndoDescription != null
                  ? 'Undo: ${dawState.history.nextUndoDescription} (Ctrl+Z)'
                  : 'Undo (Ctrl+Z)';
              final redoTip = dawState.history.nextRedoDescription != null
                  ? 'Redo: ${dawState.history.nextRedoDescription} (Ctrl+Y)'
                  : 'Redo (Ctrl+Y)';

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: undoTip,
                    child: SkeuomorphicHardwareButton(
                      icon: Icons.undo,
                      isActive: canUndo,
                      activeColor: EatsTheme.primaryCyan,
                      onTap: canUndo ? () => dawState.undo() : () {},
                      height: 34,
                      width: 32,
                      padding: EdgeInsets.zero,
                      showLed: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: redoTip,
                    child: SkeuomorphicHardwareButton(
                      icon: Icons.redo,
                      isActive: canRedo,
                      activeColor: EatsTheme.secondaryMagenta,
                      onTap: canRedo ? () => dawState.redo() : () {},
                      height: 34,
                      width: 32,
                      padding: EdgeInsets.zero,
                      showLed: false,
                    ),
                  ),
                ],
              );
            },
          ),

          // Live AI Background Status Indicator
          AiTaskStatusBar(dawState: dawState),

          const SizedBox(width: 6),

          // Gemini AI Assistant Button
          Tooltip(
            message: 'Gemini AI Assistant (Auto-Mix, Master, Sound Architect)',
            child: SkeuomorphicHardwareButton(
              icon: Icons.auto_awesome,
              isActive: true,
              activeColor: EatsTheme.primaryCyan,
              onTap: () => AiAssistantDialog.show(context, dawState),
              height: 34,
              width: 36,
              padding: EdgeInsets.zero,
              showLed: false,
            ),
          ),

          const SizedBox(width: 6),

          // Project Browser Toggle Button (Folder / Ctrl+B)
          Tooltip(
            message: 'Toggle Project & Preset Browser (Ctrl+B)',
            child: SkeuomorphicHardwareButton(
              icon: Icons.folder_copy,
              isActive: dawState.isBrowserOpen,
              activeColor: EatsTheme.primaryCyan,
              onTap: dawState.toggleBrowser,
              height: 34,
              width: 36,
              padding: EdgeInsets.zero,
              showLed: false,
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _handleSave(BuildContext context) {
    final zipBytes = dawState.exportToEatsZip();
    final fileName = '${dawState.projectName.toLowerCase().replaceAll(' ', '_')}.eats.zip';
    EatsFileHelper.saveEatsZipFile(zipBytes, fileName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved project as "$fileName"'),
        backgroundColor: EatsTheme.panelBackground,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleLoad(BuildContext context) {
    EatsFileHelper.pickEatsFile((zipBytes, textContent, fileName) {
      dawState.loadFromEatsZipOrLua(zipBytes: zipBytes, luaContent: textContent, fileName: fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded project "$fileName"'),
          backgroundColor: EatsTheme.panelBackground,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Future<String?> _fetchGistOrUrlContent(String input) async {
    return await UrlScriptHelper.resolveScript(input);
  }

  void _showCodeViewDialog(BuildContext context) {
    final controller = TextEditingController(text: dawState.exportToEatsLua());
    final gistUrlController = TextEditingController();
    bool isLoadingGist = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: EatsTheme.panelBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Icon(Icons.code, color: EatsTheme.primaryCyan),
                  const SizedBox(width: 8),
                  Text(
                    'IMPORT / EXPORT SCRIPT',
                    style: TextStyle(color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 320,
                      child: TextField(
                        controller: controller,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: EatsTheme.textPrimary),
                        decoration: InputDecoration(
                          fillColor: EatsTheme.controlBackground,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: gistUrlController,
                            style: TextStyle(color: EatsTheme.textPrimary, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Paste Gist ID, Gist URL, or Lua script URL...',
                              hintStyle: TextStyle(color: EatsTheme.textMuted, fontSize: 11),
                              labelText: 'LOAD FROM GITHUB GIST / URL',
                              labelStyle: TextStyle(color: EatsTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              prefixIcon: Icon(Icons.link, size: 16, color: EatsTheme.primaryCyan),
                              filled: true,
                              fillColor: EatsTheme.controlBackground,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EatsTheme.accentGold,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          icon: isLoadingGist
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.download_for_offline, size: 16, color: Colors.black),
                          label: const Text(
                            'FETCH GIST',
                            style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: isLoadingGist
                              ? null
                              : () async {
                                  final input = gistUrlController.text.trim();
                                  if (input.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a GitHub Gist ID, URL, or Lua script link')),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isLoadingGist = true);
                                  final content = await _fetchGistOrUrlContent(input);
                                  setDialogState(() => isLoadingGist = false);

                                  if (content != null && content.isNotEmpty) {
                                    controller.text = content;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Successfully loaded Lua script! Click "Import" to load project.')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to resolve script from Gist ID or URL. Please verify.')),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.share, size: 15),
                  label: const Text('SHARE LINK', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: EatsTheme.secondaryMagenta),
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      final shareUrl = UrlScriptHelper.buildShareableUrl(controller.text);
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied compressed shareable song URL to clipboard!')),
                      );
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 15),
                  label: const Text('COPY', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: EatsTheme.accentGold),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: controller.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied .eats.lua to clipboard!')),
                    );
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: EatsTheme.primaryCyan),
                  icon: const Icon(Icons.file_download, size: 16, color: Colors.black),
                  label: const Text('IMPORT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      dawState.loadFromEatsLua(controller.text);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Imported project from .eats.lua script!')),
                      );
                    }
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('CLOSE', style: TextStyle(color: EatsTheme.textMuted)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final titleController = TextEditingController(text: dawState.projectName);
    final authorController = TextEditingController(text: dawState.authorName);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: EatsTheme.panelBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  EatsBeatsMonsterIcon(size: 28, color: EatsTheme.primaryCyan),
                  const SizedBox(width: 10),
                  Text(
                    'EATSBEATS SETTINGS',
                    style: TextStyle(color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROJECT HUB',
                        style: TextStyle(color: EatsTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),

                      // Project Details Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EatsTheme.controlBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: EatsTheme.panelHeader),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('COMPOSITION DETAILS', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),

                            // Title input
                            TextField(
                              controller: titleController,
                              style: TextStyle(color: EatsTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Title / Song Name',
                                labelStyle: TextStyle(color: EatsTheme.textMuted, fontSize: 11),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onChanged: (val) => dawState.projectName = val,
                            ),
                            const SizedBox(height: 10),

                            // Author input
                            TextField(
                              controller: authorController,
                              style: TextStyle(color: EatsTheme.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Author / Creator',
                                labelStyle: TextStyle(color: EatsTheme.textMuted, fontSize: 11),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onChanged: (val) => dawState.authorName = val,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2x2 Grid of Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildHubActionButton(
                              icon: Icons.save,
                              label: 'SAVE (.eats.lua)',
                              color: EatsTheme.accentGold,
                              onTap: () {
                                Navigator.of(context).pop();
                                _handleSave(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHubActionButton(
                              icon: Icons.folder_open,
                              label: 'LOAD (.eats.lua)',
                              color: EatsTheme.primaryCyan,
                              onTap: () {
                                Navigator.of(context).pop();
                                _handleLoad(context);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHubActionButton(
                              icon: Icons.import_export,
                              label: 'IMPORT / EXPORT',
                              color: EatsTheme.secondaryMagenta,
                              onTap: () {
                                Navigator.of(context).pop();
                                _showCodeViewDialog(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildHubActionButton(
                              icon: Icons.download,
                              label: 'EXPORT WAV',
                              color: EatsTheme.accentGreen,
                              onTap: () {
                                Navigator.of(context).pop();
                                dawState.exportWavSong();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'SESSION PERSISTENCE & AUTO-RESTORE',
                        style: TextStyle(color: EatsTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EatsTheme.controlBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: EatsTheme.panelHeader),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Restore last project on startup',
                                        style: TextStyle(color: EatsTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Automatically resumes your previous workspace',
                                        style: TextStyle(color: EatsTheme.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                SkeuomorphicHardwareSwitch(
                                  value: dawState.autoRestoreSession,
                                  activeColor: EatsTheme.primaryCyan,
                                  tooltip: 'Restore last project on startup',
                                  onChanged: (val) {
                                    setDialogState(() {
                                      dawState.autoRestoreSession = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 14, color: Colors.white12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Auto-save project state',
                                        style: TextStyle(color: EatsTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Silently writes .eats.lua snapshot to local storage',
                                        style: TextStyle(color: EatsTheme.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                SkeuomorphicHardwareSwitch(
                                  value: dawState.autoSaveEnabled,
                                  activeColor: EatsTheme.accentGold,
                                  tooltip: 'Auto-save project state',
                                  onChanged: (val) {
                                    setDialogState(() {
                                      dawState.autoSaveEnabled = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: EatsTheme.muteColor,
                                  side: BorderSide(color: EatsTheme.muteColor.withOpacity(0.5)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('RESET TO DEFAULT TEMPLATE (CLEAN SLATE)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  dawState.loadFromEatsLua(DefaultSong.midnightBitesLua);
                                  dawState.clearSavedSession();
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Reset workspace to default Midnight Bites template')),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'DISPLAY & WORKSPACE',
                        style: TextStyle(color: EatsTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: EatsTheme.controlBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: EatsTheme.panelHeader),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('UI MAGNIFICATION', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Current Scale: ${(dawState.uiScale * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(color: EatsTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                SkeuomorphicHardwareButton(
                                  label: 'ADJUST SCALE',
                                  icon: Icons.aspect_ratio,
                                  isActive: true,
                                  activeColor: EatsTheme.primaryCyan,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    UiScaleDialog.show(context, dawState);
                                  },
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: Colors.white10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('UI THEME ENGINE', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${EatsTheme.currentPreset.name.toUpperCase()} (Active)',
                                        style: TextStyle(
                                          color: EatsTheme.accentGold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SkeuomorphicHardwareButton(
                                  label: 'THEME',
                                  icon: Icons.palette,
                                  isActive: true,
                                  activeColor: EatsTheme.accentGold,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    ThemePickerDialog.show(context, dawState);
                                  },
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: Colors.white10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('SCREEN SHADERS & CRT FX', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                        ShaderSettingsManager.instance.hasActiveShader
                                            ? '${ShaderSettingsManager.instance.activeProfile.name} (Active)'
                                            : 'Disabled (Normal Display)',
                                        style: TextStyle(
                                          color: ShaderSettingsManager.instance.hasActiveShader
                                              ? EatsTheme.primaryCyan
                                              : EatsTheme.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SkeuomorphicHardwareButton(
                                  label: 'SHADERS',
                                  icon: Icons.tv,
                                  isActive: ShaderSettingsManager.instance.hasActiveShader,
                                  activeColor: EatsTheme.primaryCyan,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    ShaderPickerDialog.show(context);
                                  },
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: Colors.white10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('GUI ANIMATIONS & CPU', style: TextStyle(color: EatsTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                        dawState.guiAnimationsEnabled
                                            ? 'Enabled (Full Visualizers & Tickers)'
                                            : 'Disabled (Static UI / Conserve CPU)',
                                        style: TextStyle(
                                          color: dawState.guiAnimationsEnabled
                                              ? EatsTheme.primaryCyan
                                              : EatsTheme.textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SkeuomorphicHardwareSwitch(
                                  value: dawState.guiAnimationsEnabled,
                                  activeColor: EatsTheme.primaryCyan,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      dawState.setGuiAnimationsEnabled(val);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'AUDIO ENGINE CONFIG',
                        style: TextStyle(color: EatsTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                      ),

                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: EatsTheme.controlBackground, borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• Clock: WebAudio Hardware Scheduler (Look-Ahead 120ms)', style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text('• Sample Rate: 44.1 kHz / 48.0 kHz Hardware Native', style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text('• Script Compiler: Embedded Lua 5.4 / LuaJIT Live Engine', style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'CREDITS & ACKNOWLEDGMENTS',
                        style: TextStyle(color: EatsTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: EatsTheme.controlBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: EatsTheme.panelHeader),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• Commuted Waveguide Piano Physical Models: Based on research by Balázs Bank, Julien Bensa, Julius O. Smith, and Scott Van Duyne (CCRMA, Stanford). DSP topology & 88-key empirical tables derived from Romain Michon\'s Faust/STK physmodels.lib (MIT/STK-4.3 License) and David Braun\'s (DBraun) physical modeling adaptation.',
                              style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10, height: 1.35),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• Eats-303 DSP & Acid Synthesis: Inspired by JC-303 (Jean-Christophe Taveau), Open303 (Robin Schmidt), and classic 303 diode ladder filter topology.',
                              style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10, height: 1.35),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• SoundFont & Sampler Engine: SoundFont parser and synthesis architecture inspired by TinySoundFont / FluidSynth with bundled Super Small Font (CC BY 4.0) by nitro-shoe and GeneralUser GS by S. Christian Collins.',
                              style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10, height: 1.35),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• Reverb & Convolution FX: Freeverb Schroeder-Moorer reverberation model and open impulse responses.',
                              style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10, height: 1.35),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• Platform Runtime: Powered by Flutter, WebAudio API, WAJUCE audio engine, and embedded Lua 5.4 / LuaJIT scripting environment.',
                              style: TextStyle(color: EatsTheme.textPrimary, fontSize: 10, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('CLOSE', style: TextStyle(color: EatsTheme.primaryCyan, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showBpmEditDialog(BuildContext context) {
    showCompactValueEditDialog(
      context: context,
      title: 'Tempo (BPM)',
      initialValue: dawState.bpm.toStringAsFixed(0),
      minMaxHint: 'Range: 40 - 240 BPM',
      accentColor: EatsTheme.primaryCyan,
      onResetDefault: () => dawState.setBpm(120.0),
      onSubmit: (text) {
        final val = double.tryParse(text);
        if (val != null) {
          dawState.setBpm(val);
        }
      },
    );
  }

  Widget _buildHubActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom EatsBeats Monster Icon Widget
class EatsBeatsMonsterIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? eyeColor;
  final bool isBadge;

  const EatsBeatsMonsterIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.backgroundColor,
    this.iconColor,
    this.eyeColor,
    this.isBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isBadge || backgroundColor != null) {
      final effectiveBg = backgroundColor ?? EatsTheme.primaryCyan;
      final effectiveIcon = iconColor ?? Colors.black;
      final effectiveEye = eyeColor ?? effectiveBg;

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: CustomPaint(
            size: Size(size * 0.85, size * 0.85),
            painter: _EatsBeatsMonsterPainter(
              bodyColor: effectiveIcon,
              eyeColor: effectiveEye,
            ),
          ),
        ),
      );
    } else {
      final effectiveColor = color ?? EatsTheme.primaryCyan;
      final effectiveEye = eyeColor ?? (EatsTheme.isLight ? Colors.white : EatsTheme.backgroundDark);

      return Container(
        width: size,
        height: size,
        color: Colors.transparent,
        child: Center(
          child: CustomPaint(
            size: Size(size * 0.9, size * 0.9),
            painter: _EatsBeatsMonsterPainter(
              bodyColor: effectiveColor,
              eyeColor: effectiveEye,
            ),
          ),
        ),
      );
    }
  }
}

class _EatsBeatsMonsterPainter extends CustomPainter {
  final Color bodyColor;
  final Color eyeColor;

  _EatsBeatsMonsterPainter({
    required this.bodyColor,
    required this.eyeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    // Monster head & open mouth
    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.15);
    path.lineTo(size.width * 0.75, size.height * 0.15);
    path.lineTo(size.width * 0.75, size.height * 0.42);
    path.lineTo(size.width * 0.4, size.height * 0.42);
    path.lineTo(size.width * 0.4, size.height * 0.68);
    path.lineTo(size.width * 0.75, size.height * 0.68);
    path.lineTo(size.width * 0.75, size.height * 0.85);
    path.lineTo(size.width * 0.15, size.height * 0.85);
    path.close();
    canvas.drawPath(path, paint);

    // Eye
    final eyePaint = Paint()..color = eyeColor;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.28), size.width * 0.08, eyePaint);

    // Eating bits
    final bitPaint = Paint()..color = bodyColor;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.82, size.height * 0.45, size.width * 0.12, size.width * 0.12), bitPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.82, size.height * 0.65, size.width * 0.1, size.width * 0.1), bitPaint);
  }

  @override
  bool shouldRepaint(covariant _EatsBeatsMonsterPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor || oldDelegate.eyeColor != eyeColor;
  }
}

// Vector Canvas Transport Symbols (Zero Font Dependency)
enum TransportSymbol { play, pause, stop, record }

class TransportSymbolWidget extends StatelessWidget {
  final TransportSymbol symbol;
  final Color color;
  final double size;

  const TransportSymbolWidget({
    super.key,
    required this.symbol,
    required this.color,
    this.size = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TransportSymbolPainter(symbol: symbol, color: color),
      ),
    );
  }
}

class _TransportSymbolPainter extends CustomPainter {
  final TransportSymbol symbol;
  final Color color;

  _TransportSymbolPainter({required this.symbol, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    switch (symbol) {
      case TransportSymbol.play:
        // Triangle pointing right
        final path = Path()
          ..moveTo(w * 0.15, h * 0.05)
          ..lineTo(w * 0.90, h * 0.50)
          ..lineTo(w * 0.15, h * 0.95)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case TransportSymbol.pause:
        // Two vertical bars
        final barW = w * 0.32;
        final gap = w * 0.22;
        final rRect1 = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.05, h * 0.05, barW, h * 0.90),
          const Radius.circular(1.5),
        );
        final rRect2 = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.05 + barW + gap, h * 0.05, barW, h * 0.90),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(rRect1, paint);
        canvas.drawRRect(rRect2, paint);
        break;

      case TransportSymbol.stop:
        // Rounded square
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.84),
          const Radius.circular(2.0),
        );
        canvas.drawRRect(rect, paint);
        break;

      case TransportSymbol.record:
        // Solid circle
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.44, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TransportSymbolPainter oldDelegate) {
    return oldDelegate.symbol != symbol || oldDelegate.color != color;
  }
}
