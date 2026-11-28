import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/omni_theme.dart';
import 'providers/omni_driver_provider.dart';
import 'screens/home_screen.dart';
import 'services/backend_service.dart';
import 'services/driver_notification_service.dart';
import 'services/firebase_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final backendService = OmniBackendService();
  final firebaseService = OmniFirebaseService();
  final locationService = OmniLocationService();
  final notificationService = DriverNotificationService();

  await backendService.loadConfiguredDomain();
  await firebaseService.initialize();
  try {
    FirebaseMessaging.onBackgroundMessage(omniFirebaseMessagingBackgroundHandler);
  } catch (_) {}
  await locationService.startTracking();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: backendService),
        ChangeNotifierProvider.value(value: firebaseService),
        ChangeNotifierProvider.value(value: locationService),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider(
          create: (_) => OmniDriverProvider(
            backend: backendService,
            locationService: locationService,
            firebaseService: firebaseService,
            notificationService: notificationService,
          ),
        ),
      ],
      child: const OmniMotoristaApp(),
    ),
  );
}

class OmniMotoristaApp extends StatefulWidget {
  const OmniMotoristaApp({super.key});

  @override
  State<OmniMotoristaApp> createState() => _OmniMotoristaAppState();
}

class _OmniMotoristaAppState extends State<OmniMotoristaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Revalida fila nativa apenas ao retornar ao app, evitando cancelar alarmes durante o fechamento
    if (state == AppLifecycleState.resumed) {
      try {
        final notifSvc = context.read<DriverNotificationService>();
        if (notifSvc.initialized) {
          unawaited(notifSvc.resyncScheduledPromoAlarms());
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMNI Motorista PRO',
      debugShowCheckedModeBanner: false,
      theme: OmniTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
