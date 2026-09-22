import 'package:build_test/build_test.dart';
import 'package:factory_generator/factory_generator.dart';
import 'package:test/test.dart';

void main() {
  test('rejects a registry without an explicit runtime', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry()
void configureFactories() {}
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('must select exactly one runtime'));
  });

  test(
    'targets the Flutter facade when the registry selects Flutter',
    () async {
      await testBuilder(
        FactoryModuleBuilder(),
        {
          ..._coreAssets,
          'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.flutter)
void configureFactories() {}
''',
        },
        rootPackage: 'example',
        generateFor: {'example|lib/configure.dart'},
        outputs: {
          'example|lib/configure.factory.dart': decodedMatches(
            contains("import 'package:factory/factory.dart';"),
          ),
        },
      );
    },
  );

  test('generates deterministic modules from annotated factories', () async {
    await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';

@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/services.dart': '''
import 'package:factory_core/factory_core.dart';

class Client {}
class Repository {}

@Register(module: 'app')
final client = Factory<Client>((ref) => Client());

@Register(module: 'app', expose: true)
final repository = Factory<Repository>((ref) => Repository());
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
      outputs: {
        'example|lib/configure.factory.dart': '''
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:factory_core/factory_core.dart';
import 'package:example/services.dart' as factory0;

final appModule = FactoryModule(
  factories: [factory0.client, factory0.repository],
  expose: [factory0.repository],
);
''',
      },
    );
  });

  test('honors the registry include glob', () async {
    await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';

@FactoryRegistry(runtime: FactoryRuntime.dart, include: ['lib/composition/**.dart'])
void configureFactories() {}
''',
        'example|lib/composition/app.dart': '''
import 'package:factory_core/factory_core.dart';
class AppService {}
@Register(module: 'app', expose: true)
final appService = Factory<AppService>((ref) => AppService());
''',
        'example|lib/ignored.dart': '''
import 'package:factory_core/factory_core.dart';
class Ignored {}
@Register(module: 'ignored')
final ignored = Factory<Ignored>((ref) => Ignored());
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
      outputs: {
        'example|lib/configure.factory.dart': decodedMatches(
          allOf(
            contains('final appModule = FactoryModule('),
            isNot(contains('ignoredModule')),
          ),
        ),
      },
    );
  });

  test('rejects duplicate exposed types in one module', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/services.dart': '''
import 'package:factory_core/factory_core.dart';
class Client {}
@Register(module: 'app', expose: true)
final primary = Factory<Client>((ref) => Client());
@Register(module: 'app', expose: true)
final secondary = Factory<Client>((ref) => Client());
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('same Factory type'));
  });

  test('rejects invalid module identifiers', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/services.dart': '''
import 'package:factory_core/factory_core.dart';
class Client {}
@Register(module: 'not-a-name')
final client = Factory<Client>((ref) => Client());
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('not a valid Dart identifier'));
  });

  test('rejects duplicate registry entrypoints in one library', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureOne() {}
@FactoryRegistry(runtime: FactoryRuntime.flutter)
void configureTwo() {}
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('Only one @FactoryRegistry'));
    expect(result.errors.single, contains('remove the conflicting registry'));
  });

  test('rejects non-Factory registrations', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/services.dart': '''
import 'package:factory_core/factory_core.dart';
@Register(module: 'app')
final String notAFactory = 'not a factory';
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('top-level final Factory'));
  });

  test('rejects private Factory registrations', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/services.dart': '''
import 'package:factory_core/factory_core.dart';
class Client {}
@Register(module: 'app')
final _client = Factory<Client>((ref) => Client());
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('public top-level final Factory'));
  });

  test('rejects Register on a top-level function', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/services.dart': '''
import 'package:factory_core/factory_core.dart';
@Register(module: 'app')
void invalidRegistration() {}
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('top-level final Factory'));
  });

  test('rejects FactoryRegistry outside a top-level function', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
class InvalidRegistry {}
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(
      result.errors.single,
      contains('only annotate a top-level function'),
    );
  });

  test('rejects Register on class members', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/services.dart': '''
import 'package:factory_core/factory_core.dart';
class Client {}
class InvalidMember {
  @Register(module: 'app')
  final client = Factory<Client>((ref) => Client());
}
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('top-level final Factory'));
  });

  test('rejects include globs outside lib', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart, include: ['test/**.dart'])
void configureFactories() {}
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.single, contains('current-package lib/ globs'));
  });

  test('does not scan stale generated factory outputs', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/stale.factory.dart': '''
import 'package:factory_core/factory_core.dart';
@Register(module: 'app')
final stale = 'must not be scanned';
''',
      },
      rootPackage: 'example',
      generateFor: {'example|lib/configure.dart'},
    );
    expect(result.succeeded, isTrue);
  });

  test('skips part inputs before resolving their library', () async {
    final result = await testBuilder(
      FactoryModuleBuilder(),
      {
        ..._coreAssets,
        'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
part 'configure_part.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
        'example|lib/configure_part.dart': '''
part of 'configure.dart';
class PartOnlyType {}
''',
      },
      rootPackage: 'example',
      generateFor: {
        'example|lib/configure.dart',
        'example|lib/configure_part.dart',
      },
      outputs: {
        'example|lib/configure.factory.dart': '''
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:factory_core/factory_core.dart';
''',
      },
    );
    expect(result.succeeded, isTrue);
  });

  test(
    'does not confuse nested generic types from different libraries',
    () async {
      final result = await testBuilder(
        FactoryModuleBuilder(),
        {
          ..._coreAssets,
          'example|lib/configure.dart': '''
import 'package:factory_core/factory_core.dart';
@FactoryRegistry(runtime: FactoryRuntime.dart)
void configureFactories() {}
''',
          'example|lib/types.dart': '''
class Wrapper<T> {}
''',
          'example|lib/one.dart': '''
import 'package:factory_core/factory_core.dart';
import 'types.dart';
class Item {}
@Register(module: 'app', expose: true)
final one = Factory<Wrapper<Item>>((ref) => Wrapper<Item>());
''',
          'example|lib/two.dart': '''
import 'package:factory_core/factory_core.dart';
import 'types.dart';
class Item {}
@Register(module: 'app', expose: true)
final two = Factory<Wrapper<Item>>((ref) => Wrapper<Item>());
''',
        },
        rootPackage: 'example',
        generateFor: {'example|lib/configure.dart'},
      );
      expect(result.succeeded, isTrue);
    },
  );
}

const _coreAssets = {
  'factory_core|lib/factory_core.dart': '''
class Register {
  const Register({required this.module, this.expose = false});
  final String module;
  final bool expose;
}

class FactoryRegistry {
  const FactoryRegistry({this.include = const ['lib/**.dart'], this.runtime});
  final List<String> include;
  final FactoryRuntime? runtime;
}

enum FactoryRuntime { dart, flutter }

class Factory<T> {
  Factory(T Function(Object) create);
}

class FactoryModule {
  FactoryModule({required List<Factory<Object>> factories, required List<Factory<Object>> expose});
}
''',
};
