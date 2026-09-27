import 'dart:convert';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    // Web does not forward test console output; retain completed flows here.
    print('Verified profile flows: ${jsonEncode(data)}');
  },
);
