import 'package:flutter/foundation.dart';

/// A service the application already provided before adopting Factory.
class Session extends ChangeNotifier {
  Session(this.displayName);

  final String displayName;
}
