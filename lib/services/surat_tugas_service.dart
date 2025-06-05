import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'package:q_officer_barantin/models/lokasi.dart';
import 'package:q_officer_barantin/models/hasil_pemeriksaan.dart';
import 'package:q_officer_barantin/databases/db_helper.dart';

class SuratTugasService {
  static const String baseUrl = 'https://esps.karantinaindonesia.go.id/api-officer';
  static const String authHeader = 'Basic bXJpZHdhbjpaPnV5JCx+NjR7KF42WDQm';

  // FIXED: Sinkronisasi dengan batas ukuran di FormPeriksa (100KB)
  static const int MAX_PAYLOAD_SIZE_BYTES = 100 * 1024; // 100KB

  static Future<StLengkap?> getSuratTugasByNip(String nip) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/surtug?nip=$nip'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('🌐 API Response Status (getSuratTugasByNip): ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == true && jsonData['data'] != null) {
          final data = jsonData['data'];

          List<Komoditas> komoditasList = [];
          if (data['komoditas'] != null && data['komoditas'] is List) {
            try {
              komoditasList = (data['komoditas'] as List)
                  .map((k) => Komoditas.fromApiResponseMap(k as Map<String, dynamic>))
                  .toList();
            } catch (e) {
              if (kDebugMode) {
                print('❌ Error parsing komoditas from API: $e');
              }
            }
          }

          List<Petugas> petugasList = [];
          if (data['petugas'] != null && data['petugas'] is List) {
            try {
              petugasList = (data['petugas'] as List)
                  .map((p) => Petugas.fromApiResponseMap(p as Map<String, dynamic>))
                  .toList();
            } catch (e) {
              if (kDebugMode) {
                print('❌ Error parsing petugas from API: $e');
              }
            }
          }

          List<Lokasi> lokasiList = [];
          if (data['lokasi'] != null && data['lokasi'] is List) {
            try {
              lokasiList = (data['lokasi'] as List)
                  .map((l) => Lokasi.fromApiResponseMap(l as Map<String, dynamic>))
                  .toList();
            } catch (e) {
              if (kDebugMode) {
                print('❌ Error parsing lokasi from API: $e');
              }
            }
          }
          return StLengkap.fromApiResponseMap(
              data as Map<String, dynamic>, petugasList, lokasiList, komoditasList);
        } else {
          if (kDebugMode) {
            print('❌ API response status false or data null (getSuratTugasByNip)');
          }
        }
      } else {
        debugPrint('❌ Error API (getSuratTugasByNip): ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Exception saat fetch surat tugas: $e');
    }
    return null;
  }

  static Future<List<StLengkap>> getAllSuratTugasByNip(String nip) async {
    final suratTugas = await getSuratTugasByNip(nip);
    return suratTugas != null ? [suratTugas] : [];
  }

  static Future<List<String>> getTargetUjiData(String? jenisKarantina, String fieldToExtract) async {
    if (jenisKarantina == null || jenisKarantina.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Jenis karantina kosong, tidak dapat mengambil data target uji.');
      }
      return [];
    }
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/targetUji?kar=$jenisKarantina'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == true && jsonData['data'] != null && jsonData['data'] is List) {
          List<String> results = [];
          for (var item in (jsonData['data'] as List)) {
            if (item is Map && item.containsKey(fieldToExtract) && item[fieldToExtract] != null) {
              results.add(item[fieldToExtract].toString());
            }
          }
          return results;
        } else {
          if (kDebugMode) {
            print('❌ API Target Uji response status false or data null/invalid format');
          }
          return [];
        }
      } else {
        debugPrint('❌ Error API Target Uji: ${response.statusCode} - ${response.reasonPhrase}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Exception saat fetch data Target Uji: $e');
      return [];
    }
  }

  static Future<String?> getIdPetugasByNip(String userNip, String idSuratTugas) async {
    try {
      if (userNip.isEmpty) {
        if (kDebugMode) {
          print('❌ GAGAL (getIdPetugasByNip): userNip kosong.');
        }
        return null;
      }

      final dbHelper = DatabaseHelper();
      final petugasListMap = await dbHelper.getPetugasById(idSuratTugas);

      for (var petugasMap in petugasListMap) {
        final petugas = Petugas.fromDbMap(petugasMap);
        if (petugas.nipPetugas == userNip) {
          if (kDebugMode) {
            print('✅ Ditemukan petugas yang cocok (getIdPetugasByNip): ${petugas.idPetugas}');
          }
          return petugas.idPetugas;
        }
      }

      if (kDebugMode) {
        print('❌ Tidak ditemukan petugas dengan NIP: $userNip untuk ST ID: $idSuratTugas di DB lokal.');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saat getIdPetugasByNip dari DB: $e');
      }
      return null;
    }
  }

  static bool _validatePayloadSize(List<Uint8List> photos) {
    int totalCompressedSize = photos.fold(0, (sum, photo) => sum + photo.length);
    int estimatedBase64Size = (totalCompressedSize * 1.33).round();
    int estimatedJsonOverhead = 2000; // Overhead untuk JSON fields lainnya
    int totalEstimatedPayload = estimatedBase64Size + estimatedJsonOverhead;

    if (kDebugMode) {
      print("🔍 Validasi ukuran payload di Service:");
      print("   - Jumlah foto: ${photos.length}");
      print("   - Ukuran total foto compressed: $totalCompressedSize bytes (${(totalCompressedSize / 1024).toStringAsFixed(2)} KB)");
      print("   - Estimasi base64: $estimatedBase64Size bytes (${(estimatedBase64Size / 1024).toStringAsFixed(2)} KB)");
      print("   - Total estimasi payload: $totalEstimatedPayload bytes (${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB)");
      print("   - Batas maksimal: ${(MAX_PAYLOAD_SIZE_BYTES / 1024).toStringAsFixed(2)} KB");
    }

    return totalEstimatedPayload <= MAX_PAYLOAD_SIZE_BYTES;
  }

  static Future<bool> submitHasilPemeriksaan(
      HasilPemeriksaan hasil,
      List<Uint8List> compressedPhotos,
      String userNip
      ) async {
    const int maxRetries = 3;
    int currentAttempt = 0;

    while (currentAttempt < maxRetries) {
      currentAttempt++;

      try {
        if (kDebugMode) {
          print('🔄 Mencoba mengirim data (percobaan ke-$currentAttempt dari $maxRetries)...');
        }

        // Validasi awal
        if (userNip.isEmpty) {
          if (kDebugMode) {
            print('❌ GAGAL (submitHasilPemeriksaan): userNip kosong.');
          }
          return false;
        }

        if (compressedPhotos.isEmpty) {
          if (kDebugMode) {
            print('❌ GAGAL (submitHasilPemeriksaan): Tidak ada foto untuk dikirim.');
          }
          return false;
        }

        // Validasi ukuran payload
        if (!_validatePayloadSize(compressedPhotos)) {
          if (kDebugMode) {
            print('❌ GAGAL: Payload terlalu besar (>${(MAX_PAYLOAD_SIZE_BYTES / 1024).toStringAsFixed(0)}KB). Kurangi ukuran/jumlah foto.');
          }
          return false;
        }

        // Get ID Petugas
        String? idPetugas = await getIdPetugasByNip(userNip, hasil.idSuratTugas);

        if (idPetugas == null || idPetugas.isEmpty) {
          if (kDebugMode) {
            print('❌ GAGAL (submitHasilPemeriksaan): id_petugas tidak ditemukan untuk NIP: $userNip, ST ID: ${hasil.idSuratTugas}.');
          }
          return false;
        }

        // Encode photos to base64
        List<String> base64Photos = [];
        try {
          for (int i = 0; i < compressedPhotos.length; i++) {
            String base64Photo = base64Encode(compressedPhotos[i]);
            base64Photos.add(base64Photo);
            if (kDebugMode) {
              print('📷 Foto ${i + 1} berhasil di-encode: ${(base64Photo.length / 1024).toStringAsFixed(1)} KB');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error saat encode foto ke base64: $e');
          }
          return false;
        }

        // Format tanggal
        String formattedTglPeriksa = hasil.tanggal;
        try {
          DateTime parsedDate;
          if (hasil.tanggal.contains('T')) {
            parsedDate = DateTime.parse(hasil.tanggal);
          } else {
            parsedDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(hasil.tanggal);
          }
          formattedTglPeriksa = DateFormat("yyyy-MM-ddTHH:mm:ss").format(parsedDate);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Gagal memformat tgl_periksa: ${hasil.tanggal}, gunakan timestamp sekarang. Error: $e');
          }
          formattedTglPeriksa = DateFormat("yyyy-MM-ddTHH:mm:ss").format(DateTime.now());
        }

        // Siapkan data untuk server
        final Map<String, dynamic> payload = {
          'id': hasil.idPemeriksaan.trim(),
          'id_surat_tugas': hasil.idSuratTugas.trim(),
          'id_komoditas': hasil.idKomoditas.trim(),
          'id_lokasi': hasil.idLokasi.trim(),
          'lat': hasil.lat.trim(),
          'long': hasil.long.trim(),
          'target': hasil.target.trim(),
          'metode': hasil.metode.trim(),
          'temuan': hasil.temuan.trim(),
          'tgl_periksa': formattedTglPeriksa,
          'attachment': base64Photos,
          'id_petugas': idPetugas.trim(),
        };

        // Tambahkan catatan jika ada
        if (hasil.catatan != null && hasil.catatan!.trim().isNotEmpty) {
          payload['catatan'] = hasil.catatan!.trim();
        }

        if (kDebugMode) {
          compressedPhotos.fold(0, (sum, photo) => sum + photo.length);
          print('📤 PAYLOAD FINAL (submitHasilPemeriksaan):');
          payload.forEach((key, value) {
            if (key != 'attachment') {
              if (kDebugMode) {
                print('   - $key: "$value"');
              }
            } else {
              if (kDebugMode) {
                print('   - attachment: [${base64Photos.length} photos]');
              }
            }
          });
          String jsonPayload = jsonEncode(payload);
          double payloadSizeKB = jsonPayload.length / 1024;
          print('📊 Total ukuran payload aktual: ${payloadSizeKB.toStringAsFixed(2)} KB');
        }

        final response = await http.post(
          Uri.parse('$baseUrl/periksa'),
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
          body: json.encode(payload),
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw TimeoutException('Request timeout setelah 60 detik');
          },
        );

        if (kDebugMode) {
          print('🌐 API Submit Status: ${response.statusCode}');
          print('🌐 API Submit Response: ${response.body}');
        }

        // Handle status code yang benar
        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final responseData = json.decode(response.body);

            // Periksa status dalam response body
            if (responseData is Map<String, dynamic>) {
              if (responseData.containsKey('status')) {
                if (responseData['status'] == true ||
                    responseData['status'] == 'true' ||
                    responseData['status'] == 1) {
                  if (kDebugMode) {
                    print('✅ Berhasil mengirim hasil pemeriksaan ke server');
                    print('📝 Pesan server: ${responseData['message'] ?? 'Tidak ada pesan'}');
                    print('🔢 Status Code: ${response.statusCode}');
                  }
                  return true;
                } else {
                  String errorMessage = responseData['message']?.toString() ?? 'Status false dari server';
                  if (kDebugMode) {
                    print('❌ Server menolak data: $errorMessage');
                    print('🔢 Status Code: ${response.statusCode}');
                  }
                  return false;
                }
              } else {
                if (kDebugMode) {
                  print('❌ Response tidak memiliki field status yang valid');
                  print('🔢 Status Code: ${response.statusCode}');
                }
                return false;
              }
            }

            if (kDebugMode) {
              print('⚠️ Format response tidak dikenal, tapi status code sukses');
              print('🔢 Status Code: ${response.statusCode}');
            }
            return true;

          } catch (e) {
            if (kDebugMode) {
              print('❌ Error parsing response JSON: $e');
              print('📄 Raw response: ${response.body}');
              print('🔢 Status Code: ${response.statusCode}');
            }
            // Jika JSON parsing gagal tapi status code sukses, anggap berhasil
            return true;
          }
        }
        else if (response.statusCode == 413) {
          if (kDebugMode) {
            print('❌ Error 413: Payload terlalu besar (>${(MAX_PAYLOAD_SIZE_BYTES / 1024).toStringAsFixed(0)}KB). Kurangi ukuran/jumlah foto.');
          }
          return false;
        }
        else if (response.statusCode >= 400 && response.statusCode < 500) {
          if (kDebugMode) {
            print('❌ Client Error ${response.statusCode}: ${response.body}');
          }
          return false;
        }
        else if (response.statusCode >= 500) {
          if (kDebugMode) {
            print('⚠️ Server Error ${response.statusCode}: ${response.body}');
          }
          if (currentAttempt >= maxRetries) {
            if (kDebugMode) {
              print('❌ Gagal setelah $maxRetries percobaan - Server Error');
            }
            return false;
          }

          await Future.delayed(Duration(seconds: currentAttempt * 2));
          continue;
        }
        else {
          if (kDebugMode) {
            print('❌ Status code tidak dikenal: ${response.statusCode}');
            print('📄 Response: ${response.body}');
          }
          return false;
        }

      } on TimeoutException catch (e) {
        if (kDebugMode) {
          print('⏰ Timeout pada percobaan ke-$currentAttempt: $e');
        }
        if (currentAttempt >= maxRetries) {
          if (kDebugMode) {
            print('❌ Gagal setelah $maxRetries percobaan - Timeout');
          }
          return false;
        }
        await Future.delayed(Duration(seconds: currentAttempt * 2));
      } on SocketException catch (e) {
        if (kDebugMode) {
          print('🌐 Koneksi bermasalah pada percobaan ke-$currentAttempt: $e');
        }
        if (currentAttempt >= maxRetries) {
          if (kDebugMode) {
            print('❌ Gagal setelah $maxRetries percobaan - Koneksi bermasalah');
          }
          return false;
        }
        await Future.delayed(Duration(seconds: currentAttempt * 2));
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error tidak terduga pada percobaan ke-$currentAttempt: $e');
          print('🔍 Stack trace: ${StackTrace.current}');
        }
        if (currentAttempt >= maxRetries) {
          if (kDebugMode) {
            print('❌ Gagal setelah $maxRetries percobaan - Error tidak terduga');
          }
          return false;
        }
        await Future.delayed(Duration(seconds: currentAttempt * 2));
      }
    }
    return false;
  }
}