import 'package:build/build.dart';
import 'package:factory_generator/factory_generator.dart';

/// Creates generated Factory modules for annotated composition entrypoints.
Builder factoryModuleBuilder(BuilderOptions options) => FactoryModuleBuilder();
