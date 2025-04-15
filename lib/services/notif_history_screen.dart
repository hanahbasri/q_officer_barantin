import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_provider.dart';

class NotifHistoryScreen extends StatelessWidget {
  const NotifHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifs = context.watch<NotificationProvider>().notifications;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Notifikasi')),
      body: notifs.isEmpty
          ? const Center(child: Text('Belum ada notifikasi.'))
          : ListView.builder(
        itemCount: notifs.length,
        itemBuilder: (context, index) {
          final notif = notifs[index];
          return ListTile(
            title: Text(notif['title'] ?? 'Tanpa Judul'),
            subtitle: Text(notif['body'] ?? 'Tanpa Isi'),
            onTap: () {
              Navigator.pushNamed(context, '/notif-detail', arguments: notif);
            },
          );
        },
      ),
    );
  }
}
