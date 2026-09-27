import 'package:integration_test/integration_test.dart';

import 'support/profile_flow.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final verified = <String>[];
  profileFlowTests(
    onVerified: (name) {
      verified.add(name);
      binding.reportData = {
        'verifiedCompositions': verified,
        'cyclesPerComposition': 2,
      };
    },
  );
}
