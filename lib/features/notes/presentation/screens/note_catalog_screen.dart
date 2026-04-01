import 'package:flutter/material.dart';
import 'package:hnsnap/common/utils/note_formatters.dart';
import 'package:hnsnap/features/notes/domain/entities/note_entry.dart';
import 'package:hnsnap/features/notes/domain/entities/note_query.dart';
import 'package:hnsnap/features/notes/domain/repositories/notes_repository.dart';
import 'package:hnsnap/features/notes/presentation/screens/note_filter_screen.dart';
import 'package:hnsnap/features/notes/presentation/widgets/note_media_view.dart';
import 'package:hnsnap/features/notes/presentation/widgets/note_shared_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum NoteCatalogAction { open, edit, delete, download, share }

class NoteCatalogResult {
  const NoteCatalogResult({required this.noteId, required this.action});

  final int? noteId;
  final NoteCatalogAction action;
}

class NoteCatalogScreen extends StatefulWidget {
  const NoteCatalogScreen({
    super.key,
    required this.notesRepository,
    this.initialSelectedNoteId,
  });

  final NotesRepository notesRepository;
  final int? initialSelectedNoteId;

  @override
  State<NoteCatalogScreen> createState() => _NoteCatalogScreenState();
}

class _NoteCatalogScreenState extends State<NoteCatalogScreen> {
  List<NoteEntry> _notes = const [];
  NoteQuery _query = const NoteQuery();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notes = await widget.notesRepository.listNotes(_query);
      if (!mounted) {
        return;
      }

      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notes = const [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được thư viện ghi chú.')),
      );
    }
  }

  Future<void> _openFilterScreen() async {
    final result = await Navigator.of(context).push<NoteQuery>(
      MaterialPageRoute(
        builder: (context) => NoteFilterScreen(
          initialQuery: _query,
          notesRepository: widget.notesRepository,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _query = result;
    });

    await _loadNotes();
  }

  Future<void> _openNoteActions(NoteEntry note) async {
    final action = await showModalBottomSheet<NoteCatalogAction>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.squarePen),
                title: const Text('Sửa'),
                onTap: () => Navigator.of(context).pop(NoteCatalogAction.edit),
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash2),
                title: const Text('Xóa'),
                onTap: () =>
                    Navigator.of(context).pop(NoteCatalogAction.delete),
              ),
              ListTile(
                leading: const Icon(LucideIcons.download),
                title: const Text('Tải xuống'),
                onTap: () =>
                    Navigator.of(context).pop(NoteCatalogAction.download),
              ),
              ListTile(
                leading: const Icon(LucideIcons.share2),
                title: const Text('Chia sẻ'),
                onTap: () => Navigator.of(context).pop(NoteCatalogAction.share),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    Navigator.of(
      context,
    ).pop(NoteCatalogResult(noteId: note.id, action: action));
  }

  List<String> _buildActiveFilterLabels(NoteQuery query) {
    final labels = <String>[];

    if (query.scope != NoteDateFilterScope.all) {
      labels.add(describeDateFilter(query));
    }

    switch (query.amountFilter) {
      case NoteAmountFilter.income:
        labels.add('Chỉ thu');
      case NoteAmountFilter.expense:
        labels.add('Chỉ chi');
      case NoteAmountFilter.all:
        break;
    }

    final keyword = query.keyword.trim();
    if (keyword.isNotEmpty) {
      labels.add('Từ khóa: $keyword');
    }

    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư viện ghi chú'),
        actions: [
          IconButton(
            onPressed: _openFilterScreen,
            icon: const Icon(LucideIcons.slidersHorizontal),
            tooltip: 'Lọc thư viện ghi chú',
          ),
        ],
      ),
      body: _isLoading
          ? const _CatalogSkeleton()
          : SafeArea(
              child: Column(
                children: [
                  if (_query.isActive)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._buildActiveFilterLabels(
                            _query,
                          ).map((label) => Chip(label: Text(label))),
                          ActionChip(
                            label: const Text('Bỏ lọc'),
                            onPressed: () async {
                              setState(() {
                                _query = const NoteQuery();
                              });
                              await _loadNotes();
                            },
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _notes.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                'Không có ghi chú nào khớp với bộ lọc hiện tại.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: _notes.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                ),
                            itemBuilder: (context, index) {
                              final note = _notes[index];
                              final isActive =
                                  note.id == widget.initialSelectedNoteId;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () => Navigator.of(context).pop(
                                    NoteCatalogResult(
                                      noteId: note.id,
                                      action: NoteCatalogAction.open,
                                    ),
                                  ),
                                  onLongPress: () => _openNoteActions(note),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isActive
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outlineVariant,
                                        width: isActive ? 2.4 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (note.mediaType.isImage)
                                            NoteMediaView(
                                              mediaPath: note.mediaPath,
                                              mediaType: note.mediaType,
                                              borderRadius:
                                                  BorderRadius.circular(21),
                                              errorLabel:
                                                  'Không đọc được media đã lưu.',
                                            )
                                          else
                                            ColoredBox(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHigh,
                                              child: Center(
                                                child: Icon(
                                                  Icons
                                                      .play_circle_outline_rounded,
                                                  size: 34,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.92),
                                                ),
                                              ),
                                            ),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: Stack(
                                              children: [
                                                if (note.mediaType.isImage)
                                                  NoteMediaView(
                                                    mediaPath: note.mediaPath,
                                                    mediaType: note.mediaType,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24,
                                                        ),
                                                    errorLabel:
                                                        'Không đọc được media đã lưu.',
                                                  )
                                                else
                                                  ColoredBox(
                                                    color: theme
                                                        .colorScheme
                                                        .surfaceContainerHigh,
                                                    child: Center(
                                                      child: Icon(
                                                        Icons
                                                            .play_circle_outline_rounded,
                                                        size: 34,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.92,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                if (note.amount != null)
                                                  Positioned(
                                                    bottom: 6,
                                                    left: 6,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .surface
                                                            .withValues(
                                                              alpha: 0.92,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      child: Text(
                                                        formatVND(
                                                          note.amount ?? 0,
                                                        ),
                                                        style: theme
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                if (isActive)
                                                  DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.18,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (isActive)
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.18),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 18,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          return const NoteSkeletonBox(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          );
        },
      ),
    );
  }
}
