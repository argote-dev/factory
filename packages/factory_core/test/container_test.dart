import 'package:factory_core/factory_core.dart';
import 'package:test/test.dart';

class Observable {}

void main() {
  test('public composition diagnostics identify declarations and corrections',
      () async {
    final missing = Factory<Object>((_) => Object(), name: 'missingClient');
    final external = Factory<Object>.external(name: 'session');
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [external]),
    ]);

    expect(
      () => container.read(missing),
      throwsA(isA<StateError>()
          .having((error) => error.message, 'declaration',
              contains('missingClient'))
          .having((error) => error.message, 'action', contains('install'))),
    );
    expect(
      () => container.read(external),
      throwsA(isA<StateError>()
          .having((error) => error.message, 'declaration', contains('session'))
          .having((error) => error.message, 'action', contains('override'))),
    );
    await container.close();

    final first = Factory<String>((_) => 'a', name: 'primaryName');
    final second = Factory<String>((_) => 'b', name: 'secondaryName');
    expect(
      () => FactoryContainer(modules: [
        FactoryModule(
          factories: [first, second],
          expose: [first, second],
        ),
      ]),
      throwsA(isA<ArgumentError>()
          .having((error) => error.message, 'type', contains('String'))
          .having((error) => error.message, 'first', contains('primaryName'))
          .having(
              (error) => error.message, 'second', contains('secondaryName'))),
    );
  });

  test('repeated public runtime cycles release observers and ownership',
      () async {
    var subscriptions = 0;
    var cancellations = 0;
    var ownedReleases = 0;
    final borrowed = Object();

    for (var cycle = 0; cycle < 100; cycle += 1) {
      final source = Factory<Object>.external(name: 'source');
      final readTarget = Factory<Object>(
        (ref) {
          ref.read(source);
          return Object();
        },
        name: 'readTarget',
        dispose: (_) => ownedReleases += 1,
      );
      final watchTarget = Factory<Object>(
        (ref) {
          ref.watch(source);
          return Object();
        },
        name: 'watchTarget',
        onChange: ChangePolicy.recreate,
        dispose: (_) => ownedReleases += 1,
      );
      final selectTarget = Factory<Object>(
        (ref) {
          ref.select(source, (_) => cycle);
          return Object();
        },
        name: 'selectTarget',
        onChange: ChangePolicy.recreate,
        dispose: (_) => ownedReleases += 1,
      );
      final container = FactoryContainer(
        modules: [
          FactoryModule(
            factories: [source, readTarget, watchTarget, selectTarget],
          ),
        ],
        overrides: [source.overrideWithValue(borrowed)],
        observe: (_, __) {
          subscriptions += 1;
          return () => cancellations += 1;
        },
      );
      container
        ..read(readTarget)
        ..read(watchTarget)
        ..read(selectTarget);
      await container.close();
    }

    expect(subscriptions, 100);
    expect(cancellations, subscriptions);
    expect(ownedReleases, 300);
  });

  test('one thousand unique resolutions preserve ownership contracts',
      () async {
    var ownedReleases = 0;
    final owned = Factory<Object>(
      (_) => Object(),
      lifetime: Lifetime.unique,
      dispose: (_) => ownedReleases += 1,
    );
    final cleanupFree = Factory<Object>(
      (_) => Object(),
      lifetime: Lifetime.unique,
    );
    final borrowed = Factory<Object>.external(name: 'borrowed');
    final borrowedValue = Object();
    final container = FactoryContainer(
      modules: [
        FactoryModule(factories: [owned, cleanupFree, borrowed])
      ],
      overrides: [borrowed.overrideWithValue(borrowedValue)],
    );
    final values = <Object>{};
    final cleanupFreeValues = <Object>{};
    for (var index = 0; index < 1000; index += 1) {
      values.add(container.read(owned));
      cleanupFreeValues.add(container.read(cleanupFree));
      expect(identical(container.read(borrowed), borrowedValue), isTrue);
    }
    expect(values, hasLength(1000));
    expect(cleanupFreeValues, hasLength(1000));
    await container.close();
    expect(ownedReleases, 1000);
  });

  test('a subscription cleanup failure does not skip owned resource cleanup',
      () async {
    var released = false;
    final source = Factory<Observable>((_) => Observable());
    final target = Factory<Object>(
        (ref) {
          ref.select(source, (value) => value);
          return Object();
        },
        onChange: ChangePolicy.recreate,
        dispose: (_) {
          released = true;
        });
    final container = FactoryContainer(
        modules: [
          FactoryModule(factories: [source, target])
        ],
        observe: (_, __) => () {
              throw StateError('unsubscribe');
            });
    container.read(target);
    await expectLater(
        container.close(), throwsA(isA<FactoryCleanupException>()));
    expect(released, isTrue);
  });

  test('cleanup can observe the same close future reentrantly', () async {
    late FactoryContainer container;
    Future<void>? seen;
    final value = Factory<Object>((_) => Object(), dispose: (_) {
      seen = container.close();
    });
    container = FactoryContainer(modules: [
      FactoryModule(factories: [value])
    ]);
    container.read(value);
    final closing = container.close();
    await closing;
    expect(identical(seen, closing), isTrue);
  });

  test(
      'failed eager opening exposes cleanup for partially constructed resources',
      () async {
    var released = false;
    final resource = Factory<Object>((_) => Object(), dispose: (_) async {
      released = true;
    });
    final failing = Factory<Object>((ref) {
      ref.read(resource);
      throw StateError('open');
    }, lazy: false);
    try {
      FactoryContainer(modules: [
        FactoryModule(factories: [failing, resource])
      ]);
      fail('Expected initialization failure');
    } on FactoryInitializationException catch (error) {
      expect(error.error, isStateError);
      await error.cleanup;
      expect(released, isTrue);
    }
  });

  test('exposure validates registration and duplicate declared types', () {
    final a = Factory<String>((_) => 'a');
    final b = Factory<String>((_) => 'b');
    expect(
        () => FactoryContainer(modules: [
              FactoryModule(factories: [a], expose: [b])
            ]),
        throwsArgumentError);
    expect(
        () => FactoryContainer(modules: [
              FactoryModule(factories: [a, b], expose: [a, b])
            ]),
        throwsArgumentError);
  });

  test('cycles report the declaration path', () async {
    late Factory<Object> first;
    final second = Factory<Object>((ref) => ref.read(first), name: 'second');
    first = Factory<Object>((ref) => ref.read(second), name: 'first');
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [first, second])
    ]);
    expect(
        () => container.read(first),
        throwsA(isA<StateError>().having((error) => error.message, 'path',
            contains('first -> second -> first'))));
    await container.close();
  });

  test('child local dependents use borrowed overrides without changing parent',
      () async {
    final cleaned = <String>[];
    final client = Factory<String>((_) => 'parent', dispose: cleaned.add);
    final repo = Factory<List<String>>((ref) => [ref.read(client)],
        dispose: (_) => cleaned.add('repo'));
    final parent = FactoryContainer(modules: [
      FactoryModule(factories: [client, repo])
    ]);
    final original = parent.read(repo);
    final child = FactoryContainer(
        parent: parent,
        local: [repo],
        overrides: [client.overrideWithValue('child')]);
    expect(child.read(repo), ['child']);
    expect(identical(parent.read(repo), original), isTrue);
    await parent.close();
    expect(cleaned, ['repo', 'repo', 'parent']);
    expect(() => child.read(repo), throwsStateError);
  });

  test('cleanup attempts every owned unique value and aggregates failures',
      () async {
    var released = 0;
    final resource = Factory<Object>((_) => Object(), lifetime: Lifetime.unique,
        dispose: (_) {
      released++;
      throw StateError('cleanup');
    });
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [resource])
    ]);
    container.read(resource);
    container.read(resource);
    final closing = container.close();
    expect(identical(closing, container.close()), isTrue);
    await expectLater(
        closing,
        throwsA(isA<FactoryCleanupException>()
            .having((error) => error.errors.length, 'errors', 2)));
    expect(released, 2);
  });

  test('close releases dependents before dependencies and awaits all cleanup',
      () async {
    final closed = <String>[];
    final client = Factory<Object>((_) => Object(), dispose: (_) async {
      await Future<void>.delayed(Duration.zero);
      closed.add('client');
    });
    final repository = Factory<Object>((ref) {
      ref.read(client);
      return Object();
    }, dispose: (_) => closed.add('repository'));
    final container = FactoryContainer(
      modules: [
        FactoryModule(factories: [repository, client])
      ],
    );
    container.read(repository);
    await container.close();
    await container.close();
    expect(closed, ['repository', 'client']);
    expect(() => container.read(client), throwsStateError);
  });

  test('eager dependency resolves its connections without registration order',
      () async {
    var constructed = '';
    final text = Factory<String>((_) => 'connected');
    final eager = Factory<Object>((ref) {
      constructed = ref.read(text);
      return Object();
    }, lazy: false);
    final container = FactoryContainer(
      modules: [
        FactoryModule(factories: [eager, text])
      ],
    );
    expect(constructed, 'connected');
    await container.close();
  });

  test('unique creates a different object for each resolution', () async {
    final service = Factory<Object>((_) => Object(), lifetime: Lifetime.unique);
    final container = FactoryContainer(
      modules: [
        FactoryModule(factories: [service])
      ],
    );
    expect(
        identical(container.read(service), container.read(service)), isFalse);
    await container.close();
  });

  test('declared dependencies stay lazy and are reused in their owning scope',
      () async {
    var created = 0;
    final service = Factory<Object>((_) {
      created++;
      return Object();
    });
    final container = FactoryContainer(
      modules: [
        FactoryModule(factories: [service])
      ],
    );
    expect(created, 0);
    final first = container.read(service);
    expect(identical(container.read(service), first), isTrue);
    expect(created, 1);
    await container.close();
  });
}
