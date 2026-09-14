import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Item descriptor for [FloatingNavBar].
class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.key,
    this.showBadge = false,
    this.badgeColor = AppColors.behind,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Key? key;
  final bool showBadge;
  final Color badgeColor;
}

/// A premium floating capsule navigation bar with smooth animated selection pills,
/// glassmorphism blur, tactile feedback, and subtle glowing borders.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealDeep.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = index == currentIndex;

                    return _NavBarItemWidget(
                      key: item.key,
                      item: item,
                      isSelected: isSelected,
                      onTap: () {
                        if (!isSelected) {
                          HapticFeedback.selectionClick();
                          onTap(index);
                        }
                      },
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItemWidget extends StatelessWidget {
  const _NavBarItemWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: AppColors.teal.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 14 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.teal.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: isSelected
                ? Border.all(
                    color: AppColors.teal.withValues(alpha: 0.18),
                    width: 1,
                  )
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with optional low-item badge
              Badge(
                isLabelVisible: item.showBadge,
                backgroundColor: item.badgeColor,
                smallSize: 7,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    key: ValueKey(isSelected),
                    size: 22,
                    color: isSelected
                        ? AppColors.teal
                        : AppColors.textSecondary.withValues(alpha: 0.75),
                  ),
                ),
              ),

              // Animated text label with clean clipping during expansion
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: isSelected
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 6),
                            Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
