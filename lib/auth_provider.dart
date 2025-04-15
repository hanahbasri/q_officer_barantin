import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:q_officer_barantin/role_detail.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoggedIn = false;
  String? userName;
  String? userId;
  String? userFullName;
  String? userEmail;
  String? accessToken;
  String? uid;
  List<RoleDetail> userRoles = [];

  String? _userPhotoPath;
  String? get userPhotoPath => _userPhotoPath;

  bool get isLoggedIn => _isLoggedIn;

  /// ✅ Load data login dari secure storage
  Future<void> checkLoginStatus() async {
    try {
      final token = await _secureStorage.read(key: "auth_token");
      _isLoggedIn = token != null;

      if (_isLoggedIn) {
        userName = await _secureStorage.read(key: "username") ?? "Guest";
        userId = await _secureStorage.read(key: "user_id") ?? "";
        userFullName = await _secureStorage.read(key: "full_name") ?? "";
        userEmail = await _secureStorage.read(key: "email") ?? "";
        accessToken = token;
        uid = await _secureStorage.read(key: "uid") ?? "";

        final detilJson = await _secureStorage.read(key: "user_roles");
        if (detilJson != null) {
          try {
            final decoded = jsonDecode(detilJson) as List;
            userRoles = decoded
                .map((e) => RoleDetail.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (e) {
            debugPrint("❌ Gagal decode role: $e");
            userRoles = [];
          }
        }

        _userPhotoPath = await _secureStorage.read(key: "user_photo_path");
      }

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error saat cek login: $e");
    }
  }

  /// ✅ Login user & simpan semua info termasuk foto lokal & FCM
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.karantinaindonesia.go.id/ums/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final userData = jsonData["data"];

        if (jsonData["status"] == "200" && userData != null) {
          accessToken = userData["accessToken"];
          uid = userData["uid"];
          userName = userData["uname"];
          userFullName = userData["nama"];
          userId = userData["nip"];
          userEmail = userData["email"];
          final detilList = userData["detil"] ?? [];

          userRoles = (detilList as List)
              .map((e) => RoleDetail.fromJson(e as Map<String, dynamic>))
              .toList();

          await _secureStorage.write(key: "auth_token", value: accessToken);
          await _secureStorage.write(key: "uid", value: uid);
          await _secureStorage.write(key: "username", value: userName);
          await _secureStorage.write(key: "user_id", value: userId);
          await _secureStorage.write(key: "full_name", value: userFullName);
          await _secureStorage.write(key: "email", value: userEmail);
          await _secureStorage.write(
              key: "user_roles", value: jsonEncode(detilList));

          _userPhotoPath = await _secureStorage.read(key: "user_photo_path");

          /// ✅ Tambahkan FCM Token
          await _sendFcmTokenToServer();

          _isLoggedIn = true;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ Login error: $e");
      return false;
    }
  }

  /// ✅ Kirim FCM token ke backend (jika dibutuhkan)
  Future<void> _sendFcmTokenToServer() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && accessToken != null) {
        debugPrint("📲 FCM Token: $fcmToken");

        // TODO: Ganti URL & format body sesuai backend kamu
        final response = await http.post(
          Uri.parse("https://api.karantinaindonesia.go.id/ums/save-fcm-token"),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "uid": uid,
            "fcm_token": fcmToken,
          }),
        );

        debugPrint("📬 Kirim FCM token status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Gagal kirim FCM token: $e");
    }
  }

  /// ✅ Logout tetap jaga foto user
  Future<void> logout() async {
    try {
      final lastPhoto = _userPhotoPath;
      await _secureStorage.deleteAll();

      _isLoggedIn = false;
      userName = null;
      userId = null;
      userFullName = null;
      userEmail = null;
      accessToken = null;
      uid = null;
      userRoles = [];

      if (lastPhoto != null) {
        await _secureStorage.write(key: "user_photo_path", value: lastPhoto);
        _userPhotoPath = lastPhoto;
      } else {
        _userPhotoPath = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Logout error: $e");
    }
  }

  Future<void> loadPhotoFromDB() async {
    try {
      _userPhotoPath = await _secureStorage.read(key: "user_photo_path");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Gagal load foto: $e");
    }
  }

  Future<void> savePhotoToDB(String path) async {
    if (path.isNotEmpty && File(path).existsSync()) {
      await _secureStorage.write(key: "user_photo_path", value: path);
      _userPhotoPath = path;
    } else {
      await _secureStorage.delete(key: "user_photo_path");
      _userPhotoPath = null;
    }
    notifyListeners();
  }

  List<String> getRoleNames() => userRoles.map((e) => e.roleName).toList();
}
