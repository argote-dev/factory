import 'package:factory/factory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('keeps exposed declarations lazy until Provider consumes them',
      (tester) async {
    var created = 0;
    final service = Factory<Object>((_) {
      created += 1;
      return Object();
    });

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(factories: [service], expose: [service])
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      ),
    );

    expect(created, 0);

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(factories: [service], expose: [service])
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(created, 0);
  });

  testWidgets(
      'adapts an exposed ChangeNotifier for existing Provider consumers',
      (tester) async {
    final controller = Factory<_Counter>((_) => _Counter());
    _Counter? instance;

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(factories: [controller], expose: [controller]),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              instance = context.read<_Counter>();
              final selected =
                  context.select<_Counter, int>((value) => value.value);
              final watched = context.watch<_Counter>();
              return Column(
                children: [
                  Text('watch:${watched.value}'),
                  Text('select:$selected'),
                  Consumer<_Counter>(
                    builder: (_, value, __) => Text('consumer:${value.value}'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('watch:0'), findsOneWidget);
    expect(find.text('select:0'), findsOneWidget);
    expect(find.text('consumer:0'), findsOneWidget);
    instance!.increment();
    await tester.pump();
    expect(find.text('watch:1'), findsOneWidget);
    expect(find.text('select:1'), findsOneWidget);
    expect(find.text('consumer:1'), findsOneWidget);
  });

  testWidgets('rebuilds an exposed dependent after a selected state change',
      (tester) async {
    final session = Factory<_Session>.external();
    final repository = Factory<_Repository>(
      (ref) => _Repository(ref.select(session, (value) => value.userId)),
      onChange: ChangePolicy.recreate,
    );
    final value = _Session('first');

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(
            factories: [session, repository],
            expose: [repository],
          ),
        ],
        overrides: [session.overrideWithValue(value)],
        child: Builder(
          builder: (context) => Directionality(
            textDirection: TextDirection.ltr,
            child: Text(context.watch<_Repository>().userId),
          ),
        ),
      ),
    );

    expect(find.text('first'), findsOneWidget);
    value.update('second');
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('closes an owned notifier once and exposes completion',
      (tester) async {
    final notifier = _DisposableNotifier();
    final owned = Factory<_DisposableNotifier>(
      (_) => notifier,
      dispose: (value) => value.dispose(),
    );
    Future<void>? closing;

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(factories: [owned], expose: [owned])
        ],
        onClose: (value) => closing = value,
        child: Builder(
          builder: (context) {
            context.read<_DisposableNotifier>();
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    expect(closing, isNotNull);
    await closing;
    expect(notifier.disposeCalls, 1);
  });

  testWidgets('does not dispose a borrowed notifier', (tester) async {
    final borrowed = Factory<_DisposableNotifier>.external();
    final notifier = _DisposableNotifier();
    Future<void>? closing;

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(factories: [borrowed], expose: [borrowed])
        ],
        overrides: [borrowed.overrideWithValue(notifier)],
        onClose: (value) => closing = value,
        child: Builder(
          builder: (context) {
            context.read<_DisposableNotifier>();
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    await closing;
    expect(notifier.disposeCalls, 0);
  });

  testWidgets('updates an exposed borrowed value when its identity changes',
      (tester) async {
    final token = Factory<_Token>.external();
    final first = _Token('first');
    final second = _Token('second');

    Widget scope(_Token value) => FactoryScope(
          modules: [
            FactoryModule(factories: [token], expose: [token])
          ],
          overrides: [token.overrideWithValue(value)],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) => Text(context.watch<_Token>().value),
            ),
          ),
        );

    await tester.pumpWidget(scope(first));
    expect(find.text('first'), findsOneWidget);
    await tester.pumpWidget(scope(second));
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('applies changes made to a reused overrides list',
      (tester) async {
    final token = Factory<_Token>.external();
    final overrides = <FactoryOverride>[
      token.overrideWithValue(_Token('first')),
    ];

    Widget scope() => FactoryScope(
          modules: [
            FactoryModule(factories: [token], expose: [token])
          ],
          overrides: overrides,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) => Text(context.watch<_Token>().value),
            ),
          ),
        );

    await tester.pumpWidget(scope());
    expect(find.text('first'), findsOneWidget);
    overrides[0] = token.overrideWithValue(_Token('second'));
    await tester.pumpWidget(scope());
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('rejects a changed configuration before applying its overrides',
      (tester) async {
    final token = Factory<_Token>.external();
    final modules = <FactoryModule>[
      FactoryModule(factories: [token], expose: [token]),
    ];
    final overrides = <FactoryOverride>[
      token.overrideWithValue(_Token('first')),
    ];
    FactoryContainer? container;

    Widget scope() => FactoryScope(
          modules: modules,
          overrides: overrides,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                container = FactoryScope.of(context);
                return Text(context.watch<_Token>().value);
              },
            ),
          ),
        );

    await tester.pumpWidget(scope());
    expect(find.text('first'), findsOneWidget);
    modules.add(FactoryModule(factories: const [], expose: const []));
    overrides[0] = token.overrideWithValue(_Token('second'));

    await tester.pumpWidget(scope());
    expect(tester.takeException(), isA<StateError>());
    expect(container!.read(token).value, 'first');
  });

  testWidgets('keeps a unique exposed value across unrelated scope rebuilds',
      (tester) async {
    var created = 0;
    final unique = Factory<_Token>(
      (_) => _Token('value-${++created}'),
      lifetime: Lifetime.unique,
    );

    Widget scope() => FactoryScope(
          modules: [
            FactoryModule(factories: [unique], expose: [unique])
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) => Text(context.watch<_Token>().value),
            ),
          ),
        );

    await tester.pumpWidget(scope());
    expect(find.text('value-1'), findsOneWidget);
    await tester.pumpWidget(scope());
    expect(find.text('value-1'), findsOneWidget);
    expect(created, 1);
  });

  testWidgets(
      'keeps an unconsumed exposed value lazy after an internal refresh',
      (tester) async {
    final session = Factory<_Token>.external();
    var created = 0;
    final unique = Factory<_Token>(
      (ref) {
        ref.watch(session);
        return _Token('value-${++created}');
      },
      lifetime: Lifetime.unique,
      onChange: ChangePolicy.recreate,
    );
    final eager = Factory<Object>(
      (ref) {
        ref.read(unique);
        return Object();
      },
      lazy: false,
    );

    Widget scope(String value) => FactoryScope(
          modules: [
            FactoryModule(
              factories: [session, unique, eager],
              expose: [unique],
            ),
          ],
          overrides: [session.overrideWithValue(_Token(value))],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(),
          ),
        );

    await tester.pumpWidget(scope('first'));
    expect(created, 1);
    await tester.pumpWidget(scope('second'));
    expect(created, 2);
  });

  testWidgets(
      'reports an asynchronous cleanup failure through onClose and onError',
      (tester) async {
    final failing = Factory<Object>(
      (_) => Object(),
      dispose: (_) async {
        await Future<void>.microtask(() {});
        throw StateError('cleanup failed');
      },
    );
    Future<void>? closing;
    Object? reported;

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(factories: [failing], expose: [failing])
        ],
        onClose: (value) => closing = value,
        onError: (error, _) => reported = error,
        child: Builder(
          builder: (context) {
            context.read<Object>();
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    final expectedClose =
        expectLater(closing!, throwsA(isA<FactoryCleanupException>()));
    await tester.pump();
    await expectedClose;
    expect(reported, isA<FactoryCleanupException>());
  });

  testWidgets(
      'keeps parent dependencies when a child rebuilds a local dependent',
      (tester) async {
    final api = Factory<_Api>((_) => _Api('parent'));
    final repository = Factory<_ApiRepository>(
      (ref) => _ApiRepository(ref.read(api)),
    );
    final flow = Factory<_Flow>(
      (ref) => _Flow(ref.read(repository)),
    );

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(
            factories: [api, repository],
            expose: [repository],
          ),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              Builder(
                builder: (context) => Text(
                  'parent:${context.watch<_ApiRepository>().api.name}',
                ),
              ),
              FactoryScope(
                modules: [
                  FactoryModule(factories: [flow], expose: [flow])
                ],
                overrides: [api.overrideWithValue(_Api('flow'))],
                local: [repository],
                child: Builder(
                  builder: (context) => Text(
                    'flow:${context.watch<_Flow>().repository.api.name}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('parent:parent'), findsOneWidget);
    expect(find.text('flow:flow'), findsOneWidget);
  });

  testWidgets(
      'surfaces a failed recreation instead of retaining a Provider value',
      (tester) async {
    final session = Factory<_Session>.external();
    final repository = Factory<_Repository>(
      (ref) {
        final userId = ref.select(session, (value) => value.userId);
        if (userId == 'broken') throw StateError('recreation failed');
        return _Repository(userId);
      },
      onChange: ChangePolicy.recreate,
    );
    final value = _Session('healthy');

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(
            factories: [session, repository],
            expose: [repository],
          ),
        ],
        overrides: [session.overrideWithValue(value)],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => Text(context.watch<_Repository>().userId),
          ),
        ),
      ),
    );
    expect(find.text('healthy'), findsOneWidget);

    value.update('broken');
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('healthy'), findsNothing);
  });

  testWidgets('preserves child state while an exposed value is replaced',
      (tester) async {
    final token = Factory<_Token>.external();

    Widget scope(String value) => FactoryScope(
          modules: [
            FactoryModule(factories: [token], expose: [token])
          ],
          overrides: [token.overrideWithValue(_Token(value))],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: _StatefulTokenConsumer(),
          ),
        );

    await tester.pumpWidget(scope('first'));
    await tester.tap(find.byKey(const ValueKey('increment')));
    await tester.pump();
    expect(find.text('first:1'), findsOneWidget);

    await tester.pumpWidget(scope('second'));
    expect(find.text('second:1'), findsOneWidget);
  });

  testWidgets('notifies Provider consumers after an in-place update',
      (tester) async {
    final session = Factory<_Session>.external();
    final repository = Factory<_MutableRepository>(
      (ref) => _MutableRepository(ref.select(session, (value) => value.userId)),
      onChange: ChangePolicy.update,
      update: (ref, value) {
        value.userId = ref.select(session, (session) => session.userId);
      },
    );
    final value = _Session('first');

    await tester.pumpWidget(
      FactoryScope(
        modules: [
          FactoryModule(
            factories: [session, repository],
            expose: [repository],
          ),
        ],
        overrides: [session.overrideWithValue(value)],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer<_MutableRepository>(
            builder: (_, repository, __) => Text(repository.userId),
          ),
        ),
      ),
    );
    expect(find.text('first'), findsOneWidget);

    value.update('second');
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
  });
}

class _Counter extends ChangeNotifier {
  int value = 0;

  void increment() {
    value += 1;
    notifyListeners();
  }
}

class _Session extends ChangeNotifier {
  _Session(this.userId);

  String userId;

  void update(String value) {
    userId = value;
    notifyListeners();
  }
}

class _Repository {
  _Repository(this.userId);

  final String userId;
}

class _DisposableNotifier extends ChangeNotifier {
  int disposeCalls = 0;

  @override
  void dispose() {
    disposeCalls += 1;
    super.dispose();
  }
}

class _Token {
  _Token(this.value);

  final String value;
}

class _Api {
  _Api(this.name);

  final String name;
}

class _ApiRepository {
  _ApiRepository(this.api);

  final _Api api;
}

class _Flow {
  _Flow(this.repository);

  final _ApiRepository repository;
}

class _MutableRepository {
  _MutableRepository(this.userId);

  String userId;
}

class _StatefulTokenConsumer extends StatefulWidget {
  const _StatefulTokenConsumer();

  @override
  State<_StatefulTokenConsumer> createState() => _StatefulTokenConsumerState();
}

class _StatefulTokenConsumerState extends State<_StatefulTokenConsumer> {
  var count = 0;

  @override
  Widget build(BuildContext context) {
    final token = context.watch<_Token>();
    return GestureDetector(
      key: const ValueKey('increment'),
      onTap: () => setState(() => count += 1),
      child: Text('${token.value}:$count'),
    );
  }
}
