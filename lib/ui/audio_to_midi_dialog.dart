import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../audio/audio_to_midi_engine.dart';
import '../audio/sampler_engine.dart';
import '../models/daw_state.dart';
import '../theme/eats_theme.dart';
import '../utils/audio_to_midi_pack_manager.dart';

class AudioToMidiDialog extends StatefulWidget {
  final DawState dawState;
  final DecodedAudioBuffer? initialAudioBuffer;
  final String? initialFileName;

  const AudioToMidiDialog({
    super.key,
    required this.dawState,
    this.initialAudioBuffer,
    this.initialFileName,
  });

  static Future<void> show(
    BuildContext context,
    DawState dawState, {
    DecodedAudioBuffer? initialAudioBuffer,
    String? initialFileName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AudioToMidiDialog(
        dawState: dawState,
        initialAudioBuffer: initialAudioBuffer,
        initialFileName: initialFileName,
      ),
    );
  }

  @override
  State<AudioToMidiDialog> createState() => _AudioToMidiDialogState();
}

class _AudioToMidiDialogState extends State<AudioToMidiDialog> {
  final AudioToMidiPackManager _packManager = AudioToMidiPackManager.instance;

  DecodedAudioBuffer? _audioBuffer;
  String _audioFileName = '';
  WaveformOverview? _waveform;

  // Options
  TranscriptionEngineMode _mode = TranscriptionEngineMode.hybridDsp;
  double _onsetThreshold = 0.45;
  double _frameThreshold = 0.35;
  double _minNoteDurationMs = 70.0;
  double _velocitySensitivity = 1.0;
  bool _enablePitchBend = false;
  bool _createNewTrack = true;
  String _trackName = '';

  bool _isProcessing = false;
  double _processProgress = 0.0;
  String _processStatus = '';

  @override
  void initState() {
    super.initState();
    _packManager.restoreDownloadedStatus();
    _packManager.addListener(_onPackManagerUpdate);

    if (widget.initialAudioBuffer != null) {
      _audioBuffer = widget.initialAudioBuffer;
      _audioFileName = widget.initialFileName ?? 'Selected Audio Clip';
      _waveform = WaveformOverview.generate(_audioBuffer!.samples, 128);
      _trackName = _audioFileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '') + ' (MIDI)';
    }
  }

  @override
  void dispose() {
    _packManager.removeListener(_onPackManagerUpdate);
    super.dispose();
  }

  void _onPackManagerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'ogg', 'flac', 'aiff', 'aif'],
      );

      if (result.isNotEmpty) {
        final picked = result.first;
        Uint8List? bytes;

        if (picked.path != null && !kIsWeb) {
          final f = io.File(picked.path!);
          if (await f.exists()) {
            bytes = await f.readAsBytes();
          }
        }

        if (bytes != null && bytes.isNotEmpty) {
          final decoded = SamplerEngine.decodeWav(bytes);
          if (decoded != null) {
            setState(() {
              _audioBuffer = decoded;
              _audioFileName = picked.name;
              _waveform = WaveformOverview.generate(decoded.samples, 128);
              _trackName = picked.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '') + ' (MIDI)';
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not decode audio file (must be PCM WAV format)')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioToMidiDialog] Error picking file: $e');
    }
  }

  Future<void> _runTranscription() async {
    if (_audioBuffer == null) return;

    setState(() {
      _isProcessing = true;
      _processProgress = 0.0;
      _processStatus = 'Preparing transcription engine...';
    });

    final options = AudioToMidiOptions(
      mode: _mode,
      onsetThreshold: _onsetThreshold,
      frameThreshold: _frameThreshold,
      minNoteDurationMs: _minNoteDurationMs,
      velocitySensitivity: _velocitySensitivity,
      enablePitchBend: _enablePitchBend,
      targetBpm: widget.dawState.bpm,
    );

    try {
      final parsedTrack = await widget.dawState.transcribeAudioToMidi(
        _audioBuffer!,
        options: options,
        targetTrackId: widget.dawState.activeTrack.id,
        createNewTrack: _createNewTrack,
        customTrackName: _trackName.isNotEmpty ? _trackName : 'Transcribed Audio',
        onProgress: (p, msg) {
          if (mounted) {
            setState(() {
              _processProgress = p;
              _processStatus = msg;
            });
          }
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: EatsTheme.primaryCyan,
            content: Text(
              'Transcribed ${parsedTrack.notes.length} MIDI notes successfully into "${_createNewTrack ? parsedTrack.name : widget.dawState.activeTrack.name}"!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processStatus = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final neuralPack = _packManager.packs.firstWhere(
      (p) => p.id == 'basic_pitch_neural',
      orElse: () => _packManager.packs.first,
    );

    return Dialog(
      backgroundColor: const Color(0xFF16181E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: EatsTheme.primaryCyan.withOpacity(0.4), width: 1.5),
      ),
      child: Container(
        width: 640,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EatsTheme.primaryCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.transform, color: EatsTheme.primaryCyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Audio to MIDI Transcription',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Convert recorded vocals, melodies, and chords into editable MIDI notes',
                          style: TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Audio Source Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.audio_file, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _audioBuffer != null ? _audioFileName : 'No audio selected',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EatsTheme.controlBackground,
                            foregroundColor: EatsTheme.primaryCyan,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: _isProcessing ? null : _pickAudioFile,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: Text(_audioBuffer == null ? 'Select Audio File' : 'Change File'),
                        ),
                      ],
                    ),
                    if (_audioBuffer != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Duration: ${(_audioBuffer!.samples.length / _audioBuffer!.sampleRate / _audioBuffer!.channels).toStringAsFixed(2)}s  •  Sample Rate: ${_audioBuffer!.sampleRate} Hz  •  Channels: ${_audioBuffer!.channels}',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      // Mini Waveform Preview
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: CustomPaint(
                          painter: _MiniWaveformPainter(waveform: _waveform),
                          child: Container(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Engine Selection
              Text(
                'TRANSCRIPTION ENGINE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EatsTheme.primaryCyan, letterSpacing: 1.1),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildEngineOption(
                      title: 'Fast DSP Polyphonic',
                      subtitle: 'Instant • 0 MB download',
                      mode: TranscriptionEngineMode.hybridDsp,
                      isSelected: _mode == TranscriptionEngineMode.hybridDsp,
                      onTap: () => setState(() => _mode = TranscriptionEngineMode.hybridDsp),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildEngineOption(
                      title: 'Basic Pitch Neural AI',
                      subtitle: neuralPack.isDownloaded ? 'Installed (~18 MB)' : 'Requires Download',
                      mode: TranscriptionEngineMode.basicPitchNeural,
                      isSelected: _mode == TranscriptionEngineMode.basicPitchNeural,
                      isInstalled: neuralPack.isDownloaded,
                      onTap: () => setState(() => _mode = TranscriptionEngineMode.basicPitchNeural),
                    ),
                  ),
                ],
              ),

              // Neural Pack Download Banner if selected and not downloaded
              if (_mode == TranscriptionEngineMode.basicPitchNeural && !neuralPack.isDownloaded) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.download, color: Colors.purpleAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Download Basic Pitch AI Model (~18 MB)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  neuralPack.statusMessage.isNotEmpty
                                      ? neuralPack.statusMessage
                                      : 'Deep-learning CNN polyphonic transcription model by Spotify.',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (neuralPack.isDownloading)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () => _packManager.downloadPack(neuralPack.id),
                              child: const Text('Download', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                        ],
                      ),
                      if (neuralPack.isDownloading) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: neuralPack.downloadProgress > 0 ? neuralPack.downloadProgress : null,
                            backgroundColor: Colors.black38,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Parameters & Sensitivity Controls
              Text(
                'DETECTION SENSITIVITY & TUNING',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EatsTheme.primaryCyan, letterSpacing: 1.1),
              ),
              const SizedBox(height: 8),

              // Onset Threshold Slider
              _buildSliderRow(
                label: 'Note Attack Sensitivity (Onset)',
                value: _onsetThreshold,
                min: 0.1,
                max: 0.9,
                displayValue: '${(_onsetThreshold * 100).toInt()}%',
                onChanged: (v) => setState(() => _onsetThreshold = v),
              ),

              // Frame / Sustain Threshold Slider
              _buildSliderRow(
                label: 'Sustain Sensitivity (Frame)',
                value: _frameThreshold,
                min: 0.1,
                max: 0.9,
                displayValue: '${(_frameThreshold * 100).toInt()}%',
                onChanged: (v) => setState(() => _frameThreshold = v),
              ),

              // Min Note Duration Slider
              _buildSliderRow(
                label: 'Min Note Length',
                value: _minNoteDurationMs,
                min: 30.0,
                max: 250.0,
                displayValue: '${_minNoteDurationMs.toInt()} ms',
                onChanged: (v) => setState(() => _minNoteDurationMs = v),
              ),

              // Velocity Sensitivity
              _buildSliderRow(
                label: 'Velocity Scaling',
                value: _velocitySensitivity,
                min: 0.5,
                max: 2.0,
                displayValue: '${_velocitySensitivity.toStringAsFixed(1)}x',
                onChanged: (v) => setState(() => _velocitySensitivity = v),
              ),

              const SizedBox(height: 8),
              // Pitch Bend Toggle & Target Track Row
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pitch Bend & Vibrato', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      value: _enablePitchBend,
                      activeColor: EatsTheme.primaryCyan,
                      checkColor: Colors.black,
                      onChanged: (v) => setState(() => _enablePitchBend = v ?? false),
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Create New Track', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      value: _createNewTrack,
                      activeColor: EatsTheme.primaryCyan,
                      checkColor: Colors.black,
                      onChanged: (v) => setState(() => _createNewTrack = v ?? true),
                    ),
                  ),
                ],
              ),

              // Destination Track Name
              if (_createNewTrack) ...[
                const SizedBox(height: 8),
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'New Track Name',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  controller: TextEditingController(text: _trackName)..selection = TextSelection.collapsed(offset: _trackName.length),
                  onChanged: (v) => _trackName = v,
                ),
              ],

              // Processing Status & Progress Bar
              if (_isProcessing) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _processProgress > 0 ? _processProgress : null,
                    backgroundColor: Colors.black38,
                    valueColor: AlwaysStoppedAnimation<Color>(EatsTheme.primaryCyan),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _processStatus,
                  style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EatsTheme.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: (_audioBuffer == null || _isProcessing) ? null : _runTranscription,
                    icon: const Icon(Icons.music_note, size: 18),
                    label: const Text(
                      'Transcribe to MIDI',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngineOption({
    required String title,
    required String subtitle,
    required TranscriptionEngineMode mode,
    required bool isSelected,
    bool isInstalled = true,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isProcessing ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? EatsTheme.primaryCyan.withOpacity(0.12) : Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? EatsTheme.primaryCyan : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? EatsTheme.primaryCyan : Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? EatsTheme.primaryCyan : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: EatsTheme.primaryCyan,
                inactiveTrackColor: Colors.white12,
                thumbColor: EatsTheme.primaryCyan,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: _isProcessing ? null : onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              displayValue,
              style: TextStyle(color: EatsTheme.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniWaveformPainter extends CustomPainter {
  final WaveformOverview? waveform;

  _MiniWaveformPainter({this.waveform});

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform == null || waveform!.minPeaks.isEmpty) return;

    final paint = Paint()
      ..color = EatsTheme.primaryCyan.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final midY = size.height / 2.0;
    final numPoints = waveform!.minPeaks.length;
    final dx = size.width / numPoints;

    for (int i = 0; i < numPoints; i++) {
      final x = i * dx + dx / 2.0;
      final minY = midY - (waveform!.maxPeaks[i] * midY * 0.9);
      final maxY = midY - (waveform!.minPeaks[i] * midY * 0.9);
      canvas.drawLine(Offset(x, minY), Offset(x, maxY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWaveformPainter oldDelegate) => oldDelegate.waveform != waveform;
}
