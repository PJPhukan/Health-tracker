import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'providers/auth_controller.dart';
import 'providers/health_provider.dart';
import 'providers/profile_controller.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_bootstrap.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // sqflite has no native web implementation — use the WASM/IndexedDB factory.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  // Never throws: without a Firebase config the app runs in local-only mode.
  await FirebaseBootstrap.init();
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        // HealthProvider owns the local logs; it also needs the current daily
        // targets, which live in ProfileController — pushed in on every change.
        ChangeNotifierProxyProvider<ProfileController, HealthProvider>(
          create: (_) => HealthProvider(),
          update: (_, profile, health) =>
              (health ?? HealthProvider())..syncGoals(profile.goals),
        ),
      ],
      child: MaterialApp(
        title: 'Stock Plate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
