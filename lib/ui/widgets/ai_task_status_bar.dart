import 'package:flutter/material.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';
import '../../services/ai_task_manager.dart';
import 'skeuomorphic_hardware_button.dart';
import 'ai_assistant_dialog.dart';

/// Top toolbar background notification & status pill for in-flight and reviewable AI tasks.
class AiTaskStatusBar extends StatelessWidget {
  final DawState dawState;

  const AiTaskStatusBar({super.key, required this.dawState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AiTaskManager.instance,
      builder: (context, _) {
        final mgr = AiTaskManager.instance;
        if (mgr.status == AiTaskStatus.idle) {
          return const SizedBox.shrink();
        }

        if (mgr.status == AiTaskStatus.running) {
          final seconds = (mgr.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
          return Tooltip(
            message: '${mgr.taskTitle} (${seconds}s)\nClick to view progress or cancel',
            child: InkWell(
              onTap: () => AiAssistantDialog.show(context, dawState, initialTab: mgr.targetTab),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: EatsTheme.primaryCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: EatsTheme.primaryCyan.withOpacity(0.7), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: EatsTheme.primaryCyan.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(EatsTheme.primaryCyan),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${seconds}s',
                      style: TextStyle(
                        color: EatsTheme.primaryCyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (mgr.status == AiTaskStatus.readyForReview) {
          return Tooltip(
            message: '${mgr.taskTitle} is Complete!\nClick to Review & Apply',
            child: InkWell(
              onTap: () => AiAssistantDialog.show(context, dawState, initialTab: mgr.targetTab),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF66).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF00FF66), width: 1.3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF66).withOpacity(0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 13, color: Color(0xFF00FF66)),
                    SizedBox(width: 5),
                    Text(
                      'READY',
                      style: TextStyle(
                        color: Color(0xFF00FF66),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (mgr.status == AiTaskStatus.failed) {
          return Tooltip(
            message: 'AI Task Failed: ${mgr.errorMessage ?? "Error occurred"}\nClick to view details',
            child: InkWell(
              onTap: () => AiAssistantDialog.show(context, dawState, initialTab: mgr.targetTab),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.redAccent, width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
                    SizedBox(width: 4),
                    Text(
                      'FAILED',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
