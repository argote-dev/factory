import 'package:factory_core/factory_core.dart';
import 'package:test/test.dart';

class Observable {}

void main() {
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
