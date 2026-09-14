import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../audio/procgen/ensemble_blueprint.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import '../../services/gemini_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/ai_mixing_engine.dart';
import '../../services/ai_task_manager.dart';
import '../../eatscript/eat_script_library.dart';
import '../../utils/eats_storage_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'skeuomorphic_hardware_button.dart';

/// Interactive modal for Gemini AI mixing, mastering, and sound architecture.
class AiAssistantDialog extends StatefulWidget {
  final DawState dawState;
  final int initialTab;

  const AiAssistantDialog({
    super.key,
    required this.dawState,
    this.initialTab = 0,
  });

  static Future<void> show(BuildContext context, DawState dawState, {int initialTab = 0}) {
    return showDialog(
      context: context,
      builder: (ctx) => AiAssistantDialog(dawState: dawState, initialTab: initialTab),
    );
  }

  @override
  State<AiAssistantDialog> createState() => _AiAssistantDialogState();
}

class _AiAssistantDialogState extends State<AiAssistantDialog> {
  late int _activeTab;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _mixInstructionsController = TextEditingController();
  final TextEditingController _soundPromptController = TextEditingController();
  final TextEditingController _songPromptController = TextEditingController();

  bool _isTestingKey = false;
  ConnectionTestResult? _testResult;

  String _soundCategory = 'instrument'; // 'instrument' or 'audio_fx'

  String _selectedGenre = 'Lo-Fi Chill';
  double _selectedTargetLufs = -14.0;

  final List<String> _genreOptions = [
    'Lo-Fi Chill',
    'Synthwave / Chiptune',
    'Cyberpunk EDM',
    'Ambient Cinematic',
    'Rock / Metal',
    'Jazz / Acoustic',
  ];

  final Map<String, double> _lufsPresets = {
    'Streaming (-14 LUFS)': -14.0,
    'Club & EDM (-9 LUFS)': -9.0,
    'Broadcast & TV (-16 LUFS)': -16.0,
    'Dynamic Audiophile (-18 LUFS)': -18.0,
  };

  final ScrollController _songArchitectScrollController = ScrollController();
  bool _isGeneratingMagicPrompt = false;

  bool _isKeyStored = false;
  bool _rememberKeyOnDevice = false;
  String? _deleteFeedback;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _apiKeyController.text = GeminiService.apiKey;
    _selectedTargetLufs = widget.dawState.masterTargetLufs;
    _initStorageStatus();
    AiTaskManager.instance.addListener(_onAiTaskManagerChanged);
  }

  Future<void> _initStorageStatus() async {
    final isStored = await SecureStorageService.isGeminiApiKeyStored();
    final remember = await SecureStorageService.getWebRememberPreference();
    if (mounted) {
      setState(() {
        _isKeyStored = isStored;
        _rememberKeyOnDevice = remember;
      });
    }
  }

  Future<void> _deleteApiKey() async {
    await GeminiService.deleteApiKey();
    _apiKeyController.clear();
    if (mounted) {
      setState(() {
        _isKeyStored = false;
        _testResult = null;
        _deleteFeedback = 'Stored API key removed from storage and memory.';
      });
    }
  }

  void _onAiTaskManagerChanged() {
    if (!mounted) return;
    final mgr = AiTaskManager.instance;
    if (_activeTab == 1 && mgr.status == AiTaskStatus.readyForReview && mgr.taskType == AiTaskType.songArrangement) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_songArchitectScrollController.hasClients) {
          _songArchitectScrollController.animateTo(
            _songArchitectScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _generateMagicPrompt() async {
    if (_isGeneratingMagicPrompt) return;
    setState(() => _isGeneratingMagicPrompt = true);
    try {
      final prompt = await GeminiService.generateMagicPrompt();
      if (mounted) {
        setState(() {
          _songPromptController.text = prompt;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingMagicPrompt = false);
      }
    }
  }

  @override
  void dispose() {
    AiTaskManager.instance.removeListener(_onAiTaskManagerChanged);
    _apiKeyController.dispose();
    _mixInstructionsController.dispose();
    _soundPromptController.dispose();
    _songPromptController.dispose();
    _songArchitectScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EatsTheme.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.8), width: 1.5),
      ),
      child: Container(
        width: 620,
        height: 640,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.auto_awesome, color: EatsTheme.primaryCyan, size: 22),
                const SizedBox(width: 8),
                Text(
                  'GEMINI AI ASSISTANT',
                  style: TextStyle(
                    color: EatsTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: EatsTheme.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tab Buttons (4 Tabs)
            Row(
              children: [
                _buildTabButton(0, 'MIX & MASTER', Icons.equalizer),
                const SizedBox(width: 4),
                _buildTabButton(1, 'SONG ARCHITECT', Icons.library_music),
                const SizedBox(width: 4),
                _buildTabButton(2, 'SOUND ARCHITECT', Icons.graphic_eq),
                const SizedBox(width: 4),
                _buildTabButton(3, 'AI SETTINGS', Icons.key),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _buildActiveTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildMixMasterTab();
      case 1:
        return _buildSongArchitectTab();
      case 2:
        return _buildSoundArchitectTab();
      case 3:
      default:
        return _buildSettingsTab();
    }
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isActive = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? EatsTheme.primaryCyan.withOpacity(0.15) : EatsTheme.controlBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? EatsTheme.primaryCyan : Colors.white10,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isActive ? EatsTheme.primaryCyan : EatsTheme.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? EatsTheme.primaryCyan : EatsTheme.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 1: Mix & Master ────────────────────────────────────────────────────

  Widget _buildMixMasterTab() {
    if (!GeminiService.hasApiKey) {
      return _buildKeyRequiredBanner();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Target Loudness Selector
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TARGET LOUDNESS', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: EatsTheme.controlBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButton<double>(
                        value: _selectedTargetLufs,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: EatsTheme.panelBackground,
                        items: _lufsPresets.entries.map((e) {
                          return DropdownMenuItem<double>(
                            value: e.value,
                            child: Text(e.key, style: const TextStyle(fontSize: 12, color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTargetLufs = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GENRE VIBE', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: EatsTheme.controlBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedGenre,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: EatsTheme.panelBackground,
                        items: _genreOptions.map((g) {
                          return DropdownMenuItem<String>(
                            value: g,
                            child: Text(g, style: const TextStyle(fontSize: 12, color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGenre = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custom Instructions
          Text('PRODUCER INSTRUCTIONS (OPTIONAL)', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: _mixInstructionsController,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Make the snare punchier, give the acoustic guitar space, keep 808 tight...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
              filled: true,
              fillColor: EatsTheme.controlBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 14),

          // Action Button & Live Progress
          AnimatedBuilder(
            animation: AiTaskManager.instance,
            builder: (context, _) {
              final mgr = AiTaskManager.instance;
              if (mgr.isRunning && mgr.taskType == AiTaskType.mixAndMaster) {
                final seconds = (mgr.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EatsTheme.primaryCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(EatsTheme.primaryCyan),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Analyzing track telemetry & mastering... (${seconds}s)',
                          style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SkeuomorphicHardwareButton(
                        label: 'CANCEL',
                        isActive: true,
                        activeColor: Colors.redAccent,
                        height: 26,
                        width: 70,
                        onTap: () => mgr.cancelActiveTask(),
                      ),
                    ],
                  ),
                );
              }

              return SkeuomorphicHardwareButton(
                label: '✨ ANALYZE & PREPARE AI MIX/MASTER',
                isActive: true,
                activeColor: EatsTheme.primaryCyan,
                height: 40,
                onTap: _runMixMaster,
              );
            },
          ),
          const SizedBox(height: 14),

          // Results & Review Approval Card
          AnimatedBuilder(
            animation: AiTaskManager.instance,
            builder: (context, _) {
              final mgr = AiTaskManager.instance;
              if (mgr.status == AiTaskStatus.readyForReview && mgr.taskType == AiTaskType.mixAndMaster && mgr.pendingMixResult != null) {
                final result = mgr.pendingMixResult!;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EatsTheme.primaryCyan.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF00FF66), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'AI MASTER READY FOR REVIEW (${result.tracksAdjusted} Tracks Polished)',
                            style: const TextStyle(
                              color: Color(0xFF00FF66),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.summary,
                        style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SkeuomorphicHardwareButton(
                              label: '✓ APPLY TO PROJECT (UNDOABLE)',
                              isActive: true,
                              activeColor: const Color(0xFF00FF66),
                              height: 34,
                              onTap: () {
                                mgr.applyPendingResult(widget.dawState);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('AI Mix & Master applied successfully. Press Ctrl+Z to undo.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SkeuomorphicHardwareButton(
                            label: 'DISCARD',
                            isActive: true,
                            activeColor: Colors.redAccent,
                            height: 34,
                            width: 80,
                            onTap: () => mgr.discardPendingResult(),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              if (mgr.status == AiTaskStatus.failed && mgr.taskType == AiTaskType.mixAndMaster) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 16),
                          SizedBox(width: 6),
                          Text('MIXING FAILED', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(mgr.errorMessage ?? 'An error occurred.', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _runMixMaster() {
    AiTaskManager.instance.startAutoMix(
      widget.dawState,
      genre: _selectedGenre,
      targetLufs: _selectedTargetLufs,
      customInstructions: _mixInstructionsController.text,
    );
  }

  // ── Tab 2: Song Architect (4-Track Arrangement) ───────────────────────────

  Widget _buildSongArchitectTab() {
    if (!GeminiService.hasApiKey) {
      return _buildKeyRequiredBanner();
    }

    final promptSuggestions = [
      'Medieval fantasy adventure with Spanish guitar, grand piano, and vibraphone (Ultima VI)',
      'RPG tavern waltz with acoustic lute and wooden flute in 3/4',
      'Evolving battle theme starting with solo strings into heavy synth drop',
      'Ambient cavern in D minor with harp, pad, and ocarina',
      'Late night jazz trio with upright bass, warm Rhodes, and vibraphone',
      'C64 8-bit chiptune battle with fast 50Hz arpeggio',
      'Pastoral anime town theme with acoustic guitar and accordion',
    ];

    return SingleChildScrollView(
      controller: _songArchitectScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: EatsTheme.controlBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: EatsTheme.primaryCyan, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI SONG ARCHITECT & DYNAMIC ENSEMBLE',
                        style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Describe your musical vision. Gemini designs the custom ensemble (2 to 8+ tracks), harmonic progression, meter (3/4, 4/4, 6/8), and section flow with dynamic builds and dropouts, then renders directly into the DAW.',
                        style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (widget.dawState.songBlueprint != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EatsTheme.primaryCyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.style, color: EatsTheme.primaryCyan, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'PROJECT STYLE ARCHITECTURE (SAVED IN .EAT)',
                          style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: EatsTheme.primaryCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Seed #${widget.dawState.songBlueprintSeed ?? 42}',
                          style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.dawState.songBlueprint!.title} • ${widget.dawState.songBlueprint!.bpm.round()} BPM • ${widget.dawState.songBlueprint!.meter} • ${widget.dawState.songBlueprint!.mode.toUpperCase()} • ${widget.dawState.songBlueprint!.ensemble.length} Tracks • ${widget.dawState.songBlueprint!.totalBars} Bars',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SkeuomorphicHardwareButton(
                          label: '🎲 RE-SEED / NEW VARIATION',
                          isActive: true,
                          activeColor: EatsTheme.primaryCyan,
                          height: 30,
                          onTap: () {
                            final newSeed = (DateTime.now().microsecondsSinceEpoch % 900000) + 100000;
                            widget.dawState.regenerateFromSongBlueprint(newSeed: newSeed);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Generated fresh variation of "${widget.dawState.songBlueprint!.title}" with seed #$newSeed! Press Ctrl+Z to undo.'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SkeuomorphicHardwareButton(
                        label: '📋 COPY STYLE',
                        isActive: true,
                        activeColor: Colors.white70,
                        height: 30,
                        width: 95,
                        onTap: () {
                          final jsonStr = const JsonEncoder.withIndent('  ').convert(widget.dawState.songBlueprint!.toJson());
                          Clipboard.setData(ClipboardData(text: jsonStr));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied complete Song Architecture JSON to clipboard! Ready to share or use in prompts.'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Text('PROMPT / MUSICAL VISION:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              const Spacer(),
              _isGeneratingMagicPrompt
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(EatsTheme.primaryCyan)),
                    )
                  : InkWell(
                      onTap: _generateMagicPrompt,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, color: EatsTheme.primaryCyan, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '✨ MAGIC PROMPT',
                              style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _songPromptController,
            maxLines: 3,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Describe anything: mood, instruments (lute, flute, cello, synth...), tempo, meter (e.g. 3/4 waltz), key, or chord suggestions...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
              filled: true,
              fillColor: EatsTheme.controlBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: promptSuggestions.map((s) {
              return ActionChip(
                backgroundColor: EatsTheme.controlBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                label: Text(s, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                onPressed: () {
                  setState(() {
                    _songPromptController.text = s;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: AiTaskManager.instance,
            builder: (context, _) {
              final mgr = AiTaskManager.instance;
              final isArranging = mgr.isRunning && mgr.taskType == AiTaskType.songArrangement;

              if (isArranging) {
                final seconds = (mgr.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EatsTheme.primaryCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(EatsTheme.primaryCyan)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Composing Song Architecture & Dynamic Arrangement... (${seconds}s)',
                          style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SkeuomorphicHardwareButton(
                        label: 'CANCEL',
                        isActive: true,
                        activeColor: Colors.redAccent,
                        height: 24,
                        width: 65,
                        onTap: () => mgr.cancelActiveTask(),
                      ),
                    ],
                  ),
                );
              }

              return SkeuomorphicHardwareButton(
                label: '⚡ COMPOSE WITH AI SONG ARCHITECT',
                isActive: true,
                activeColor: EatsTheme.primaryCyan,
                height: 38,
                onTap: _generateSong,
              );
            },
          ),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: AiTaskManager.instance,
            builder: (context, _) {
              final mgr = AiTaskManager.instance;
              if (mgr.status == AiTaskStatus.readyForReview &&
                  mgr.taskType == AiTaskType.songArrangement &&
                  (mgr.pendingBlueprint != null || mgr.pendingLuaScript != null)) {
                final bp = mgr.pendingBlueprint;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('GENERATED SONG ARCHITECTURE:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('Ready to Render', style: TextStyle(color: const Color(0xFF00FF66), fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (bp != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F141C),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    bp.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: EatsTheme.primaryCyan.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${bp.bpm.round()} BPM • ${bp.meter} • ${bp.mode.toUpperCase()} • ${bp.totalBars} BARS',
                                    style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ENSEMBLE (${bp.ensemble.length} TRACKS):',
                              style: TextStyle(color: EatsTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: bp.ensemble.map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(t.colorHex).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Color(t.colorHex).withOpacity(0.6)),
                                  ),
                                  child: Text(
                                    '${t.name} (${t.role.name})',
                                    style: TextStyle(color: Color(t.colorHex), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SECTIONS (${bp.sections.length} PARTS):',
                              style: TextStyle(color: EatsTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: bp.sections.map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${s.name} (${s.lengthBars}b)',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        height: 120,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F141C),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            mgr.pendingLuaScript!,
                            style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Color(0xFF00FF66)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SkeuomorphicHardwareButton(
                            label: '✓ RENDER SONG INTO DAW (UNDOABLE)',
                            isActive: true,
                            activeColor: const Color(0xFF00FF66),
                            height: 32,
                            onTap: () {
                              mgr.applyPendingResult(widget.dawState);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Song generated and rendered successfully into DAW! Press Play to listen.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SkeuomorphicHardwareButton(
                          label: 'DISCARD',
                          isActive: true,
                          activeColor: Colors.redAccent,
                          height: 32,
                          width: 80,
                          onTap: () => mgr.discardPendingResult(),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _generateSong() {
    final prompt = _songPromptController.text.trim();
    if (prompt.isEmpty) return;

    AiTaskManager.instance.startGenerateSong(
      widget.dawState,
      prompt: prompt,
    );
  }

  // ── Tab 3: Sound Architect ─────────────────────────────────────────────────

  Widget _buildSoundArchitectTab() {
    if (!GeminiService.hasApiKey) {
      return _buildKeyRequiredBanner();
    }

    final activeTrack = widget.dawState.activeTrack;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('TARGET TRACK: ${activeTrack.name.toUpperCase()}', style: TextStyle(color: activeTrack.color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Radio<String>(
                    value: 'instrument',
                    groupValue: _soundCategory,
                    activeColor: EatsTheme.primaryCyan,
                    onChanged: (val) => setState(() => _soundCategory = val!),
                  ),
                  const Text('Instrument', style: TextStyle(fontSize: 11, color: Colors.white)),
                  const SizedBox(width: 10),
                  Radio<String>(
                    value: 'audio_fx',
                    groupValue: _soundCategory,
                    activeColor: EatsTheme.primaryCyan,
                    onChanged: (val) => setState(() => _soundCategory = val!),
                  ),
                  const Text('Audio FX', style: TextStyle(fontSize: 11, color: Colors.white)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text('PROMPT SOUND DESIGN:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: _soundPromptController,
            maxLines: 3,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: _soundCategory == 'instrument'
                  ? 'e.g. 80s punchy analog synth bass with lowpass filter and Moog knobs...'
                  : 'e.g. Vintage 1970s tape flutter and warm overdrive with vintage tone knob...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
              filled: true,
              fillColor: EatsTheme.controlBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: AiTaskManager.instance,
            builder: (context, _) {
              final mgr = AiTaskManager.instance;
              final isGenerating = mgr.isRunning && (mgr.taskType == AiTaskType.soundInstrument || mgr.taskType == AiTaskType.soundFx);

              if (isGenerating) {
                final seconds = (mgr.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EatsTheme.primaryCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(EatsTheme.primaryCyan)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Generating DSP Synthesizer & Hardware GUI... (${seconds}s)',
                          style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SkeuomorphicHardwareButton(
                        label: 'CANCEL',
                        isActive: true,
                        activeColor: Colors.redAccent,
                        height: 24,
                        width: 65,
                        onTap: () => mgr.cancelActiveTask(),
                      ),
                    ],
                  ),
                );
              }

              return SkeuomorphicHardwareButton(
                label: '⚡ GENERATE SOUND & HARDWARE GUI',
                isActive: true,
                activeColor: EatsTheme.primaryCyan,
                height: 38,
                onTap: _generateSound,
              );
            },
          ),
          const SizedBox(height: 12),

          AnimatedBuilder(
            animation: AiTaskManager.instance,
            builder: (context, _) {
              final mgr = AiTaskManager.instance;
              if (mgr.status == AiTaskStatus.readyForReview && (mgr.taskType == AiTaskType.soundInstrument || mgr.taskType == AiTaskType.soundFx) && mgr.pendingLuaScript != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('GENERATED LUA DSP & GUI SCRIPT:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('Ready to Apply', style: TextStyle(color: const Color(0xFF00FF66), fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 150,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141C),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          mgr.pendingLuaScript!,
                          style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Color(0xFF00FF66)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SkeuomorphicHardwareButton(
                            label: '✓ APPLY TO ACTIVE TRACK',
                            isActive: true,
                            activeColor: const Color(0xFF00FF66),
                            height: 32,
                            onTap: () {
                              mgr.applyPendingResult(widget.dawState);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Applied to ${widget.dawState.activeTrack.name}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SkeuomorphicHardwareButton(
                          label: 'DISCARD',
                          isActive: true,
                          activeColor: Colors.redAccent,
                          height: 32,
                          width: 80,
                          onTap: () => mgr.discardPendingResult(),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _generateSound() {
    final prompt = _soundPromptController.text.trim();
    if (prompt.isEmpty) return;

    AiTaskManager.instance.startGenerateSound(
      widget.dawState,
      prompt: prompt,
      category: _soundCategory,
      targetTrack: widget.dawState.activeTrack,
    );
  }

  // ── Tab 3: API Settings (BYOK) ─────────────────────────────────────────────

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EatsTheme.controlBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: EatsTheme.primaryCyan),
                    const SizedBox(width: 6),
                    Text('GOOGLE GEMINI API KEY (FREE)', style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _buildStorageStatusBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  kIsWeb
                      ? 'Eatsbeats connects directly to Google AI Studio from your browser. In-memory for this session by default.'
                      : 'Eatsbeats connects directly to Google AI Studio from your device. Keys are saved in your OS Credential Manager / Keychain.',
                  style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF0F141C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (val) {
                    GeminiService.apiKey = val;
                    setState(() {
                      _testResult = null;
                      _deleteFeedback = null;
                    });
                  },
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: _rememberKeyOnDevice,
                          activeColor: EatsTheme.primaryCyan,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) async {
                            final checked = val ?? false;
                            setState(() => _rememberKeyOnDevice = checked);
                            await SecureStorageService.setWebRememberPreference(checked);
                            if (checked && _apiKeyController.text.trim().isNotEmpty) {
                              await GeminiService.persistApiKey(_apiKeyController.text.trim());
                              setState(() => _isKeyStored = true);
                            } else if (!checked) {
                              await SecureStorageService.deleteGeminiApiKey();
                              setState(() => _isKeyStored = false);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Remember key in this browser (⚠️ Do NOT enable on public or shared computers)',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Text('ACTIVE GEMINI MODEL:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F141C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButton<String>(
                    value: GeminiService.availableModels.contains(GeminiService.activeModel) ? GeminiService.activeModel : GeminiService.availableModels.first,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: EatsTheme.panelBackground,
                    items: GeminiService.availableModels.map((m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 12, color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          GeminiService.activeModel = val;
                          _testResult = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SkeuomorphicHardwareButton(
                      label: _isTestingKey ? 'TESTING...' : 'TEST KEY CONNECTION',
                      isActive: true,
                      activeColor: EatsTheme.primaryCyan,
                      height: 28,
                      width: 160,
                      onTap: _testApiKey,
                    ),
                    if (_isKeyStored || GeminiService.hasApiKey || _apiKeyController.text.isNotEmpty)
                      SkeuomorphicHardwareButton(
                        label: 'DELETE STORED KEY',
                        isActive: true,
                        activeColor: Colors.redAccent,
                        height: 28,
                        width: 155,
                        onTap: _deleteApiKey,
                      ),
                    if (!kIsWeb)
                      SkeuomorphicHardwareButton(
                        label: 'OPEN SETTINGS FOLDER',
                        isActive: true,
                        activeColor: EatsTheme.textSecondary,
                        height: 28,
                        width: 175,
                        onTap: () async {
                          await EatsStorageHelper.openSettingsFolder();
                        },
                      ),
                  ],
                ),
                if (_deleteFeedback != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _deleteFeedback!,
                            style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_testResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _testResult!.isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _testResult!.isSuccess ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _testResult!.isSuccess ? Icons.check_circle : Icons.error_outline,
                          color: _testResult!.isSuccess ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _testResult!.message,
                            style: TextStyle(
                              color: _testResult!.isSuccess ? Colors.green : Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // How to get key instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EatsTheme.controlBackground.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOW TO GET A FREE GEMINI API KEY:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    try {
                      launchUrl(Uri.parse('https://aistudio.google.com/api-keys'), mode: LaunchMode.externalApplication);
                    } catch (e) {
                      debugPrint('Could not launch URL: $e');
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: EatsTheme.primaryCyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new, size: 14, color: EatsTheme.primaryCyan),
                        const SizedBox(width: 6),
                        Text(
                          'https://aistudio.google.com/api-keys',
                          style: TextStyle(
                            color: EatsTheme.primaryCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Click the link above to open Google AI Studio\n2. Sign in with any standard Google account\n3. Click "Create API Key" (or copy existing key)\n4. Paste your key above and click "Test Key Connection".\n\nNote: Brand new Google AI keys may take 30–60 seconds to propagate globally across Google servers.',
                  style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageStatusBadge() {
    String label;
    Color color;
    IconData icon;

    if (GeminiService.keySource == GeminiKeySource.environment) {
      label = 'ENV VAR';
      color = EatsTheme.primaryCyan;
      icon = Icons.terminal;
    } else if (GeminiService.keySource == GeminiKeySource.settingsFile) {
      label = 'SETTINGS FILE';
      color = const Color(0xFF64B5F6);
      icon = Icons.description_outlined;
    } else if (_isKeyStored) {
      label = kIsWeb ? 'BROWSER' : 'SECURE VAULT';
      color = Colors.green;
      icon = Icons.shield_outlined;
    } else if (GeminiService.hasApiKey) {
      label = 'SESSION ONLY';
      color = Colors.amber;
      icon = Icons.schedule;
    } else {
      label = 'NOT CONFIGURED';
      color = Colors.white38;
      icon = Icons.key_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRequiredBanner() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.vpn_key_outlined, size: 40, color: EatsTheme.primaryCyan.withOpacity(0.6)),
          const SizedBox(height: 12),
          Text('Gemini API Key Required', style: TextStyle(color: EatsTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'To enable AI Mixing, Mastering, and Sound Generation,\nconfigure your free Google AI Studio key.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
          ),
          const SizedBox(height: 16),
          SkeuomorphicHardwareButton(
            label: 'GO TO API SETTINGS',
            isActive: true,
            activeColor: EatsTheme.primaryCyan,
            height: 32,
            width: 180,
            onTap: () => setState(() => _activeTab = 2),
          ),
        ],
      ),
    );
  }

  Future<void> _testApiKey() async {
    final key = _apiKeyController.text.trim();
    GeminiService.apiKey = key;
    setState(() {
      _isTestingKey = true;
      _testResult = null;
      _deleteFeedback = null;
    });

    final result = await GeminiService.testConnection();
    if (result.isSuccess) {
      if (!kIsWeb || _rememberKeyOnDevice) {
        await GeminiService.persistApiKey(key);
        _isKeyStored = true;
      }
    }
    if (mounted) {
      setState(() {
        _isTestingKey = false;
        _testResult = result;
      });
    }
  }
}
