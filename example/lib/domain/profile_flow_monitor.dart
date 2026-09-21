import 'dart:async';

import 'package:flutter/foundation.dart';

/// Application-owned instrumentation used to make the profile scope visible.
class ProfileFlowMonitor extends ChangeNotifier {
  var _closedFlows = 0;

  int get closedFlows => _closedFlows;

  void recordClosedFlow() {
    _closedFlows++;
    // A scope can close while Flutter is unmounting its route. Delay the
    // notification until the framework unlocks the widget tree.
    scheduleMicrotask(notifyListeners);
  }
}
