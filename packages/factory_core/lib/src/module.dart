part of '../factory_core.dart';

/// Declarations installed together, with explicit Provider exposure.
class FactoryModule {
  /// Groups declarations independently of their order.
  FactoryModule({
    required List<Factory<Object>> factories,
    List<Factory<Object>> expose = const [],
  })  : factories = List.unmodifiable(factories),
        expose = List.unmodifiable(expose);

  /// All declarations owned by the receiving container.
  final List<Factory<Object>> factories;

  /// The declarations made visible to Provider consumers.
  final List<Factory<Object>> expose;
}
