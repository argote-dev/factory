import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'profile_controller.dart';

/// This widget works with both composition roots because it only uses Provider.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile flow')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.isLoading) const CircularProgressIndicator(),
            if (controller.error case final error?) Text('Error: $error'),
            if (controller.profileName case final name?) Text('Profile: $name'),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('load-profile'),
              onPressed: controller.isLoading ? null : controller.load,
              child: const Text('Load local profile'),
            ),
          ],
        ),
      ),
    );
  }
}
