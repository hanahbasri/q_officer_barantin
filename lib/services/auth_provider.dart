import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:q_officer_barantin/models/role_detail.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:q_officer_barantin/databases/db_helper.dart';

/// 🔐 Konstanta key untuk secure storage
class AuthKeys {
  static const authToken = "auth_token";
  static const uid = "uid";
  static const username = "username";
  static const userId = "user_id";
  static const nip = "nip";
  static const fullName = "full_name";
  static const email = "email";
  static const userRoles = "user_roles";
  static const userPhotoPath = "user_photo_path";
  static const nik = "nik";
  static const idPegawai = "id_pegawai";
  static const upt = "upt";
}

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoggedIn = false;
  String? userName;
  String? userId;
  String? nip;
  String? userFullName;
  String? userEmail;
  String? accessToken;
  String? uid;
  List<RoleDetail> userRoles = [];
  String? nik;
  String? idPegawai;
  String? upt;

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
        nip = await _secureStorage.read(key: AuthKeys.nip) ?? ""; // Load NIP terpisah
        userFullName = await _secureStorage.read(key: AuthKeys.fullName) ?? "";
        userEmail = await _secureStorage.read(key: AuthKeys.email) ?? "";

        nik = await _secureStorage.read(key: AuthKeys.nik);
        idPegawai = await _secureStorage.read(key: AuthKeys.idPegawai);
        upt = await _secureStorage.read(key: AuthKeys.upt);

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

  /// ✅ Login user
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

          userId = userData["uid"];
          nip = userData["nip"];

          userEmail = userData["email"];

          nik = userData["nik"];
          idPegawai = userData["idpegawai"];
          upt = userData["upt"]?.toString();

          final detilList = userData["detil"];

          if (detilList is List) {
            userRoles = detilList
                .map((e) => RoleDetail.fromJson(e as Map<String, dynamic>))
                .toList();
          }

          // Debug: Print data yang diparsing
          debugPrint("🔍 FIXED Login parsing:");
          debugPrint("   - userId (uid): $userId");
          debugPrint("   - nip: $nip");
          debugPrint("   - userName: $userName");
          debugPrint("   - userFullName: $userFullName");

          // Simpan semua data dengan key yang benar
          await _secureStorage.write(key: AuthKeys.authToken, value: accessToken);
          await _secureStorage.write(key: AuthKeys.uid, value: uid);
          await _secureStorage.write(key: AuthKeys.username, value: userName);
          await _secureStorage.write(key: AuthKeys.userId, value: userId);
          await _secureStorage.write(key: AuthKeys.nip, value: nip);
          await _secureStorage.write(key: AuthKeys.fullName, value: userFullName);
          await _secureStorage.write(key: AuthKeys.email, value: userEmail);
          await _secureStorage.write(key: AuthKeys.nik, value: nik);
          await _secureStorage.write(key: AuthKeys.idPegawai, value: idPegawai);
          await _secureStorage.write(key: AuthKeys.upt, value: upt);
          await _secureStorage.write(
              key: AuthKeys.userRoles, value: jsonEncode(detilList));

          _userPhotoPath = await _secureStorage.read(key: AuthKeys.userPhotoPath);

          _isLoggedIn = true;

          if (nip != null && nip!.isNotEmpty) {
            try {
              final dbHelper = DatabaseHelper();
              await dbHelper.syncSuratTugasFromApi(nip!);
              debugPrint("✅ Surat tugas berhasil disync setelah login dengan NIP: $nip");
            } catch (e) {
              debugPrint("❌ Error sync surat tugas setelah login: $e");
            }
          }

          await sendFcmTokenToServer();

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

  /// ✅ Kirim token FCM ke server - FIXED dengan field yang diperlukan
  Future<void> sendFcmTokenToServer() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint("❌ FCM token tidak tersedia atau kosong");
        return;
      }

      debugPrint("📲 Mengirim FCM token ke server: $fcmToken");
      debugPrint("🔍 FCM Token length: ${fcmToken.length}");

      // Validasi data yang akan dikirim
      if (uid == null || uid!.isEmpty) {
        debugPrint("❌ UID tidak tersedia");
        return;
      }

      if (nip == null || nip!.isEmpty) {
        debugPrint("❌ NIP tidak tersedia");
        return;
      }

      // Format request body dengan field "Karantina" yang diperlukan server
      final requestBody = <String, dynamic>{
        "uid": uid!.trim(),
        "uname": (userName ?? "").trim(),
        "nama": (userFullName ?? "").trim(),
        "nip": nip!.trim(),
        "nik": (nik ?? "").trim(),
        "email": (userEmail ?? "").trim(),
        "idpegawai": int.tryParse(idPegawai?.toString() ?? "0") ?? 0,
        "upt": int.tryParse(upt?.toString() ?? "1000") ?? 1000,
        "token": fcmToken.trim(),
        "Karantina": upt ?? "1000", // Tambahan field yang diperlukan server
      };

      debugPrint("📤 FCM request body: ${json.encode(requestBody)}");
      debugPrint("🔍 Data validation:");
      debugPrint("   - uid: '${requestBody['uid']}'");
      debugPrint("   - nip: '${requestBody['nip']}'");
      debugPrint("   - token length: ${fcmToken.trim().length}");
      debugPrint("   - Karantina: ${requestBody['Karantina']}");

      final response = await http.post(
        Uri.parse('https://esps.karantinaindonesia.go.id/api-officer/tokenFCM'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic bXJpZHdhbjpaPnV5JCx+NjR7KF42WDQm',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      debugPrint("🌐 FCM Response Status: ${response.statusCode}");
      debugPrint("🌐 FCM Response Body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body) as Map<String, dynamic>;
          if (responseData['status'] == true) {
            debugPrint("✅ FCM token berhasil dikirim ke server");
          } else {
            debugPrint("❌ FCM token gagal: ${responseData['message']}");
            // Coba format alternatif jika masih gagal
            await _sendFcmTokenAlternative(fcmToken);
          }
        } catch (e) {
          debugPrint("❌ Error parsing response: $e");
          debugPrint("🔍 Raw response: ${response.body}");
        }
      } else if (response.statusCode == 400) {
        debugPrint("❌ Bad Request (400) - Mencoba format alternatif");
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          debugPrint("🔍 Error details: $errorData");
          await _sendFcmTokenAlternative(fcmToken);
        } catch (e) {
          debugPrint("❌ Could not parse error response: $e");
        }
      } else {
        debugPrint("❌ FCM request failed with status: ${response.statusCode}");
        debugPrint("🔍 Response: ${response.body}");
      }
    } on SocketException {
      debugPrint("❌ Tidak ada koneksi internet saat mengirim FCM token");
    } catch (e) {
      debugPrint("❌ Error saat mengirim FCM token ke server: $e");
      debugPrint("🔍 Error type: ${e.runtimeType}");
    }
  }

  /// ✅ Method alternatif dengan berbagai format yang mungkin diterima server
  Future<void> _sendFcmTokenAlternative(String fcmToken) async {
    try {
      debugPrint("🔄 Mencoba format alternatif untuk FCM token...");

      // Format 1: Dengan field Karantina sebagai string
      final alternativeBody1 = <String, dynamic>{
        "uid": uid!,
        "uname": userName ?? "",
        "nama": userFullName ?? "",
        "nip": nip!,
        "nik": nik ?? "",
        "email": userEmail ?? "",
        "idpegawai": idPegawai ?? "0",
        "upt": upt ?? "1000",
        "token": fcmToken,
        "Karantina": upt ?? "1000",
      };

      debugPrint("📤 Alternative format 1: ${json.encode(alternativeBody1)}");

      var response = await http.post(
        Uri.parse('https://esps.karantinaindonesia.go.id/api-officer/tokenFCM'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic bXJpZHdhbjpaPnV5JCx~NjR7KF42WDQm',
        },
        body: json.encode(alternativeBody1),
      );

      debugPrint("🌐 Alt1 Response Status: ${response.statusCode}");
      debugPrint("🌐 Alt1 Response: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        if (responseData['status'] == true) {
          debugPrint("✅ FCM token berhasil dikirim dengan format alternatif 1");
          return;
        }
      }

      // Format 2: Hanya field essential dengan Karantina
      final alternativeBody2 = <String, dynamic>{
        "uid": uid!,
        "nip": nip!,
        "token": fcmToken,
        "Karantina": upt ?? "1000",
      };

      debugPrint("📤 Alternative format 2 (minimal): ${json.encode(alternativeBody2)}");

      response = await http.post(
        Uri.parse('https://esps.karantinaindonesia.go.id/api-officer/tokenFCM'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic bXJpZHdhbjpaPnV5JCx~NjR7KF42WDQm',
        },
        body: json.encode(alternativeBody2),
      );

      debugPrint("🌐 Alt2 Response Status: ${response.statusCode}");
      debugPrint("🌐 Alt2 Response: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        if (responseData['status'] == true) {
          debugPrint("✅ FCM token berhasil dikirim dengan format alternatif 2");
          return;
        }
      }

      // Format 3: Dengan fcm_token sebagai field name (case server expect different field name)
      final alternativeBody3 = <String, dynamic>{
        "uid": uid!,
        "uname": userName ?? "",
        "nama": userFullName ?? "",
        "nip": nip!,
        "nik": nik ?? "",
        "email": userEmail ?? "",
        "idpegawai": idPegawai ?? "0",
        "upt": upt ?? "1000",
        "fcm_token": fcmToken, // Different field name
        "Karantina": upt ?? "1000",
      };

      debugPrint("📤 Alternative format 3 (fcm_token): ${json.encode(alternativeBody3)}");

      response = await http.post(
        Uri.parse('https://esps.karantinaindonesia.go.id/api-officer/tokenFCM'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic bXJpZHdhbjpaPnV5JCx~NjR7KF42WDQm',
        },
        body: json.encode(alternativeBody3),
      );

      debugPrint("🌐 Alt3 Response Status: ${response.statusCode}");
      debugPrint("🌐 Alt3 Response: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        if (responseData['status'] == true) {
          debugPrint("✅ FCM token berhasil dikirim dengan format alternatif 3");
          return;
        }
      }

      debugPrint("❌ Semua format alternatif gagal");

    } catch (e) {
      debugPrint("❌ Error pada format alternatif: $e");
    }
  }

  /// ✅ Method dengan form-data format (jika server expect form data)
  Future<void> _sendFcmTokenWithFormData(String fcmToken) async {
    try {
      debugPrint("🔄 Mencoba dengan format form-data...");

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://esps.karantinaindonesia.go.id/api-officer/tokenFCM'),
      );

      request.headers.addAll({
        'Authorization': 'Basic bXJpZHdhbjpaPnV5JCx~NjR7KF42WDQm',
        'Accept': 'application/json',
      });

      request.fields.addAll({
        'uid': uid!,
        'uname': userName ?? "",
        'nama': userFullName ?? "",
        'nip': nip!,
        'nik': nik ?? "",
        'email': userEmail ?? "",
        'idpegawai': idPegawai ?? "0",
        'upt': upt ?? "1000",
        'token': fcmToken,
        'Karantina': upt ?? "1000",
      });

      debugPrint("📤 Form-data fields: ${request.fields}");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("🌐 Form-data Response Status: ${response.statusCode}");
      debugPrint("🌐 Form-data Response: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        if (responseData['status'] == true) {
          debugPrint("✅ FCM token berhasil dikirim dengan form-data");
        }
      }

    } catch (e) {
      debugPrint("❌ Error pada format form-data: $e");
    }
  }

  /// ✅ Logout
  Future<void> logout() async {
    try {
      final lastPhoto = _userPhotoPath;
      await _secureStorage.deleteAll();

      _isLoggedIn = false;
      userName = null;
      userId = null;
      nip = null;
      userFullName = null;
      userEmail = null;
      accessToken = null;
      uid = null;
      userRoles = [];
      nik = null;
      idPegawai = null;
      upt = null;

      if (lastPhoto != null) {
        await _secureStorage.write(key: AuthKeys.userPhotoPath, value: lastPhoto);
        _userPhotoPath = lastPhoto;
      } else {
        _userPhotoPath = null;
      }

      debugPrint("✅ Logout berhasil untuk user yang keluar");
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

  /// ✅ Getter untuk NIP (untuk submit hasil pemeriksaan)
  String? get userNip => nip;
}