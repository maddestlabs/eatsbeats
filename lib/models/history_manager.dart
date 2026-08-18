import 'package:flutter/material.dart';
import 'daw_state.dart';

enum HistoryDiffType {
  unchanged,
  added,
  removed,
}

class HistoryDiffLine {
  final String text;
  final HistoryDiffType type;
  final int? oldLineNumber;
  final int? newLineNumber;

  const HistoryDiffLine({
    required this.text,
    required this.type,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

class HistoryEntry {
  final String id;
  final String description;
  final IconData icon;
  final DateTime timestamp;
  final String snapshotLua;
  final bool isMilestone;
  final String? milestoneName;

  const HistoryEntry({
    required this.id,
    required this.description,
    required this.icon,
    required this.timestamp,
    required this.snapshotLua,
    this.isMilestone = false,
    this.milestoneName,
  });

  HistoryEntry copyWith({
    String? id,
    String? description,
    IconData? icon,
    DateTime? timestamp,
    String? snapshotLua,
    bool? isMilestone,
    String? milestoneName,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      timestamp: timestamp ?? this.timestamp,
      snapshotLua: snapshotLua ?? this.snapshotLua,
      isMilestone: isMilestone ?? this.isMilestone,
      milestoneName: milestoneName ?? this.milestoneName,
    );
  }
}

class HistoryManager extends ChangeNotifier {
  static const int defaultMaxDepth = 50;
  final int maxDepth;

  final List<HistoryEntry> _past = [];
  HistoryEntry? _current;
  final List<HistoryEntry> _future = []; // top of future stack is next redo

  // Transaction coalescing (for continuous slider drags / knob turns)
  bool _inTransaction = false;
  String? _transactionDescription;
  IconData? _transactionIcon;
  String? _transactionInitialSnapshot;

  bool _isRestoring = false;
  bool get isRestoring => _isRestoring;

  bool _isPaused = false;
  bool get isPaused => _isPaused;
  void pauseRecording() => _isPaused = true;
  void resumeRecording() => _isPaused = false;

  HistoryManager({this.maxDepth = defaultMaxDepth});

  List<HistoryEntry> get past => List.unmodifiable(_past);
  HistoryEntry? get current => _current;
  List<HistoryEntry> get future => List.unmodifiable(_future);

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  String? get nextUndoDescription => _past.isNotEmpty ? _past.last.description : null;
  String? get nextRedoDescription => _future.isNotEmpty ? _future.last.description : null;

  /// Returns the flat chronological list of all entries from oldest to newest.
  /// Past items: 0 .. _past.length - 1
  /// Current item: index == _past.length
  /// Future items: index > _past.length
  List<HistoryEntry> get timeline {
    final list = <HistoryEntry>[];
    list.addAll(_past);
    if (_current != null) {
      list.add(_current!);
    }
    // _future is stored as a stack (last is top/next redo), so reverse it for chronological future
    list.addAll(_future.reversed);
    return list;
  }

  int get currentTimelineIndex => _current != null ? _past.length : -1;

  /// Initializes history with the initial DAW state snapshot.
  void init(DawState state, {String initialDescription = 'Initial Project State'}) {
    final snapshot = state.exportToEatsLua();
    _past.clear();
    _future.clear();
    _current = HistoryEntry(
      id: 'init_${DateTime.now().microsecondsSinceEpoch}',
      description: initialDescription,
      icon: Icons.flag,
      timestamp: DateTime.now(),
      snapshotLua: snapshot,
      isMilestone: true,
      milestoneName: 'Initial State',
    );
    notifyListeners();
  }

  /// Records a discrete user action snapshot into history.
  void record(
    DawState state,
    String description, {
    IconData icon = Icons.edit,
    bool isMilestone = false,
    String? milestoneName,
    bool force = false,
  }) {
    if (_isRestoring || _isPaused || _current == null) return;
    if (_inTransaction) return; // Coalesced into current transaction

    final newSnapshot = state.exportToEatsLua();

    // Prevent duplicate entries if state hasn't changed
    if (!force && _current != null && _current!.snapshotLua == newSnapshot) {
      return;
    }

    if (_current != null) {
      _past.add(_current!);
      if (_past.length > maxDepth) {
        _past.removeAt(0);
      }
    }

    _future.clear();

    _current = HistoryEntry(
      id: 'h_${DateTime.now().microsecondsSinceEpoch}',
      description: description,
      icon: icon,
      timestamp: DateTime.now(),
      snapshotLua: newSnapshot,
      isMilestone: isMilestone,
      milestoneName: milestoneName,
    );

    notifyListeners();
  }

  /// Begins a continuous gesture transaction (e.g. knob/slider drag start).
  void beginTransaction(DawState state, String description, {IconData icon = Icons.tune}) {
    if (_isRestoring || _isPaused || _current == null || _inTransaction) return;
    _inTransaction = true;
    _transactionDescription = description;
    _transactionIcon = icon;
    _transactionInitialSnapshot = state.exportToEatsLua();
  }

  /// Commits a continuous gesture transaction (e.g. knob/slider drag end).
  void commitTransaction(DawState state) {
    if (!_inTransaction) return;
    _inTransaction = false;

    final currentSnapshot = state.exportToEatsLua();
    if (_transactionInitialSnapshot != null && _transactionInitialSnapshot == currentSnapshot) {
      // No actual value changed during drag
      _transactionDescription = null;
      _transactionIcon = null;
      _transactionInitialSnapshot = null;
      return;
    }

    if (_current != null) {
      _past.add(_current!);
      if (_past.length > maxDepth) {
        _past.removeAt(0);
      }
    }

    _future.clear();

    _current = HistoryEntry(
      id: 'h_${DateTime.now().microsecondsSinceEpoch}',
      description: _transactionDescription ?? 'Adjust Parameter',
      icon: _transactionIcon ?? Icons.tune,
      timestamp: DateTime.now(),
      snapshotLua: currentSnapshot,
    );

    _transactionDescription = null;
    _transactionIcon = null;
    _transactionInitialSnapshot = null;

    notifyListeners();
  }

  /// Cancels an active transaction without recording an undo step.
  void cancelTransaction() {
    _inTransaction = false;
    _transactionDescription = null;
    _transactionIcon = null;
    _transactionInitialSnapshot = null;
  }

  /// Performs an Undo step, restoring the previous DAW state.
  bool undo(DawState state) {
    if (!canUndo || _isRestoring) return false;

    final target = _past.removeLast();
    if (_current != null) {
      _future.add(_current!);
    }
    _current = target;

    _applySnapshot(state, target.snapshotLua);
    notifyListeners();
    return true;
  }

  /// Performs a Redo step, restoring the next DAW state.
  bool redo(DawState state) {
    if (!canRedo || _isRestoring) return false;

    final target = _future.removeLast();
    if (_current != null) {
      _past.add(_current!);
    }
    _current = target;

    _applySnapshot(state, target.snapshotLua);
    notifyListeners();
    return true;
  }

  /// Jumps / Time-travels to any specific index in the chronological timeline list.
  bool jumpToTimelineIndex(DawState state, int targetIndex) {
    if (_isRestoring) return false;
    final all = timeline;
    if (targetIndex < 0 || targetIndex >= all.length) return false;

    final currentIndex = currentTimelineIndex;
    if (targetIndex == currentIndex) return true;

    final targetEntry = all[targetIndex];

    if (targetIndex < currentIndex) {
      // Moving back in time (undoing)
      final stepsToUndo = currentIndex - targetIndex;
      for (int i = 0; i < stepsToUndo; i++) {
        if (_past.isNotEmpty) {
          final p = _past.removeLast();
          if (_current != null) {
            _future.add(_current!);
          }
          _current = p;
        }
      }
    } else {
      // Moving forward in time (redoing)
      final stepsToRedo = targetIndex - currentIndex;
      for (int i = 0; i < stepsToRedo; i++) {
        if (_future.isNotEmpty) {
          final f = _future.removeLast();
          if (_current != null) {
            _past.add(_current!);
          }
          _current = f;
        }
      }
    }

    _applySnapshot(state, targetEntry.snapshotLua);
    notifyListeners();
    return true;
  }

  /// Creates a named checkpoint/milestone at the current state.
  void createMilestone(DawState state, String name) {
    if (_current == null) {
      init(state);
    }
    _current = _current!.copyWith(
      isMilestone: true,
      milestoneName: name.trim().isNotEmpty ? name.trim() : 'Checkpoint',
      icon: Icons.bookmark,
    );
    notifyListeners();
  }

  /// Clears the history stack, retaining only the current state.
  void clear(DawState? state) {
    _past.clear();
    _future.clear();
    if (state != null && _current == null) {
      init(state);
    }
    notifyListeners();
  }

  void _applySnapshot(DawState state, String luaScript) {
    _isRestoring = true;
    try {
      state.loadFromEatsLua(luaScript);
    } finally {
      _isRestoring = false;
    }
  }

  /// Computes a human-readable line-by-line diff between two Lua scripts.
  static List<HistoryDiffLine> computeDiff(String oldText, String newText) {
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');
    final diff = <HistoryDiffLine>[];

    int oldIdx = 0;
    int newIdx = 0;

    while (oldIdx < oldLines.length && newIdx < newLines.length) {
      if (oldLines[oldIdx] == newLines[newIdx]) {
        diff.add(HistoryDiffLine(
          text: oldLines[oldIdx],
          type: HistoryDiffType.unchanged,
          oldLineNumber: oldIdx + 1,
          newLineNumber: newIdx + 1,
        ));
        oldIdx++;
        newIdx++;
      } else {
        // Look ahead for matching lines
        int matchInNew = -1;
        for (int k = newIdx + 1; k < newLines.length && k < newIdx + 10; k++) {
          if (newLines[k] == oldLines[oldIdx]) {
            matchInNew = k;
            break;
          }
        }

        int matchInOld = -1;
        for (int k = oldIdx + 1; k < oldLines.length && k < oldIdx + 10; k++) {
          if (oldLines[k] == newLines[newIdx]) {
            matchInOld = k;
            break;
          }
        }

        if (matchInNew != -1 && (matchInOld == -1 || matchInNew - newIdx <= matchInOld - oldIdx)) {
          // Lines were added in new
          while (newIdx < matchInNew) {
            diff.add(HistoryDiffLine(
              text: newLines[newIdx],
              type: HistoryDiffType.added,
              newLineNumber: newIdx + 1,
            ));
            newIdx++;
          }
        } else if (matchInOld != -1) {
          // Lines were removed in old
          while (oldIdx < matchInOld) {
            diff.add(HistoryDiffLine(
              text: oldLines[oldIdx],
              type: HistoryDiffType.removed,
              oldLineNumber: oldIdx + 1,
            ));
            oldIdx++;
          }
        } else {
          // Changed line
          diff.add(HistoryDiffLine(
            text: oldLines[oldIdx],
            type: HistoryDiffType.removed,
            oldLineNumber: oldIdx + 1,
          ));
          diff.add(HistoryDiffLine(
            text: newLines[newIdx],
            type: HistoryDiffType.added,
            newLineNumber: newIdx + 1,
          ));
          oldIdx++;
          newIdx++;
        }
      }
    }

    while (oldIdx < oldLines.length) {
      diff.add(HistoryDiffLine(
        text: oldLines[oldIdx],
        type: HistoryDiffType.removed,
        oldLineNumber: oldIdx + 1,
      ));
      oldIdx++;
    }

    while (newIdx < newLines.length) {
      diff.add(HistoryDiffLine(
        text: newLines[newIdx],
        type: HistoryDiffType.added,
        newLineNumber: newIdx + 1,
      ));
      newIdx++;
    }

    return diff;
  }
}
