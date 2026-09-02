import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';
import '../../services/gemini_service.dart';
import '../../services/ai_mixing_engine.dart';
import '../../lua/lua_script_library.dart';
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

  bool _isTestingKey = false;
  ConnectionTestResult? _testResult;
  bool _isProcessingMix = false;
  AiMixResult? _lastMixResult;

  bool _isGeneratingSound = false;
  String _generatedLuaCode = '';
  String _soundCategory = 'instrument'; // 'instrument' or 'audio_fx'

  String _selectedGenre = 'Lo-Fi Chill';
  double _selectedTargetLufs = -14.0;

  final List<String> _genreOptions = [
    'Lo-Fi Chill',
    'Modern Trap / Hip-Hop',
    'Synthwave / Retrowave',
    'EDM / Club House',
    'Acoustic / Folk',
    'Neo-Soul / R&B',
    'Cyberpunk / Industrial',
    'Custom / Neutral',
  ];

  final Map<String, double> _lufsPresets = {
    'Streaming (-14 LUFS)': -14.0,
    'Club & EDM (-9 LUFS)': -9.0,
    'Broadcast & TV (-16 LUFS)': -16.0,
    'Dynamic Audiophile (-18 LUFS)': -18.0,
  };

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _apiKeyController.text = GeminiService.apiKey;
    _selectedTargetLufs = widget.dawState.masterTargetLufs;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _mixInstructionsController.dispose();
    _soundPromptController.dispose();
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
        width: 580,
        height: 600,
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

            // Tab Buttons
            Row(
              children: [
                _buildTabButton(0, 'MIX & MASTER', Icons.equalizer),
                const SizedBox(width: 6),
                _buildTabButton(1, 'SOUND ARCHITECT', Icons.graphic_eq),
                const SizedBox(width: 6),
                _buildTabButton(2, 'AI SETTINGS (BYOK)', Icons.key),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _activeTab == 0
                  ? _buildMixMasterTab()
                  : (_activeTab == 1 ? _buildSoundArchitectTab() : _buildSettingsTab()),
            ),
          ],
        ),
      ),
    );
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

          // Action Button
          SkeuomorphicHardwareButton(
            label: _isProcessingMix ? 'ANALYZING & POLISHING...' : '✨ ANALYZE & EXECUTE AI MIX/MASTER',
            isActive: true,
            activeColor: EatsTheme.primaryCyan,
            height: 40,
            onTap: _isProcessingMix ? () {} : _runMixMaster,
          ),
          const SizedBox(height: 14),

          // Results feedback card
          if (_lastMixResult != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lastMixResult!.success ? EatsTheme.primaryCyan.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _lastMixResult!.success ? EatsTheme.primaryCyan.withOpacity(0.4) : Colors.red.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lastMixResult!.success ? Icons.check_circle : Icons.error,
                        color: _lastMixResult!.success ? EatsTheme.primaryCyan : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _lastMixResult!.success ? 'MASTERING APPLIED (${_lastMixResult!.tracksAdjusted} Tracks Polished)' : 'MIXING FAILED',
                        style: TextStyle(
                          color: _lastMixResult!.success ? EatsTheme.primaryCyan : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lastMixResult!.summary,
                    style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runMixMaster() async {
    setState(() {
      _isProcessingMix = true;
      _lastMixResult = null;
    });

    final result = await AiMixingEngine.runAutoMixMaster(
      dawState: widget.dawState,
      genre: _selectedGenre,
      targetLufs: _selectedTargetLufs,
      customInstructions: _mixInstructionsController.text,
    );

    if (mounted) {
      setState(() {
        _isProcessingMix = false;
        _lastMixResult = result;
      });
    }
  }

  // ── Tab 2: Sound Architect ─────────────────────────────────────────────────

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
                  ? 'e.g. Fat acid 303 sub bass with resonant filter and glide...'
                  : 'e.g. Vintage 1970s tape flutter and warm overdrive with tone control...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
              filled: true,
              fillColor: EatsTheme.controlBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 12),

          SkeuomorphicHardwareButton(
            label: _isGeneratingSound ? 'GENERATING DSP CODE...' : '⚡ GENERATE SOUND & APPLY TO TRACK',
            isActive: true,
            activeColor: EatsTheme.primaryCyan,
            height: 38,
            onTap: _isGeneratingSound ? () {} : _generateSound,
          ),
          const SizedBox(height: 12),

          if (_generatedLuaCode.isNotEmpty) ...[
            Text('GENERATED LUA DSP SCRIPT:', style: TextStyle(color: EatsTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              height: 160,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F141C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _generatedLuaCode,
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Color(0xFF00FF66)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateSound() async {
    final prompt = _soundPromptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGeneratingSound = true;
      _generatedLuaCode = '';
    });

    try {
      String luaCode = '';
      if (_soundCategory == 'instrument') {
        luaCode = await GeminiService.generateInstrumentScript(prompt: prompt);
        final scriptDef = LuaScriptLibrary.parseFromLuaScript(luaCode);
        widget.dawState.applyPreset(scriptDef, targetTrack: widget.dawState.activeTrack);
      } else {
        luaCode = await GeminiService.generateAudioFxScript(prompt: prompt);
        final scriptDef = LuaScriptLibrary.parseFromLuaScript(luaCode);
        widget.dawState.addAudioFXFromPreset(widget.dawState.activeTrack, scriptDef);
      }

      if (mounted) {
        setState(() {
          _isGeneratingSound = false;
          _generatedLuaCode = luaCode;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingSound = false;
          _generatedLuaCode = '-- Error generating sound: $e';
        });
      }
    }
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
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Eatsbeats connects directly to Google AI Studio from your device. Your API key is stored locally and never shared with third parties.',
                  style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
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
                    setState(() => _testResult = null);
                  },
                ),
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
                Row(
                  children: [
                    SkeuomorphicHardwareButton(
                      label: _isTestingKey ? 'TESTING...' : 'TEST KEY CONNECTION',
                      isActive: true,
                      activeColor: EatsTheme.primaryCyan,
                      height: 28,
                      width: 160,
                      onTap: _testApiKey,
                    ),
                  ],
                ),
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
    GeminiService.apiKey = _apiKeyController.text.trim();
    setState(() {
      _isTestingKey = true;
      _testResult = null;
    });

    final result = await GeminiService.testConnection();
    if (mounted) {
      setState(() {
        _isTestingKey = false;
        _testResult = result;
      });
    }
  }
}
