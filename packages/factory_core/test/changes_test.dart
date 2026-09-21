import 'package:factory_core/factory_core.dart';
import 'package:test/test.dart';

class Signal {
  Signal(this.value);
  int value;
  final listeners = <void Function()>[];
  void emit() {
    for (final listener in listeners.toList()) {
      listener();
    }
  }
}

void main() {
  test('observed unique failures recover after a later override', () async {
    final source = Factory<int>((_) => 1, lifetime: Lifetime.unique);
    final target = Factory<List<int>>((ref) => [ref.watch(source)],
        onChange: ChangePolicy.recreate);
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [source, target])
    ]);
    expect(container.read(target), [1]);
    container.setOverrides(
        [source.overrideWith((_) => throw StateError('unavailable'))]);
    expect(() => container.read(target), throwsStateError);
    container.setOverrides([source.overrideWithValue(2)]);
    expect(container.read(target), [2]);
    await container.close();
  });

  test('notifications emitted during an update do not reenter the graph',
      () async {
    final source = Factory<int>.external();
    final signal = Factory<Signal>((ref) => Signal(ref.watch(source)),
        onChange: ChangePolicy.update, update: (ref, value) {
      value.value = ref.watch(source);
      value.emit();
    });
    var builds = 0;
    final target = Factory<List<int>>((ref) {
      builds++;
      return [ref.select(signal, (value) => value.value)];
    }, onChange: ChangePolicy.recreate);
    final container = FactoryContainer(
        modules: [
          FactoryModule(factories: [source, signal, target])
        ],
        overrides: [
          source.overrideWithValue(1)
        ],
        observe: (value, changed) {
          final signal = value as Signal;
          signal.listeners.add(changed);
          return () => signal.listeners.remove(changed);
        });
    expect(container.read(target), [1]);
    container.setOverrides([source.overrideWithValue(2)]);
    expect(container.read(target), [2]);
    expect(builds, 2);
    await container.close();
  });

  test('overrides notify consumers of unique declarations too', () async {
    final source = Factory<int>((_) => 1, lifetime: Lifetime.unique);
    final target = Factory<List<int>>((ref) => [ref.watch(source)],
        onChange: ChangePolicy.recreate);
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [source, target])
    ]);
    expect(container.read(target), [1]);
    container.setOverrides([source.overrideWithValue(2)]);
    expect(container.read(target), [2]);
    await container.close();
  });

  test('a failed dependency chain recovers when its observed source changes',
      () async {
    final source = Factory<int>.external();
    final middle = Factory<List<int>>((ref) {
      final value = ref.watch(source);
      if (value == 2) throw StateError('unavailable');
      return [value];
    }, onChange: ChangePolicy.recreate);
    final last = Factory<List<int>>((ref) => [...ref.watch(middle)],
        onChange: ChangePolicy.recreate);
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [source, middle, last])
    ], overrides: [
      source.overrideWithValue(1)
    ]);
    expect(container.read(last), [1]);
    container.setOverrides([source.overrideWithValue(2)]);
    expect(() => container.read(last), throwsStateError);
    container.setOverrides([source.overrideWithValue(3)]);
    expect(container.read(last), [3]);
    await container.close();
  });

  test('diamond changes build dependents once with consistent inputs',
      () async {
    final source = Factory<int>.external();
    final left = Factory<int>((ref) => ref.watch(source) + 10,
        onChange: ChangePolicy.recreate);
    final right = Factory<int>((ref) => ref.watch(source) + 20,
        onChange: ChangePolicy.recreate);
    var builds = 0;
    final leaf = Factory<List<int>>((ref) {
      builds++;
      return [ref.watch(left), ref.watch(right)];
    }, onChange: ChangePolicy.recreate);
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [leaf, right, left, source])
    ], overrides: [
      source.overrideWithValue(1)
    ]);
    expect(container.read(leaf), [11, 21]);
    container.setOverrides([source.overrideWithValue(2)]);
    expect(container.read(leaf), [12, 22]);
    expect(builds, 2);
    await container.close();
  });

  test('explicit selectors update in place only when their value changes',
      () async {
    final signal = Signal(1);
    final source = Factory<Signal>.external();
    var updates = 0;
    final target = Factory<List<int>>(
        (ref) => [ref.select(source, (s) => s.value)],
        onChange: ChangePolicy.update, update: (ref, value) {
      updates++;
      value[0] = ref.select(source, (s) => s.value);
    });
    final container = FactoryContainer(
        modules: [
          FactoryModule(factories: [source, target])
        ],
        overrides: [
          source.overrideWithValue(signal)
        ],
        observe: (value, changed) {
          final signal = value as Signal;
          signal.listeners.add(changed);
          return () => signal.listeners.remove(changed);
        });
    final value = container.read(target);
    signal.emit();
    expect(updates, 0);
    signal.value = 2;
    signal.emit();
    expect(value, [2]);
    expect(identical(container.read(target), value), isTrue);
    expect(updates, 1);
    await container.close();
    expect(signal.listeners, isEmpty);
  });

  test('failed recreation throws instead of serving an old value and recovers',
      () async {
    final source = Factory<int>.external();
    final target = Factory<List<int>>((ref) {
      final value = ref.watch(source);
      if (value == 2) throw StateError('cannot construct');
      return [value];
    }, onChange: ChangePolicy.recreate);
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [source, target])
    ], overrides: [
      source.overrideWithValue(1)
    ]);
    final original = container.read(target);
    container.setOverrides([source.overrideWithValue(2)]);
    expect(() => container.read(target), throwsStateError);
    expect(original, [1]);
    container.setOverrides([source.overrideWithValue(3)]);
    expect(container.read(target), [3]);
    await container.close();
  });

  test('replacement retains old dependencies until their consumers close',
      () async {
    final released = <String>[];
    final source = Factory<String>((_) => 'old', dispose: released.add);
    final target = Factory<Object>((ref) {
      ref.read(source);
      return Object();
    }, dispose: (_) => released.add('consumer'));
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [source, target])
    ]);
    container.read(target);
    container.setOverrides(
        [source.overrideWith((_) => 'new', dispose: released.add)]);
    expect(released, isEmpty);
    await container.close();
    expect(released.indexOf('consumer'), lessThan(released.indexOf('old')));
    expect(released.toSet(), {'old', 'new', 'consumer'});
  });

  test('watch recreates on replacement, read does not, and identity is stable',
      () async {
    final source = Factory<Object>.external();
    final watched = Factory<List<Object>>((ref) => [ref.watch(source)],
        onChange: ChangePolicy.recreate);
    final read = Factory<List<Object>>((ref) => [ref.read(source)]);
    final first = Object();
    final second = Object();
    final container = FactoryContainer(modules: [
      FactoryModule(factories: [source, watched, read])
    ], overrides: [
      source.overrideWithValue(first)
    ]);
    final original = container.read(watched);
    final unobserved = container.read(read);
    container.setOverrides([source.overrideWithValue(first)]);
    expect(identical(container.read(watched), original), isTrue);
    container.setOverrides([source.overrideWithValue(second)]);
    expect(container.read(watched), [second]);
    expect(identical(container.read(watched), original), isFalse);
    expect(identical(container.read(read), unobserved), isTrue);
    expect(unobserved, [first]);
    await container.close();
  });
}
