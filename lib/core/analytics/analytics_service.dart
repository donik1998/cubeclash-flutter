/// Analytics abstraction. The default implementation is a no-op so the app runs
/// with zero configuration. Wire PostHog (client events) when keys are set;
/// authoritative events (`race_completed`, `is_pb`) fire server-side.
/// See docs → `03 Engineering/Observability & Analytics`.
abstract class AnalyticsService {
  void capture(String event, {Map<String, Object?> properties});
  void screen(String name);
}

class NoopAnalytics implements AnalyticsService {
  const NoopAnalytics();

  @override
  void capture(String event, {Map<String, Object?> properties = const {}}) {}

  @override
  void screen(String name) {}
}
