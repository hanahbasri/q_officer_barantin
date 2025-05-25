import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationApi {
  static const String baseUrl = 'https://esps.karantinaindonesia.go.id/api-officer';

  // Send notification to a specific user
  static Future<bool> sendNotification({
    required String userNip,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'nip': userNip,
          'title': title,
          'body': body,
          'data': additionalData ?? {},
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) print("✅ Notification sent successfully");
        return true;
      } else {
        if (kDebugMode) print("❌ Failed to send notification: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      if (kDebugMode) print("❌ Error sending notification: $e");
      return false;
    }
  }

  // Send surat tugas notification to a specific user
  static Future<bool> sendSuratTugasNotification({
    required String userNip,
    required String suratTugasId,
    required String authToken,
  }) async {
    return sendNotification(
      userNip: userNip,
      title: 'Surat Tugas 📢',
      body: 'Anda memiliki surat tugas baru yang perlu ditindaklanjuti',
      additionalData: {
        'type': 'surat_tugas',
        'surat_tugas_id': suratTugasId,
      },
      authToken: authToken,
    );
  }
}