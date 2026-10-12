// 支援 Web / Windows 滑鼠 Hover 視覺反饋與 Android 觸控水波紋的通用卡片元件
import 'package:flutter/material.dart';

class HoverableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accentColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const HoverableCard({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
  });

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = widget.accentColor ?? colorScheme.primary;

    return Padding(
      padding: widget.margin,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -3.0 : 0.0, 0),
          decoration: BoxDecoration(
            color: _isHovered
                ? Color.alphaBlend(
                    highlightColor.withValues(alpha: 0.04),
                    colorScheme.surface,
                  )
                : colorScheme.surface,
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _isHovered
                  ? highlightColor.withValues(alpha: 0.65)
                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: highlightColor.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: widget.borderRadius,
            child: InkWell(
              borderRadius: widget.borderRadius,
              onTap: widget.onTap,
              hoverColor: highlightColor.withValues(alpha: 0.04),
              splashColor: highlightColor.withValues(alpha: 0.1),
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
