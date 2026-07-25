import 'package:equatable/equatable.dart';

/// A visual family for a badge, mapped to an icon by the presentation layer.
///
/// The domain stays free of Flutter, so it names the icon rather than holding
/// one — `profile_page.dart` turns each into an `IconData`.
enum BadgeIcon {
  firstSolve,
  speed,
  milestone,
  streak,
  race,
  podium,
  allEvents,
  comeback,
}

/// An achievement — earned or still locked.
///
/// Gamification is server-owned in production (the server decides when a badge
/// is earned, the same way it owns `is_pb` and Elo). The fake seeds a plausible
/// set so the profile has something real to show; the real repository will read
/// them from the backend.
class Badge extends Equatable {
  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.earned = false,
    this.progressLabel,
  });

  final String id;
  final String name;
  final String description;
  final BadgeIcon icon;
  final bool earned;

  /// For a locked badge, how close you are — e.g. `72/100`. Null when earned or
  /// when there is nothing to count toward.
  final String? progressLabel;

  @override
  List<Object?> get props =>
      <Object?>[id, name, description, icon, earned, progressLabel];
}
