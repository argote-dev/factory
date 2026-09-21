import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/profile_flow_monitor.dart';
import '../domain/session.dart';

/// Shared presentation: it consumes Provider and has no Factory dependency.
class ExampleHome extends StatelessWidget {
  const ExampleHome({
    required this.title,
    required this.onOpenProfile,
    super.key,
  });

  final String title;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final flowMonitor = context.watch<ProfileFlowMonitor>();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Signed in as ${session.displayName}'),
            Text('Closed profile flows: ${flowMonitor.closedFlows}'),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('open-profile'),
              onPressed: onOpenProfile,
              child: const Text('Open profile'),
            ),
          ],
        ),
      ),
    );
  }
}
