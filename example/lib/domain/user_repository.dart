import 'profile_client.dart';
import 'session.dart';

/// Business code only knows the dependencies it needs through its constructor.
class UserRepository {
  UserRepository(this._client, this._session);

  final LocalProfileClient _client;
  final Session _session;

  Future<String> loadProfileName() =>
      _client.fetchProfileName(_session.displayName);
}
