import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Import untuk pakai initFirebaseOnce()

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize(BuildContext context) async {
    // ✅ Pastikan Firebase sudah siap
    await initFirebaseOnce();

    // ✅ Minta izin notifikasi
    NotificationSettings settings = await _messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print("🔔 Notifikasi diizinkan");

      // ✅ Ambil FCM token untuk backend (jika perlu dikirim)
      final fcmToken = await _messaging.getToken();
      if (kDebugMode) print("📲 FCM Token: $fcmToken");

      // ✅ Inisialisasi notifikasi lokal
      const androidInit = AndroidInitializationSettings('@drawable/logo_barantin');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotif.initialize(initSettings);

      // ✅ Saat app AKTIF: tampilkan notifikasi lokal
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notif = message.notification;
        final title = notif?.title ?? message.data['title'] ?? 'Q-Officer';
        final body = notif?.body ?? message.data['body'] ?? '';

        const androidDetails = AndroidNotificationDetails(
          'karantina_channel', // Channel ID
          'Karantina Notifications', // Channel name
          channelDescription: 'Notifikasi Pemeriksaan Lapangan',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/logo_barantin',
        );
        const notifDetails = NotificationDetails(android: androidDetails);

        _localNotif.show(
          notif.hashCode,
          title,
          body,
          notifDetails,
        );
      });

      // ✅ Saat notifikasi DIKLIK (app background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) print("📬 Notif diklik: ${message.data}");

        Navigator.of(context).pushNamed(
          '/notif-detail',
          arguments: message.data, // Bisa diakses di NotifDetailScreen
        );
      });
    } else {
      if (kDebugMode) print("❌ Notifikasi tidak diizinkan oleh pengguna");
    }
  }
}
