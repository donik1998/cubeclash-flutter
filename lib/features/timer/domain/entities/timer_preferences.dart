import 'package:equatable/equatable.dart';

/// How the timer is started.
enum TimerStyle {
  /// Press and hold until the readout turns green, then release to start.
  /// The WCA-realistic default — it mirrors a Stackmat.
  hold,

  /// A single tap starts, a single tap stops. Easier on a phone.
  tap,
}

/// User-controlled timer behaviour, owned by Settings (docs → Navigation & IA
/// § You/Settings).
///
/// Pure domain so [TimerBloc] can be tested against any configuration without
/// touching preferences storage. Phase E persists it and feeds the real values
/// in; until then the defaults below are what the timer runs on.
class TimerPreferences extends Equatable {
  const TimerPreferences({
    this.style = TimerStyle.hold,
    this.inspectionEnabled = true,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
  });

  final TimerStyle style;

  /// WCA 15-second inspection. Off by default for casual practice is a
  /// defensible choice, but CubeClash is a competitive app — on is the default.
  final bool inspectionEnabled;

  final bool hapticsEnabled;
  final bool soundEnabled;

  /// How long the user must hold before the timer arms.
  ///
  /// 550 ms is the Stackmat convention: long enough that a stray brush of the
  /// screen can't arm the timer, short enough not to feel sticky.
  static const Duration holdThreshold = Duration(milliseconds: 550);

  TimerPreferences copyWith({
    TimerStyle? style,
    bool? inspectionEnabled,
    bool? hapticsEnabled,
    bool? soundEnabled,
  }) =>
      TimerPreferences(
        style: style ?? this.style,
        inspectionEnabled: inspectionEnabled ?? this.inspectionEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );

  @override
  List<Object?> get props =>
      <Object?>[style, inspectionEnabled, hapticsEnabled, soundEnabled];
}
