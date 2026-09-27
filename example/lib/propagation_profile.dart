import 'dart:convert';
import 'dart:developer' as developer;

import 'package:factory_provider/factory_provider.dart';
import 'package:flutter/foundation.dart' show kProfileMode;
import 'package:flutter/widgets.dart';

// A separate entrypoint keeps the existing memory scenarios unchanged.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  var running = false;
  developer.registerExtension('ext.factory.profilePropagation', (
    method,
    parameters,
  ) async {
    if (!kProfileMode || running) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Requires profile mode and one request at a time.',
      );
    }
    running = true;
    try {
      final size = int.parse(parameters['size']!);
      if (![10, 100, 1000].contains(size)) {
        throw ArgumentError.value(size, 'size');
      }
      return developer.ServiceExtensionResponse.result(
        jsonEncode(await _measure(size, parameters['trace'] == 'true')),
      );
    } on Object catch (error, stack) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        '$error\n$stack',
      );
    } finally {
      running = false;
    }
  });
  runApp(const SizedBox.shrink());
}

Future<Map<String, Object>> _measure(int size, bool trace) async {
  const warmup = 10;
  const samples = 40;
  var builds = 0;
  var notifications = 0;
  var cleanup = 0;
  final source = Factory<int>.external(name: 'source');
  final nodes = <Factory<int>>[source];
  final construction = Stopwatch()..start();
  for (var index = 1; index < size; index++) {
    final previous = nodes.last;
    nodes.add(
      Factory<int>(
        (ref) {
          builds++;
          return ref.watch(previous) + 1;
        },
        onChange: ChangePolicy.recreate,
        dispose: (_) => cleanup++,
      ),
    );
  }
  final container = FactoryContainer(
    modules: [FactoryModule(factories: nodes)],
    overrides: [source.overrideWithValue(0)],
  );
  // Resolving the leaf inserts records leaf-first, opposite dependency order.
  container.read(nodes.last);
  construction.stop();
  container.addListener((_) => notifications++);
  final ticks = <int>[];
  final timer = Stopwatch();
  try {
    for (var wave = 1; wave <= warmup + samples; wave++) {
      // Allocate overrides outside the measured interval.
      final overrides = [source.overrideWithValue(wave)];
      timer
        ..reset()
        ..start();
      if (trace) {
        developer.Timeline.startSync(
          'factory.propagate',
          arguments: {'size': size, 'wave': wave, 'warmup': wave <= warmup},
        );
      }
      container.setOverrides(overrides);
      if (trace) developer.Timeline.finishSync();
      timer.stop();
      if (wave > warmup) ticks.add(timer.elapsedTicks);
      // Fail in profile builds too; assertions would be disabled.
      if (container.read(nodes.last) != wave + size - 1 ||
          builds != (size - 1) * (wave + 1) ||
          notifications != size * wave ||
          cleanup != 0) {
        throw StateError('Propagation counters/value mismatch at wave $wave');
      }
    }
  } finally {
    await container.close();
  }
  if (cleanup != builds) throw StateError('Cleanup mismatch: $cleanup/$builds');
  final micros = ticks.map((tick) => tick * 1000000 / timer.frequency).toList();
  final sorted = [...micros]..sort();
  return {
    'size': size,
    'trace': trace,
    'warmup': warmup,
    'samples': samples,
    'constructionUs': construction.elapsedMicroseconds,
    'wallUs': micros,
    'p50Us': sorted[(samples * .50).ceil() - 1],
    'p95Us': sorted[(samples * .95).ceil() - 1],
    'builds': builds,
    'notifications': notifications,
    'cleanup': cleanup,
  };
}
