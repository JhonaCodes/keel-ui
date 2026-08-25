import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_composer_field.dart';
import 'package:keel_ui/src/modules/projects/model/chat_reference_kind.dart';
import 'package:keel_ui/src/modules/projects/model/chat_reference_query.dart';
import 'package:keel_ui/src/modules/projects/model/chat_reference_suggestion.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/service/project_chat_reference_service.dart';

/// Composer de sesión con referencias seleccionables en cualquier posición.
class SessionChatComposerField extends StatefulWidget {
  const SessionChatComposerField({
    super.key,
    required this.controller,
    required this.project,
    required this.members,
    required this.onSend,
    required this.hintText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final Project project;
  final List<AgentProfile> members;
  final VoidCallback onSend;
  final String hintText;
  final bool enabled;

  @override
  State<SessionChatComposerField> createState() =>
      _SessionChatComposerFieldState();
}

class _SessionChatComposerFieldState extends State<SessionChatComposerField> {
  ChatReferenceQuery? _query;
  List<ChatReferenceSuggestion> _suggestions = const [];
  final List<({String visible, String insertion})> _selectedReferences = [];
  int _selectedIndex = 0;
  int _requestSerial = 0;

  @override
  void didUpdateWidget(SessionChatComposerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_query != null &&
        (oldWidget.project != widget.project ||
            oldWidget.members != widget.members)) {
      _refreshSuggestions();
    }
  }

  void _onChanged(String text) {
    _selectedReferences.removeWhere(
      (reference) => !text.contains(reference.visible),
    );
    final offset = widget.controller.selection.baseOffset;
    final query = ProjectChatReferenceService.queryAt(text, offset);
    if (query == null) {
      _closeSuggestions();
      return;
    }
    _query = query;
    _selectedIndex = 0;
    _refreshSuggestions();
  }

  Future<void> _refreshSuggestions() async {
    final query = _query;
    if (query == null) return;
    final request = ++_requestSerial;
    final suggestions = await ProjectChatReferenceService.suggestions(
      project: widget.project,
      members: widget.members,
      query: query,
    );
    if (!mounted || request != _requestSerial || _query != query) return;
    setState(() {
      _suggestions = suggestions;
      _selectedIndex = suggestions.isEmpty
          ? 0
          : _selectedIndex.clamp(0, suggestions.length - 1);
    });
  }

  void _closeSuggestions() {
    _requestSerial++;
    if (_query == null && _suggestions.isEmpty) return;
    setState(() {
      _query = null;
      _suggestions = const [];
      _selectedIndex = 0;
    });
  }

  void _select(ChatReferenceSuggestion suggestion) {
    final query = _query;
    if (query == null) return;
    final current = widget.controller.text;
    if (query.start < 0 ||
        query.end > current.length ||
        query.start > query.end) {
      _closeSuggestions();
      return;
    }
    final replacement = '${suggestion.title} ';
    final updated = current.replaceRange(query.start, query.end, replacement);
    final caret = query.start + replacement.length;
    if (suggestion.insertion != suggestion.title) {
      _selectedReferences.add((
        visible: suggestion.title,
        insertion: suggestion.insertion,
      ));
    }
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: caret),
    );
    _closeSuggestions();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (_suggestions.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(
        () => _selectedIndex = (_selectedIndex + 1).clamp(
          0,
          _suggestions.length - 1,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _selectedIndex = (_selectedIndex - 1).clamp(
          0,
          _suggestions.length - 1,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _closeSuggestions();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _select(_suggestions[_selectedIndex]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _sendWithReferences() {
    final visibleValue = widget.controller.value;
    var materialized = visibleValue.text;
    for (final reference in _selectedReferences) {
      final token = RegExp.escape(reference.visible);
      materialized = materialized.replaceAllMapped(
        RegExp('(^|\\s)($token)(?=\\s|\$|[.,;:!?])', multiLine: true),
        (match) => '${match.group(1)}${reference.insertion}',
      );
    }
    widget.controller.value = TextEditingValue(
      text: materialized,
      selection: TextSelection.collapsed(offset: materialized.length),
    );
    widget.onSend();
    _selectedReferences.clear();
    // The regular project composer clears on success. If another embedding
    // rejects the send, keep the readable text instead of exposing internals.
    if (widget.controller.text == materialized) {
      widget.controller.value = visibleValue;
    }
    _closeSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_suggestions.isNotEmpty)
          _ReferenceSuggestionsPanel(
            suggestions: _suggestions,
            selectedIndex: _selectedIndex,
            onSelected: _select,
            onHovered: (index) => setState(() => _selectedIndex = index),
          ),
        ChatComposerField(
          controller: widget.controller,
          onSend: _sendWithReferences,
          hintText: widget.hintText,
          enabled: widget.enabled,
          onChanged: _onChanged,
          onKeyEvent: _onKeyEvent,
        ),
      ],
    );
  }
}

class _ReferenceSuggestionsPanel extends StatelessWidget {
  const _ReferenceSuggestionsPanel({
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelected,
    required this.onHovered,
  });

  final List<ChatReferenceSuggestion> suggestions;
  final int selectedIndex;
  final ValueChanged<ChatReferenceSuggestion> onSelected;
  final ValueChanged<int> onHovered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: suggestions.length,
        itemBuilder: (context, index) => _ReferenceSuggestionTile(
          suggestion: suggestions[index],
          selected: index == selectedIndex,
          onTap: () => onSelected(suggestions[index]),
          onHover: (hovering) {
            if (hovering) onHovered(index);
          },
        ),
      ),
    );
  }
}

class _ReferenceSuggestionTile extends StatelessWidget {
  const _ReferenceSuggestionTile({
    required this.suggestion,
    required this.selected,
    required this.onTap,
    required this.onHover,
  });

  final ChatReferenceSuggestion suggestion;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  IconData get _icon => switch (suggestion.kind) {
    ChatReferenceKind.directory => Icons.folder_outlined,
    ChatReferenceKind.agent => Icons.smart_toy_outlined,
    ChatReferenceKind.skill => Icons.auto_awesome_outlined,
    ChatReferenceKind.rule => Icons.rule_outlined,
    ChatReferenceKind.knowledge => Icons.menu_book_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onHover: onHover,
      child: ColoredBox(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Icon(_icon, size: 17, color: scheme.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      suggestion.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
