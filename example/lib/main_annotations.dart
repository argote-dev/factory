import 'package:flutter/material.dart';

import 'composition/registry.factory.dart';
import 'composition/factory_example_app.dart';

void main() => runApp(
  FactoryExampleApp(appModule: appModule, profileModule: profileModule),
);
