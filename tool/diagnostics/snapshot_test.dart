import 'package:factory_core/factory_core.dart';
import 'package:test/test.dart';

class Secret {
  @override
  String toString() => throw StateError('Values must never be inspected');
}

void main() {
  test('capture is deterministic, redacted and does not construct lazy values',
      () async {
    var calls = 0;
    final hidden = Factory<Secret>((_) {
      calls++;
      return Secret();
    }, name: 'secret\nmetadata');
    final exposed = Factory<int>((_) => 42);
    final scope = FactoryContainer(modules: [
      FactoryModule(factories: [hidden, exposed], expose: [exposed])
    ]);
    final before = captureFactoryGraph(scope);
    expect(before, captureFactoryGraph(scope));
    expect(calls, 0);
    expect(before, contains('visibility=internal'));
    expect(before, contains('visibility=exposed'));
    expect(before, isNot(contains('generation')));
    expect(before, isNot(contains('secret')));
    expect(captureFactoryGraph(scope, includeNames: true),
        contains(r'\u0073\u0065\u0063\u0072\u0065\u0074\u000a'));
    scope.read(hidden);
    expect(captureFactoryGraph(scope), contains('value=present'));
    expect(calls, 1);
    await scope.close();
  });

  test('child override and inherited ownership are visible without reads',
      () async {
    final source = Factory<Secret>((_) => Secret());
    final parent = FactoryContainer(local: [source]);
    final child = FactoryContainer(
        parent: parent, overrides: [source.overrideWithValue(Secret())]);
    expect(captureFactoryGraph(child), contains('scope s2 parent=1'));
    expect(
        captureFactoryGraph(child),
        contains(
            'declaration d1 scope=s2 visibility=internal override=borrowed'));
    child.read(source);
    expect(captureFactoryGraph(parent),
        contains('declaration=d1 owner=s2 state=active'));
    await parent.close();
  });

  test('retained snapshots allow cleanup of active and retired generations',
      () async {
    var released = 0;
    final source = Factory<Secret>((_) => Secret(), dispose: (_) => released++);
    final consumer = Factory<List<Secret>>((ref) => [ref.read(source)]);
    final scope = FactoryContainer(local: [source, consumer]);
    scope.read(consumer);
    scope.setOverrides(
        [source.overrideWith((_) => Secret(), dispose: (_) => released++)]);
    final snapshot = captureFactoryGraph(scope);
    expect(snapshot, contains('state=retired'));
    expect(snapshot, contains('override=constructor'));
    expect(snapshot, contains('relation=read-or-resolve-or-retired-watch'));
    expect(snapshot, contains('cleanup=scope'));
    expect(released, 0);
    await scope.close();
    expect(released, 2);
    expect(snapshot, contains('state=retired'));
    expect(captureFactoryGraph(scope), isNot(contains('generation')));
  });

  test('watch and select share an observed relation; capture invokes neither',
      () async {
    var selections = 0;
    var subscriptions = 0;
    final source = Factory<int>((_) => 7);
    final consumer = Factory<List<int>>(
        (ref) => [
              ref.select(source, (value) {
                selections++;
                return value;
              })
            ],
        onChange: ChangePolicy.recreate);
    final scope = FactoryContainer(
        local: [source, consumer],
        observe: (_, __) {
          subscriptions++;
          return () => subscriptions--;
        });
    scope.read(consumer);
    final snapshot = captureFactoryGraph(scope);
    expect(snapshot,
        contains('relation=watch-or-select cleanup=true observed=true'));
    expect(selections, 1);
    expect(subscriptions, 1);
    await scope.close();
    expect(subscriptions, 0);
    expect(snapshot, contains('observed=true'));
  });

  test('cycle capture reports failed records without replaying construction',
      () async {
    var attempts = 0;
    late Factory<int> a;
    late Factory<int> b;
    a = Factory((ref) {
      attempts++;
      return ref.read(b);
    }, name: 'a');
    b = Factory((ref) => ref.read(a), name: 'b');
    final scope = FactoryContainer(local: [a, b]);
    expect(
        () => scope.read(a),
        throwsA(isA<StateError>().having((error) => error.message, 'message',
            'Dependency cycle: a -> b -> a')));
    final snapshot = captureFactoryGraph(scope);
    expect(snapshot, contains('value=absent error=present'));
    expect(snapshot, isNot(contains('edge ')));
    expect(attempts, 1);
    await scope.close();
  });

  test('snapshots survive child close and resolver invalidation', () async {
    late FactoryResolver resolver;
    final source = Factory<Secret>((_) => Secret());
    final owner = Factory<Secret>((ref) {
      resolver = ref.resolver;
      resolver.resolve(source);
      return Secret();
    });
    final root = FactoryContainer(local: [source]);
    final child = FactoryContainer(parent: root, local: [owner]);
    child.read(owner);
    final snapshot = captureFactoryGraph(root);
    expect(snapshot, contains('resolver=present'));
    await child.close();
    expect(() => resolver.resolve(source), throwsStateError);
    expect(captureFactoryGraph(root), isNot(contains('scope s2')));
    expect(snapshot, contains('scope s2'));
    await root.close();
  });
}
