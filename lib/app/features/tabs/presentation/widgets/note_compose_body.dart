import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hnsnap/app/features/tabs/presentation/widgets/note_shared_widgets.dart';

class NoteComposeBody extends StatelessWidget {
  const NoteComposeBody({
    super.key,
    required this.preview,
    required this.isPostMode,
    required this.isEditingMode,
    required this.hasStoredNotes,
    required this.isSavingNote,
    required this.isSwitchingCamera,
    required this.captionController,
    required this.captionFocusNode,
    required this.priceController,
    required this.priceFocusNode,
    required this.onFocusCaption,
    required this.onFocusPrice,
    required this.onCancelOrPick,
    required this.onCancelEditing,
    required this.onCaptureOrSubmit,
    required this.onCropOrSwitch,
    required this.onOpenFirstNote,
    required this.isSelectedMediaVideo,
  });

  final Widget preview;
  final bool isPostMode;
  final bool isEditingMode;
  final bool hasStoredNotes;
  final bool isSavingNote;
  final bool isSwitchingCamera;
  final TextEditingController captionController;
  final FocusNode captionFocusNode;
  final TextEditingController priceController;
  final FocusNode priceFocusNode;
  final VoidCallback onFocusCaption;
  final VoidCallback onFocusPrice;
  final VoidCallback onCancelOrPick;
  final VoidCallback onCancelEditing;
  final VoidCallback onCaptureOrSubmit;
  final VoidCallback onCropOrSwitch;
  final VoidCallback onOpenFirstNote;
  final bool isSelectedMediaVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final squareSize = constraints.maxWidth;
            final content = ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: squareSize,
                      height: squareSize,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          preview,
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(48),
                                border: Border.all(
                                  color: colorScheme.outline,
                                  width: 2.4,
                                ),
                              ),
                            ),
                          ),
                          if (isPostMode)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: NoteOverlayInputChip(
                                controller: priceController,
                                focusNode: priceFocusNode,
                                icon: Icons.sell_outlined,
                                hintText: 'Số tiền',
                                textColor: Colors.white,
                                iconColor: colorScheme.primary,
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.82,
                                ),
                                borderColor: colorScheme.primary.withValues(
                                  alpha: 0.42,
                                ),
                                onTap: onFocusPrice,
                                width: 180,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      signed: true,
                                      decimal: true,
                                    ),
                              ),
                            ),
                          if (isPostMode)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Center(
                                child: NoteOverlayInputChip(
                                  controller: captionController,
                                  focusNode: captionFocusNode,
                                  icon: Icons.auto_awesome_outlined,
                                  hintText: 'Ghi chú (tùy chọn)',
                                  textColor: Colors.white,
                                  iconColor: colorScheme.primary,
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.82,
                                  ),
                                  borderColor: colorScheme.primary.withValues(
                                    alpha: 0.42,
                                  ),
                                  onTap: onFocusCaption,
                                  width: 300,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isPostMode) ...[
                      const SizedBox(height: 20),
                      Text(
                        isEditingMode
                            ? 'Bạn đang sửa ghi chú. Có thể đổi ảnh hoặc video khác rồi bấm gửi để cập nhật lại ghi chú hiện tại.'
                            : 'Chụp ảnh, chọn ảnh hoặc video từ máy. Số tiền và ghi chú đều là tùy chọn.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isEditingMode) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: isSavingNote ? null : onCancelEditing,
                          icon: const Icon(LucideIcons.x, size: 16),
                          label: const Text('Hủy chỉnh'),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        NoteActionIconButton(
                          icon: isPostMode
                              ? (isEditingMode
                                    ? LucideIcons.images
                                    : LucideIcons.x)
                              : LucideIcons.images,
                          onPressed: isSavingNote ? null : onCancelOrPick,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 24),
                        NoteCaptureButton(
                          onPressed: isSavingNote ? null : onCaptureOrSubmit,
                          color: colorScheme.primary,
                          iconColor: colorScheme.onPrimary,
                          icon: isPostMode
                              ? Icons.send_rounded
                              : Icons.camera_alt_rounded,
                        ),
                        const SizedBox(width: 24),
                        NoteActionIconButton(
                          icon: isPostMode
                              ? (isSelectedMediaVideo
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.crop_free_rounded)
                              : LucideIcons.refreshCcw,
                          onPressed: isSavingNote
                              ? null
                              : (isPostMode
                                    ? (isSelectedMediaVideo
                                          ? null
                                          : onCropOrSwitch)
                                    : (isSwitchingCamera
                                          ? null
                                          : onCropOrSwitch)),
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (hasStoredNotes)
                      FilledButton.tonalIcon(
                        onPressed: onOpenFirstNote,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        label: const Text('Vuốt lên hoặc bấm để xem ghi chú'),
                      )
                    else
                      Text(
                        'Chưa có ghi chú nào phía dưới. Lưu ghi chú đầu tiên để bắt đầu vuốt xem.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            );

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: keyboardInset > 0
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: keyboardInset + 16),
              child: content,
            );
          },
        ),
      ),
    );
  }
}
