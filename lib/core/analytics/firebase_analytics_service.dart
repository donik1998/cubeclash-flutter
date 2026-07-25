import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_service.dart';
import 'firebase_event_sanitizer.dart';

/// [AnalyticsService] on Google Analytics for Firebase.
///
/// Slots in behind the existing seam, so **no call site changes**: the blocks
/// and cubits keep calling `capture('solve_completed', properties: {...})` and
/// this adapter makes it something Firebase will accept
/// ([FirebaseEventSanitizer] owns those rules).
///
/// ## Two properties this deliberately guarantees
///
/// **It never throws into the caller.** `capture` and `screen` are `void` by
/// interface — they are called from bloc handlers on the path of a solve
/// starting or stopping. An analytics failure (no network, an uninitialised
/// plugin, a malformed payload) must never surface as a broken timer, so every
/// send is fire-and-forget and every error is swallowed here.
///
/// **It never makes the user wait.** Nothing is awaited at the call site. A
/// solve is latency-critical; blocking a state transition on an HTTP round trip
/// to Google would be indefensible.
///
/// What it does *not* do is decide competitive truth. `is_pb`, `elo` and rank
/// are server-owned (docs → API Design) and are not derived or sent from here;
/// the authoritative events fire server-side.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._analytics);

  /// The default binding — Firebase must already be initialised.
  FirebaseAnalyticsService.instance() : _analytics = FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  void capture(String event, {Map<String, Object?> properties = const {}}) {
    final String? name = FirebaseEventSanitizer.eventName(event);
    if (name == null) return;

    _fireAndForget(
      () => _analytics.logEvent(
        name: name,
        parameters: FirebaseEventSanitizer.parameters(properties),
      ),
    );
  }

  @override
  void screen(String name) {
    final String? screenName = FirebaseEventSanitizer.eventName(name);
    if (screenName == null) return;

    _fireAndForget(
      () => _analytics.logScreenView(screenName: screenName),
    );
  }

  /// Sends without blocking the caller and without letting a failure escape.
  ///
  /// The `catchError` covers an async rejection; the `try` covers a synchronous
  /// throw from the plugin before it ever returns a future.
  void _fireAndForget(Future<void> Function() send) {
    try {
      unawaited(send().catchError((Object _) {}));
    } catch (_) {
      // Analytics is telemetry, not a feature. Losing an event is acceptable;
      // taking the app down with it is not.
    }
  }
}
