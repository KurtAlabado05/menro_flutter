import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/inspection_provider.dart';
import 'providers/report_provider.dart';
import 'providers/project_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/onboarding/app_entry_gate.dart';
import 'firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize(); // 🔥 THIS IS REQUIRED

  runApp(const CenroApp());
}

class CenroApp extends StatelessWidget {
  const CenroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        // Not auto-started: only the Inspection Officer shell calls start().
        ChangeNotifierProvider(create: (_) => InspectionProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..loadNotifications(),
        ),
      ],
      child: MaterialApp(
        title: 'EcoMap',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AppEntryGate(),
      ),
    );
  }
}
