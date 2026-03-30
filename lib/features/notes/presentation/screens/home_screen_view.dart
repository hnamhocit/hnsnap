// ignore_for_file: invalid_use_of_protected_member

part of 'home_screen.dart';

extension on _HomeScreenState {
  Widget _buildPreviewSurface(ThemeData theme) {
    if (_selectedMedia != null && _selectedMediaType != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(48),
        ),
        child: NoteMediaView(
          mediaPath: _selectedMedia!.path,
          mediaType: _selectedMediaType!,
          borderRadius: BorderRadius.circular(48),
          isActive: _isOnComposePage,
          mirrorHorizontally: _shouldMirrorSelectedImage,
          autoplay: _selectedMediaType!.isVideo,
          allowTapToToggle: _selectedMediaType!.isVideo,
          onOverlayInteractionChanged: _handleMediaOverlayInteractionChanged,
          errorLabel: 'Không đọc được media vừa chọn.',
        ),
      );
    }

    final initializeFuture = _initializeCameraFuture;
    final controller = _cameraController;

    if (_errorMessage != null) {
      return _buildStatusCard(theme, _errorMessage!);
    }

    if (initializeFuture == null || controller == null) {
      return _buildLoadingCard(theme);
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingCard(theme);
        }

        if (snapshot.hasError) {
          return _buildStatusCard(
            theme,
            'Không thể hiển thị camera: ${snapshot.error}',
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(48),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(48),
            child: Builder(
              builder: (context) {
                final previewSize = controller.value.previewSize;
                if (previewSize == null) {
                  return _buildLoadingCard(theme);
                }

                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: previewSize.height,
                      height: previewSize.width,
                      child: CameraPreview(controller),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(ThemeData theme) {
    return NoteSkeletonBox(
      borderRadius: BorderRadius.circular(48),
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surfaceContainerHigh,
    );
  }

  Widget _buildStatusCard(ThemeData theme, String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(48),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoredNotePage(ThemeData theme, NoteEntry note, int noteIndex) {
    final colorScheme = theme.colorScheme;
    final isActive = !_isOnComposePage && _currentFeedIndex == noteIndex;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: NoteFeedView(
              note: note,
              isActive: isActive,
              onOverlayInteractionChanged:
                  _handleMediaOverlayInteractionChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentFeedIndex + 1}/${_notes.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    NoteBottomCircleActionButton(
                      icon: LucideIcons.grid2x2,
                      onPressed: _openCatalogPage,
                      color: colorScheme.primary,
                      tooltip: 'Mở thư viện ghi chú',
                    ),
                    NoteCaptureButton(
                      onPressed: _jumpToComposePage,
                      color: colorScheme.primary,
                      iconColor: colorScheme.onPrimary,
                      icon: LucideIcons.camera,
                      size: 82,
                      iconSize: 32,
                    ),
                    NoteBottomCircleActionButton(
                      icon: LucideIcons.circleEllipsis,
                      onPressed: _isRunningNoteAction
                          ? null
                          : _openCurrentNoteActions,
                      color: colorScheme.primary,
                      tooltip: 'Thao tác ghi chú',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleVerticalPageChanged(int pageIndex) {
    setState(() {
      _currentPageIndex = pageIndex;
      if (pageIndex > 0) {
        _currentFeedIndex = _normalizeFeedIndex(pageIndex - 1, _notes.length);
      }
    });

    _syncCameraActivity();
  }
}

enum _StoredNoteAction { edit, delete, download, share }

class _HomeScreenSkeleton extends StatelessWidget {
  const _HomeScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NoteSkeletonBox(borderRadius: BorderRadius.circular(48)),
                  const SizedBox(height: 24),
                  NoteSkeletonBox(
                    width: 148,
                    height: 44,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 12),
                  NoteSkeletonBox(
                    width: 116,
                    height: 44,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                NoteSkeletonBox(width: 52, height: 52, shape: BoxShape.circle),
                NoteSkeletonBox(width: 82, height: 82, shape: BoxShape.circle),
                NoteSkeletonBox(width: 52, height: 52, shape: BoxShape.circle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
