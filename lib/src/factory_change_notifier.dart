import 'package:factory_core/factory_core.dart';
import 'package:flutter/foundation.dart' hide Factory;

/// A notifier with explicit access to its Factory dependencies.
///
/// Pass [FactoryRef.resolver] from the notifier's declaration. Register a
/// [Factory] cleanup callback that calls [dispose] for Factory-owned notifiers.
/// Dependencies remain owned by their scopes, and reads do not observe changes.
abstract class FactoryChangeNotifier extends ChangeNotifier {
  /// Creates a notifier using the resolution capability for its instance.
  FactoryChangeNotifier(FactoryResolver resolver) : _resolver = resolver;

  final FactoryResolver _resolver;
  bool _disposed = false;

  /// Resolves [factory] using its declared lifetime without an additional cache.
  ///
  /// Available in the constructor body, `late` initializers and later methods.
  /// Throws a [StateError] after [dispose], when the scope closes, or when the
  /// read introduces a dependency cycle. Results may be stored in fields when
  /// the notifier needs to retain a particular instance.
  @protected
  @nonVirtual
  T resolve<T extends Object>(Factory<T> factory) {
    if (_disposed) {
      throw StateError('Cannot resolve $factory after $runtimeType.dispose().');
    }
    return _resolver.resolve(factory);
  }

  /// Invalidates dependency access and releases this notifier's listeners.
  ///
  /// Leaves dependencies and their scope under their existing ownership.
  @override
  @mustCallSuper
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
