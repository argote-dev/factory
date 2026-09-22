import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:factory/factory.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appKey = GlobalKey<_MemoryProfileAppState>();
  developer.registerExtension('ext.factory.runMemoryScenario', (
    method,
    parameters,
  ) async {
    final scenario = parameters['scenario'];
    if (scenario == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Missing scenario.',
      );
    }
    try {
      final counters = scenario == 'flutterScopeLifecycle'
          ? await appKey.currentState!.runScopeCycles()
          : await _runCoreScenario(scenario);
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'scenario': scenario, ...counters}),
      );
    } on Object catch (error, stackTrace) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        '$error\n$stackTrace',
      );
    }
  });
  runApp(_MemoryProfileApp(key: appKey));
}

Future<Map<String, Object>> _runCoreScenario(String scenario) async {
  return switch (scenario) {
    'containerLifecycle' => _containerLifecycle(),
    'uniqueWithoutCleanup' => _uniqueWithoutCleanup(),
    'uniqueWithCleanup' => _uniqueWithCleanup(),
    'scopedReplacements' => _scopedReplacements(),
    'propagationGraphs' => _propagationGraphs(),
    _ => throw ArgumentError.value(scenario, 'scenario', 'Unknown scenario'),
  };
}

Future<Map<String, Object>> _containerLifecycle() async {
  var subscriptions = 0;
  var cancellations = 0;
  var releases = 0;
  for (var cycle = 0; cycle < 100; cycle += 1) {
    final signal = _Signal(cycle);
    final source = Factory<_Signal>.external(name: 'profileSignal');
    final target = Factory<Object>(
      (ref) {
        ref.read(source);
        ref.watch(source);
        ref.select(source, (value) => value.value);
        return Object();
      },
      onChange: ChangePolicy.recreate,
      dispose: (_) => releases += 1,
    );
    final container = FactoryContainer(
      modules: [
        FactoryModule(factories: [source, target]),
      ],
      overrides: [source.overrideWithValue(signal)],
      observe: (value, changed) {
        subscriptions += 1;
        final observed = value as _Signal;
        observed.listeners.add(changed);
        return () {
          cancellations += 1;
          observed.listeners.remove(changed);
        };
      },
    );
    container.read(target);
    await container.close();
  }
  return {
    'cycles': 100,
    'subscriptions': subscriptions,
    'cancellations': cancellations,
    'releases': releases,
  };
}

Future<Map<String, Object>> _uniqueWithoutCleanup() async {
  final declaration = Factory<Object>(
    (_) => Object(),
    lifetime: Lifetime.unique,
  );
  final container = FactoryContainer(
    modules: [
      FactoryModule(factories: [declaration]),
    ],
  );
  final identities = <Object>{};
  for (var index = 0; index < 1000; index += 1) {
    identities.add(container.read(declaration));
  }
  await container.close();
  return {'resolutions': identities.length};
}

Future<Map<String, Object>> _uniqueWithCleanup() async {
  var releases = 0;
  final declaration = Factory<Object>(
    (_) => Object(),
    lifetime: Lifetime.unique,
    dispose: (_) => releases += 1,
  );
  final container = FactoryContainer(
    modules: [
      FactoryModule(factories: [declaration]),
    ],
  );
  for (var index = 0; index < 1000; index += 1) {
    container.read(declaration);
  }
  await container.close();
  return {'resolutions': 1000, 'releases': releases};
}

Future<Map<String, Object>> _scopedReplacements() async {
  var releases = 0;
  final declaration = Factory<_Generation>(
    (_) => const _Generation(0),
    dispose: (_) => releases += 1,
  );
  final container = FactoryContainer(
    modules: [
      FactoryModule(factories: [declaration]),
    ],
  );
  container.read(declaration);
  for (var generation = 1; generation <= 100; generation += 1) {
    container.setOverrides([
      declaration.overrideWith(
        (_) => _Generation(generation),
        dispose: (_) => releases += 1,
      ),
    ]);
    container.read(declaration);
  }
  await container.close();
  return {'replacements': 100, 'releases': releases};
}

Future<Map<String, Object>> _propagationGraphs() async {
  var builds = 0;
  for (final size in [10, 100, 1000]) {
    final source = Factory<int>.external(name: 'graphSource');
    final declarations = <Factory<int>>[source];
    for (var index = 1; index < size; index += 1) {
      final previous = declarations.last;
      declarations.add(
        Factory<int>((ref) {
          builds += 1;
          return ref.watch(previous) + 1;
        }, onChange: ChangePolicy.recreate),
      );
    }
    final container = FactoryContainer(
      modules: [FactoryModule(factories: declarations)],
      overrides: [source.overrideWithValue(0)],
    );
    container.read(declarations.last);
    for (var wave = 1; wave <= 100; wave += 1) {
      container.setOverrides([source.overrideWithValue(wave)]);
    }
    await container.close();
  }
  return {'sizes': '10,100,1000', 'wavesPerGraph': 100, 'builds': builds};
}

class _MemoryProfileApp extends StatefulWidget {
  const _MemoryProfileApp({super.key});

  @override
  State<_MemoryProfileApp> createState() => _MemoryProfileAppState();
}

class _MemoryProfileAppState extends State<_MemoryProfileApp> {
  var _showScope = false;
  var _generation = 0;
  var _listenerAdds = 0;
  var _listenerRemoves = 0;
  var _releases = 0;
  Future<void>? _closing;

  Future<Map<String, Object>> runScopeCycles() async {
    _listenerAdds = 0;
    _listenerRemoves = 0;
    _releases = 0;
    for (var cycle = 0; cycle < 100; cycle += 1) {
      setState(() {
        _generation += 1;
        _showScope = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      setState(() => _showScope = false);
      await WidgetsBinding.instance.endOfFrame;
      await _closing;
    }
    return {
      'cycles': 100,
      'listenerAdds': _listenerAdds,
      'listenerRemoves': _listenerRemoves,
      'releases': _releases,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _showScope
          ? _profileScope(_generation)
          : const Scaffold(body: Center(child: Text('memory-profile-ready'))),
    );
  }

  Widget _profileScope(int generation) {
    final notifier = Factory<_TrackedNotifier>(
      (_) => _TrackedNotifier(
        onAdd: () => _listenerAdds += 1,
        onRemove: () => _listenerRemoves += 1,
      ),
      dispose: (value) {
        _releases += 1;
        value.dispose();
      },
    );
    return FactoryScope(
      key: ValueKey(generation),
      modules: [
        FactoryModule(factories: [notifier], expose: [notifier]),
      ],
      onClose: (closing) => _closing = closing,
      child: Builder(
        builder: (context) {
          context.watch<_TrackedNotifier>();
          return const Scaffold(body: SizedBox());
        },
      ),
    );
  }
}

class _Signal {
  _Signal(this.value);

  final int value;
  final listeners = <void Function()>[];
}

class _Generation {
  const _Generation(this.value);

  final int value;
}

class _TrackedNotifier extends ChangeNotifier {
  _TrackedNotifier({required this.onAdd, required this.onRemove});

  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  void addListener(VoidCallback listener) {
    onAdd();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    onRemove();
    super.removeListener(listener);
  }
}
