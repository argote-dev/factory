import 'package:flutter/foundation.dart';

import '../domain/profile_flow_monitor.dart';
import '../domain/user_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._repository, this._flowMonitor);

  final UserRepository _repository;
  final ProfileFlowMonitor _flowMonitor;
  String? _profileName;
  Object? _error;
  var _isLoading = false;

  String? get profileName => _profileName;
  Object? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _profileName = await _repository.loadProfileName();
    } on Object catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _flowMonitor.recordClosedFlow();
    super.dispose();
  }
}
