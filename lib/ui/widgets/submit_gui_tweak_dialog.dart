import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';
import '../../services/github_tweak_submission_service.dart';

/// Modal dialog for reviewing and submitting mobile/desktop GUI tweaks directly to GitHub.
class SubmitGuiTweakDialog extends StatefulWidget {
  final String presetId;
  final String presetName;
  final String eatCode;

  const SubmitGuiTweakDialog({
    super.key,
    required this.presetId,
    required this.presetName,
    required this.eatCode,
  });

  static Future<void> show(
    BuildContext context, {
    required String presetId,
    required String presetName,
    required String eatCode,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => SubmitGuiTweakDialog(
        presetId: presetId,
        presetName: presetName,
        eatCode: eatCode,
      ),
    );
  }

  @override
  State<SubmitGuiTweakDialog> createState() => _SubmitGuiTweakDialogState();
}

class _SubmitGuiTweakDialogState extends State<SubmitGuiTweakDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _authorController;
  bool _showCodePreview = false;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _authorController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    await GithubTweakSubmissionService.copyPayloadToClipboard(
      presetId: widget.presetId,
      presetName: widget.presetName,
      eatCode: widget.eatCode,
      description: _descriptionController.text,
      author: _authorController.text,
    );

    setState(() => _isCopied = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied GUI submission packet to clipboard!'),
          duration: Duration(seconds: 2),
          backgroundColor: EatsTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    final result = await GithubTweakSubmissionService.openGitHubIssue(
      presetId: widget.presetId,
      presetName: widget.presetName,
      eatCode: widget.eatCode,
      description: _descriptionController.text,
      author: _authorController.text,
    );

    if (mounted) {
      if (result.success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.requiredClipboardPaste
                  ? '📋 Packet copied to clipboard! Tap Paste in the GitHub description.'
                  : 'Opening GitHub issue...',
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: EatsTheme.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open browser. Please use "Copy Packet" and open GitHub manually.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: const Color(0xFF141720),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2B3245), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 580,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.merge_type, size: 20, color: EatsTheme.primaryCyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUBMIT GUI TWEAK TO GITHUB',
                          style: EatsTheme.getDisplayFontStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Generates a prefilled pull-request issue with no login required',
                          style: TextStyle(fontSize: 11, color: EatsTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: EatsTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF222838), height: 24),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Target Preset Info Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1017),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF202638)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tune, size: 24, color: EatsTheme.accentGreen),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.presetName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Preset ID: ${widget.presetId}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: EatsTheme.primaryCyan,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Description
                      Text(
                        'WHAT DID YOU TWEAK? (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: EatsTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'e.g. Swapped cutoff knob to vintage Bakelite, tightened row spacing...',
                          hintStyle: TextStyle(color: EatsTheme.textMuted.withOpacity(0.6), fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF0E1017),
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFF2B3245)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFF2B3245)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: EatsTheme.primaryCyan),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Optional Author Handle
                      Text(
                        'YOUR GITHUB / DISCORD USERNAME (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: EatsTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _authorController,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: '@username',
                          hintStyle: TextStyle(color: EatsTheme.textMuted.withOpacity(0.6), fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF0E1017),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFF2B3245)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFF2B3245)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: EatsTheme.primaryCyan),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Code Preview Toggle
                      InkWell(
                        onTap: () => setState(() => _showCodePreview = !_showCodePreview),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _showCodePreview ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                size: 16,
                                color: EatsTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showCodePreview ? 'Hide Payload Preview' : 'Preview Eatscript Code Packet',
                                style: TextStyle(
                                  color: EatsTheme.primaryCyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_showCodePreview) ...[
                        const SizedBox(height: 6),
                        Container(
                          height: 140,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2B3245)),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              widget.eatCode,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFF00FF9D),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (GithubTweakSubmissionService.isUrlTooLong(
                        presetId: widget.presetId,
                        presetName: widget.presetName,
                        eatCode: widget.eatCode,
                        description: _descriptionController.text,
                        author: _authorController.text,
                      )) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: EatsTheme.primaryCyan.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.content_paste_go, size: 16, color: EatsTheme.primaryCyan),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Packet will auto-copy to clipboard. Simply tap Paste when GitHub opens.',
                                  style: TextStyle(fontSize: 11, color: EatsTheme.primaryCyan),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFF222838), height: 1),
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: Icon(
                      _isCopied ? Icons.check : Icons.copy,
                      size: 14,
                      color: _isCopied ? EatsTheme.accentGreen : EatsTheme.textMuted,
                    ),
                    label: Text(
                      _isCopied ? 'COPIED!' : 'COPY PACKET',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isCopied ? EatsTheme.accentGreen : EatsTheme.textMuted,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2B3245)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onPressed: _handleCopy,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(
                      GithubTweakSubmissionService.isUrlTooLong(
                        presetId: widget.presetId,
                        presetName: widget.presetName,
                        eatCode: widget.eatCode,
                        description: _descriptionController.text,
                        author: _authorController.text,
                      )
                          ? 'COPY & OPEN GITHUB'
                          : 'OPEN GITHUB ISSUE',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EatsTheme.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _handleSubmit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
