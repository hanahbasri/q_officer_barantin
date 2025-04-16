import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:q_officer_barantin/surat_tugas/surat_tugas.dart';
import 'package:q_officer_barantin/surat_tugas/firebase_options.dart';

import 'services/notification_service.dart';
import 'services/notif_history_screen.dart';
import 'services/notification_provider.dart';
import 'services/notif_detail_screen.dart';

import 'auth_provider.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'beranda/home_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📨 [Background] ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLoginStatus()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static const Color karantinaBrown = Color(0xFF522E2E);
  static const Color softBackground = Color(0xFFF9F6F1);
  static const Color accentGold = Color(0xFFD2B48C);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    NotificationService.initialize(context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Q-Officer App',
      theme: ThemeData(
        primaryColor: MyApp.karantinaBrown,
        scaffoldBackgroundColor: MyApp.softBackground,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: MyApp.karantinaBrown,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: MyApp.karantinaBrown,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.brown,
        ).copyWith(
          primary: MyApp.karantinaBrown,
          secondary: MyApp.accentGold,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(), // mulai dari splash
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/notif-detail': (context) => const NotifDetailScreen(),
        '/notif-history': (context) => const NotifHistoryScreen(),
        '/surat-tugas': (context) => SuratTugasPage(), // ← Tambahkan ini!
      },
    );
  }
}