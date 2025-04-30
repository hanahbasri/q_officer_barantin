import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:q_officer_barantin/models/role_detail.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// 🔐 Konstanta key untuk secure storage
class AuthKeys {
  static const authToken = "auth_token";
  static const uid = "uid";
  static const username = "username";
  static const userId = "user_id";
  static const fullName = "full_name";
  static const email = "email";
  static const userRoles = "user_roles";
  static const userPhotoPath = "user_photo_path";
}

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

  /// ✅ Cek status login dari local storage
  Future<void> checkLoginStatus() async {
    try {
      final token = await _secureStorage.read(key: AuthKeys.authToken);
      _isLoggedIn = token != null;

      if (_isLoggedIn) {
        accessToken = token;
        uid = await _secureStorage.read(key: AuthKeys.uid);
        userName = await _secureStorage.read(key: AuthKeys.username) ?? "Guest";
        userId = await _secureStorage.read(key: AuthKeys.userId) ?? "";
        userFullName = await _secureStorage.read(key: AuthKeys.fullName) ?? "";
        userEmail = await _secureStorage.read(key: AuthKeys.email) ?? "";

        final detilJson = await _secureStorage.read(key: AuthKeys.userRoles);
        if (detilJson != null) {
          try {
            final decoded = jsonDecode(detilJson);
            if (decoded is List) {
              userRoles = decoded
                  .map((e) => RoleDetail.fromJson(e as Map<String, dynamic>))
                  .toList();
            }
          } catch (e) {
            debugPrint("❌ Gagal decode role: $e");
            userRoles = [];
          }
        }

        _userPhotoPath = await _secureStorage.read(key: AuthKeys.userPhotoPath);
      }

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error saat cek login: $e");
    }
  }

  /// ✅ Login user & simpan data ke local
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
          final detilList = userData["detil"];

          if (detilList is List) {
            userRoles = detilList
                .map((e) => RoleDetail.fromJson(e as Map<String, dynamic>))
                .toList();
          }

          // Simpan semua data
          await _secureStorage.write(key: AuthKeys.authToken, value: accessToken);
          await _secureStorage.write(key: AuthKeys.uid, value: uid);
          await _secureStorage.write(key: AuthKeys.username, value: userName);
          await _secureStorage.write(key: AuthKeys.userId, value: userId);
          await _secureStorage.write(key: AuthKeys.fullName, value: userFullName);
          await _secureStorage.write(key: AuthKeys.email, value: userEmail);
          await _secureStorage.write(
              key: AuthKeys.userRoles, value: jsonEncode(detilList));

          _userPhotoPath = await _secureStorage.read(key: AuthKeys.userPhotoPath);

          await _sendFcmTokenToServer();

          _isLoggedIn = true;
          notifyListeners();
          return true;
        }
      }

      return false;
    } on SocketException {
      debugPrint("⚠️ Tidak ada koneksi internet saat login.");
      return false;
    } catch (e) {
      debugPrint("❌ Login error: $e");
      return false;
    }
  }

  /// ✅ Kirim token FCM ke server
  Future<void> _sendFcmTokenToServer() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && accessToken != null) {
        debugPrint("📲 FCM Token: $fcmToken");

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

  /// ✅ Logout dan tetap simpan foto user
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
        await _secureStorage.write(key: AuthKeys.userPhotoPath, value: lastPhoto);
        _userPhotoPath = lastPhoto;
      } else {
        _userPhotoPath = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Logout error: $e");
    }
  }

  /// ✅ Load path foto user
  Future<void> loadPhotoFromDB() async {
    try {
      _userPhotoPath = await _secureStorage.read(key: AuthKeys.userPhotoPath);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Gagal load foto: $e");
    }
  }

  /// ✅ Simpan path foto user
  Future<void> savePhotoToDB(String path) async {
    if (path.isNotEmpty && File(path).existsSync()) {
      await _secureStorage.write(key: AuthKeys.userPhotoPath, value: path);
      _userPhotoPath = path;
    } else {
      await _secureStorage.delete(key: AuthKeys.userPhotoPath);
      _userPhotoPath = null;
    }
    notifyListeners();
  }

  /// ✅ Ambil list nama role
  List<String> getRoleNames() => userRoles.map((e) => e.roleName).toList();
}
