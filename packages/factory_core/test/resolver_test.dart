import 'dart:async';

import 'package:factory_core/factory_core.dart';
import 'package:test/test.dart';

void main() {
  test('resolves during construction and later by declaration identity',
      () async {
    final first = Factory<Object>((_) => Object(), name: 'first');
    final second = Factory<Object>((_) => Object(), name: 'second');
    late Object initial;
    final consumer = Factory<FactoryResolver>((ref) {
      initial = ref.resolver.resolve(first);
      return ref.resolver;
    });
    final container = FactoryContainer(local: [first, second, consumer]);
    addTearDown(container.close);

    final resolver = container.read(consumer);
    expect(resolver.resolve(first), same(initial));
    expect(resolver.resolve(second), isNot(same(initial)));
    final missing = Factory<Object>((_) => Object(), name: 'missing');
    expect(
      () => resolver.resolve(missing),
      throwsA(isA<StateError>()
          .having((error) => error.message, 'diagnostic', contains('missing'))),
    );
  });

  test('respects scoped and unique without adding a cache', () async {
    final scoped = Factory<Object>((_) => Object());
    final unique = Factory<Object>((_) => Object(), lifetime: Lifetime.unique);
    final consumer = Factory<FactoryResolver>((ref) => ref.resolver);
    final container = FactoryContainer(local: [scoped, unique, consumer]);
    addTearDown(container.close);
    final resolver = container.read(consumer);

    expect(resolver.resolve(scoped), same(resolver.resolve(scoped)));
    expect(resolver.resolve(unique), isNot(same(resolver.resolve(unique))));
  });

  test('uses the consumer owner scope and isolates local overrides', () async {
    final dependency = Factory<Object>((_) => Object());
    final consumer = Factory<FactoryResolver>((ref) => ref.resolver);
    final parent = FactoryContainer(local: [dependency, consumer]);
    addTearDown(parent.close);
    final replacement = Object();
    final child = FactoryContainer(
      parent: parent,
      overrides: [dependency.overrideWithValue(replacement)],
    );
    final local = FactoryContainer(
      parent: parent,
      local: [consumer],
      overrides: [dependency.overrideWithValue(replacement)],
    );

    expect(child.read(consumer), same(parent.read(consumer)));
    expect(child.read(consumer).resolve(dependency),
        same(parent.read(dependency)));
    expect(local.read(consumer).resolve(dependency), same(replacement));
    await local.close();
    expect(parent.read(consumer).resolve(dependency),
        same(parent.read(dependency)));
  });

  test('reads current overrides without observing or recreating its consumer',
      () async {
    var creations = 0;
    var subscriptions = 0;
    final dependency = Factory<Object>((_) => Object());
    final consumer = Factory<FactoryResolver>((ref) {
      creations++;
      return ref.resolver;
    });
    final container = FactoryContainer(
      local: [dependency, consumer],
      observe: (_, __) {
        subscriptions++;
        return () {};
      },
    );
    addTearDown(container.close);
    final resolver = container.read(consumer);
    final original = resolver.resolve(dependency);
    final replacement = Object();
    container.setOverrides([dependency.overrideWithValue(replacement)]);

    expect(container.read(consumer), same(resolver));
    expect(resolver.resolve(dependency), same(replacement));
    expect(original, isNot(same(replacement)));
    expect(creations, 1);
    expect(subscriptions, 0);
  });

  test('cleans late dependencies after consumers and preserves borrowed values',
      () async {
    final events = <String>[];
    final borrowed = Factory<Object>(
      (_) => Object(),
      dispose: (_) => events.add('borrowed'),
    );
    final dependency = Factory<Object>(
      (_) => Object(),
      lifetime: Lifetime.unique,
      dispose: (_) => events.add('dependency'),
    );
    final consumer = Factory<FactoryResolver>(
      (ref) => ref.resolver,
      dispose: (_) => events.add('consumer'),
    );
    final container = FactoryContainer(
      local: [dependency, consumer, borrowed],
      overrides: [borrowed.overrideWithValue(Object())],
    );
    final resolver = container.read(consumer);
    resolver.resolve(dependency);
    resolver.resolve(dependency);
    resolver.resolve(borrowed);
    await container.close();
    await container.close();

    expect(events, ['consumer', 'dependency', 'dependency']);
  });

  test('rejects a late cycle without retaining its rejected edge', () async {
    final events = <String>[];
    final first = Factory<FactoryResolver>(
      (ref) => ref.resolver,
      name: 'first',
      dispose: (_) => events.add('first'),
    );
    final second = Factory<FactoryResolver>(
      (ref) => ref.resolver,
      name: 'second',
      dispose: (_) => events.add('second'),
    );
    final container = FactoryContainer(local: [first, second]);
    final a = container.read(first);
    final b = container.read(second);
    expect(a.resolve(second), same(b));

    expect(
      () => b.resolve(first),
      throwsA(isA<StateError>().having((error) => error.message, 'cycle',
          contains('second -> first -> second'))),
    );
    expect(() => a.resolve(first), throwsStateError);
    await container.close();
    expect(events, ['first', 'second']);
  });

  test('detects cycles through dependencies constructed by a late read',
      () async {
    final events = <String>[];
    final consumer = Factory<FactoryResolver>(
      (ref) => ref.resolver,
      name: 'consumer',
      dispose: (_) => events.add('consumer'),
    );
    final dependency = Factory<Object>(
      (ref) {
        ref.read(consumer);
        return Object();
      },
      name: 'dependency',
      dispose: (_) => events.add('dependency'),
    );
    final container = FactoryContainer(local: [consumer, dependency]);
    final resolver = container.read(consumer);

    expect(() => resolver.resolve(dependency), throwsStateError);
    await container.close();
    expect(events, ['dependency', 'consumer']);
  });

  test('retained resolvers follow their instance through multiple recreations',
      () async {
    final events = <String>[];
    var created = 0;
    final consumer = Factory<_Consumer>(
      (ref) => _Consumer(ref.resolver, ++created),
      dispose: (value) => events.add('consumer${value.id}'),
    );
    final bridge = Factory<Object>(
      (ref) {
        ref.read(consumer);
        return Object();
      },
      dispose: (_) => events.add('bridge'),
    );
    final container = FactoryContainer(local: [consumer, bridge]);
    final first = container.read(consumer);
    container.setOverrides([
      consumer.overrideWith(
        (ref) => _Consumer(ref.resolver, ++created),
        dispose: (value) => events.add('consumer${value.id}'),
      ),
    ]);
    final second = container.read(consumer);
    container.setOverrides([]);
    final third = container.read(consumer);

    first.resolver.resolve(bridge);
    second.resolver.resolve(bridge);
    expect(() => third.resolver.resolve(bridge), throwsStateError);
    await container.close();
    expect(events.toSet(), {'consumer1', 'consumer2', 'consumer3', 'bridge'});
    expect(events.length, 4);
    expect(events.indexOf('consumer1'), lessThan(events.indexOf('bridge')));
    expect(events.indexOf('consumer2'), lessThan(events.indexOf('bridge')));
    expect(events.indexOf('bridge'), lessThan(events.indexOf('consumer3')));
  });

  test('unique snapshots retain resolution after an override', () async {
    final dependency = Factory<Object>((_) => Object());
    final consumer = Factory<FactoryResolver>(
      (ref) => ref.resolver,
      lifetime: Lifetime.unique,
    );
    final container = FactoryContainer(local: [dependency, consumer]);
    final original = container.read(consumer);
    container.setOverrides([consumer.overrideWith((ref) => ref.resolver)]);
    final replacement = container.read(consumer);

    expect(original, isNot(same(replacement)));
    expect(original.resolve(dependency), same(replacement.resolve(dependency)));
    await container.close();
    expect(() => original.resolve(dependency), throwsStateError);
    expect(() => replacement.resolve(dependency), throwsStateError);
  });

  test('an in-place update preserves the resolution capability', () async {
    final dependency = Factory<Object>((_) => Object());
    late FactoryResolver updateResolver;
    final consumer = Factory<FactoryResolver>(
      (ref) {
        ref.watch(dependency);
        return ref.resolver;
      },
      onChange: ChangePolicy.update,
      update: (ref, value) {
        ref.watch(dependency);
        updateResolver = ref.resolver;
      },
    );
    final container = FactoryContainer(local: [dependency, consumer]);
    addTearDown(container.close);
    final original = container.read(consumer);
    final replacement = Object();
    container.setOverrides([dependency.overrideWithValue(replacement)]);

    expect(updateResolver, same(original));
    expect(original.resolve(dependency), same(replacement));
  });

  test('resolution stops as soon as asynchronous parent closure begins',
      () async {
    final gate = Completer<void>();
    final dependency = Factory<Object>((_) => Object());
    final consumer = Factory<FactoryResolver>(
      (ref) => ref.resolver,
      dispose: (_) => gate.future,
    );
    final parent = FactoryContainer(local: [dependency]);
    final child = FactoryContainer(parent: parent, local: [consumer]);
    final resolver = child.read(consumer);
    final closing = parent.close();

    expect(() => resolver.resolve(dependency), throwsStateError);
    gate.complete();
    await closing;
    expect(() => resolver.resolve(dependency), throwsStateError);
  });

  test('a capability escaped from failed construction cannot be reused',
      () async {
    final dependency = Factory<Object>((_) => Object());
    late FactoryResolver failed;
    final consumer = Factory<FactoryResolver>((ref) {
      failed = ref.resolver;
      throw StateError('construction failed');
    });
    final container = FactoryContainer(local: [dependency, consumer]);
    addTearDown(container.close);
    expect(() => container.read(consumer), throwsStateError);
    expect(() => failed.resolve(dependency), throwsStateError);
    container.setOverrides([consumer.overrideWith((ref) => ref.resolver)]);
    final recovered = container.read(consumer);
    expect(recovered.resolve(dependency), same(container.read(dependency)));
    expect(() => failed.resolve(dependency), throwsStateError);
  });
}

class _Consumer {
  _Consumer(this.resolver, this.id);

  final FactoryResolver resolver;
  final int id;
}
