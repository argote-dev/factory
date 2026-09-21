/// A local HTTP-shaped client. It deliberately performs no network I/O.
class LocalProfileClient {
  var isClosed = false;

  Future<String> fetchProfileName(String sessionName) async {
    if (isClosed) {
      throw StateError('The profile client has already been closed.');
    }
    return '$sessionName profile';
  }

  Future<void> close() async => isClosed = true;
}
