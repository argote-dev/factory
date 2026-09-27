part of '../factory_core.dart';

/// Unpublished experiment. The returned string owns no runtime references.
String captureFactoryGraph(FactoryContainer scope,
    {bool includeNames = false}) {
  final scopes = <FactoryContainer>[];
  void visit(FactoryContainer current) {
    scopes.add(current);
    for (final child in current._children) {
      visit(child);
    }
  }

  visit(scope._root);
  final scopeIds = <FactoryContainer, int>{
    for (var i = 0; i < scopes.length; i++) scopes[i]: i + 1,
  };
  final declarations = <Factory<Object>, int>{};
  final records = <_Record, int>{};
  for (final current in scopes) {
    for (final factory in current._factories) {
      declarations.putIfAbsent(factory, () => declarations.length + 1);
    }
    for (final record in current._records) {
      records[record] = records.length + 1;
    }
  }
  final out = StringBuffer('factory-graph-v0 ids=capture-local\n');
  for (final current in scopes) {
    final sid = scopeIds[current];
    out.writeln('scope s$sid parent=${scopeIds[current.parent] ?? "none"} '
        'state=${current._closed ? "closed" : "open"}');
    for (final factory in current._factories) {
      final override = current._overrides[factory];
      final replacement = override == null
          ? 'none'
          : override._value != null
              ? 'borrowed'
              : 'constructor';
      // Escape names as code units: no user-defined toString or callbacks.
      final name = includeNames && factory.name != null
          ? factory.name!.codeUnits
              .map((c) => '\\u${c.toRadixString(16).padLeft(4, "0")}')
              .join()
          : 'redacted';
      out.writeln('declaration d${declarations[factory]} scope=s$sid '
          'visibility=${current._exposed.containsValue(factory) ? "exposed" : "internal"} '
          'override=$replacement lifetime=${factory.lifetime.name} name=$name');
    }
  }
  for (final entry in records.entries) {
    final record = entry.key;
    out.writeln(
        'generation g${entry.value} declaration=d${declarations[record.factory]} '
        'owner=s${scopeIds[record.owner]} '
        'state=${record.isRetired ? "retired" : "active"} '
        'value=${record.value == null ? "absent" : "present"} '
        'error=${record.error == null ? "none" : "present"} '
        'cleanup=${record.release == null ? "none" : "scope"} '
        'resolver=${record.resolver == null ? "absent" : "present"}');
    final targets = {...record.dependencies, ...record.watches}.toList()
      ..sort((a, b) => (records[a] ?? 0).compareTo(records[b] ?? 0));
    for (final target in targets) {
      final cleanup = record.dependencies.contains(target);
      final observed = record.watches.contains(target);
      out.writeln(
          'edge g${entry.value}->${records[target] == null ? "unknown" : "g${records[target]}"} '
          'relation=${observed ? "watch-or-select" : "read-or-resolve-or-retired-watch"} '
          'cleanup=$cleanup observed=$observed');
    }
  }
  return out.toString();
}
