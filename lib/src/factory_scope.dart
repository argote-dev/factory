import 'dart:async';

import 'package:factory_core/factory_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Installs a [FactoryContainer] for an application or a nested flow.
///
/// Only declarations selected by a module's `expose` list become Provider
/// values. Factory retains ownership of values it creates; this widget never
/// supplies Provider with a disposal callback.
class FactoryScope extends StatefulWidget {
  /// Installs [modules] around [child].
  const FactoryScope({
    required this.child,
    this.modules = const [],
    this.overrides = const [],
    this.local = const [],
    this.onClose,
    this.onError,
    super.key,
  });

  /// Modules whose declarations belong to this scope.
  final List<FactoryModule> modules;

  /// The subtree that can consume exposed declarations through Provider.
  final Widget child;

  /// Values or constructors that replace declarations in this scope.
  final List<FactoryOverride> overrides;

  /// Inherited declarations rebuilt in this scope.
  final List<Factory<Object>> local;

  /// Receives the future that completes when this scope's cleanup finishes.
  final ValueChanged<Future<void>>? onClose;

  /// Receives a cleanup failure from the asynchronous close operation.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Finds the closest enclosing container.
  static FactoryContainer of(BuildContext context) {
    final container = maybeOf(context);
    if (container == null) {
      throw StateError('No FactoryScope exists above this context.');
    }
    return container;
  }

  /// Finds the closest enclosing container, if one exists.
  static FactoryContainer? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_FactoryScopeMarker>()
      ?.container;

  @override
  State<FactoryScope> createState() => _FactoryScopeState();
}

class _FactoryScopeState extends State<FactoryScope> {
  FactoryContainer? _container;
  FactoryContainer? _parent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = FactoryScope.maybeOf(context);
    if (_container == null) {
      _parent = parent;
      _container = FactoryContainer(
        modules: widget.modules,
        overrides: widget.overrides,
        local: widget.local,
        parent: parent,
        observe: _observeListenable,
      );
    } else if (!identical(_parent, parent)) {
      throw StateError(
          'A FactoryScope cannot move below a different parent scope.');
    }
  }

  @override
  void didUpdateWidget(covariant FactoryScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.overrides, widget.overrides)) {
      _container!.setOverrides(widget.overrides);
    }
    if (!_sameModules(oldWidget.modules, widget.modules) ||
        !_sameReferences(oldWidget.local, widget.local)) {
      throw StateError(
        'FactoryScope modules and local declarations cannot change after mounting.',
      );
    }
  }

  @override
  void dispose() {
    final closing = _container?.close();
    if (closing != null) {
      widget.onClose?.call(closing);
      unawaited(_reportCloseError(closing));
    }
    super.dispose();
  }

  Future<void> _reportCloseError(Future<void> closing) async {
    try {
      await closing;
    } on Object catch (error, stackTrace) {
      final onError = widget.onError;
      if (onError != null) {
        onError(error, stackTrace);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'factory',
            context: ErrorDescription('while closing a FactoryScope'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final container = _container!;
    Widget result =
        _FactoryScopeMarker(container: container, child: widget.child);
    for (final factory in container.exposedFactories.reversed) {
      result = factory.accept(_ProviderVisitor(container, result));
    }
    return result;
  }
}

bool _sameModules(List<FactoryModule> first, List<FactoryModule> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index += 1) {
    final before = first[index];
    final after = second[index];
    if (!_sameReferences(before.factories, after.factories) ||
        !_sameReferences(before.expose, after.expose)) {
      return false;
    }
  }
  return true;
}

void Function() _observeListenable(Object value, void Function() changed) {
  if (value is! Listenable) {
    throw ArgumentError.value(
      value,
      'value',
      'FactoryRef.select requires a Flutter Listenable.',
    );
  }
  value.addListener(changed);
  return () => value.removeListener(changed);
}

bool _sameReferences<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index += 1) {
    if (!identical(first[index], second[index])) return false;
  }
  return true;
}

class _FactoryScopeMarker extends InheritedWidget {
  const _FactoryScopeMarker({required this.container, required super.child});

  final FactoryContainer container;

  @override
  bool updateShouldNotify(_FactoryScopeMarker oldWidget) =>
      !identical(container, oldWidget.container);
}

class _ProviderVisitor implements FactoryVisitor<Widget> {
  const _ProviderVisitor(this.container, this.child);

  final FactoryContainer container;
  final Widget child;

  @override
  Widget visit<T extends Object>(Factory<T> factory) => _FactoryProvider<T>(
        factory: factory,
        container: container,
        child: child,
      );
}

class _FactoryProvider<T extends Object> extends StatefulWidget {
  const _FactoryProvider({
    required this.factory,
    required this.container,
    required this.child,
  });

  final Factory<T> factory;
  final FactoryContainer container;
  final Widget child;

  @override
  State<_FactoryProvider<T>> createState() => _FactoryProviderState<T>();
}

class _FactoryProviderState<T extends Object>
    extends State<_FactoryProvider<T>> {
  late final VoidCallback _unsubscribe;
  T? _value;
  var _hasValue = false;
  Object? _error;
  StackTrace? _errorStackTrace;
  var _needsNotify = false;

  @override
  void initState() {
    super.initState();
    _unsubscribe = widget.container.addListener((factory) {
      if (!identical(factory, widget.factory) || !mounted) return;
      try {
        _value = widget.container.read(widget.factory);
        _hasValue = true;
        _error = null;
        _errorStackTrace = null;
        _needsNotify = true;
      } on Object catch (error, stackTrace) {
        _error = error;
        _errorStackTrace = stackTrace;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  T _create() {
    if (_hasValue) return _value as T;
    final value = widget.container.read(widget.factory);
    _value = value;
    _hasValue = true;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      Error.throwWithStackTrace(_error!, _errorStackTrace!);
    }
    return InheritedProvider<T>(
      create: (_) => _create(),
      update: (_, __) => _value as T,
      updateShouldNotify: (_, __) {
        final shouldNotify = _needsNotify;
        _needsNotify = false;
        return shouldNotify;
      },
      startListening: widget.factory.isType<ChangeNotifier>()
          ? (element, value) {
              final notifier = value as ChangeNotifier;
              void listener() => element.markNeedsNotifyDependents();
              notifier.addListener(listener);
              return () => notifier.removeListener(listener);
            }
          : null,
      child: widget.child,
    );
  }
}
