import 'package:flutter/material.dart';
import 'package:hnsnap/common/utils/note_formatters.dart';
import 'package:hnsnap/features/notes/domain/entities/note_entry.dart';
import 'package:hnsnap/features/notes/presentation/widgets/note_media_view.dart';
import 'package:hnsnap/features/notes/presentation/widgets/note_shared_widgets.dart';

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
                      if (note.amount != null || note.note.trim().isNotEmpty)
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 24,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withOpacity(
                                    0.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (note.amount != null)
                                    Text(
                                      formatVND(note.amount!),
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: note.amount! >= 0
                                                ? const Color(0xFF53D18C)
                                                : const Color(0xFFFF8E7D),
                                          ),
                                    ),
                                  if (note.amount != null &&
                                      note.note.trim().isNotEmpty)
                                    const SizedBox(height: 6),
                                  if (note.note.trim().isNotEmpty)
                                    Text(
                                      note.note.trim(),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
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
