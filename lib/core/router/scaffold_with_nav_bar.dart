import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'immersive_controller.dart';

/// Identifies the nav item's motion wrapper, so tests can assert on the
/// signature animation rather than on transforms the framework adds itself.
const Key navItemMotionKey = Key('nav-item-motion');

/// Bottom navigation shell (4 tabs: Timer · Race · Stats · You).
///
/// Selected tab = a `brand/primary-soft` rounded pill, per the design system.
///
/// ## Signature motion — "Variant C: pinch-squeeze + directional icon tilt"
///
/// Spec: docs → `03 Engineering/Bottom Nav Motion`.
///
///  * The pill **slides** to the tapped tab on a spring
///    (`cubic-bezier(.45,1.6,.5,1)`, ~460 ms) — it overshoots and settles.
///  * Mid-flight it **pinches**: `scaleX` 1 → 0.62 → 1 and `scaleY`
///    1 → 1.08 → 1 about its centre. Squash-and-stretch, so it reads as one
///    object accelerating rather than a rectangle teleporting. No skew — skew
///    on a rounded rect distorts the corner radii and looks like a bug.
///  * The newly selected **icon** pops 0.9 → 1.2 → 1.0, tilts
///    `dir × 15°` *toward* the direction of travel and unwinds, and bobs
///    `-3 px` at the peak. ~440 ms.
///
/// All of it is driven from **one** [AnimationController] per tab change; the
/// icon's window is an [Interval] on the same timeline, so nothing can drift
/// out of sync.
///
/// Under `MediaQuery.disableAnimations` every transform is dropped and the
/// pill simply crossfades — the motion is characterful, and character is
/// exactly what someone with vestibular sensitivity has asked not to receive.
class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar>
    with SingleTickerProviderStateMixin {
  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec('Timer', Icons.timer_outlined, Icons.timer),
    _TabSpec('Race', Icons.bolt_outlined, Icons.bolt),
    _TabSpec('Stats', Icons.bar_chart_outlined, Icons.bar_chart),
    _TabSpec('You', Icons.person_outline, Icons.person),
  ];

  /// Pill travel. The icon finishes marginally earlier (see [_iconWindow]).
  static const Duration _duration = Duration(milliseconds: 460);

  /// Springy: overshoots past 1 and settles back.
  /// `cubic-bezier(.45,1.6,.5,1)` from the motion spec.
  static const Cubic spring = Cubic(0.45, 1.6, 0.5, 1);

  /// 440 ms of the 460 ms timeline.
  static const Interval iconWindow = Interval(0, 440 / 460);

  /// Starts **completed**, not at zero.
  ///
  /// The animation runs 0 → 1, and its 0 pose is "small, tilted and lifted".
  /// A controller resting at 0 would render the initially-selected tab stuck
  /// in that pose on first paint, and again on every rebuild that isn't a tab
  /// change. Resting at 1 is the identity pose; `forward(from: 0)` replays it.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1,
  );

  /// Where the pill is travelling from and to.
  late int _fromIndex = widget.navigationShell.currentIndex;
  late int _toIndex = widget.navigationShell.currentIndex;

  /// -1, 0 or +1 — the tilt leans toward the direction of travel.
  int _direction = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    final int current = widget.navigationShell.currentIndex;

    if (index != current) {
      setState(() {
        _fromIndex = current;
        _toIndex = index;
        _direction = index > current ? 1 : -1;
      });
      _controller.forward(from: 0);
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == current,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      // Chrome disappears during an immersive flow (a running solve) so the
      // nav bar cannot be mis-tapped. The shell listens to a plain boolean
      // rather than any feature's bloc — see ImmersiveController.
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: sl<ImmersiveController>(),
        builder: (BuildContext context, bool immersive, _) =>
            immersive ? const SizedBox.shrink() : _buildBar(context),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final AppColors colors = context.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final int selected = widget.navigationShell.currentIndex;

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
          child: SizedBox(
            height: 56,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) => Stack(
                children: <Widget>[
                  _Pill(
                    fromIndex: _fromIndex,
                    toIndex: _toIndex,
                    selectedIndex: selected,
                    tabCount: _tabs.length,
                    progress: _controller.value,
                    reduceMotion: reduceMotion,
                    color: colors.brandPrimarySoft,
                  ),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < _tabs.length; i++)
                        Expanded(
                          child: _NavItem(
                            spec: _tabs[i],
                            selected: selected == i,
                            // Only the tab being moved *to* animates.
                            animation: i == _toIndex ? _controller : null,
                            direction: _direction,
                            reduceMotion: reduceMotion,
                            onTap: () => _onTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sliding, pinching selection pill.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.fromIndex,
    required this.toIndex,
    required this.selectedIndex,
    required this.tabCount,
    required this.progress,
    required this.reduceMotion,
    required this.color,
  });

  final int fromIndex;
  final int toIndex;
  final int selectedIndex;
  final int tabCount;
  final double progress;
  final bool reduceMotion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      // Crossfade: no travel, no squash. The pill simply appears under the
      // selected tab.
      return Align(
        alignment: Alignment(_alignmentFor(selectedIndex), 0),
        child: FractionallySizedBox(
          widthFactor: 1 / tabCount,
          heightFactor: 1,
          child: _body(),
        ),
      );
    }

    final double eased =
        _ScaffoldWithNavBarState.spring.transform(progress.clamp(0.0, 1.0));

    // Overshoot means `eased` can exceed 1 — that is the point, and the
    // alignment lerp handles it without clamping.
    final double x = _lerp(
      _alignmentFor(fromIndex),
      _alignmentFor(toIndex),
      eased,
    );

    // Pinch: hardest at the midpoint, back to rest at both ends.
    // sin(πt) peaks at 1 when t = 0.5 and is 0 at both ends.
    final double pinch = _pinchAmount(progress);
    final double scaleX = 1 - 0.38 * pinch; // 1 → 0.62 → 1
    final double scaleY = 1 + 0.08 * pinch; // 1 → 1.08 → 1

    return Align(
      alignment: Alignment(x, 0),
      child: FractionallySizedBox(
        widthFactor: 1 / tabCount,
        heightFactor: 1,
        child: Transform(
          alignment: Alignment.center, // origin: centre, per the spec
          transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() => Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      );

  /// Tab index → x in Alignment space (-1 … +1).
  double _alignmentFor(int index) =>
      tabCount == 1 ? 0 : (index / (tabCount - 1)) * 2 - 1;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// 0 → 1 → 0 across the timeline, peaking at the midpoint.
  static double _pinchAmount(double t) {
    final double clamped = t.clamp(0.0, 1.0);
    return 1 - (2 * clamped - 1).abs();
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
    required this.animation,
    required this.direction,
    required this.reduceMotion,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;

  /// Non-null only for the tab being animated to.
  final Animation<double>? animation;
  final int direction;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color tint = selected ? colors.brandPrimary : colors.textMuted;

    Widget icon = Icon(
      selected ? spec.activeIcon : spec.icon,
      size: 24,
      color: tint,
    );

    final Animation<double>? anim = animation;
    if (!reduceMotion && selected && anim != null && anim.value < 1) {
      icon = _animatedIcon(icon, anim.value);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        // The whole tab cell is the target, which on a 4-up bar is ~90×56 —
        // comfortably past the 48dp minimum in both axes.
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              icon,
              const SizedBox(height: 2),
              Text(
                spec.label,
                style: AppTypography.caption.copyWith(
                  color: tint,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Identifies the motion wrapper so tests can assert on *our* transforms
  /// rather than the several the framework contributes on its own.
  static const Key motionKey = Key('nav-item-motion');

  /// Pop, tilt and bob — all read off the same [t] as the pill.
  Widget _animatedIcon(Widget icon, double t) {
    final double windowed =
        _ScaffoldWithNavBarState.iconWindow.transform(t.clamp(0.0, 1.0));

    // 0.9 → 1.2 → 1.0: overshoot on the way in, settle after.
    final double scale = windowed < 0.5
        ? 0.9 + (1.2 - 0.9) * (windowed / 0.5)
        : 1.2 + (1.0 - 1.2) * ((windowed - 0.5) / 0.5);

    // Tilts toward the direction of travel, then unwinds to square.
    const double maxTiltRadians = 15 * 3.1415926535 / 180;
    final double tilt = direction * maxTiltRadians * (1 - windowed);

    // Bobs up at the peak of the pop.
    final double bob = -3.0 * (1 - (2 * windowed - 1).abs());

    return Transform.translate(
      key: motionKey,
      offset: Offset(0, bob),
      child: Transform.rotate(
        angle: tilt,
        child: Transform.scale(scale: scale, child: icon),
      ),
    );
  }
}
