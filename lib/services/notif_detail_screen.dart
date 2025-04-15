import 'package:flutter/material.dart';

class NotifDetailScreen extends StatelessWidget {
  const NotifDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    String title = 'Detail Notifikasi';
    String body = '';
    if (arguments is Map<String, dynamic>) {
      title = arguments['title'] ?? title;
      body = arguments['body'] ?? arguments.toString();
    } else if (arguments is String) {
      body = arguments;
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          body,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
