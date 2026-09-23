part of '../factory_core.dart';

/// The reuse policy of an installed declaration.
enum Lifetime {
  /// Reuses one instance in the owning container.
  scoped,

  /// Constructs an instance for every resolution.
  unique,
}

/// The response to an explicitly observed dependency change.
enum ChangePolicy {
  /// Constructs a replacement value.
  recreate,

  /// Mutates the existing value using the declaration's update callback.
  update,
}

/// A typed declaration that does not construct its value until resolved.
class Factory<T extends Object> {
  /// Declares how to create a dependency.
  Factory(
    T Function(FactoryRef ref) create, {
    this.name,
    FutureOr<void> Function(T value)? dispose,
    this.lifetime = Lifetime.scoped,
    this.lazy = true,
    this.onChange,
    void Function(FactoryRef ref, T value)? update,
  })  : _create = create,
        _dispose = dispose,
        _update = update {
    if ((onChange == ChangePolicy.update) != (update != null)) {
      throw ArgumentError(
          'ChangePolicy.update requires an update callback and vice versa.');
    }
  }

  /// Declares a value that must be supplied through an override.
  Factory.external({this.name})
      : _create = null,
        _dispose = null,
        lifetime = Lifetime.scoped,
        lazy = true,
        onChange = null,
        _update = null;

  final T Function(FactoryRef ref)? _create;
  final void Function(FactoryRef ref, T value)? _update;
  void _updateValue(FactoryRef ref, Object value) => _update!(ref, value as T);

  /// The explicit response when a watched dependency changes.
  final ChangePolicy? onChange;
  final FutureOr<void> Function(T value)? _dispose;
  bool get _hasDispose => _dispose != null;
  FutureOr<void> _release(Object value) => _dispose?.call(value as T);
  Object _construct(FactoryRef ref) {
    if (_create == null) {
      throw StateError(
        '$this is external and needs an override with a value or constructor '
        'in its Factory scope.',
      );
    }
    return _create(ref);
  }

  /// The optional name used in diagnostics.
  final String? name;

  /// The reuse policy, independent of when creation occurs.
  final Lifetime lifetime;

  /// Whether creation waits until the first resolution.
  final bool lazy;

  /// The declared value type.
  Type get valueType => T;

  /// Tests the declared type rather than the runtime implementation.
  bool isType<S>() => <T>[] is List<S>;

  /// Visits the declaration without erasing its declared type.
  R accept<R>(FactoryVisitor<R> visitor) => visitor.visit<T>(this);

  /// Borrows an existing value without taking ownership of its cleanup.
  FactoryOverride overrideWithValue(T value) =>
      FactoryOverride._(this, value, null, null);

  /// Replaces creation and takes ownership using the supplied cleanup callback.
  FactoryOverride overrideWith(T Function(FactoryRef ref) create,
          {FutureOr<void> Function(T value)? dispose}) =>
      FactoryOverride._(this, null, create,
          dispose == null ? null : (value) => dispose(value as T));
  @override
  String toString() => name ?? 'Factory<$T>';
}

/// Visits a declaration while preserving its value type.
abstract interface class FactoryVisitor<R> {
  /// Receives the original generic declaration.
  R visit<T extends Object>(Factory<T> factory);
}

/// A local replacement for a declaration.
class FactoryOverride {
  FactoryOverride._(this.factory, this._value, this._create, this._dispose);

  /// The declaration being replaced.
  final Factory<Object> factory;
  final Object? _value;
  final Object Function(FactoryRef)? _create;
  final FutureOr<void> Function(Object)? _dispose;
}

/// Scoped dependency access that can be retained by a constructed instance.
///
/// Obtained through [FactoryRef.resolver]. Reads preserve the owning scope's
/// lifetime and cleanup order without observing replacements or state changes.
abstract interface class FactoryResolver {
  /// Resolves [factory] without caching its result or subscribing to changes.
  ///
  /// Throws a [StateError] if the scope has closed, the instance failed to
  /// construct, or this read would introduce a dependency cycle.
  T resolve<T extends Object>(Factory<T> factory);
}

/// Access to dependencies while constructing or updating an instance.
abstract interface class FactoryRef {
  /// The resolution capability for this instance, usable after construction.
  ///
  /// Passes dependency access to an instance without retaining this ref's
  /// construction and observation operations.
  FactoryResolver get resolver;

  /// Resolves a declaration without subscribing to changes.
  T read<T extends Object>(Factory<T> factory);

  /// Resolves a declaration and observes instance replacements.
  T watch<T extends Object>(Factory<T> factory);

  /// Observes replacements and selected state changes using the container adapter.
  R select<T extends Object, R>(
      Factory<T> factory, R Function(T value) selector);
}
