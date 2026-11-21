import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/omni_theme.dart';
import 'providers/omni_driver_provider.dart';
import 'screens/home_screen.dart';
import 'services/backend_service.dart';
import 'services/firebase_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final backendService = OmniBackendService();
  final firebaseService = OmniFirebaseService();
  final locationService = OmniLocationService();

  await backendService.loadConfiguredDomain();
  await firebaseService.initialize();
  await locationService.startTracking();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: backendService),
        ChangeNotifierProvider.value(value: firebaseService),
        ChangeNotifierProvider.value(value: locationService),
        ChangeNotifierProvider(
          create: (_) => OmniDriverProvider(
            backend: backendService,
            locationService: locationService,
          ),
        ),
      ],
      child: const OmniMotoristaApp(),
    ),
  );
}

class OmniMotoristaApp extends StatelessWidget {
  const OmniMotoristaApp({super.key});

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
