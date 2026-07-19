import 'package:flutter/foundation.dart';

/// Whether the app is in an immersive flow and the shell chrome should hide.
///
/// **Why this rather than a full-screen route.** The architecture rule is that
/// immersive flows live outside the shell so the nav bar cannot be mis-tapped.
/// That is exactly right for the Live Race, which is a genuinely different
/// screen you navigate to — and it is what Phase D does.
///
/// The *running solve* is a different case. It is the same screen in a
/// different state, entered and left many times a minute, on the most
/// latency-critical interaction in the app. Pushing and popping a route around
/// every solve buys the same nav-bar safety at the cost of a navigation on the
/// press that starts the timer. This notifier gets the stated benefit — the bar
/// is gone, so it cannot be hit — for the price of one rebuild.
///
/// A [ValueNotifier] rather than bloc state because the shell must not depend
/// on any feature's bloc; it only needs one boolean.
class ImmersiveController extends ValueNotifier<bool> {
  ImmersiveController() : super(false);

  // ignore: use_setters_to_change_properties — reads better at the call site.
  void set(bool immersive) => value = immersive;
}
