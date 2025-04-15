import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  static Future<void> initialize(BuildContext context) async {
    NotificationSettings settings = await _messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print("🔔 Notifikasi diizinkan");

      // ✅ Ambil token untuk backend (kalau perlu)
      final fcmToken = await _messaging.getToken();
      if (kDebugMode) print("📲 FCM Token: $fcmToken");

      // ✅ Setup untuk local notif
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@drawable/logo_barantin');
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
      await _localNotif.initialize(initSettings);

      // ✅ Saat notifikasi masuk (app aktif)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notif = message.notification;
        final title = notif?.title ?? message.data['title'] ?? 'Q-Officer';
        final body = notif?.body ?? message.data['body'] ?? '';

        const androidDetails = AndroidNotificationDetails(
          'karantina_channel',
          'Karantina Notifications',
          channelDescription: 'Notifikasi Pemeriksaan Lapangan',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/logo_barantin',
        );
        const details = NotificationDetails(android: androidDetails);

        _localNotif.show(
          notif.hashCode,
          title,
          body,
          details,
        );
      });

      // ✅ Saat notifikasi diklik (app background / terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) print("📬 Notif diklik: ${message.data}");

        // Navigasi ke halaman detail
        Navigator.of(context).pushNamed(
          '/notif-detail',
          arguments: message.data, // bisa kamu olah di NotifDetailScreen
        );
      });
    } else {
      if (kDebugMode) print("❌ Notifikasi tidak diizinkan");
    }
  }
}
