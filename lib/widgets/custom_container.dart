import 'package:flutter/material.dart';
import 'package:quranapplication/providers/show_overlay_provider.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';

class CustomContainer extends StatelessWidget {
  const CustomContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.offsetY = 1,
  });

  final Widget child;
  final EdgeInsets padding;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Consumer<ShowOverlayProvider>(
      child: child,
      builder: (context, overlay, ch) {
        return AnimatedSlide(
          curve: Curves.easeOutQuart,
          duration: const Duration(milliseconds: 200),
          offset: Offset(0, overlay.isShowOverlay ? 0 : offsetY * .8),
          child: AnimatedOpacity(
            curve: Curves.easeOutQuart,
            duration: const Duration(milliseconds: 200),
            opacity: overlay.isShowOverlay ? 1 : 0,
            child: Container(
              padding: padding,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.overlay,
                border: Border.all(
                  width: 1.5,
                  color: colorScheme.gold.withValues(alpha: isDark ? 0.6 : 0.8),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ch,
            ),
          ),
        );
      },
    );
  }
}
