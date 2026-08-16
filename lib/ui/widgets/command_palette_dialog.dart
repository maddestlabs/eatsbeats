import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/command_palette_registry.dart';
import '../../models/daw_state.dart';
import '../../theme/eats_theme.dart';

class CommandPaletteDialog extends StatefulWidget {
  final DawState dawState;

  const CommandPaletteDialog({super.key, required this.dawState});

  static Future<void> show(BuildContext context, DawState dawState) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => CommandPaletteDialog(dawState: dawState),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<QuickCommand> _filteredCommands = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredCommands = CommandPaletteRegistry.getCommands(widget.dawState, context);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredCommands = CommandPaletteRegistry.search(_searchController.text, widget.dawState, context);
      _selectedIndex = 0;
    });
  }

  void _executeCommand(QuickCommand command) {
    Navigator.of(context).pop();
    command.onExecute(widget.dawState, context);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_filteredCommands.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
        });
        _scrollToIndex(_selectedIndex);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_filteredCommands.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + _filteredCommands.length) % _filteredCommands.length;
        });
        _scrollToIndex(_selectedIndex);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_filteredCommands.isNotEmpty && _selectedIndex >= 0 && _selectedIndex < _filteredCommands.length) {
        _executeCommand(_filteredCommands[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0;
    final targetOffset = index * itemHeight;
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    if (targetOffset < currentOffset) {
      _scrollController.jumpTo(targetOffset);
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _scrollController.jumpTo(targetOffset + itemHeight - viewportHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final bgColor = isGrungy ? const Color(0xFF1E1A17) : EatsTheme.backgroundDark;
    final borderColor = isGrungy ? const Color(0xFF4A423A) : EatsTheme.primaryCyan.withOpacity(0.4);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          width: 640,
          constraints: const BoxConstraints(maxHeight: 520),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 20,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: EatsTheme.primaryCyan.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Input Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: EatsTheme.panelHeader,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: EatsTheme.primaryCyan,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _inputFocusNode,
                        style: EatsTheme.getDisplayFontStyle(
                          fontSize: 15,
                          color: EatsTheme.textLight,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a command, preset, view, or theme... (e.g. 303, reverb, ate track)',
                          hintStyle: EatsTheme.getPrimaryFontStyle(
                            fontSize: 13,
                            color: EatsTheme.textMuted.withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EatsTheme.panelHeader, width: 1),
                      ),
                      child: Text(
                        'ESC to exit',
                        style: EatsTheme.getDisplayFontStyle(
                          fontSize: 10,
                          color: EatsTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Command List View
              Expanded(
                child: _filteredCommands.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No matching commands found',
                            style: EatsTheme.getPrimaryFontStyle(
                              fontSize: 13,
                              color: EatsTheme.textMuted,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _filteredCommands.length,
                        itemBuilder: (context, index) {
                          final cmd = _filteredCommands[index];
                          final isSelected = index == _selectedIndex;

                          return InkWell(
                            onTap: () => _executeCommand(cmd),
                            onHover: (hovering) {
                              if (hovering) {
                                setState(() => _selectedIndex = index);
                              }
                            },
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? EatsTheme.primaryCyan.withOpacity(0.18)
                                    : (index % 2 == 0 ? Colors.black.withOpacity(0.15) : Colors.transparent),
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected ? cmd.category.categoryColor : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    cmd.icon,
                                    size: 20,
                                    color: isSelected ? cmd.category.categoryColor : EatsTheme.textMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          cmd.title,
                                          style: EatsTheme.getPrimaryFontStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? Colors.white : EatsTheme.textLight,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cmd.subtitle,
                                          style: EatsTheme.getPrimaryFontStyle(
                                            fontSize: 11,
                                            color: EatsTheme.textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Category Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cmd.category.categoryColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: cmd.category.categoryColor.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      cmd.category.displayName,
                                      style: EatsTheme.getDisplayFontStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: cmd.category.categoryColor,
                                      ),
                                    ),
                                  ),

                                  if (cmd.shortcutHint != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        cmd.shortcutHint!,
                                        style: EatsTheme.getDisplayFontStyle(
                                          fontSize: 10,
                                          color: EatsTheme.primaryCyan,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Footer Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: EatsTheme.panelHeader,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                  border: Border(
                    top: BorderSide(color: borderColor.withOpacity(0.5), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredCommands.length} command${_filteredCommands.length == 1 ? '' : 's'} available',
                      style: EatsTheme.getDisplayFontStyle(
                        fontSize: 10,
                        color: EatsTheme.textMuted,
                      ),
                    ),
                    Text(
                      '↑↓ Navigate  •  ENTER Select  •  ESC Close',
                      style: EatsTheme.getDisplayFontStyle(
                        fontSize: 10,
                        color: EatsTheme.primaryCyan.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
