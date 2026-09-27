import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:factory_core/factory_core.dart';

Future<(String, WeakReference<FactoryContainer>, WeakReference<Object>)>
    closedGraph() async {
  final factory = Factory<Object>((_) => Object());
  final scope = FactoryContainer(local: [factory]);
  final value = WeakReference(scope.read(factory));
  final snapshot = captureFactoryGraph(scope);
  await scope.close();
  return (snapshot, WeakReference(scope), value);
}

Future<void> main() async {
  final (snapshot, scope, value) = await closedGraph();
  final service = (await Service.getInfo()).serverUri!;
  final uri = service.resolve('getAllocationProfile').replace(queryParameters: {
    'isolateId': Service.getIsolateId(Isolate.current)!,
    'gc': 'true',
  });
  final client = HttpClient();
  try {
    // Full collections also clear temporary async frames after close.
    for (var i = 0; i < 3; i++) {
      final response = await (await client.getUrl(uri)).close();
      final body = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
      if (body.containsKey('error')) throw StateError('GC request failed');
    }
    if (scope.target != null || value.target != null) {
      throw StateError('Closed graph retained while keeping a snapshot');
    }
    if (!snapshot.contains('value=present')) throw StateError('Lost snapshot');
    print('Retained snapshot: scope and instance collected after close.');
  } finally {
    client.close(force: true);
  }
}
