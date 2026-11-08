import 'package:flutter/material.dart';

/// The navigator that owns [AuthGate].
///
/// Guests can push screens such as the cart on top of the storefront. When a
/// guest starts checkout, [AuthGate] swaps the root widget for the login
/// prompt; the pushed screens must be removed so that prompt becomes visible.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Removes every route above the root so a root-level screen is visible.
void unwindToRoot() {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.popUntil((route) => route.isFirst);
}
