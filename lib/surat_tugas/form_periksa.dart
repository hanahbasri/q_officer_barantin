import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../databases/db_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:q_officer_barantin/models/hasil_pemeriksaan.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:q_officer_barantin/services/surat_tugas_service.dart';
import 'package:q_officer_barantin/models/lokasi.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

class FormPeriksa extends StatefulWidget {
  final StLengkap suratTugas;
  final String idSuratTugas;
  final VoidCallback onSelesaiTugas;
  final String userNip;

  const FormPeriksa({
    super.key,
    required this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
    required this.userNip,
  });

  @override
  FormPeriksaState createState() => FormPeriksaState();
}

class FormPeriksaState extends State<FormPeriksa> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final uuid = const Uuid();
  late String idPemeriksaan;
  List<Lokasi> lokasiList = [];
  List<Komoditas> komoditasList = [];
  final List<Uint8List> _compressedPhotosForServer = [];
  bool _formSubmitted = false;
  bool _isSubmitting = false;
  bool _isPickingImage = false;

  late AnimationController _searchController;

  String? selectedTarget;
  String? selectedTemuan;
  String? selectedLokasiId;
  String? selectedLokasiName;
  String? selectedKomoditasId;
  String? selectedKomoditasName;
  double? latitude;
  double? longitude;
  Position? devicePosition;
  String? waktuAmbilPosisi;

  static final ImagePicker _picker = ImagePicker();
  final TextEditingController _metodeController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  final List<Uint8List> _uploadedPhotos = [];
  final List<XFile> _pickedXFiles = [];

  final Map<String, bool> _fieldErrors = {
    'lokasi': false,
    'target': false,
    'metode': false,
    'temuan': false,
    'komoditas': false,
    'foto': false,
  };

  List<String> targetAndTemuanList = [];
  bool _isLoadingDropdownData = true;
  static const int _maxPhotos = 4;
  late DatabaseHelper _dbHelper;


  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    idPemeriksaan = uuid.v4();
    lokasiList = widget.suratTugas.lokasi;
    komoditasList = widget.suratTugas.komoditas;

    if (lokasiList.isNotEmpty && selectedLokasiName == null) {
      selectedLokasiName = lokasiList.first.namaLokasi;
      selectedLokasiId = lokasiList.first.idLokasi;
    }
    if (komoditasList.isNotEmpty && selectedKomoditasName == null) {
      selectedKomoditasName = komoditasList.first.namaKomoditas;
      selectedKomoditasId = komoditasList.first.idKomoditas;
    }

    if (kDebugMode) {
      print('DEBUG: jenisKarantina in FormPeriksa initState: ${widget.suratTugas.jenisKarantina}');
    }

    _loadTargetAndTemuanList();
    ambilPosisiAwal();

    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  Future<void> _loadTargetAndTemuanList() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDropdownData = true;
    });

    String jenisKarantina = widget.suratTugas.jenisKarantina ?? "";
    if (jenisKarantina.isEmpty) {
      if (kDebugMode) {
        print("⚠️ Jenis karantina kosong, tidak dapat memuat data target/temuan.");
      }
      if (mounted) {
        setState(() {
          targetAndTemuanList = [];
          _isLoadingDropdownData = false;
        });
      }
      return;
    }

    try {
      List<String> localData = await _dbHelper.getLocalMasterTargetTemuan(jenisKarantina);

      if (localData.isNotEmpty) {
        if (kDebugMode) {
          print("📦 Data target/temuan dimuat dari DB Lokal untuk jenis: $jenisKarantina");
        }
        if (mounted) {
          setState(() {
            targetAndTemuanList = localData;
            if (targetAndTemuanList.isNotEmpty) {
              selectedTarget ??= targetAndTemuanList.first;
              selectedTemuan ??= targetAndTemuanList.first;
            }
          });
        }
      } else {
        if (kDebugMode) {
          print("🌐 Data target/temuan tidak ditemukan lokal, mengambil dari API untuk jenis: $jenisKarantina");
        }
        final connectivityResult = await Connectivity().checkConnectivity();
        bool isOnline = connectivityResult == ConnectivityResult.mobile ||
            connectivityResult == ConnectivityResult.wifi ||
            connectivityResult == ConnectivityResult.ethernet;

        if (isOnline) {
          final apiData = await SuratTugasService.getTargetUjiData(jenisKarantina, 'uraian');
          if (mounted) {
            setState(() {
              targetAndTemuanList = apiData;
              if (targetAndTemuanList.isNotEmpty) {
                selectedTarget ??= targetAndTemuanList.first;
                selectedTemuan ??= targetAndTemuanList.first;
                _dbHelper.insertOrUpdateMasterTargetTemuan(jenisKarantina, apiData);
                if (kDebugMode) {
                  print("💾 Data target/temuan dari API disimpan ke DB Lokal untuk jenis: $jenisKarantina");
                }
              } else {
                if (kDebugMode) {
                  print("⚠️ Data target/temuan dari API kosong untuk jenis: $jenisKarantina");
                }
              }
            });
          }
        } else {
          if (kDebugMode) {
            print("📴 Tidak ada koneksi internet dan data lokal tidak tersedia untuk target/temuan jenis: $jenisKarantina.");
          }
          if (mounted) {
            setState(() {
              targetAndTemuanList = [];
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error loading target and temuan list: $e");
      }
      if (mounted) {
        setState(() {
          targetAndTemuanList = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDropdownData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _metodeController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<void> ambilPosisiAwal() async {
    final granted = await requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Izin lokasi diperlukan untuk mengambil posisi")),
      );
      return;
    }

    try {
      final posisi = await _dbHelper.getLocation();
      if (posisi != null) {
        if (!mounted) return;
        setState(() {
          devicePosition = posisi;
          latitude = posisi.latitude;
          longitude = posisi.longitude;
          waktuAmbilPosisi = DateTime.now().toIso8601String();
        });

        if (kDebugMode) {
          print("Lokasi berhasil: lat=$latitude, long=$longitude");
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❗ Gagal mengambil lokasi")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<Uint8List> _compressImageOptimized(XFile imageFile) async {
    try {
      if (kDebugMode) {
        final originalBytes = await imageFile.readAsBytes();
        print("🔧 Mulai kompresi gambar - Ukuran awal: ${originalBytes.length} bytes (${(originalBytes.length / 1024).toStringAsFixed(2)} KB)");
      }

      const int finalTargetSize = 28 * 1024;
      const int intermediateTargetSize = 50 * 1024;

      // Kompresi tahap 1
      Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 800,
        minHeight: 600,
        quality: 70,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (compressedBytes == null) {
        throw Exception("Kompresi tahap 1 gagal.");
      }

      // Kompresi tahap 2 jika masih terlalu besar
      if (compressedBytes.length > intermediateTargetSize) {
        if (kDebugMode) print("🔧 Ukuran > ${intermediateTargetSize / 1024}KB (${compressedBytes.length / 1024}KB), kompresi tahap 2...");
        Uint8List? tempBytes = await FlutterImageCompress.compressWithList(
          compressedBytes,
          minWidth: 640,
          minHeight: 480,
          quality: 55, // Turunkan kualitas secara bertahap
          format: CompressFormat.jpeg,
        );
        compressedBytes = tempBytes; // Gunakan hasil kompresi jika berhasil
      }

      // Kompresi tahap 3 jika masih terlalu besar
      if (compressedBytes.length > finalTargetSize) {
        if (kDebugMode) print("🔧 Ukuran > ${finalTargetSize / 1024}KB (${compressedBytes.length / 1024}KB), kompresi tahap 3...");
        Uint8List? tempBytes = await FlutterImageCompress.compressWithList(
          compressedBytes,
          minWidth: 500,
          minHeight: 375,
          quality: 40, // Kualitas lebih rendah untuk mencapai target
          format: CompressFormat.jpeg,
        );
        compressedBytes = tempBytes; // Gunakan hasil kompresi jika berhasil
      }

      if (compressedBytes.length > finalTargetSize + (5 * 1024)) {
        if (kDebugMode) {
          print("⚠️ PERINGATAN: Ukuran foto setelah kompresi (${(compressedBytes.length / 1024).toStringAsFixed(2)} KB) mungkin masih terlalu besar untuk target ${finalTargetSize/1024}KB.");
        }
      }

      final result = compressedBytes;

      if (kDebugMode) {
        print("✅ Kompresi selesai - Ukuran akhir: ${result.length} bytes (${(result.length / 1024).toStringAsFixed(2)} KB)");
      }
      return result;

    } catch (e) {
      if (kDebugMode) {
        print("❌ Error saat kompresi (_compressImageOptimized) untuk ${imageFile.name}: $e");
      }
      // Fallback: coba kompresi sederhana jika optimasi gagal
      try {
        Uint8List? fallbackBytes = await FlutterImageCompress.compressWithFile(
          imageFile.path,
          minWidth: 800,
          minHeight: 600,
          quality: 60,
          format: CompressFormat.jpeg,
          keepExif: false,
        );
        if (fallbackBytes != null) {
          if (kDebugMode) print("⚠️ Menggunakan kompresi fallback untuk ${imageFile.name} karena error. Ukuran: ${(fallbackBytes.length / 1024).toStringAsFixed(2)} KB");
          return fallbackBytes;
        }
      } catch (fe) {
        if (kDebugMode) print("❌ Error pada kompresi fallback untuk ${imageFile.name}: $fe");
      }
      // Jika semua gagal, kembalikan byte asli (berpotensi besar)
      if (kDebugMode) print("⚠️⚠️ Semua upaya kompresi gagal untuk ${imageFile.name}, mengembalikan byte asli. Ini bisa sangat besar!");
      return await imageFile.readAsBytes();
    }
  }


  Future<Map<String, dynamic>> _processImageAsync(XFile imageFile) async {
    try {
      final displayBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 800,
        minHeight: 600,
        quality: 75,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      // Kompresi untuk dikirim ke server (ukuran lebih kecil)
      final serverBytes = await _compressImageOptimized(imageFile);

      return {
        'display': displayBytes ?? await imageFile.readAsBytes(), // Fallback jika displayBytes null
        'compressed': serverBytes,
        'success': true,
      };
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error processing image ${imageFile.name}: $e");
      }
      // Fallback: gunakan gambar asli jika pemrosesan gagal total
      final bytes = await imageFile.readAsBytes();
      return {
        'display': bytes,
        'compressed': bytes,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<void> pickImages(BuildContext context, ImageSource source, {bool isMulti = false}) async {
    if (_isPickingImage) {
      if (kDebugMode) {
        print("⚠️ Image picker sedang aktif, mengabaikan request baru");
      }
      return;
    }

    int remainingSlots = _maxPhotos - _uploadedPhotos.length;
    if (remainingSlots <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batas maksimal $_maxPhotos foto sudah tercapai.')),
        );
      }
      return;
    }

    try {
      if (!mounted) return;
      setState(() {
        _isPickingImage = true;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 16),
                Text('Mengambil foto...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      List<XFile> tempXFiles = [];

      if (isMulti) {
        final List<XFile> selectedImages = await _picker.pickMultiImage(
          imageQuality: 80,
        ).timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            throw TimeoutException("Waktu memilih foto dari galeri habis.");
          },
        );

        if (selectedImages.isEmpty && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }

        if (selectedImages.length > remainingSlots) {
          tempXFiles = selectedImages.sublist(0, remainingSlots);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hanya ${tempXFiles.length} foto pertama yang diambil karena batas maksimal.')),
            );
          }
        } else {
          tempXFiles = selectedImages;
        }


      } else {
        final XFile? singleImage = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1920, // Dimensi maksimal dari kamera
          maxHeight: 1080,
        ).timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            throw TimeoutException("Waktu mengambil foto dengan kamera habis.");
          },
        );

        if (singleImage == null && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          if (!mounted) return;
          setState(() { _isPickingImage = false; });
          return;
        }
        if (singleImage != null) tempXFiles = [singleImage];
      }

      if (tempXFiles.isEmpty) {
        if (!mounted) return;
        setState(() { _isPickingImage = false; });
        return;
      }


      if (kDebugMode) {
        print("📷 Memproses ${tempXFiles.length} foto yang dipilih");
      }

      List<Uint8List> newDisplayPhotos = [];
      List<Uint8List> newServerPhotos = [];
      List<XFile> newXFiles = [];
      int successCount = 0;

      for (int i = 0; i < tempXFiles.length; i++) {
        if ((_uploadedPhotos.length + newDisplayPhotos.length) >= _maxPhotos) {
          if (kDebugMode) print("ℹ️ Batas maksimal foto tercapai saat iterasi, menghentikan penambahan.");
          break;
        }

        final image = tempXFiles[i];
        if (kDebugMode) print("⏳ Memproses foto: ${image.name}");


        try {
          final result = await _processImageAsync(image);

          if (result['success'] == true) {
            newDisplayPhotos.add(result['display']);
            newServerPhotos.add(result['compressed']);
            newXFiles.add(image);
            successCount++;

            if (kDebugMode) {
              print("✅ Foto ${image.name} berhasil diproses:");
              print("   - Ukuran display: ${result['display'].length} bytes");
              print("   - Ukuran server: ${result['compressed'].length} bytes");
            }
          } else {
            if (kDebugMode) {
              print("❌ Gagal memproses foto ${image.name}: ${result['error']}");
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal memproses foto: ${image.name}. Error: ${result['error'].toString().substring(0, (result['error'].toString().length > 50) ? 50 : result['error'].toString().length)}...'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print("❌ Error berat saat memproses foto ${image.name}: $e");
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saat memproses ${image.name}: Coba lagi.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        await Future.delayed(const Duration(milliseconds: 100)); // Jeda kecil
      }

      if (mounted) {
        setState(() {
          _uploadedPhotos.addAll(newDisplayPhotos);
          _compressedPhotosForServer.addAll(newServerPhotos);
          _pickedXFiles.addAll(newXFiles);

          if (_formSubmitted) {
            _updateFieldError('foto', _uploadedPhotos.isEmpty);
          }
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $successCount foto berhasil ditambahkan.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (tempXFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Tidak ada foto yang berhasil diproses. Coba lagi dengan foto lain.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

    } catch (e) { // Error utama di pickImages (misal, timeout picker, permission)
      if (kDebugMode) {
        print("❌ Error utama di pickImages: $e");
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        String errorMessage = 'Terjadi kesalahan tidak diketahui.';
        if (e is TimeoutException) {
          errorMessage = e.message ?? 'Waktu habis saat memilih/mengambil foto.';
        } else if (e.toString().toLowerCase().contains("permission")) {
          errorMessage = 'Izin akses galeri/kamera ditolak.';
        }
        else {
          var parts = e.toString().split(':');
          errorMessage = parts.isNotEmpty ? parts.last.trim() : e.toString();
          if (errorMessage.length > 100) errorMessage = "${errorMessage.substring(0,97)}...";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void deleteImage(int index) {
    if (index >= 0 && index < _uploadedPhotos.length) {
      if (!mounted) return;
      setState(() {
        _uploadedPhotos.removeAt(index);
        _pickedXFiles.removeAt(index);
        if (index < _compressedPhotosForServer.length) {
          _compressedPhotosForServer.removeAt(index);
        }
        if (_formSubmitted) {
          _updateFieldError('foto', _uploadedPhotos.isEmpty);
        }
      });
    }
  }

  bool _validatePayloadSize() {
    if (_compressedPhotosForServer.isEmpty) {
      if (kDebugMode) {
        print("⚠️ Tidak ada foto untuk divalidasi");
      }
      return true;
    }

    int totalCompressedSize = 0;
    for (var photo in _compressedPhotosForServer) {
      totalCompressedSize += photo.length;
    }

    int estimatedBase64Size = (totalCompressedSize * 4 / 3).ceil();
    int estimatedJsonOverhead = 2000 + (_compressedPhotosForServer.length * 100);
    int totalEstimatedPayload = estimatedBase64Size + estimatedJsonOverhead;

    if (kDebugMode) {
      print("🔍 Validasi ukuran payload:");
      print("   - Jumlah foto: ${_compressedPhotosForServer.length}");
      print("   - Ukuran total compressed (binary): ${(totalCompressedSize / 1024).toStringAsFixed(2)} KB");
      print("   - Estimasi Base64 size: ${(estimatedBase64Size / 1024).toStringAsFixed(2)} KB");
      print("   - Estimasi payload total: ${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB");
    }

    const maxPayloadSize = 100 * 1024;

    if (totalEstimatedPayload > maxPayloadSize) {
      if (kDebugMode) {
        print("🚫 Payload terlalu besar: ${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB > ${(maxPayloadSize / 1024).toStringAsFixed(2)} KB");
      }
      return false;
    }
    if (kDebugMode) print("✅ Ukuran payload (${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB) dalam batas.");
    return true;
  }

  void _updateFieldError(String field, bool hasError) {
    if (!mounted) return;
    setState(() {
      _fieldErrors[field] = hasError;
    });
  }

  void _resetForm() {
    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
    _metodeController.clear();
    _catatanController.clear();
    if (!mounted) return;
    setState(() {
      selectedTarget = targetAndTemuanList.isNotEmpty ? targetAndTemuanList.first : null;
      selectedTemuan = targetAndTemuanList.isNotEmpty ? targetAndTemuanList.first : null;
      selectedLokasiName = lokasiList.isNotEmpty ? lokasiList.first.namaLokasi : null;
      selectedLokasiId = lokasiList.isNotEmpty ? lokasiList.first.idLokasi : null;
      selectedKomoditasName = komoditasList.isNotEmpty ? komoditasList.first.namaKomoditas : null;
      selectedKomoditasId = komoditasList.isNotEmpty ? komoditasList.first.idKomoditas : null;

      _uploadedPhotos.clear();
      _pickedXFiles.clear();
      _compressedPhotosForServer.clear();
      _formSubmitted = false;
      idPemeriksaan = uuid.v4();
    });
    ambilPosisiAwal();
  }

  Future<void> _showCustomDialog(BuildContext context, String title, String message, IconData icon, Color iconColor) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    width: MediaQuery.of(ctx).size.width * 0.85,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder(
                            duration: const Duration(milliseconds: 1000),
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            curve: Curves.bounceOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Icon(icon, size: 70, color: iconColor),
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF522E2E),
                              decorationThickness: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF333333),
                              decorationThickness: 0,
                              decoration: TextDecoration.none,
                            ),
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF522E2E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text(
                                "OK",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }


  void _handleSubmit(BuildContext context) async {
    if (!mounted) return;
    setState(() {
      _formSubmitted = true;
      _updateFieldError('lokasi', selectedLokasiId == null);
      _updateFieldError('target', selectedTarget == null);
      _updateFieldError('metode', _metodeController.text.isEmpty);
      _updateFieldError('temuan', selectedTemuan == null);
      _updateFieldError('komoditas', selectedKomoditasId == null);
      _updateFieldError('foto', _compressedPhotosForServer.isEmpty);
    });

    if (_formKey.currentState == null || !_formKey.currentState!.validate() ||
        selectedLokasiId == null ||
        selectedTarget == null ||
        selectedTemuan == null ||
        selectedKomoditasId == null ||
        _compressedPhotosForServer.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              "Harap lengkapi seluruh isian pada form pemeriksaan dan upload minimal 1 foto!")),
        );
      }
      return;
    }

    if (!_validatePayloadSize()) {
      if (mounted) {
        // Calculate current estimated payload for the message
        int totalCompressedSize = _compressedPhotosForServer.map((e) => e.length).reduce((a, b) => a + b);
        int estimatedBase64Size = (totalCompressedSize * 4 / 3).ceil();
        int estimatedJsonOverhead = 2000 + (_compressedPhotosForServer.length * 100);
        int totalEstimatedPayload = estimatedBase64Size + estimatedJsonOverhead;
        String currentSizeKB = (totalEstimatedPayload / 1024).toStringAsFixed(0);
        String maxSizeKB = (100 * 1024 / 1024).toStringAsFixed(0);


        await _showCustomDialog(
          context,
          "Foto Terlalu Besar",
          "Total ukuran foto melebihi batas maksimal (${maxSizeKB}KB). Harap kurangi jumlah foto atau gunakan foto dengan resolusi/kualitas lebih rendah. Saat ini sekitar: ${currentSizeKB}KB.",
          Icons.photo_size_select_actual_outlined,
          Colors.orange.shade700,
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userNip = authProvider.userNip ?? widget.userNip;

    if (kDebugMode) {
      print('🔍 DEBUG - userNip yang akan digunakan untuk submit: "$userNip"');
    }

    if (userNip.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        await _showCustomDialog(
          context,
          "Error Autentikasi",
          "NIP pengguna tidak ditemukan. Silakan login ulang.",
          Icons.error_outline_rounded,
          Colors.red.shade700,
        );
      }
      return;
    }

    final hasil = HasilPemeriksaan(
      idPemeriksaan: idPemeriksaan,
      idSuratTugas: widget.idSuratTugas,
      idKomoditas: selectedKomoditasId!,
      namaKomoditas: selectedKomoditasName!,
      idLokasi: selectedLokasiId!,
      namaLokasi: selectedLokasiName!,
      lat: latitude?.toString() ?? '0.0',
      long: longitude?.toString() ?? '0.0',
      target: selectedTarget!,
      metode: _metodeController.text,
      temuan: selectedTemuan!,
      catatan: _catatanController.text,
      tanggal: waktuAmbilPosisi ?? DateTime.now().toIso8601String(),
      syncData: 0, // Default ke 0 (belum sinkron)
    );

    bool isOnline = false;

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      isOnline = connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi ||
          connectivityResult == ConnectivityResult.ethernet;
    } catch (e) {
      if (kDebugMode) print("Error checking connectivity: $e");
    }


    if (isOnline) {
      if (kDebugMode) {
        print("🚀 Mengirim dengan foto yang sudah dikompresi ke server (${_compressedPhotosForServer.length} foto)");
      }

      final bool success = await SuratTugasService.submitHasilPemeriksaan(
          hasil,
          _compressedPhotosForServer,
          userNip
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        final syncedHasil = hasil.toMap();
        syncedHasil['syncdata'] = 1; // Tandai sudah sinkron
        await _dbHelper.insert('Hasil_Pemeriksaan', syncedHasil);

        for (var photoBytes in _uploadedPhotos) { // Simpan foto display (UI version) ke DB
          await _dbHelper.getImagetoDatabase(photoBytes, idPemeriksaan);
        }
        await _dbHelper.updateStatusTugas(widget.idSuratTugas, 'dikirim');
        _resetForm();

        if (mounted) {
          await _showCustomDialog(
            context,
            "Berhasil Dikirim",
            "Hasil pemeriksaan telah berhasil dikirim! Anda dapat melanjutkan pemeriksaan kembali atau menyelesaikan tugas.",
            Icons.check_circle_outline_rounded,
            const Color(0xFF522E2E),
          );
          if (context.mounted) Navigator.of(context).pop(true); // Kembali dan tandai sukses
        }
      } else {
        // Jika gagal kirim ke server, simpan lokal sebagai unsynced
        final unsyncedHasil = hasil.toMap(); // syncData default 0
        await _dbHelper.insert('Hasil_Pemeriksaan', unsyncedHasil);

        for (var photoBytes in _uploadedPhotos) { // Simpan foto display
          await _dbHelper.getImagetoDatabase(photoBytes, idPemeriksaan);
        }

        _resetForm();

        if (mounted) {
          await _showCustomDialog(
            context,
            "Gagal Mengirim",
            "Gagal mengirim hasil pemeriksaan ke server. Data disimpan lokal dan akan disinkronkan nanti.",
            Icons.cloud_upload_outlined,
            Colors.blueGrey.shade600,
          );
          // Tidak pop, atau pop(false) agar user tahu gagal tapi data aman
        }
      }
    } else { // Offline
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      final unsyncedHasil = hasil.toMap(); // syncData default 0
      await _dbHelper.insert('Hasil_Pemeriksaan', unsyncedHasil);

      for (var photoBytes in _uploadedPhotos) {
        await _dbHelper.getImagetoDatabase(photoBytes, idPemeriksaan);
      }
      await _dbHelper.updateStatusTugas(widget.idSuratTugas, 'tersimpan_offline');
      _resetForm();

      if (mounted) {
        await _showCustomDialog(
          context,
          "Tersimpan Offline",
          "Hasil pemeriksaan telah disimpan dan akan dikirim saat online. Anda dapat melanjutkan pemeriksaan atau menyelesaikan tugas.",
          Icons.cloud_queue_outlined,
          Colors.blue.shade600,
        );
        if (context.mounted) Navigator.of(context).pop(true); // Kembali, tandai bahwa form selesai (meski offline)
      }
    }
  }


  void _showImagePicker(BuildContext context) {
    if (!mounted) return;
    // Cek batasan foto sebelum menampilkan pilihan
    if (_uploadedPhotos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anda sudah mengupload maksimal $_maxPhotos foto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) =>
          Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Pilih Sumber Foto',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildImageSourceOption(
                          icon: Icons.camera_alt,
                          label: "Kamera",
                          onTap: () {
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            if (_uploadedPhotos.length < _maxPhotos) {
                              pickImages(context, ImageSource.camera);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Batas maksimal foto tercapai.')),
                              );
                            }
                          },
                        ),
                        _buildImageSourceOption(
                          icon: Icons.photo_library,
                          label: "Galeri",
                          onTap: () {
                            Navigator.pop(ctx); // Tutup bottom sheet dulu
                            if (!mounted) return;
                            if (_uploadedPhotos.length < _maxPhotos) {
                              int currentRemainingSlots = _maxPhotos - _uploadedPhotos.length;
                              pickImages(context, ImageSource.gallery, isMulti: currentRemainingSlots > 1);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Batas maksimal foto tercapai.')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  InputDecoration _getInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      border: OutlineInputBorder( // Default border
        borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  String? _customValidator(String? value, String fieldName) {
    bool hasError = _formSubmitted && (value == null || value.isEmpty);
    if (!mounted) return null; // Check mounted before calling _updateFieldError
    _updateFieldError(fieldName, hasError);
    return hasError ? "Wajib diisi" : null;
  }

  Widget _buildSearchableDropdown<T>({
    required String title,
    required List<T> items,
    required String Function(T) itemAsString,
    required T? selectedItem,
    required String hint,
    required Function(T?) onChanged,
    required bool isRequired,
    required String fieldName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownSearch<T>(
          asyncItems: (filter) => Future.value(items),
          itemAsString: itemAsString,
          selectedItem: selectedItem,
          onChanged: (value) {
            onChanged(value);
            if (_formSubmitted) {
              if (!mounted) return;
              setState(() {
                _fieldErrors[fieldName] = value == null;
              });
            }
          },
          dropdownButtonProps: const DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down, color: Color(0xFF522E2E)),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            baseStyle: const TextStyle(fontSize: 14),
            dropdownSearchDecoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
                borderRadius: BorderRadius.circular(5),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _fieldErrors[fieldName] == true ? Colors.red : const Color(0xFF522E2E),
                    width: 1
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _fieldErrors[fieldName] == true ? Colors.red : const Color(0xFF522E2E), // Keep color consistent or highlight
                    width: 1
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 1),
                borderRadius: BorderRadius.circular(5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              errorText: _fieldErrors[fieldName] == true ? "Wajib diisi" : null,
            ),
          ),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Cari $title...',
                prefixIcon: AnimatedBuilder(
                  animation: _searchController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_searchController.value * 2, 0),
                      child: const Icon(Icons.search, color: Color(0xFF522E2E)),
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            menuProps: MenuProps(
                backgroundColor: Colors.white,
                elevation: 2, // Shadow for the popup menu
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[400]!, width: 1),
                  borderRadius: BorderRadius.circular(8),
                )
            ),
            // constraints: BoxConstraints(maxHeight: 300),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canUploadMore = _uploadedPhotos.length < _maxPhotos;
    return Scaffold(
      appBar: AppBar(title: const Text("Form Pemeriksaan")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildSearchableDropdown<Lokasi>(
                    title: "Lokasi",
                    items: lokasiList,
                    itemAsString: (lok) => lok.namaLokasi,
                    selectedItem: lokasiList.firstWhere(
                          (element) => element.idLokasi == selectedLokasiId,
                      orElse: () => lokasiList.isNotEmpty ? lokasiList.first : Lokasi( // Provide a default non-null Lokasi if list is empty or item not found
                        idLokasi: '', idSuratTugas: '', namaLokasi: 'Pilih Lokasi', latitude: 0, longitude: 0, detail: '', timestamp: '', // Placeholder name
                      ),
                    ),
                    hint: "Pilih Lokasi",
                    fieldName: 'lokasi',
                    onChanged: (value) {
                      if (value == null) return;
                      if (!mounted) return;
                      setState(() {
                        selectedLokasiName = value.namaLokasi;
                        selectedLokasiId = value.idLokasi;
                        if (_formSubmitted) {
                          _updateFieldError('lokasi', false);
                        }
                      });
                    },
                    isRequired: true,
                  ),

                  _isLoadingDropdownData
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Target / Sasaran", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Center(child: CircularProgressIndicator()),
                      SizedBox(height: 16),
                    ],
                  )
                      : (targetAndTemuanList.isEmpty && !_isLoadingDropdownData
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Target / Sasaran", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        "Tidak ada data target/sasaran yang tersedia untuk jenis karantina ini atau sedang offline.",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                      : _buildSearchableDropdown<String>(
                    title: "Target / Sasaran",
                    items: targetAndTemuanList,
                    itemAsString: (target) => target,
                    selectedItem: selectedTarget,
                    hint: "Pilih Target / Sasaran",
                    fieldName: 'target',
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() {
                        selectedTarget = value;
                        if (_formSubmitted) {
                          _updateFieldError('target', value == null);
                        }
                      });
                    },
                    isRequired: true,
                  )),

                  const Text("Metode", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _metodeController,
                    validator: (value) => _customValidator(value, 'metode'),
                    onChanged: (value) {
                      if (_formSubmitted) {
                        if (!mounted) return;
                        _updateFieldError('metode', value.isEmpty);
                        if (_formKey.currentState != null ) _formKey.currentState?.validate();
                      }
                    },
                    decoration: _getInputDecoration("Masukkan metode").copyWith(
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _isLoadingDropdownData
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Center(child: CircularProgressIndicator()),
                      SizedBox(height: 16),
                    ],
                  )
                      : (targetAndTemuanList.isEmpty && !_isLoadingDropdownData
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        "Tidak ada data temuan yang tersedia untuk jenis karantina ini atau sedang offline.",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                      : _buildSearchableDropdown<String>(
                    title: "Temuan",
                    items: targetAndTemuanList,
                    itemAsString: (temuan) => temuan,
                    selectedItem: selectedTemuan,
                    hint: "Pilih Temuan",
                    fieldName: 'temuan',
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() {
                        selectedTemuan = value;
                        if (_formSubmitted) {
                          _updateFieldError('temuan', value == null);
                        }
                      });
                    },
                    isRequired: true,
                  )),

                  _buildSearchableDropdown<Komoditas>(
                    title: "Komoditas",
                    items: komoditasList,
                    itemAsString: (kom) => kom.namaKomoditas,
                    selectedItem: komoditasList.firstWhere(
                          (element) => element.idKomoditas == selectedKomoditasId,
                      orElse: () => komoditasList.isNotEmpty ? komoditasList.first : Komoditas(
                        idKomoditas: '', idSuratTugas: '', namaKomoditas: 'Pilih Komoditas',
                      ),
                    ),
                    hint: "Pilih Komoditas",
                    fieldName: 'komoditas',
                    onChanged: (value) {
                      if (value == null) return;
                      if (!mounted) return;
                      setState(() {
                        selectedKomoditasName = value.namaKomoditas;
                        selectedKomoditasId = value.idKomoditas;
                        if (_formSubmitted) {
                          _updateFieldError('komoditas', false);
                        }
                      });
                    },
                    isRequired: true,
                  ),

                  const Text("Catatan", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _catatanController,
                    decoration: _getInputDecoration("Masukkan catatan (opsional)").copyWith(
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Dokumentasi", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("(${_uploadedPhotos.length}/$_maxPhotos foto)", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: (_isPickingImage || !canUploadMore)
                              ? null
                              : () => _showImagePicker(context),
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(
                              canUploadMore ? "Upload Foto" : "Maks. $_maxPhotos Foto",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canUploadMore ? const Color(0xFF522E2E) : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                            textStyle: const TextStyle(overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                      if (_formSubmitted && _fieldErrors['foto'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text(
                            "Wajib upload minimal 1 foto",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  if (_uploadedPhotos.isNotEmpty)
                    SizedBox(
                      height: 220,
                      child: PageView.builder(
                        itemCount: _uploadedPhotos.length,
                        controller: PageController(viewportFraction: 0.9),
                        itemBuilder: (context, index) {
                          final bytes = _uploadedPhotos[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (!mounted) return;
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.memory(bytes),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Tutup'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!, width: 1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        if (!mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Hapus Foto"),
                                            content: const Text("Apakah Anda yakin ingin menghapus foto ini?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(),
                                                child: const Text("Batal"),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(ctx).pop();
                                                  deleteImage(index);
                                                },
                                                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      "${index + 1}/${_uploadedPhotos.length}",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 5),
                  const Text("Format .JPG, .PNG, .JPEG. Maks. $_maxPhotos foto.",
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                  const SizedBox(height: 20),

                  Center(
                    child: SizedBox(
                      width: 250,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _handleSubmit(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF522E2E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                            side: const BorderSide(
                                color: Color(0xFF522E2E), width: 1),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                            : const Text(
                          "Kirim",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isSubmitting || _isPickingImage)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      _isSubmitting ? "Mengirim data..." : "Memproses foto...",
                      style: const TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.normal), // Ensure no underline
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _buildImageSourceOption({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.brown.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF522E2E), size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

void showImagePreview(BuildContext context, Uint8List imageBytes) {
  showDialog(
    context: context,
    builder: (_) =>
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(imageBytes),
            ),
          ),
        ),
  );
}
