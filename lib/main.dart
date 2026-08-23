import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only: every screen is a single column, and locking the
  // orientation keeps the timetable readable on small phones.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final notifications = NotificationService();
  await notifications.init();

  runApp(
    ProviderScope(
      overrides: <Override>[
        // Share the already-initialised instance so the first reminder does
        // not have to wait for time-zone data to load again.
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const StudySyncApp(),
    ),
  );
}
