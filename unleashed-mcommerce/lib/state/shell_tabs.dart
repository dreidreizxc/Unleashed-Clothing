import 'package:flutter/foundation.dart';

/// A tiny global request channel so screens presented above the main shell
/// (checkout success, order detail) can ask the shell to switch tabs.
class ShellTabs {
  ShellTabs._();

  static const int home = 0;
  static const int orders = 1;
  static const int cart = 2;
  static const int notifications = 3;
  static const int profile = 4;

  static final ValueNotifier<int> request = ValueNotifier<int>(home);

  static void go(int tab) {
    request.value = tab;
  }
}
