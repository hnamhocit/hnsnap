import 'package:flutter/material.dart';
import 'package:hnsnap/app/features/tabs/data/models/note_entry.dart';
import 'package:hnsnap/app/features/tabs/presentation/utils/note_formatters.dart';
import 'package:hnsnap/app/features/tabs/presentation/widgets/note_media_view.dart';
import 'package:hnsnap/app/features/tabs/presentation/widgets/note_shared_widgets.dart';

class NoteFeedView extends StatelessWidget {
  const NoteFeedView({
    super.key,
    required this.note,
    this.isActive = true,
    this.onOverlayInteractionChanged,
  });

  final NoteEntry note;
  final bool isActive;
  final ValueChanged<bool>? onOverlayInteractionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSize = constraints.maxWidth;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: squareSize,
                  height: squareSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(48),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(48),
                          child: NoteMediaView(
                            mediaPath: note.mediaPath,
                            mediaType: note.mediaType,
                            borderRadius: BorderRadius.circular(48),
                            isActive: isActive,
                            autoplay: note.mediaType.isVideo,
                            allowTapToToggle: note.mediaType.isVideo,
                            onOverlayInteractionChanged:
                                onOverlayInteractionChanged,
                            errorLabel: 'Không đọc được media đã lưu.',
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(48),
                            border: Border.all(
                              color: colorScheme.outline,
                              width: 2.2,
                            ),
                          ),
                        ),
                      ),
                      if ((note.transactionType ?? '').trim().isNotEmpty)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: NotePreviewDisplayChip(
                            icon: Icons.category_outlined,
                            label: note.transactionType!.trim(),
                            color: colorScheme.primary,
                          ),
                        ),
                      if (note.amount != null)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: NotePreviewDisplayChip(
                            icon: note.amount! >= 0
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            label: formatAmount(note.amount!),
                            color: note.amount! >= 0
                                ? Colors.greenAccent.shade400
                                : Colors.redAccent.shade100,
                          ),
                        ),
                      if (note.note.trim().isNotEmpty)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Center(
                            child: NotePreviewDisplayChip(
                              icon: Icons.auto_awesome_outlined,
                              label: note.note.trim(),
                              color: colorScheme.primary,
                              maxWidth: 320,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  formatDateTime(note.createdAt),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
