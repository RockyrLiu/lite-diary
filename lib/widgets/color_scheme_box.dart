import 'package:flutter/material.dart';

/// 色板预览 — 显示种子色衍生的 primary/secondary/tertiary 三色
class ColorSchemeBox extends StatelessWidget {
  final Color? seedColor;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? badge;

  const ColorSchemeBox({
    super.key,
    this.seedColor,
    this.isSelected = false,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = seedColor != null
        ? ColorScheme.fromSeed(seedColor: seedColor!, brightness: Theme.of(context).brightness)
        : Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: scheme.primary, width: 2.5) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(child: Container(color: scheme.secondary)),
                      Expanded(child: Container(color: scheme.tertiary)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(color: scheme.primary),
                ),
              ],
            ),
            if (badge != null)
              Positioned(right: 2, bottom: 2, child: badge!),
          ],
        ),
      ),
    );
  }
}
