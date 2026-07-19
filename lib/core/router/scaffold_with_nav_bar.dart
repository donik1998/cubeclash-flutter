import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../theme/app_colors.dart';
import 'immersive_controller.dart';
import '../theme/app_spacing.dart';

/// Bottom navigation shell (4 tabs: Timer · Race · Stats · You).
///
/// Selected tab = a `brand/primary-soft` rounded pill with brand icon + label,
/// per the design system. The signature pinch-squeeze transition (Variant C) is
/// a follow-up — see docs → `03 Engineering/Bottom Nav Motion`.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec('Timer', Icons.timer_outlined, Icons.timer),
    _TabSpec('Race', Icons.bolt_outlined, Icons.bolt),
    _TabSpec('Stats', Icons.bar_chart_outlined, Icons.bar_chart),
    _TabSpec('You', Icons.person_outline, Icons.person),
  ];

  void _onTap(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      // Chrome disappears during an immersive flow (a running solve) so the
      // nav bar cannot be mis-tapped. The shell listens to a plain boolean
      // rather than any feature's bloc — see ImmersiveController.
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: sl<ImmersiveController>(),
        builder: (BuildContext context, bool immersive, Widget? bar) =>
            immersive ? const SizedBox.shrink() : bar!,
        child: _buildBar(context),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final AppColors colors = context.colors;
    return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSurface,
          border: Border(top: BorderSide(color: colors.borderSubtle)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (int i = 0; i < _tabs.length; i++)
                  _NavItem(
                    spec: _tabs[i],
                    selected: navigationShell.currentIndex == i,
                    onTap: () => _onTap(i),
                  ),
              ],
            ),
          ),
        ));
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.brandPrimarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              selected ? spec.activeIcon : spec.icon,
              size: 24,
              color: selected ? colors.brandPrimary : colors.textMuted,
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Text(
                spec.label,
                style: TextStyle(
                  color: colors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
