import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'domain/profile_client.dart';
import 'domain/profile_flow_monitor.dart';
import 'domain/session.dart';
import 'domain/user_repository.dart';
import 'presentation/app.dart';
import 'presentation/profile_controller.dart';
import 'presentation/profile_page.dart';

void main() => runApp(const ProviderExampleApp());

/// The removable composition uses the same domain and widgets with no Factory
/// import.
class ProviderExampleApp extends StatelessWidget {
  const ProviderExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session('Ada Lovelace')),
        ChangeNotifierProvider(create: (_) => ProfileFlowMonitor()),
        Provider(
          create: (_) => LocalProfileClient(),
          dispose: (_, client) => client.close(),
        ),
        ProxyProvider2<LocalProfileClient, Session, UserRepository>(
          update: (_, client, session, __) => UserRepository(client, session),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Provider only',
          home: Builder(
            builder: (navigatorContext) => ExampleHome(
              title: 'Provider only',
              onOpenProfile: () => Navigator.of(navigatorContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider(
                    create: (context) => ProfileController(
                      context.read<UserRepository>(),
                      context.read<ProfileFlowMonitor>(),
                    ),
                    child: const ProfilePage(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
