import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hnsnap/app/features/tabs/data/models/note_entry.dart';
import 'package:hnsnap/app/features/tabs/presentation/widgets/note_shared_widgets.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryMediaPickerResult {
  const GalleryMediaPickerResult({required this.file, required this.mediaType});

  final File file;
  final NoteMediaType mediaType;
}

class GalleryMediaPickerScreen extends StatefulWidget {
  const GalleryMediaPickerScreen({super.key});

  @override
  State<GalleryMediaPickerScreen> createState() =>
      _GalleryMediaPickerScreenState();
}

class _GalleryMediaPickerScreenState extends State<GalleryMediaPickerScreen> {
  static const _pageSize = 80;
  static final FilterOptionGroup _recentFirstFilter = FilterOptionGroup(
    orders: const [
      OrderOption(type: OrderOptionType.createDate, asc: false),
      OrderOption(type: OrderOptionType.updateDate, asc: false),
    ],
  );

  final ScrollController _scrollController = ScrollController();

  AssetPathEntity? _path;
  List<AssetEntity> _assets = const [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasPermission = true;
  bool _shouldSuggestOpeningSettings = false;
  bool _hasMore = true;
  int _nextPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _initializePicker();
  }

  Future<void> _initializePicker() async {
    setState(() {
      _isLoading = true;
      _hasPermission = true;
      _shouldSuggestOpeningSettings = false;
      _hasMore = true;
      _nextPage = 0;
      _assets = const [];
    });

    final permission = await PhotoManager.requestPermissionExtend();
    final hasAccess = permission.hasAccess;

    if (!mounted) {
      return;
    }

    if (!hasAccess) {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
        _shouldSuggestOpeningSettings = true;
      });
      return;
    }

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: _recentFirstFilter,
    );

    if (!mounted) {
      return;
    }

    if (paths.isEmpty) {
      setState(() {
        _path = null;
        _isLoading = false;
        _hasMore = false;
      });
      return;
    }

    setState(() {
      _path = paths.first;
    });

    await _loadMoreAssets(reset: true);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 600) {
      _loadMoreAssets();
    }
  }

  Future<void> _loadMoreAssets({bool reset = false}) async {
    final path = _path;
    if (path == null || _isLoadingMore) {
      if (reset && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingMore = true;
      if (reset) {
        _isLoading = true;
      }
    });

    final page = reset ? 0 : _nextPage;
    final pageAssets = await path.getAssetListPaged(
      page: page,
      size: _pageSize,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _assets = <AssetEntity>[if (!reset) ..._assets, ...pageAssets];
      _isLoading = false;
      _isLoadingMore = false;
      _nextPage = page + 1;
      _hasMore = pageAssets.length >= _pageSize;
    });
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    final file = await asset.file;

    if (!mounted) {
      return;
    }

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không đọc được file đã chọn.')),
      );
      return;
    }

    Navigator.of(context).pop(
      GalleryMediaPickerResult(
        file: file,
        mediaType: asset.type == AssetType.video
            ? NoteMediaType.video
            : NoteMediaType.image,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Thư viện')),
      body: SafeArea(
        child: _isLoading
            ? const _GalleryPickerSkeleton()
            : !_hasPermission
            ? _PermissionEmptyState(
                onRetry: _initializePicker,
                onOpenSettings: _shouldSuggestOpeningSettings
                    ? PhotoManager.openSetting
                    : null,
              )
            : _assets.isEmpty
            ? _EmptyState(
                message: 'Không tìm thấy ảnh hoặc video nào trong máy.',
                onRetry: _initializePicker,
              )
            : RefreshIndicator(
                onRefresh: () => _loadMoreAssets(reset: true),
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _assets.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _assets.length) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const NoteSkeletonBox(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                      );
                    }

                    final asset = _assets[index];
                    return _GalleryAssetTile(
                      asset: asset,
                      onTap: () => _selectAsset(asset),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _GalleryAssetTile extends StatelessWidget {
  const _GalleryAssetTile({required this.asset, required this.onTap});

  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(
                    const ThumbnailSize(360, 360),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const NoteSkeletonBox(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      );
                    }

                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                          ),
                        ),
                      );
                    }

                    return Image.memory(bytes, fit: BoxFit.cover);
                  },
                ),
                if (asset.type == AssetType.video)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatGalleryDuration(asset.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryPickerSkeleton extends StatelessWidget {
  const _GalleryPickerSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 18,
      itemBuilder: (context, index) {
        return const NoteSkeletonBox(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        );
      },
    );
  }
}

class _PermissionEmptyState extends StatelessWidget {
  const _PermissionEmptyState({required this.onRetry, this.onOpenSettings});

  final Future<void> Function() onRetry;
  final Future<void> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      message:
          'App chưa có quyền đọc thư viện ảnh/video. Hãy cấp quyền rồi thử lại.',
      actionLabel: 'Thử lại',
      onRetry: onRetry,
      secondaryActionLabel: onOpenSettings == null ? null : 'Mở cài đặt',
      onSecondaryAction: onOpenSettings,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Tải lại',
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onRetry;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                onRetry();
              },
              child: Text(actionLabel),
            ),
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  onSecondaryAction!();
                },
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatGalleryDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}
