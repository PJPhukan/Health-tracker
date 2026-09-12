import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database/sync_service.dart';
import 'providers/auth_controller.dart';
import 'providers/health_provider.dart';
import 'providers/profile_controller.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // sqflite has no native web implementation — use the WASM/IndexedDB factory.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  // Never throws: without a Firebase config the app runs in local-only mode.
  await FirebaseBootstrap.init();
  // Resolves getNotificationAppLaunchDetails() for a cold-start deep link
  // before MainShell ever mounts. Never throws — reminders just won't fire.
  await NotificationService.instance.init();
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
        // Owns the SQLite <-> Firestore sync; bound to the signed-in uid below.
        Provider(create: (_) => SyncService()),
        // RevenueCat — identifies to the signed-in account so entitlements
        // follow the user. Placeholder keys => `available` stays false.
        ChangeNotifierProxyProvider<AuthController, SubscriptionService>(
          create: (_) => SubscriptionService()..init(),
          update: (_, auth, sub) => sub!..identify(auth.user?.uid),
        ),
        // AdMob state for the free tier. Premium flips it off with no restart.
        ChangeNotifierProxyProvider<SubscriptionService, AdService>(
          create: (_) => AdService()..init(),
          update: (_, sub, ad) => (ad ?? (AdService()..init()))
            ..setPremium(sub.isPremium),
        ),
        // HealthProvider owns the local logs; it also needs the current daily
        // targets (from ProfileController) and the active profile id (from
        // AuthController, to scope meal favorites) — pushed in on every change.
        ChangeNotifierProxyProvider3<AuthController, ProfileController,
            SyncService, HealthProvider>(
          create: (ctx) => HealthProvider(sync: ctx.read<SyncService>()),
          update: (_, auth, profile, sync, health) {
            sync.bind(auth.user?.uid);
            return (health ?? HealthProvider(sync: sync))
              ..syncGoals(profile.goals)
              ..syncProfileId(auth.profileId);
          },
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
