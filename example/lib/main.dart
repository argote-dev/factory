import 'dart:async';

import 'package:factory/factory.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'composition/factories.dart';
import 'composition/registry.factory.dart';
import 'domain/session.dart';
import 'domain/profile_flow_monitor.dart';
import 'presentation/app.dart';
import 'presentation/profile_page.dart';

void main() => runApp(const FactoryExampleApp());

/// The Factory composition of the example. [Session] is supplied by the
/// existing Provider application, so Factory borrows and never closes it.
class FactoryExampleApp extends StatelessWidget {
  const FactoryExampleApp({super.key});

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
