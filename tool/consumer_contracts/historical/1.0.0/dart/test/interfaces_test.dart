import 'package:factory_core/factory_core.dart';
import 'package:test/test.dart';

// Intentionally implement every member: adding an abstract member must break
// this consumer at compile time, even when ordinary calls remain compatible.
class ApplicationResolver implements FactoryResolver {
  ApplicationResolver(this.container);
  final FactoryContainer container;

  @override
  T resolve<T extends Object>(Factory<T> factory) => container.read(factory);
}

class ApplicationRef implements FactoryRef {
  ApplicationRef(this.delegate);
  final FactoryRef delegate;

  @override
  FactoryResolver get resolver => delegate.resolver;

  @override
  T read<T extends Object>(Factory<T> factory) => delegate.read(factory);

  @override
  T watch<T extends Object>(Factory<T> factory) => delegate.watch(factory);

  @override
  R select<T extends Object, R>(Factory<T> factory, R Function(T) selector) =>
      delegate.select(factory, selector);
}

class DeclarationType implements FactoryVisitor<Type> {
  @override
  Type visit<T extends Object>(Factory<T> factory) => T;
}

void main() {
  test('external interfaces preserve typed resolution and observation',
      () async {
    final source = Factory<String>.external();
    final derived = Factory<String>(
      (ref) {
        final application = ApplicationRef(ref);
        expect(application.read(source), application.resolver.resolve(source));
        return '${application.watch(source)}!';
      },
      onChange: ChangePolicy.recreate,
    );
    final container = FactoryContainer(
      modules: [
        FactoryModule(factories: [source, derived])
      ],
      overrides: [source.overrideWithValue('first')],
    );
    addTearDown(container.close);
    final resolver = ApplicationResolver(container);
    expect(resolver.resolve(derived), 'first!');
    container.setOverrides([source.overrideWithValue('second')]);
    expect(resolver.resolve(derived), 'second!');
    expect(derived.accept(DeclarationType()), String);
  });
}
