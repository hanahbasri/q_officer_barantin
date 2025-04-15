import 'package:flutter/material.dart';

class NotificationProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _notifications = [];

  List<Map<String, dynamic>> get notifications => _notifications;

  void addNotification(Map<String, dynamic> data) {
    _notifications.insert(0, data); // Tambahkan notif ke paling atas
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    notifyListeners();
  }
}
