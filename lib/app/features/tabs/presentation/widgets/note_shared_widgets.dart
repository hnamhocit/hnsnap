import 'package:flutter/material.dart';

class NoteActionIconButton extends StatelessWidget {
  const NoteActionIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: color,
      iconSize: 28,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
    );
  }
}

class NoteCaptureButton extends StatelessWidget {
  const NoteCaptureButton({
    super.key,
    required this.onPressed,
    required this.color,
    required this.iconColor,
    required this.icon,
    this.size = 92,
    this.iconSize = 36,
  });

  final VoidCallback? onPressed;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.28), width: 3),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.9), color],
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            splashRadius: 30,
            icon: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class NoteBottomCircleActionButton extends StatelessWidget {
  const NoteBottomCircleActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 24),
      color: color,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(52),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
    );
  }
}

class NoteOverlayInputChip extends StatelessWidget {
  const NoteOverlayInputChip({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.icon,
    required this.hintText,
    required this.textColor,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
    required this.width,
    this.keyboardType,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final IconData icon;
  final String hintText;
  final Color textColor;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;
  final double width;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final chipShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: borderColor),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        final isEditing = focusNode.hasFocus;

        if (isEditing) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 1,
              keyboardType: keyboardType,
              textInputAction: TextInputAction.done,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textColor),
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.72),
                ),
                prefixIcon: Icon(icon, size: 18, color: iconColor),
                filled: true,
                fillColor: backgroundColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: chipShape,
                enabledBorder: chipShape,
                focusedBorder: chipShape.copyWith(
                  borderSide: BorderSide(color: iconColor, width: 1.5),
                ),
              ),
            ),
          );
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              constraints: BoxConstraints(maxWidth: width),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      hasText ? controller.text.trim() : hintText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasText
                            ? textColor
                            : textColor.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class NotePreviewDisplayChip extends StatelessWidget {
  const NotePreviewDisplayChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.maxWidth = 220,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class NoteSkeletonBox extends StatelessWidget {
  const NoteSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.baseColor,
    this.highlightColor,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBase = baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final resolvedHighlight =
        highlightColor ?? theme.colorScheme.surfaceContainerHigh;

    return _NoteSkeletonShimmer(
      baseColor: resolvedBase,
      highlightColor: resolvedHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: resolvedBase,
          shape: shape,
          borderRadius: shape == BoxShape.circle ? null : borderRadius,
        ),
      ),
    );
  }
}

class _NoteSkeletonShimmer extends StatefulWidget {
  const _NoteSkeletonShimmer({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<_NoteSkeletonShimmer> createState() => _NoteSkeletonShimmerState();
}

class _NoteSkeletonShimmerState extends State<_NoteSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.8 + (progress * 2.8), -0.3),
              end: Alignment(-0.8 + (progress * 2.8), 0.3),
              colors: [
                widget.baseColor,
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
                widget.baseColor,
              ],
              stops: const [0, 0.35, 0.5, 0.65, 1],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}
