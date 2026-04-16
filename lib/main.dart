import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pulsemarket/services/background_services.dart';
import 'package:pulsemarket/services/notification_services.dart' show NotificationService, navigatorKey;
import 'package:pulsemarket/theme.dart';
import 'package:pulsemarket/services/market_service.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // ── 1. Firebase ──────────────────────────────────────────────────────────
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   // ── 2. FCM + local notifications ─────────────────────────────────────────
//   await NotificationService.initialize();
//
//   // ── 3. Background service ─────────────────────────────────────────────────
//   await BackgroundPriceService.initialize();
//   await BackgroundPriceService.start();
//
//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//       systemNavigationBarColor: AppTheme.surface,
//       systemNavigationBarIconBrightness: Brightness.light,
//     ),
//   );
//   SystemChrome.setPreferredOrientations([
//     DeviceOrientation.portraitUp,
//     DeviceOrientation.portraitDown,
//   ]);
//
//   runApp(
//     ChangeNotifierProvider(
//       create: (_) => MarketService(),
//       child: const PulseMarketApp(),
//     ),
//   );
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => MarketService(),
      child: const PulseMarketApp(),
    ),
  );

  // Fire-and-forget after runApp so the native splash releases immediately
  NotificationService.initialize().ignore();
  BackgroundPriceService.initialize()
      .then((_) => BackgroundPriceService.start())
      .ignore();
}

class PulseMarketApp extends StatelessWidget {
  const PulseMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse Market',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // navigatorKey lets NotificationService push routes without a
      // BuildContext (needed for terminated-state deep-linking).
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}