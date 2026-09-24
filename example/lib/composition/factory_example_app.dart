import 'dart:async';

import 'package:factory_provider/factory_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'factories.dart';
import '../domain/session.dart';
import '../domain/profile_flow_monitor.dart';
import '../presentation/app.dart';
import '../presentation/profile_page.dart';

/// The shared profile flow for manual and generated modules.
///
/// [Session] is owned by Provider and borrowed by Factory.
class FactoryExampleApp extends StatelessWidget {
  const FactoryExampleApp({
    required this.appModule,
    required this.profileModule,
    super.key,
  });

  final FactoryModule appModule;
  final FactoryModule profileModule;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session('Ada Lovelace')),
        ChangeNotifierProvider(create: (_) => ProfileFlowMonitor()),
      ],
      child: Builder(
        builder: (context) => FactoryScope(
          modules: [appModule],
          overrides: [
            session.overrideWithValue(context.watch<Session>()),
            profileFlowMonitor.overrideWithValue(
              context.watch<ProfileFlowMonitor>(),
            ),
          ],
          child: MaterialApp(
            title: 'Factory + Provider',
            home: Builder(
              builder: (navigatorContext) => ExampleHome(
                title: 'Factory + Provider',
                onOpenProfile: () => Navigator.of(navigatorContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FactoryScope(
                      modules: [profileModule],
                      local: [userRepository],
                      overrides: [
                        session.overrideWith(
                          (_) => Session('Grace Hopper'),
                          dispose: (value) => value.dispose(),
                        ),
                      ],
                      onClose: (closing) {
                        unawaited(
                          closing.then(
                            (_) => debugPrint('Profile Factory scope closed'),
                            onError: (_) {},
                          ),
                        );
                      },
                      onError: (error, stackTrace) {
                        FlutterError.reportError(
                          FlutterErrorDetails(
                            exception: error,
                            stack: stackTrace,
                            context: ErrorDescription(
                              'while closing the profile flow',
                            ),
                          ),
                        );
                      },
                      child: const ProfilePage(),
                    ),
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
