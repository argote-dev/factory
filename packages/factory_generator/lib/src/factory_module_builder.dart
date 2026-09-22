import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

const _registryChecker = TypeChecker.typeNamedLiterally(
  'FactoryRegistry',
  inPackage: 'factory_core',
);
const _registerChecker = TypeChecker.typeNamedLiterally(
  'Register',
  inPackage: 'factory_core',
);

/// Aggregates annotated top-level Factory declarations into module constants.
class FactoryModuleBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.factory.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) return;
    final input = await buildStep.inputLibrary;
    _validateFactoryRegistryTargets(input);
    _validateRegisterTargets(input);
    final registries = input.topLevelFunctions
        .where((element) => _registryChecker.hasAnnotationOf(element))
        .toList();

    if (registries.isEmpty) return;
    if (registries.length > 1) {
      throw InvalidGenerationSource(
        'Only one @FactoryRegistry entrypoint is allowed per library. Choose '
        'one runtime target and remove the conflicting registry.',
        element: registries.last,
      );
    }

    final annotation = ConstantReader(
      _registryChecker.firstAnnotationOf(registries.single),
    );
    final runtime = annotation.read('runtime');
    if (runtime.isNull) {
      throw InvalidGenerationSource(
        'FactoryRegistry must select exactly one runtime: '
        'FactoryRuntime.dart or FactoryRuntime.flutter.',
        element: registries.single,
      );
    }
    final runtimeName = runtime.objectValue.variable?.name;
    final runtimeImport = switch (runtimeName) {
      'dart' => 'package:factory_core/factory_core.dart',
      'flutter' => 'package:factory_provider/factory_provider.dart',
      _ => throw InvalidGenerationSource(
        'Unsupported FactoryRegistry runtime. Choose FactoryRuntime.dart or '
        'FactoryRuntime.flutter.',
        element: registries.single,
      ),
    };
    final includes = annotation
        .read('include')
        .listValue
        .map((value) => ConstantReader(value).stringValue)
        .toList();
    for (final include in includes) {
      if (!include.startsWith('lib/')) {
        throw InvalidGenerationSource(
          '@FactoryRegistry.include only supports current-package lib/ globs. '
          'Received "$include".',
          element: registries.single,
        );
      }
    }

    final registrations = <_Registration>[];
    final visited = <AssetId>{};
    for (final include in includes) {
      await for (final asset in buildStep.findAssets(Glob(include))) {
        if (asset.package != buildStep.inputId.package ||
            !asset.path.endsWith('.dart') ||
            asset.path.endsWith('.factory.dart') ||
            !visited.add(asset) ||
            !await buildStep.resolver.isLibrary(asset)) {
          continue;
        }
        final library = await buildStep.resolver.libraryFor(asset);
        registrations.addAll(_registrationsIn(library, asset));
      }
    }

    final source = _render(registrations, runtimeImport);
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.factory.dart'),
      source,
    );
  }

  Iterable<_Registration> _registrationsIn(
    LibraryElement library,
    AssetId asset,
  ) sync* {
    for (final variable in library.topLevelVariables) {
      final register = _registerChecker.firstAnnotationOf(
        variable,
        throwOnUnresolved: false,
      );
      if (register == null) continue;

      final name = variable.name;
      if (name == null || name.startsWith('_')) {
        throw InvalidGenerationSource(
          '@Register may only annotate a public top-level final Factory.',
          element: variable,
        );
      }
      if (!variable.isFinal || !_isFactory(variable.type)) {
        throw InvalidGenerationSource(
          '@Register may only annotate a public top-level final Factory<T>.',
          element: variable,
        );
      }

      final reader = ConstantReader(register);
      final module = reader.read('module').stringValue;
      if (!_isDartIdentifier(module)) {
        throw InvalidGenerationSource(
          'Module "$module" is not a valid Dart identifier. '
          'It must form a valid generated name such as appModule.',
          element: variable,
        );
      }

      final factoryType = variable.type as InterfaceType;
      if (factoryType.typeArguments.length != 1) {
        throw InvalidGenerationSource(
          '@Register requires Factory<T> with one type argument.',
          element: variable,
        );
      }
      yield _Registration(
        asset: asset,
        variable: variable,
        module: module,
        expose: reader.read('expose').boolValue,
        exposedType: factoryType.typeArguments.single,
      );
    }
  }

  bool _isFactory(DartType type) =>
      type is InterfaceType &&
      type.element.name == 'Factory' &&
      type.element.library.uri.scheme == 'package' &&
      type.element.library.uri.path.startsWith('factory_core/');

  void _validateFactoryRegistryTargets(LibraryElement library) {
    for (final variable in library.topLevelVariables) {
      _rejectAnnotationOn(
        variable,
        _registryChecker,
        '@FactoryRegistry may only annotate a top-level function.',
      );
    }
    for (final classElement in library.classes) {
      _rejectAnnotationOn(
        classElement,
        _registryChecker,
        '@FactoryRegistry may only annotate a top-level function.',
      );
      for (final member in _membersOf(classElement)) {
        _rejectAnnotationOn(
          member,
          _registryChecker,
          '@FactoryRegistry may only annotate a top-level function.',
        );
      }
    }
  }

  void _validateRegisterTargets(LibraryElement library) {
    for (final function in library.topLevelFunctions) {
      _rejectAnnotationOn(
        function,
        _registerChecker,
        '@Register may only annotate a public top-level final Factory<T>.',
      );
    }
    for (final classElement in library.classes) {
      _rejectAnnotationOn(
        classElement,
        _registerChecker,
        '@Register may only annotate a public top-level final Factory<T>.',
      );
      for (final member in _membersOf(classElement)) {
        _rejectAnnotationOn(
          member,
          _registerChecker,
          '@Register may only annotate a public top-level final Factory<T>.',
        );
      }
    }
  }

  Iterable<Element> _membersOf(ClassElement classElement) sync* {
    yield* classElement.constructors;
    yield* classElement.fields;
    yield* classElement.getters;
    yield* classElement.setters;
    yield* classElement.methods;
  }

  void _rejectAnnotationOn(
    Element element,
    TypeChecker checker,
    String message,
  ) {
    if (checker.hasAnnotationOf(element, throwOnUnresolved: false)) {
      throw InvalidGenerationSource(message, element: element);
    }
  }

  String _render(List<_Registration> registrations, String runtimeImport) {
    final sorted = [...registrations]
      ..sort((left, right) {
        final byAsset = left.asset.path.compareTo(right.asset.path);
        return byAsset != 0
            ? byAsset
            : left.variable.name!.compareTo(right.variable.name!);
      });
    _validateExposedTypes(sorted);

    final aliases = <AssetId, String>{};
    for (final registration in sorted) {
      aliases.putIfAbsent(registration.asset, () => 'factory${aliases.length}');
    }

    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln()
      ..writeln("import '$runtimeImport';");
    for (final entry in aliases.entries) {
      buffer.writeln("import '${_packageUri(entry.key)}' as ${entry.value};");
    }
    buffer.writeln();

    final grouped = <String, List<_Registration>>{};
    for (final registration in sorted) {
      (grouped[registration.module] ??= []).add(registration);
    }
    for (final module in grouped.keys.toList()..sort()) {
      final values = grouped[module]!;
      final factories = values
          .map((value) => '${aliases[value.asset]}.${value.variable.name}')
          .join(', ');
      final exposed = values
          .where((value) => value.expose)
          .map((value) => '${aliases[value.asset]}.${value.variable.name}')
          .join(', ');
      buffer
        ..writeln('final ${module}Module = FactoryModule(')
        ..writeln('  factories: [$factories],')
        ..writeln('  expose: [$exposed],')
        ..writeln(');')
        ..writeln();
    }
    return '${buffer.toString().trimRight()}\n';
  }

  void _validateExposedTypes(List<_Registration> registrations) {
    final seen = <String, List<_Registration>>{};
    for (final registration in registrations.where((value) => value.expose)) {
      final inModule = seen.putIfAbsent(registration.module, () => []);
      _Registration? previous;
      for (final candidate in inModule) {
        if (candidate.exposedType == registration.exposedType) {
          previous = candidate;
          break;
        }
      }
      if (previous != null) {
        throw InvalidGenerationSource(
          'Module "${registration.module}" exposes both '
          '${previous.variable.name} and ${registration.variable.name} with '
          'the same Factory type.',
          element: registration.variable,
        );
      }
      inModule.add(registration);
    }
  }

  String _packageUri(AssetId asset) {
    if (!asset.path.startsWith('lib/')) {
      throw ArgumentError.value(
        asset,
        'asset',
        'Only lib/ sources can be imported.',
      );
    }
    return 'package:${asset.package}/${asset.path.substring(4)}';
  }
}

class _Registration {
  const _Registration({
    required this.asset,
    required this.variable,
    required this.module,
    required this.expose,
    required this.exposedType,
  });

  final AssetId asset;
  final TopLevelVariableElement variable;
  final String module;
  final bool expose;
  final DartType exposedType;
}

bool _isDartIdentifier(String value) =>
    RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(value) &&
    !_dartKeywords.contains(value);

const _dartKeywords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};
