import 'dart:async';
import 'dart:io';
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

  final List<XFile> _originalPickedXFiles = [];

  // Tetap digunakan untuk menampilkan foto di UI (hasil kompresi display)
  final List<Uint8List> _uploadedPhotos = [];

  // Diisi saat akan submit ke server (hasil kompresi server)
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
  static const int _maxTotalServerPayloadKb = 100;

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

  // Fungsi kompresi untuk tampilan UI
  Future<Uint8List?> _compressForDisplay(XFile imageFile) async {
    try {
      final filePath = imageFile.path;
      final targetPath = filePath.replaceAll(
          RegExp(r'\.\w+$'), '_display${DateTime.now().millisecondsSinceEpoch}.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        minWidth: 1024,
        minHeight: 768,
        quality: 75,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result == null) return null;
      final bytes = await result.readAsBytes();
      await File(result.path).delete(); // Hapus file sementara setelah dibaca
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error compressing for display for ${imageFile.name}: $e");
      }
      return await imageFile.readAsBytes(); // Fallback ke original jika gagal
    }
  }

  // Fungsi kompresi untuk server
  Future<Uint8List> _compressForServer(XFile imageFile, double targetKbPerPhoto) async {
    final targetBytes = targetKbPerPhoto * 1024;
    Uint8List originalBytes;
    try {
      originalBytes = await imageFile.readAsBytes(); // Baca sekali di awal
      if (kDebugMode) {
        print("🔧 SERVER COMPRESSION for ${imageFile.name} - Original: ${(originalBytes.length / 1024).toStringAsFixed(2)}KB, Target for this photo: ${targetKbPerPhoto.toStringAsFixed(2)}KB (${targetBytes.toStringAsFixed(0)} bytes)");
      }
    } catch (e) {
      if (kDebugMode) print("❌ Error reading original file for ${imageFile.name}: $e. Returning empty list.");
      return Uint8List(0);
    }

    try {
      int quality = 75; // Mulai dengan kualitas yang sedikit lebih tinggi
      int minWidth = 1000; // Mulai dengan dimensi yang lebih besar
      int minHeight = 750;
      Uint8List? compressedBytes;
      String? lastError;

      // Upaya pertama dengan parameter awal
      try {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.path,
          minWidth: minWidth,
          minHeight: minHeight,
          quality: quality,
          format: CompressFormat.jpeg,
          keepExif: false,
        );
      } catch (e) {
        lastError = e.toString();
        if (kDebugMode) print("  SERVER COMPRESSION - Initial attempt error: $e");
      }


      if (compressedBytes == null) { // Jika upaya awal gagal total
        if (kDebugMode) print("  SERVER COMPRESSION - Initial compression failed for ${imageFile.name}, trying safer params.");
        quality = 50; minWidth = 640; minHeight = 480; // Parameter lebih aman
        try {
          compressedBytes = await FlutterImageCompress.compressWithFile(
              imageFile.path, minWidth: minWidth, minHeight: minHeight, quality: quality, format: CompressFormat.jpeg, keepExif: false);
        } catch (e) {
          lastError = "Safer params also failed: $e";
          if (kDebugMode) print("  SERVER COMPRESSION - Safer params also failed for ${imageFile.name}: $e");
        }
      }

      if (compressedBytes == null) { // Jika masih gagal, kembalikan original
        if (kDebugMode) print("❌ SERVER COMPRESSION - All attempts failed for ${imageFile.name}. Error: $lastError. Returning original.");
        return originalBytes;
      }


      if (kDebugMode) print("  SERVER COMPRESSION - After Q$quality, Dim${minWidth}x$minHeight: ${(compressedBytes.length / 1024).toStringAsFixed(2)}KB");

      // Iterasi untuk menurunkan kualitas/dimensi jika ukuran masih terlalu besar
      int iteration = 0;
      while (compressedBytes!.length > targetBytes && quality > 5 && iteration < 5) { // Batasi iterasi dan kualitas minimum
        iteration++;
        if (quality > 10) {
          quality -= (quality > 30 ? 15 : 10); // Turunkan kualitas lebih agresif jika kualitas masih tinggi
        } else {
          quality -= 2; // Turunan kecil jika kualitas sudah rendah
        }
        if (quality < 5) quality = 5;

        // Jika ukuran masih jauh di atas target, coba perkecil dimensi juga
        if (compressedBytes.length > targetBytes * 1.8 && minWidth > 320) { // Jika > 180% target
          minWidth = (minWidth * 0.75).round().clamp(320, 2000); // Clamp agar tidak terlalu kecil/besar
          minHeight = (minHeight * 0.75).round().clamp(240, 1500);
        } else if (compressedBytes.length > targetBytes * 1.3 && minWidth > 500) { // Jika > 130% target
          minWidth = (minWidth * 0.85).round().clamp(320, 2000);
          minHeight = (minHeight * 0.85).round().clamp(240, 1500);
        }


        if (kDebugMode) print("  SERVER COMPRESSION - Iteration $iteration: Trying Q$quality, Dim${minWidth}x$minHeight");
        Uint8List? tempBytes;
        try {
          tempBytes = await FlutterImageCompress.compressWithList(
            compressedBytes, // Kompres dari hasil sebelumnya untuk efisiensi
            minWidth: minWidth,
            minHeight: minHeight,
            quality: quality,
            format: CompressFormat.jpeg,
          );
        } catch (e) {
          lastError = e.toString();
          if (kDebugMode) print("    Error in iteration $iteration: $e. Using previous best.");
          break; // Keluar loop jika ada error di iterasi, gunakan hasil kompresi terakhir yang berhasil
        }

        if (tempBytes.isEmpty) {
          if (kDebugMode) print("    Iteration $iteration resulted in null/empty bytes. Using previous best.");
          break;
        }
        compressedBytes = tempBytes;
        if (kDebugMode) print("    Result: ${(compressedBytes.length / 1024).toStringAsFixed(2)}KB");
      }

      if (compressedBytes.length > targetBytes * 1.15) { // Toleransi 15% di atas target
        if (kDebugMode) print("⚠️ SERVER COMPRESSION - Final size for ${imageFile.name} (${(compressedBytes.length / 1024).toStringAsFixed(2)}KB) is still above target ${targetKbPerPhoto.toStringAsFixed(2)}KB after $iteration iterations. Last error: $lastError");
      } else {
        if (kDebugMode) print("✅ SERVER COMPRESSION - Final size for ${imageFile.name}: ${(compressedBytes.length / 1024).toStringAsFixed(2)}KB after $iteration iterations.");
      }
      return compressedBytes;

    } catch (e) {
      if (kDebugMode) {
        print("❌ FATAL Error in _compressForServer for ${imageFile.name}: $e. Returning original bytes as fallback.");
      }
      return originalBytes;
    }
  }

  Future<void> pickImages(BuildContext context, ImageSource source, {bool isMulti = false}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_isPickingImage) {
      if (kDebugMode) {
        print("⚠️ Image picker sedang aktif, mengabaikan request baru");
      }
      return;
    }

    int remainingSlots = _maxPhotos - _originalPickedXFiles.length; // Cek berdasarkan original XFiles
    if (remainingSlots <= 0) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Batas maksimal $_maxPhotos foto sudah tercapai.')),
        );
      }
      return;
    }

    try {
      if (!mounted) return;
      setState(() { _isPickingImage = true; });

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Row(children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 16), Text('Mengambil foto...'),
            ],
            ),
            duration: Duration(seconds: 2), // Dibuat singkat karena ada proses lanjut
          ),
        );
      }

      List<XFile> tempXFiles = [];
      if (isMulti) {
        final List<XFile> selectedImages = await _picker.pickMultiImage(imageQuality: 80)
            .timeout(const Duration(seconds: 45), onTimeout: () => throw TimeoutException("Waktu memilih foto dari galeri habis."));
        if (selectedImages.length > remainingSlots) {
          tempXFiles = selectedImages.sublist(0, remainingSlots);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hanya ${tempXFiles.length} foto pertama yang diambil karena batas maksimal.')));
        } else {
          tempXFiles = selectedImages;
        }
      } else {
        final XFile? singleImage = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920, maxHeight: 1080)
            .timeout(const Duration(seconds: 45), onTimeout: () => throw TimeoutException("Waktu mengambil foto dengan kamera habis."));
        if (singleImage != null) tempXFiles = [singleImage];
      }

      if (tempXFiles.isEmpty) {
        if (mounted) {
          scaffoldMessenger.clearSnackBars();
          setState(() { _isPickingImage = false; });
        }
        return;
      }
      if (mounted) scaffoldMessenger.clearSnackBars();

      // Tampilkan snackbar proses
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Row(children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 16), Text('Memproses foto untuk tampilan...'),
            ],
            ),
            duration: Duration(days: 1), // Biarkan terbuka sampai selesai atau diganti
          ),
        );
      }

      List<Uint8List> newDisplayPhotos = [];
      List<XFile> successfullyProcessedOriginals = []; // Untuk melacak XFile yang berhasil diproses displaynya
      int successCount = 0;

      for (int i = 0; i < tempXFiles.length; i++) {
        if ((_originalPickedXFiles.length + successfullyProcessedOriginals.length) >= _maxPhotos) break;

        final imageXFile = tempXFiles[i];
        if (kDebugMode) print("⏳ Memproses foto untuk DISPLAY: ${imageXFile.name}");

        try {
          final displayBytes = await _compressForDisplay(imageXFile);
          if (displayBytes != null) {
            newDisplayPhotos.add(displayBytes);
            successfullyProcessedOriginals.add(imageXFile); // Tambahkan XFile asli jika display berhasil
            successCount++;
            if (kDebugMode) print("✅ Foto DISPLAY ${imageXFile.name} berhasil diproses: ${displayBytes.length} bytes");
          } else {
            if (kDebugMode) print("❌ Gagal memproses foto DISPLAY ${imageXFile.name}");
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memproses foto (display): ${imageXFile.name}'), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)));
          }
        } catch (e) {
          if (kDebugMode) print("❌ Error berat saat memproses foto DISPLAY ${imageXFile.name}: $e");
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saat memproses ${imageXFile.name} (display): Coba lagi.'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
        }
        await Future.delayed(const Duration(milliseconds: 50)); // Jeda kecil
      }

      if (mounted) {
        setState(() {
          _uploadedPhotos.addAll(newDisplayPhotos); // Ini untuk UI
          _originalPickedXFiles.addAll(successfullyProcessedOriginals); // Simpan XFile asli yang berhasil
          if (_formSubmitted) {
            _updateFieldError('foto', _originalPickedXFiles.isEmpty);
          }
        });
      }

      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        if (successCount > 0) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('✅ $successCount foto berhasil ditambahkan ke tampilan.'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
        } else if (tempXFiles.isNotEmpty) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('❌ Tidak ada foto yang berhasil diproses untuk tampilan. Coba lagi dengan foto lain.'), backgroundColor: Colors.red, duration: Duration(seconds: 3)));
        }
      }

    } catch (e) {
      final scaffoldMessengerOnCatch = ScaffoldMessenger.of(context);
      if (kDebugMode) print("❌ Error utama di pickImages: $e");
      if (mounted) {
        scaffoldMessengerOnCatch.clearSnackBars();
        String errorMessage = 'Terjadi kesalahan tidak diketahui.';
        if (e is TimeoutException) {
          errorMessage = e.message ?? 'Waktu habis saat memilih/mengambil foto.';
        } else if (e.toString().toLowerCase().contains("permission")) {
          errorMessage = 'Izin akses galeri/kamera ditolak.';
        } else {
          var parts = e.toString().split(':');
          errorMessage = parts.isNotEmpty ? parts.last.trim() : e.toString();
          if (errorMessage.length > 100) errorMessage = "${errorMessage.substring(0, 97)}...";
        }
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('❌ Error: $errorMessage'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
      }
    } finally {
      if (mounted) setState(() { _isPickingImage = false; });
    }
  }

  void deleteImage(int index) {
    if (index >= 0 && index < _uploadedPhotos.length && index < _originalPickedXFiles.length) {
      if (!mounted) return;
      setState(() {
        _uploadedPhotos.removeAt(index);
        _originalPickedXFiles.removeAt(index);
        if (_formSubmitted) {
          _updateFieldError('foto', _originalPickedXFiles.isEmpty);
        }
      });
    }
  }

  bool _validateServerPayloadSize(List<Uint8List> photosForServer) {
    if (photosForServer.isEmpty) {
      if (kDebugMode) print("⚠️ Tidak ada foto server untuk divalidasi");
      return true;
    }

    int totalCompressedServerSize = photosForServer.fold(0, (sum, photo) => sum + photo.length);

    int estimatedBase64Size = (totalCompressedServerSize * 1.333).ceil();
    int estimatedJsonOverhead = 2000 + (photosForServer.length * 150);
    int totalEstimatedPayload = estimatedBase64Size + estimatedJsonOverhead;

    if (kDebugMode) {
      print("🔍 Validasi ukuran payload SERVER:");
      print("   - Jumlah foto server: ${photosForServer.length}");
      print("   - Ukuran total compressed SERVER (binary): ${(totalCompressedServerSize / 1024).toStringAsFixed(2)} KB");
      print("   - Estimasi Base64 size SERVER: ${(estimatedBase64Size / 1024).toStringAsFixed(2)} KB");
      print("   - Estimasi payload total SERVER: ${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB");
    }

    if (totalEstimatedPayload > (_maxTotalServerPayloadKb * 1024)) {
      if (kDebugMode) print("🚫 Payload SERVER terlalu besar: ${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB > ${_maxTotalServerPayloadKb}KB");
      return false;
    }
    if (kDebugMode) print("✅ Ukuran payload SERVER (${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB) dalam batas.");
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
      _originalPickedXFiles.clear();
      _compressedPhotosForServer.clear();
      _formSubmitted = false;
      idPemeriksaan = uuid.v4();
    });
    ambilPosisiAwal();
  }

  Future<void> _showCustomDialog(BuildContext context, String title, String message, IconData icon, Color iconColor) async {
    Navigator.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (contextDialog, value, child) {
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
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Simpan
    Navigator.of(context);

    if (!mounted) return;
    setState(() {
      _formSubmitted = true;
      _updateFieldError('lokasi', selectedLokasiId == null);
      _updateFieldError('target', selectedTarget == null);
      _updateFieldError('metode', _metodeController.text.isEmpty);
      _updateFieldError('temuan', selectedTemuan == null);
      _updateFieldError('komoditas', selectedKomoditasId == null);
      _updateFieldError('foto', _originalPickedXFiles.isEmpty);
    });

    if (_formKey.currentState == null || !_formKey.currentState!.validate() ||
        selectedLokasiId == null ||
        selectedTarget == null ||
        selectedTemuan == null ||
        selectedKomoditasId == null ||
        _originalPickedXFiles.isEmpty) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text(
              "Harap lengkapi seluruh isian pada form pemeriksaan dan upload minimal 1 foto!")),
        );
      }
      return;
    }

    _compressedPhotosForServer.clear();
    double initialTargetKbPerPhoto = (_maxTotalServerPayloadKb - 8) / _originalPickedXFiles.length; // Misal, kurangi 8KB untuk JSON
    if (initialTargetKbPerPhoto < 5) initialTargetKbPerPhoto = 5;

    if (kDebugMode) {
      print("📸 Initial target per photo for server: ${initialTargetKbPerPhoto.toStringAsFixed(2)}KB");
    }

    for (int i = 0; i < _originalPickedXFiles.length; i++) {
      final xFile = _originalPickedXFiles[i];
      final serverBytes = await _compressForServer(xFile, initialTargetKbPerPhoto);
      _compressedPhotosForServer.add(serverBytes);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    int recompressAttempts = 0;
    final int maxRecompressAttempts = 2;

    while (!_validateServerPayloadSize(_compressedPhotosForServer) && recompressAttempts < maxRecompressAttempts) {
      recompressAttempts++;
      if (kDebugMode) {
        int currentTotalSize = _compressedPhotosForServer.fold(0, (sum, item) => sum + item.length);
        print("⚠️ Payload SERVER masih terlalu besar (${(currentTotalSize / 1024).toStringAsFixed(2)}KB). Percobaan re-kompresi ke-$recompressAttempts...");
      }

      int currentTotalBytes = _compressedPhotosForServer.fold(0, (sum, photo) => sum + photo.length);
      double overshootFactor = (_maxTotalServerPayloadKb * 1024 * 0.95) / currentTotalBytes; // Target 95% dari maks untuk aman

      // Target per foto baru, dikalikan dengan faktor overshoot (jika overshoot < 1, akan memperkecil)
      // dan pastikan tidak terlalu kecil.
      double newAggressiveTargetKb = initialTargetKbPerPhoto * (overshootFactor < 1.0 ? overshootFactor : 0.85);
      if (newAggressiveTargetKb < 3) newAggressiveTargetKb = 3; // Minimal absolut 3KB per foto

      if (kDebugMode) {
        print("   Re-kompresi dengan target baru per foto: ${newAggressiveTargetKb.toStringAsFixed(2)}KB");
      }

      List<Uint8List> tempCompressedForServer = [];
      for (final xFile in _originalPickedXFiles) {
        final serverBytes = await _compressForServer(xFile, newAggressiveTargetKb);
        tempCompressedForServer.add(serverBytes);
        await Future.delayed(const Duration(milliseconds: 30));
      }
      _compressedPhotosForServer.clear();
      _compressedPhotosForServer.addAll(tempCompressedForServer);
    }

    if (!_validateServerPayloadSize(_compressedPhotosForServer)) {
      if (mounted) {
        setState(() { _isSubmitting = false; });
        int totalSize = _compressedPhotosForServer.fold(0, (sum, item) => sum + item.length);
        String currentSizeKB = (totalSize / 1024).toStringAsFixed(0);

        // Jika setelah usaha maksimal masih terlalu besar, kita tetap kirim tapi beri log atau warning internal.
        // User meminta untuk tidak diblokir.
        if (kDebugMode) {
          print("🔥 PERINGATAN FINAL: Ukuran total foto (${currentSizeKB}KB) masih melebihi batas (${_maxTotalServerPayloadKb}KB) setelah $maxRecompressAttempts percobaan re-kompresi. Akan tetap mencoba mengirim.");
        }
        // Untuk production, mungkin kamu mau log ini ke server analytics-mu.
        // Untuk sekarang, kita akan lanjutkan pengiriman.
        // Jika kamu ingin tetap ada dialog error jika GAGAL TOTAL mencapai batas, uncomment bagian _showCustomDialog di bawah
        // dan mungkin tambahkan return;
        // await _showCustomDialog(
        //   context,
        //   "Foto Masih Terlalu Besar",
        //   "Ukuran total foto (${currentSizeKB}KB) masih melebihi batas maksimal (${_maxTotalServerPayloadKb}KB) meskipun sudah dicoba dikompres ulang. Pengiriman mungkin gagal atau data foto tidak lengkap.",
        //   Icons.warning_amber_rounded,
        //   Colors.red.shade700,
        // );
        // return; // Hapus ini jika ingin tetap mengirim
      }
      // return; // Hapus ini jika ingin tetap mengirim meskipun validasi akhir gagal
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
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        await _showCustomDialog(this.context, "Error Autentikasi", "NIP pengguna tidak ditemukan. Silakan login ulang.",
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

        if (_uploadedPhotos.length == _compressedPhotosForServer.length) {
          for (int i = 0; i < _uploadedPhotos.length; i++) {
            await _dbHelper.savePemeriksaanFoto(
                idPemeriksaan: idPemeriksaan,
                fotoDisplayBytes: _uploadedPhotos[i],
                fotoServerBytes: _compressedPhotosForServer[i]
            );
          }
        } else {
          if (kDebugMode) {
            print("❌ Error di FormPeriksa (if success): Jumlah foto display dan server tidak cocok.");
          }
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

        if (_uploadedPhotos.length == _compressedPhotosForServer.length) {
          for (int i = 0; i < _uploadedPhotos.length; i++) {
            await _dbHelper.savePemeriksaanFoto(
                idPemeriksaan: idPemeriksaan,
                fotoDisplayBytes: _uploadedPhotos[i],
                fotoServerBytes: _compressedPhotosForServer[i]
            );
          }
        } else {
          if (kDebugMode) {
            print("❌ Error di FormPeriksa (else gagal kirim online): Jumlah foto display dan server tidak cocok.");
          }
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

      if (_uploadedPhotos.length == _compressedPhotosForServer.length) {
        for (int i = 0; i < _uploadedPhotos.length; i++) {
          await _dbHelper.savePemeriksaanFoto(
              idPemeriksaan: idPemeriksaan,
              fotoDisplayBytes: _uploadedPhotos[i],
              fotoServerBytes: _compressedPhotosForServer[i]
          );
        }
      } else {
        if (kDebugMode) {
          print("❌ Error di FormPeriksa (offline): Jumlah foto display dan server tidak cocok.");
        }
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
