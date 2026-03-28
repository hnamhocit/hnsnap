import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hnsnap/app/features/tabs/data/models/note_entry.dart';
import 'package:hnsnap/app/features/tabs/presentation/widgets/note_shared_widgets.dart';
import 'package:video_player/video_player.dart';

const _defaultVideoVolume = 0.5;

class NoteMediaView extends StatelessWidget {
  const NoteMediaView({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    required this.borderRadius,
    this.isActive = true,
    this.fit = BoxFit.cover,
    this.mirrorHorizontally = false,
    this.autoplay = false,
    this.showPlayOverlay = false,
    this.allowTapToToggle = false,
    this.onOverlayInteractionChanged,
    this.errorLabel = 'Không đọc được media đã lưu.',
  });

  final String mediaPath;
  final NoteMediaType mediaType;
  final BorderRadius borderRadius;
  final bool isActive;
  final BoxFit fit;
  final bool mirrorHorizontally;
  final bool autoplay;
  final bool showPlayOverlay;
  final bool allowTapToToggle;
  final ValueChanged<bool>? onOverlayInteractionChanged;
  final String errorLabel;

  @override
  Widget build(BuildContext context) {
    if (mediaType.isImage) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scaleByDouble(mirrorHorizontally ? -1.0 : 1.0, 1.0, 1.0, 1.0),
          child: Image.file(
            File(mediaPath),
            fit: fit,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _MediaErrorView(label: errorLabel);
            },
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: _LocalVideoPlayerView(
        mediaPath: mediaPath,
        isActive: isActive,
        fit: fit,
        autoplay: autoplay,
        showPlayOverlay: showPlayOverlay,
        allowTapToToggle: allowTapToToggle,
        onOverlayInteractionChanged: onOverlayInteractionChanged,
        errorLabel: errorLabel,
      ),
    );
  }
}

class _LocalVideoPlayerView extends StatefulWidget {
  const _LocalVideoPlayerView({
    required this.mediaPath,
    required this.isActive,
    required this.fit,
    required this.autoplay,
    required this.showPlayOverlay,
    required this.allowTapToToggle,
    this.onOverlayInteractionChanged,
    required this.errorLabel,
  });

  final String mediaPath;
  final bool isActive;
  final BoxFit fit;
  final bool autoplay;
  final bool showPlayOverlay;
  final bool allowTapToToggle;
  final ValueChanged<bool>? onOverlayInteractionChanged;
  final String errorLabel;

  @override
  State<_LocalVideoPlayerView> createState() => _LocalVideoPlayerViewState();
}

class _LocalVideoPlayerViewState extends State<_LocalVideoPlayerView> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(
    _defaultVideoVolume,
  );

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant _LocalVideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaPath != widget.mediaPath) {
      _attachController();
      return;
    }

    if (oldWidget.isActive != widget.isActive ||
        oldWidget.autoplay != widget.autoplay) {
      _syncPlaybackState();
    }
  }

  Future<void> _attachController() async {
    final previousController = _controller;
    final controller = VideoPlayerController.file(File(widget.mediaPath));
    final initializeFuture = _initializeController(controller);

    setState(() {
      _controller = controller;
      _initializeFuture = initializeFuture;
    });

    await previousController?.dispose();
  }

  Future<void> _initializeController(VideoPlayerController controller) async {
    await controller.setLooping(true);
    await controller.initialize();
    await controller.setVolume(_volumeNotifier.value);

    if (!mounted || _controller != controller) {
      return;
    }

    await _syncPlaybackState(controller: controller);
  }

  Future<void> _syncPlaybackState({VideoPlayerController? controller}) async {
    final activeController = controller ?? _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      return;
    }

    final shouldPlay = widget.autoplay && widget.isActive;
    if (shouldPlay) {
      if (!activeController.value.isPlaying) {
        await activeController.play();
      }
      return;
    }

    if (activeController.value.isPlaying) {
      await activeController.pause();
    }
  }

  Future<void> _setVolume(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    await controller.setVolume(value);
    _volumeNotifier.value = value;
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final navigator = Navigator.of(context);
    final wasPlaying = controller.value.isPlaying;
    final startPosition = controller.value.position;
    final startVolume = _volumeNotifier.value;

    await controller.pause();

    if (!mounted) {
      return;
    }

    final result = await navigator.push<_VideoFullscreenResult>(
      PageRouteBuilder<_VideoFullscreenResult>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _VideoFullscreenPage(
            mediaPath: widget.mediaPath,
            initialPosition: startPosition,
            startPlaying: wasPlaying || widget.autoplay,
            initialVolume: startVolume,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (!mounted || _controller != controller) {
      return;
    }

    if (result != null) {
      await controller.seekTo(result.position);
      await controller.setVolume(result.volume);
      if (result.wasPlaying) {
        await controller.play();
      }
      _volumeNotifier.value = result.volume;
    } else if (wasPlaying || widget.autoplay) {
      await controller.play();
    }
  }

  @override
  void dispose() {
    _volumeNotifier.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initializeFuture = _initializeFuture;

    if (controller == null || initializeFuture == null) {
      return const _VideoLoadingSkeleton();
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MediaErrorView(label: widget.errorLabel);
        }

        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const _VideoLoadingSkeleton();
        }

        final size = controller.value.size;
        final player = SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );

        final content = Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            if (widget.allowTapToToggle)
              Positioned.fill(
                child: GestureDetector(onTap: _togglePlayback, child: player),
              )
            else
              player,
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final showOverlay =
                        widget.showPlayOverlay ||
                        (widget.allowTapToToggle && !value.isPlaying);
                    return showOverlay ? child! : const SizedBox.shrink();
                  },
                  child: const _VideoPlayOverlay(),
                ),
              ),
            ),
            Positioned(
              right: 72,
              bottom: 12,
              child: ValueListenableBuilder<double>(
                valueListenable: _volumeNotifier,
                builder: (context, volume, _) {
                  return _VideoVolumePopupButton(
                    volume: volume,
                    onChanged: _setVolume,
                    onOpenChanged: widget.onOverlayInteractionChanged,
                  );
                },
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _VideoOverlayButton(
                icon: Icons.fullscreen_rounded,
                onPressed: _openFullscreen,
              ),
            ),
          ],
        );

        return content;
      },
    );
  }
}

class _VideoLoadingSkeleton extends StatelessWidget {
  const _VideoLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NoteSkeletonBox(
          baseColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(0),
        ),
        IgnorePointer(
          child: Center(
            child: NoteSkeletonBox(
              width: 72,
              height: 72,
              shape: BoxShape.circle,
              baseColor: Colors.white.withValues(alpha: 0.10),
              highlightColor: Colors.white.withValues(alpha: 0.18),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoFullscreenPage extends StatefulWidget {
  const _VideoFullscreenPage({
    required this.mediaPath,
    required this.initialPosition,
    required this.startPlaying,
    required this.initialVolume,
  });

  final String mediaPath;
  final Duration initialPosition;
  final bool startPlaying;
  final double initialVolume;

  @override
  State<_VideoFullscreenPage> createState() => _VideoFullscreenPageState();
}

class _VideoFullscreenPageState extends State<_VideoFullscreenPage> {
  static const _seekStep = Duration(seconds: 15);
  static const _playbackSpeeds = [0.5, 1.0, 1.25, 1.5, 2.0];

  late final VideoPlayerController _controller = VideoPlayerController.file(
    File(widget.mediaPath),
  );
  late final Future<void> _initializeFuture = _initializeController();
  double _playbackSpeed = 1.0;
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(
    _defaultVideoVolume,
  );
  double? _dragPositionMs;
  bool _wasPlayingBeforeDrag = false;

  Future<void> _initializeController() async {
    await _controller.setLooping(true);
    await _controller.initialize();
    _volumeNotifier.value = widget.initialVolume;
    await _controller.setVolume(_volumeNotifier.value);
    await _controller.setPlaybackSpeed(_playbackSpeed);
    await _controller.seekTo(widget.initialPosition);

    if (widget.startPlaying) {
      await _controller.play();
    }
  }

  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) {
      return;
    }

    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
  }

  Future<void> _seekRelative(Duration offset) async {
    if (!_controller.value.isInitialized) {
      return;
    }

    final duration = _controller.value.duration;
    final current = _controller.value.position;
    final rawTarget = current + offset;
    final target = rawTarget < Duration.zero
        ? Duration.zero
        : (rawTarget > duration ? duration : rawTarget);
    await _controller.seekTo(target);
  }

  Future<void> _changePlaybackSpeed(double speed) async {
    await _controller.setPlaybackSpeed(speed);
    if (mounted) {
      setState(() {
        _playbackSpeed = speed;
      });
    }
  }

  Future<void> _setVolume(double value) async {
    await _controller.setVolume(value);
    _volumeNotifier.value = value;
  }

  void _handleSeekStart(double value) {
    _wasPlayingBeforeDrag = _controller.value.isPlaying;
    _dragPositionMs = value;
    if (_wasPlayingBeforeDrag) {
      _controller.pause();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _handleSeekChanged(double value) {
    if (mounted) {
      setState(() {
        _dragPositionMs = value;
      });
    }
  }

  Future<void> _handleSeekEnd(double value) async {
    final target = Duration(milliseconds: value.round());
    await _controller.seekTo(target);
    if (_wasPlayingBeforeDrag) {
      await _controller.play();
    }
    if (mounted) {
      setState(() {
        _dragPositionMs = null;
      });
    }
  }

  void _close() {
    Navigator.of(context).pop(
      _VideoFullscreenResult(
        position: _controller.value.position,
        wasPlaying: _controller.value.isPlaying,
        volume: _volumeNotifier.value,
      ),
    );
  }

  @override
  void dispose() {
    _volumeNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _MediaErrorView(label: 'Không mở được video.');
            }

            if (snapshot.connectionState != ConnectionState.done ||
                !_controller.value.isInitialized) {
              return const ColoredBox(
                color: Colors.black,
                child: _VideoLoadingSkeleton(),
              );
            }

            final size = _controller.value.size;

            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: _togglePlayback,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.54),
                        ],
                        stops: const [0, 0.24, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _VideoOverlayButton(
                    icon: Icons.close_rounded,
                    onPressed: _close,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 128,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _volumeNotifier,
                    builder: (context, volume, _) {
                      return _VideoVolumePopupButton(
                        volume: volume,
                        onChanged: _setVolume,
                        onOpenChanged: null,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 72,
                  child: PopupMenuButton<double>(
                    initialValue: _playbackSpeed,
                    tooltip: 'Tốc độ phát',
                    color: Colors.black.withValues(alpha: 0.88),
                    onSelected: _changePlaybackSpeed,
                    itemBuilder: (context) {
                      return _playbackSpeeds
                          .map((speed) {
                            return PopupMenuItem<double>(
                              value: speed,
                              child: Text(
                                '${_formatSpeed(speed)}x',
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          })
                          .toList(growable: false);
                    },
                    child: _VideoOverlayLabelButton(
                      label: '${_formatSpeed(_playbackSpeed)}x',
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _VideoOverlayButton(
                    icon: Icons.fullscreen_exit_rounded,
                    onPressed: _close,
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final maxPositionMs = value.duration.inMilliseconds <= 0
                          ? 1.0
                          : value.duration.inMilliseconds.toDouble();
                      final currentPositionMs =
                          (_dragPositionMs ??
                                  value.position.inMilliseconds.toDouble())
                              .clamp(0.0, maxPositionMs);
                      final displayedPosition = Duration(
                        milliseconds: currentPositionMs.round(),
                      );

                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white.withValues(
                                    alpha: 0.16,
                                  ),
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7,
                                  ),
                                ),
                                child: Slider(
                                  value: currentPositionMs,
                                  min: 0,
                                  max: maxPositionMs,
                                  onChangeStart: _handleSeekStart,
                                  onChanged: _handleSeekChanged,
                                  onChangeEnd: _handleSeekEnd,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(displayedPosition),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDuration(value.duration),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _VideoTransportButton(
                                    icon: Icons.fast_rewind_rounded,
                                    label: '-15',
                                    onPressed: () => _seekRelative(-_seekStep),
                                  ),
                                  const SizedBox(width: 10),
                                  _VideoTransportButton(
                                    icon: value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    iconSize: 32,
                                    buttonSize: 62,
                                    onPressed: _togglePlayback,
                                  ),
                                  const SizedBox(width: 10),
                                  _VideoTransportButton(
                                    icon: Icons.fast_forward_rounded,
                                    label: '+15',
                                    onPressed: () => _seekRelative(_seekStep),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, child) {
                        return value.isPlaying
                            ? const SizedBox.shrink()
                            : child!;
                      },
                      child: const _VideoPlayOverlay(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VideoFullscreenResult {
  const _VideoFullscreenResult({
    required this.position,
    required this.wasPlaying,
    required this.volume,
  });

  final Duration position;
  final bool wasPlaying;
  final double volume;
}

class _VideoPlayOverlay extends StatelessWidget {
  const _VideoPlayOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            shape: BoxShape.circle,
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoOverlayButton extends StatelessWidget {
  const _VideoOverlayButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.52),
      ),
    );
  }
}

class _VideoOverlayLabelButton extends StatelessWidget {
  const _VideoOverlayLabelButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _VideoVolumePopupButton extends StatefulWidget {
  const _VideoVolumePopupButton({
    required this.volume,
    required this.onChanged,
    this.onOpenChanged,
  });

  final double volume;
  final Future<void> Function(double) onChanged;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<_VideoVolumePopupButton> createState() =>
      _VideoVolumePopupButtonState();
}

class _VideoVolumePopupButtonState extends State<_VideoVolumePopupButton> {
  static const _buttonSize = 52.0;
  static const _popupGap = 8.0;
  static const _popupVerticalPadding = 12.0;
  static const _popupTextHeight = 17.0;
  static const _popupTextSpacing = 6.0;
  static const _volumeDebounce = Duration(milliseconds: 220);

  final GlobalKey _buttonKey = GlobalKey();
  bool _isOpen = false;
  bool _openAbove = true;
  double _sliderExtent = 132;
  double? _dragVolume;
  Timer? _debounceTimer;

  double get _popupHeight =>
      (_popupVerticalPadding * 2) +
      _popupTextHeight +
      _popupTextSpacing +
      _sliderExtent;

  double get _containerHeight =>
      _isOpen ? _popupHeight + _popupGap + _buttonSize : _buttonSize;

  double get _displayedVolume => _dragVolume ?? widget.volume;

  void _toggle() {
    final nextOpen = !_isOpen;
    setState(() {
      _isOpen = nextOpen;
    });
    widget.onOpenChanged?.call(nextOpen);

    if (!_isOpen) {
      _dragVolume = null;
      _debounceTimer?.cancel();
    }

    if (_isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _measureAvailableSpace();
        }
      });
    }
  }

  void _measureAvailableSpace() {
    final buttonContext = _buttonKey.currentContext;
    if (buttonContext == null) {
      return;
    }

    final renderBox = buttonContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final safeTop = mediaQuery.padding.top + 16;
    final safeBottom = mediaQuery.padding.bottom + 16;
    final buttonHeight = renderBox.size.height;
    final availableAbove = (position.dy - safeTop)
        .clamp(72.0, 220.0)
        .toDouble();
    final availableBelow =
        (screenHeight - safeBottom - position.dy - buttonHeight)
            .clamp(72.0, 220.0)
            .toDouble();
    final openAbove = availableAbove >= availableBelow;

    setState(() {
      _openAbove = openAbove;
      _sliderExtent = openAbove ? availableAbove : availableBelow;
    });
  }

  void _queueVolumeCommit(double value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_volumeDebounce, () {
      widget.onChanged(value);
    });
  }

  void _handleVolumeChanged(double value) {
    setState(() {
      _dragVolume = value;
    });
    _queueVolumeCommit(value);
  }

  Future<void> _handleVolumeChangeEnd(double value) async {
    _debounceTimer?.cancel();
    await widget.onChanged(value);

    if (mounted) {
      setState(() {
        _dragVolume = null;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _VideoVolumePopupButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isOpen) {
      _dragVolume = null;
    }
  }

  @override
  void dispose() {
    widget.onOpenChanged?.call(false);
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _buttonSize,
      height: _containerHeight,
      child: Stack(
        children: [
          if (_isOpen)
            Positioned(
              top: _openAbove ? 0 : _buttonSize + _popupGap,
              bottom: _openAbove ? null : null,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: _popupVerticalPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_displayedVolume * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: _popupTextSpacing),
                      RotatedBox(
                        quarterTurns: 3,
                        child: SizedBox(
                          width: _sliderExtent,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                            ),
                            child: Slider(
                              value: _displayedVolume,
                              onChanged: _handleVolumeChanged,
                              onChangeEnd: _handleVolumeChangeEnd,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            key: _buttonKey,
            left: 0,
            right: 0,
            bottom: _openAbove ? 0 : null,
            top: _openAbove ? null : 0,
            child: _VideoOverlayButton(
              icon: _volumeIcon(widget.volume),
              onPressed: _toggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoTransportButton extends StatelessWidget {
  const _VideoTransportButton({
    required this.icon,
    required this.onPressed,
    this.label,
    this.iconSize = 24,
    this.buttonSize = 52,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final double iconSize;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: IconButton.filledTonal(
              onPressed: onPressed,
              icon: Icon(icon, size: iconSize, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.52),
              ),
            ),
          ),
          if (label != null)
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaErrorView extends StatelessWidget {
  const _MediaErrorView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration value) {
  final totalSeconds = value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }

  return '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
}

String _formatSpeed(double speed) {
  return speed % 1 == 0 ? speed.toStringAsFixed(0) : speed.toStringAsFixed(2);
}

IconData _volumeIcon(double volume) {
  if (volume <= 0.001) {
    return Icons.volume_off_rounded;
  }

  if (volume < 0.5) {
    return Icons.volume_down_rounded;
  }

  return Icons.volume_up_rounded;
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
