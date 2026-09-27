import 'dart:convert';
import 'dart:io';

import 'package:factory_core/factory_core.dart';

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<Map<String, Object>> measure(int size, bool capture) async {
  var builds = 0;
  var releases = 0;
  var notifications = 0;
  final source = Factory<int>.external();
  final nodes = [source];
  for (var i = 1; i < size; i++) {
    final previous = nodes.last;
    nodes.add(Factory((ref) {
      builds++;
      return ref.watch(previous) + 1;
    }, onChange: ChangePolicy.recreate, dispose: (_) => releases++));
  }
  final scope =
      FactoryContainer(local: nodes, overrides: [source.overrideWithValue(0)]);
  scope.addListener((_) => notifications++);
  require(scope.read(nodes.last) == size - 1, 'Initial value');
  final samples = <double>[];
  final captureSamples = <double>[];
  var characters = 0;
  String? retained;
  for (var wave = 1; wave <= 50; wave++) {
    final overrides = [source.overrideWithValue(wave)];
    final watch = Stopwatch()..start();
    scope.setOverrides(overrides);
    final captureWatch = Stopwatch();
    if (capture) {
      captureWatch.start();
      retained = captureFactoryGraph(scope);
      captureWatch.stop();
      characters += retained.length;
    }
    watch.stop();
    if (wave > 10) {
      samples.add(watch.elapsedTicks * 1000000 / watch.frequency);
      captureSamples
          .add(captureWatch.elapsedTicks * 1000000 / captureWatch.frequency);
    }
    require(scope.read(nodes.last) == wave + size - 1, 'Leaf value');
    require(builds == (size - 1) * (wave + 1), 'Build count');
    require(notifications == size * wave, 'Notification count');
    require(releases == 0, 'Early cleanup');
  }
  await scope.close();
  require(releases == builds, 'Cleanup count');
  require(!capture || retained!.contains('generation'), 'Retained snapshot');
  double percentile(double p) =>
      (samples.toList()..sort())[(samples.length * p).ceil() - 1];
  return {
    'size': size,
    'capture': capture,
    'wallUs': samples,
    'captureUs': captureSamples,
    'p50Us': percentile(.5),
    'p95Us': percentile(.95),
    'builds': builds,
    'releases': releases,
    'notifications': notifications,
    'snapshotCharacters': characters,
  };
}

Future<void> main(List<String> arguments) async {
  final index = int.parse(arguments.single);
  final results = <Map<String, Object>>[];
  for (final capture in index == 1 ? [true, false] : [false, true]) {
    for (final size in [10, 100, 1000]) {
      results.add(await measure(size, capture));
    }
  }
  print(jsonEncode({
    'pid': pid,
    'os': Platform.operatingSystemVersion,
    'processors': Platform.numberOfProcessors,
    'results': results,
  }));
}
