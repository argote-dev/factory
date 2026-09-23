part of '../factory_core.dart';

/// Subscribes to an object's state and returns a function that stops listening.
///
/// The Flutter adapter supplies Listenable support. Pure Dart callers can supply
/// their own observer without adding any interface to application classes.
typedef FactoryObserver = void Function() Function(
    Object value, void Function() changed);

/// Resolves installed declarations independently of a widget tree.
class FactoryContainer {
  /// Installs declarations locally and inherits unmodified values from [parent].
  FactoryContainer(
      {List<FactoryModule> modules = const [],
      this.parent,
      List<Factory<Object>> local = const [],
      List<FactoryOverride> overrides = const [],
      FactoryObserver? observe})
      : _observe = observe ?? parent?._observe {
    parent?._checkOpen();
    for (final module in modules) {
      _factories.addAll(module.factories);
      for (final factory in module.expose) {
        if (!module.factories.contains(factory)) {
          throw ArgumentError(
              'Exposed $factory is not installed in its module.');
        }
        final previous = _exposed[factory.valueType];
        if (previous != null && !identical(previous, factory)) {
          throw ArgumentError(
              'Duplicate exposed type ${factory.valueType}: $previous and '
              '$factory conflict in the same Factory scope. Expose only one.');
        }
        _exposed[factory.valueType] = factory;
      }
    }
    _factories.addAll(local);
    for (final override in overrides) {
      if (_overrides.containsKey(override.factory)) {
        throw ArgumentError('Duplicate override for ${override.factory}.');
      }
      _factories.add(override.factory);
      _overrides[override.factory] = override;
    }
    parent?._children.add(this);
    try {
      for (final factory in _factories) {
        if (!factory.lazy) read(factory);
      }
    } catch (error, stack) {
      // A synchronous opening failure still exposes the asynchronous cleanup.
      final cleanup = close();
      unawaited(cleanup.catchError((Object _) {}));
      throw FactoryInitializationException(error, stack, cleanup);
    }
  }

  /// The enclosing scope, if any.
  final FactoryContainer? parent;
  final FactoryObserver? _observe;
  final List<FactoryContainer> _children = [];
  final Set<Factory<Object>> _factories = {};
  final Map<Type, Factory<Object>> _exposed = {};
  final Map<Factory<Object>, FactoryOverride> _overrides = {};
  final Map<Factory<Object>, _Record> _instances = {};
  final List<_Record> _records = [];
  final List<Factory<Object>> _resolving = [];
  final List<void Function(Factory<Object>)> _listeners = [];
  bool _closed = false;
  Future<void>? _closing;
  bool _propagating = false;
  Set<_Record> _wave = {};
  final Set<_Record> _pending = {};

  /// Declarations made available to the adapter in this scope.
  List<Factory<Object>> get exposedFactories =>
      List.unmodifiable(_exposed.values);

  void _checkOpen() {
    if (_closed) throw StateError('The FactoryContainer is closed.');
  }

  FactoryContainer _owner(Factory<Object> factory) {
    _checkOpen();
    if (_factories.contains(factory)) return this;
    if (parent != null) return parent!._owner(factory);
    final scope = parent == null ? 'root Factory scope' : 'Factory scope';
    throw StateError(
      '$factory is not installed in this $scope. Install it in a module or '
      'as a local declaration in the appropriate scope.',
    );
  }

  /// Resolves a declaration in its owning scope.
  T read<T extends Object>(Factory<T> factory) {
    final record = _resolve(factory);
    final value = record.value as T;
    // Direct unique values need no bookkeeping unless they retain scope access,
    // cleanup or observation. Graph reads keep edges for cleanup order.
    if (factory.lifetime == Lifetime.unique &&
        record.release == null &&
        record.watches.isEmpty &&
        record.resolver == null) {
      record.owner._records.remove(record);
    }
    return value;
  }

  _Record _resolve(Factory<Object> factory) {
    final owner = _owner(factory);
    if (!identical(owner, this)) return owner._resolve(factory);
    if (_resolving.contains(factory)) {
      throw StateError(
          'Dependency cycle: ${[..._resolving, factory].join(' -> ')}');
    }
    var record = _instances[factory];
    if (record == null || factory.lifetime == Lifetime.unique) {
      record = _Record(this, factory);
      _records.add(record);
      if (factory.lifetime == Lifetime.scoped) _instances[factory] = record;
    }
    if (record.dirty) _build(record);
    if (record.error != null) {
      Error.throwWithStackTrace(record.error!, record.stack!);
    }
    return record;
  }

  void _build(_Record record) {
    final factory = record.factory;
    _resolving.add(factory);
    record.dirty = false;
    record.error = null;
    try {
      record.stopWatching();
      final ref = _Ref(this, record);
      if (record.value != null &&
          !record.forceRecreate &&
          factory.onChange == ChangePolicy.update) {
        factory._updateValue(ref, record.value!);
      } else {
        // Retain retired values: unobserved consumers may still reference them.
        if (record.value != null) {
          final retired = record.retired();
          for (final consumer in _root._allRecords) {
            if (consumer.dependencies.remove(record)) {
              consumer.dependencies.add(retired);
            }
          }
          _records.add(retired);
          record.value = null;
          record.dependencies.clear();
        }
        final override = _overrides[factory];
        record.release = override?._value != null
            ? null
            : override == null
                ? (factory._hasDispose ? factory._release : null)
                : override._dispose;
        record.value = override?._value ??
            override?._create?.call(ref) ??
            factory._construct(ref);
      }
    } catch (error, stack) {
      record.error = error;
      record.stack = stack;
      if (record.value == null) {
        record.resolver?.invalidate();
        record.resolver = null;
      }
    } finally {
      record.forceRecreate = false;
      _resolving.removeLast();
    }
  }

  /// Replaces this scope's overrides as one change transaction.
  ///
  /// Identical borrowed values do not trigger dependents. Existing unobserved
  /// connections keep their values until scope closure.
  void setOverrides(List<FactoryOverride> overrides) {
    _checkOpen();
    if (_root._propagating) {
      throw StateError(
          'Overrides cannot change while the dependency graph is updating.');
    }
    final next = <Factory<Object>, FactoryOverride>{};
    for (final override in overrides) {
      if (next.containsKey(override.factory)) {
        throw ArgumentError('Duplicate override for ${override.factory}.');
      }
      if (!_factories.contains(override.factory)) {
        throw ArgumentError('${override.factory} is not installed locally.');
      }
      next[override.factory] = override;
    }
    final changed = <_Record>{};
    final declarations = <Factory<Object>>{};
    for (final factory in {..._overrides.keys, ...next.keys}) {
      final before = _overrides[factory];
      final after = next[factory];
      if (identical(before, after)) continue;
      if (before?._value != null && identical(before?._value, after?._value)) {
        continue;
      }
      declarations.add(factory);
      for (final record in _records.where((record) =>
          !record.isRetired && identical(record.factory, factory))) {
        record.forceRecreate = true;
        changed.add(record);
      }
    }
    _overrides
      ..clear()
      ..addAll(next);
    _propagate(changed);
    // Direct unique values may already have been released from bookkeeping.
    // Declaration listeners still need one invalidation, without creating values.
    for (final factory in declarations) {
      if (changed.any((record) => identical(record.factory, factory))) continue;
      for (final listener in _listeners.toList()) {
        listener(factory);
      }
    }
  }

  /// Receives invalidations of resolved declarations; returns an unsubscribe.
  void Function() addListener(void Function(Factory<Object>) listener) {
    _checkOpen();
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  FactoryContainer get _root => parent?._root ?? this;
  Iterable<_Record> get _allRecords sync* {
    yield* _records;
    for (final child in _children) {
      yield* child._allRecords;
    }
  }

  Iterable<_Record> get _activeRecords sync* {
    if (_closed) return;
    yield* _records.where((record) => !record.isRetired);
    for (final child in _children) {
      yield* child._activeRecords;
    }
  }

  void _propagate(Set<_Record> changed) {
    if (changed.isEmpty || _closed) return;
    if (!identical(_root, this)) {
      _root._propagate(changed);
      return;
    }
    _pending.addAll(changed.where((record) => !_wave.contains(record)));
    if (_propagating) return;
    _propagating = true;
    try {
      while (_pending.isNotEmpty) {
        _wave = Set.of(_pending);
        _pending.clear();
        final records = _activeRecords.toList();
        bool grew;
        do {
          grew = false;
          for (final record in records) {
            if (!_wave.contains(record) && record.watches.any(_wave.contains)) {
              _wave.add(record);
              grew = true;
            }
          }
        } while (grew);
        // Mark the entire graph before resolving any member. Notifications from
        // in-place updates are coalesced into this wave, never resolved reentrantly.
        for (final record in _wave) {
          if (record.forceRecreate &&
              record.factory.lifetime == Lifetime.unique) {
            // Every prior unique resolution is a snapshot, never a cached slot.
            record.isRetired = true;
            record.forceRecreate = false;
          } else {
            record.dirty = true;
          }
        }
        for (final record in _wave) {
          if (!record.isRetired && record.dirty) record.owner._build(record);
        }
        final notified = <(FactoryContainer, Factory<Object>)>{};
        for (final record in _wave) {
          if (!notified.add((record.owner, record.factory))) continue;
          for (final listener in record.owner._listeners.toList()) {
            listener(record.factory);
          }
        }
        _wave = {};
      }
    } finally {
      _wave = {};
      _pending.clear();
      _propagating = false;
    }
  }

  /// Closes child scopes and then this scope, attempting every cleanup callback.
  ///
  /// Resolution stops immediately. Repeated calls return the same future.
  Future<void> close() {
    if (_closing != null) return _closing!;
    _markClosed();
    final completer = Completer<void>();
    _closing = completer.future;
    unawaited(_releaseAll()
        .then(completer.complete, onError: completer.completeError));
    return _closing!;
  }

  void _markClosed() {
    _closed = true;
    for (final child in _children) {
      child._markClosed();
    }
  }

  Future<void> _releaseAll() async {
    final errors = <Object>[];
    for (final child in _children.reversed.toList()) {
      try {
        await child.close();
      } catch (error) {
        errors.add(error);
      }
    }
    for (final record in _records) {
      try {
        record.stopWatching();
      } catch (error) {
        errors.add(error);
      }
    }
    final ordered = <_Record>[];
    final visited = <_Record>{};
    void visit(_Record record) {
      if (!identical(record.owner, this) || !visited.add(record)) return;
      for (final dependency in record.dependencies) {
        visit(dependency);
      }
      ordered.add(record);
    }

    for (final record in _records) {
      visit(record);
    }
    for (final record in ordered.reversed) {
      try {
        if (record.value != null) await record.release?.call(record.value!);
      } catch (error) {
        errors.add(error);
      } finally {
        record.resolver?.invalidate();
        record.resolver = null;
      }
    }
    _records.clear();
    _instances.clear();
    _listeners.clear();
    parent?._children.remove(this);
    if (errors.isNotEmpty) throw FactoryCleanupException(errors);
  }
}

class _Record {
  _Record(this.owner, this.factory);
  final FactoryContainer owner;
  final Factory<Object> factory;
  Object? value;
  Object? error;
  StackTrace? stack;
  bool dirty = true;
  bool forceRecreate = false;
  bool isRetired = false;
  FutureOr<void> Function(Object)? release;
  _Resolver? resolver;
  final Set<_Record> dependencies = {};
  final Set<_Record> watches = {};
  final List<void Function()> subscriptions = [];
  void stopWatching() {
    final errors = <Object>[];
    for (final cancel in subscriptions) {
      try {
        cancel();
      } catch (error) {
        errors.add(error);
      }
    }
    subscriptions.clear();
    watches.clear();
    if (errors.isNotEmpty) throw FactoryCleanupException(errors);
  }

  void addDependency(_Record dependency) {
    final visited = <_Record>{};
    final path = <_Record>[];
    bool reachesThis(_Record current) {
      if (!visited.add(current)) return false;
      path.add(current);
      if (identical(current, this)) return true;
      for (final next in current.dependencies) {
        if (reachesThis(next)) return true;
      }
      path.removeLast();
      return false;
    }

    if (reachesThis(dependency)) {
      throw StateError(
        'Dependency cycle: ${[
          factory,
          ...path.map((r) => r.factory)
        ].join(' -> ')}',
      );
    }
    dependencies.add(dependency);
  }

  _Record retired() {
    final retired = _Record(owner, factory)
      ..value = value
      ..release = release
      ..isRetired = true
      ..dirty = false
      ..dependencies.addAll(dependencies)
      ..resolver = resolver;
    // A retained capability follows the old value, not the slot being rebuilt.
    resolver?._record = retired;
    resolver = null;
    return retired;
  }
}

class _Resolver implements FactoryResolver {
  _Resolver(this._record);

  _Record? _record;

  void invalidate() => _record = null;

  _Record _activeRecord() {
    final record = _record;
    if (record == null) {
      throw StateError('The FactoryResolver is no longer active.');
    }
    record.owner._checkOpen();
    return record;
  }

  @override
  T resolve<T extends Object>(Factory<T> factory) {
    final dependency = _activeRecord().owner._resolve(factory);
    // Construction can replace the consumer or start closing its scope.
    _activeRecord().addDependency(dependency);
    return dependency.value as T;
  }
}

class _Ref implements FactoryRef {
  _Ref(this.owner, this.record);
  final FactoryContainer owner;
  final _Record record;
  @override
  FactoryResolver get resolver => record.resolver ??= _Resolver(record);

  @override
  T read<T extends Object>(Factory<T> factory) {
    final dependency = owner._resolve(factory);
    record.addDependency(dependency);
    return dependency.value as T;
  }

  @override
  T watch<T extends Object>(Factory<T> factory) {
    if (record.factory.onChange == null) {
      throw StateError(
          '${record.factory} must choose onChange to observe $factory.');
    }
    final target = owner._owner(factory);
    late final _Record dependency;
    try {
      dependency = target._resolve(factory);
    } catch (_) {
      for (final failed in target._records.reversed) {
        if (!failed.isRetired && identical(failed.factory, factory)) {
          record.watches.add(failed);
          break;
        }
      }
      rethrow;
    }
    record.addDependency(dependency);
    record.watches.add(dependency);
    return dependency.value as T;
  }

  @override
  R select<T extends Object, R>(Factory<T> factory, R Function(T) selector) {
    final value = watch(factory);
    final observer = owner._observe;
    if (observer == null) {
      throw StateError('Selecting $factory requires an observer adapter.');
    }
    var selected = selector(value);
    record.subscriptions.add(observer(value, () {
      if (owner._closed || record.isRetired) return;
      final next = selector(value);
      if (next == selected) return;
      selected = next;
      owner._propagate({record});
    }));
    return selected;
  }
}

/// A synchronous creation failure with observable cleanup of partially built values.
class FactoryInitializationException implements Exception {
  /// Describes the creation error and cleanup started by the container.
  FactoryInitializationException(this.error, this.stackTrace, this.cleanup);

  /// The original creation failure.
  final Object error;

  /// Where creation failed.
  final StackTrace stackTrace;

  /// Cleanup of values created before the failure.
  final Future<void> cleanup;
  @override
  String toString() => 'FactoryInitializationException: $error';
}

/// All failures collected while releasing a scope.
class FactoryCleanupException implements Exception {
  /// Collects the cleanup failures.
  FactoryCleanupException(List<Object> errors)
      : errors = List.unmodifiable(errors);

  /// Failures, in cleanup order.
  final List<Object> errors;
  @override
  String toString() => 'FactoryCleanupException: ${errors.join('; ')}';
}
