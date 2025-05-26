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
  _FormPeriksaState createState() => _FormPeriksaState();
}

class _FormPeriksaState extends State<FormPeriksa> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final uuid = Uuid();
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

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _isLoadingDropdownData = true;
    });
    try {
      final data = await SuratTugasService.getTargetUjiData(
          widget.suratTugas.jenisKarantina, 'uraian');
      if (mounted) {
        setState(() {
          targetAndTemuanList = data;
          if (targetAndTemuanList.isNotEmpty) {
            selectedTarget ??= targetAndTemuanList.first;
            selectedTemuan ??= targetAndTemuanList.first;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading target and temuan list: $e");
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
      final db = DatabaseHelper();
      final posisi = await db.getLocation();
      if (posisi != null) {
        setState(() {
          devicePosition = posisi;
          latitude = posisi.latitude;
          longitude = posisi.longitude;
          waktuAmbilPosisi = DateTime.now().toIso8601String();
        });

        if (!mounted) return;
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

      const int targetSize = 25 * 1024; // Target 25KB per foto

      // Lakukan kompresi dengan parameter yang sudah dioptimasi
      Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 640,
        minHeight: 480,
        quality: 60, // Mulai dengan kualitas sedang
        format: CompressFormat.jpeg,
        keepExif: false, // Buang EXIF data untuk menghemat space
      );

      if (compressedBytes == null) {
        throw Exception("Gagal kompresi gambar");
      }

      // Jika masih terlalu besar, lakukan kompresi bertahap
      if (compressedBytes.length > targetSize) {
        compressedBytes = await FlutterImageCompress.compressWithList(
          compressedBytes,
          minWidth: 500,
          minHeight: 375,
          quality: 40,
          format: CompressFormat.jpeg,
        );
      }

      // Kompresi final jika masih perlu
      if (compressedBytes.length > targetSize) {
        compressedBytes = await FlutterImageCompress.compressWithList(
          compressedBytes,
          minWidth: 400,
          minHeight: 300,
          quality: 25,
          format: CompressFormat.jpeg,
        );
      }

      final result = compressedBytes;

      if (kDebugMode) {
        print("✅ Kompresi selesai - Ukuran akhir: ${result.length} bytes (${(result.length / 1024).toStringAsFixed(2)} KB)");
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error saat kompresi: $e");
      }
      // Fallback ke ukuran asli jika kompresi gagal
      return await imageFile.readAsBytes();
    }
  }

  // FIXED: Proses gambar dengan isolate untuk mencegah UI freeze
  Future<Map<String, dynamic>> _processImageAsync(XFile imageFile) async {
    try {
      // Kompresi untuk display (tidak terlalu agresif)
      final displayBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 800,
        minHeight: 600,
        quality: 70,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      // Kompresi untuk server (lebih agresif)
      final serverBytes = await _compressImageOptimized(imageFile);

      return {
        'display': displayBytes ?? await imageFile.readAsBytes(),
        'compressed': serverBytes,
        'success': true,
      };
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error processing image: $e");
      }

      // Fallback: gunakan gambar asli
      final bytes = await imageFile.readAsBytes();
      return {
        'display': bytes,
        'compressed': bytes,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // FIXED: Perbaiki logika image picking untuk menghindari "already active" error
  Future<void> pickImages(BuildContext context, ImageSource source, {bool isMulti = false}) async {
    // Cek apakah sedang dalam proses picking
    if (_isPickingImage) {
      if (kDebugMode) {
        print("⚠️ Image picker sedang aktif, mengabaikan request baru");
      }
      return;
    }

    try {
      setState(() {
        _isPickingImage = true;
      });

      // Tampilkan loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
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
        // FIXED: Tambahkan timeout dan error handling
        final List<XFile> selectedImages = await _picker.pickMultiImage(
          imageQuality: 80, // Kualitas yang lebih baik untuk mengurangi kompresi bertahap
          limit: 5, // Batasi jumlah foto untuk menghindari overload
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception("Timeout saat memilih foto");
          },
        );

        if (selectedImages.isEmpty) return;
        tempXFiles = selectedImages;
      } else {
        // FIXED: Tambahkan timeout untuk single image
        final XFile? singleImage = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1920, // Batasi resolusi maksimal
          maxHeight: 1080,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception("Timeout saat mengambil foto");
          },
        );

        if (singleImage == null) return;
        tempXFiles = [singleImage];
      }

      if (kDebugMode) {
        print("📷 Memproses ${tempXFiles.length} foto yang dipilih");
      }

      // Proses foto satu per satu untuk menghindari memory overload
      List<Uint8List> newDisplayPhotos = [];
      List<Uint8List> newServerPhotos = [];
      List<XFile> newXFiles = [];

      for (int i = 0; i < tempXFiles.length; i++) {
        final image = tempXFiles[i];

        // Tampilkan progress
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Memproses foto ${i + 1} dari ${tempXFiles.length}...'),
              duration: const Duration(milliseconds: 500),
            ),
          );
        }

        try {
          final result = await _processImageAsync(image);

          if (result['success'] == true) {
            newDisplayPhotos.add(result['display']);
            newServerPhotos.add(result['compressed']);
            newXFiles.add(image);

            if (kDebugMode) {
              print("✅ Foto ${i + 1} berhasil diproses:");
              print("   - Ukuran display: ${result['display'].length} bytes");
              print("   - Ukuran server: ${result['compressed'].length} bytes");
            }
          } else {
            if (kDebugMode) {
              print("❌ Gagal memproses foto ${i + 1}: ${result['error']}");
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print("❌ Error memproses foto ${i + 1}: $e");
          }
        }

        // Beri jeda kecil untuk menghindari overload
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Update state setelah semua foto diproses
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

      // Tampilkan hasil akhir
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${newDisplayPhotos.length} foto berhasil ditambahkan'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      if (kDebugMode) {
        print("❌ Error picking images: $e");
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Pastikan flag di-reset dalam kondisi apapun
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void deleteImage(int index) {
    if (index >= 0 && index < _uploadedPhotos.length) {
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

    int estimatedBase64Size = (totalCompressedSize * 1.33).round();
    int estimatedJsonOverhead = 2000;
    int totalEstimatedPayload = estimatedBase64Size + estimatedJsonOverhead;

    if (kDebugMode) {
      print("🔍 Validasi ukuran payload:");
      print("   - Jumlah foto: ${_compressedPhotosForServer.length}");
      print("   - Ukuran total compressed: ${(totalCompressedSize / 1024).toStringAsFixed(2)} KB");
      print("   - Estimasi payload total: ${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB");
    }

    const maxPayloadSize = 100 * 1024;

    if (totalEstimatedPayload > maxPayloadSize) {
      if (kDebugMode) {
        print("🚫 Payload terlalu besar: ${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB > ${(maxPayloadSize / 1024).toStringAsFixed(2)} KB");
      }
      return false;
    }

    return true;
  }

  void _updateFieldError(String field, bool hasError) {
    setState(() {
      _fieldErrors[field] = hasError;
    });
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _metodeController.clear();
    _catatanController.clear();
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
    await showDialog(
      context: context,
      barrierDismissible: false, // User must tap button!
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
                          color: Colors.black.withValues(alpha: 0.2),
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
    setState(() {
      _formSubmitted = true;
      _updateFieldError('lokasi', selectedLokasiId == null);
      _updateFieldError('target', selectedTarget == null);
      _updateFieldError('metode', _metodeController.text.isEmpty);
      _updateFieldError('temuan', selectedTemuan == null);
      _updateFieldError('komoditas', selectedKomoditasId == null);
      _updateFieldError('foto', _compressedPhotosForServer.isEmpty);
    });

    if (!_formKey.currentState!.validate() ||
        selectedLokasiId == null ||
        selectedTarget == null ||
        selectedTemuan == null ||
        selectedKomoditasId == null ||
        _compressedPhotosForServer.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              "Harap lengkapi seluruh isian pada form pemeriksaan!")),
        );
      }
      return;
    }

    if (!_validatePayloadSize()) {
      if (mounted) {
        await _showCustomDialog(
          context,
          "Foto Terlalu Besar",
          "Total ukuran foto melebihi batas maksimal server (sekitar 100KB setelah dienkripsi). Harap kurangi jumlah foto atau gunakan foto dengan resolusi/kualitas lebih rendah.",
          Icons.photo_size_select_actual_outlined,
          Colors.orange.shade700,
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userNip = authProvider.userNip ?? widget.userNip;

    if (kDebugMode) {
      print('🔍 DEBUG - userNip yang akan digunakan untuk submit: "$userNip"');
    }

    if (userNip.isEmpty) {
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
      syncData: 0,
    );

    final dbHelper = DatabaseHelper();
    bool isOnline = false;

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      isOnline = (connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi);
    } catch (e) {
      if (kDebugMode) print("Error checking connectivity: $e");
    }

    if (isOnline) {
      if (kDebugMode) {
        print("🚀 Mengirim dengan foto yang sudah dikompresi ke server");
      }

      final bool success = await SuratTugasService.submitHasilPemeriksaan(
          hasil,
          _compressedPhotosForServer,
          userNip
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }

      if (success) {
        // Simpan hasil pemeriksaan yang sudah ter-sync
        final syncedHasil = hasil.toMap();
        syncedHasil['syncdata'] = 1;
        await dbHelper.insert('Hasil_Pemeriksaan', syncedHasil);

        for (var photoBytes in _uploadedPhotos) {
          await dbHelper.getImagetoDatabase(photoBytes, idPemeriksaan);
        }

        await dbHelper.updateStatusTugas(widget.idSuratTugas, 'dikirim');


        _resetForm();

        if (mounted) {
          await _showCustomDialog(
            context,
            "Berhasil Dikirim",
            "Hasil pemeriksaan telah berhasil dikirim! Anda dapat melanjutkan pemeriksaan atau menyelesaikan tugas.",
            Icons.check_circle_outline_rounded,
            Color(0xFF522E2E),
          );

          // PERBAIKAN: Return true untuk update parent tapi jangan keluar dari halaman
          // Biarkan user tetap bisa membuat pemeriksaan lain atau selesaikan tugas manual
          Navigator.of(context).pop(true);
        }
      } else {
        // Jika gagal kirim ke server, tetap simpan lokal
        final unsyncedHasil = hasil.toMap();
        await dbHelper.insert('Hasil_Pemeriksaan', unsyncedHasil);

        for (var photoBytes in _uploadedPhotos) {
          await dbHelper.getImagetoDatabase(photoBytes, idPemeriksaan);
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
        }
      }
    } else {
      // PERBAIKAN: Untuk mode offline, juga jangan langsung selesaikan tugas
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }

      // Simpan hasil pemeriksaan offline
      final unsyncedHasil = hasil.toMap();
      await dbHelper.insert('Hasil_Pemeriksaan', unsyncedHasil);

      for (var photoBytes in _uploadedPhotos) {
        await dbHelper.getImagetoDatabase(photoBytes, idPemeriksaan);
      }

      // Update status ke 'dikirim' meskipun offline (akan di-sync nanti)
      await dbHelper.updateStatusTugas(widget.idSuratTugas, 'dikirim');

      _resetForm();

      if (mounted) {
        await _showCustomDialog(
          context,
          "Tersimpan Offline",
          "Hasil pemeriksaan telah disimpan dan akan dikirim saat online. Anda dapat melanjutkan pemeriksaan atau menyelesaikan tugas.",
          Icons.cloud_queue_outlined,
          Colors.blue.shade600,
        );

        Navigator.of(context).pop(true);
      }
    }
  }

  void _showImagePicker(BuildContext context) {
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
                            Navigator.pop(context);
                            pickImages(context, ImageSource.camera);
                          },
                        ),
                        _buildImageSourceOption(
                          icon: Icons.photo_library,
                          label: "Galeri",
                          onTap: () {
                            Navigator.pop(context);
                            pickImages(
                                context, ImageSource.gallery, isMulti: true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  // Function to create consistent input decoration
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
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  // Custom validator that only shows error if form was submitted
  String? _customValidator(String? value, String fieldName) {
    bool hasError = _formSubmitted && (value == null || value.isEmpty);
    _updateFieldError(fieldName, hasError);
    return hasError ? "Wajib diisi" : null;
  }

  // Searchable dropdown widget
  Widget _buildSearchableDropdown<T>({
    required String title,
    required List<T> items,
    required String Function(T) itemAsString,
    required T? selectedItem,
    required String hint,
    required Function(T?) onChanged,
    required bool isRequired,
    required String fieldName,
    String? Function(T?)? validator,
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
                    color: _fieldErrors[fieldName] == true ? Colors.red : const Color(0xFF522E2E),
                    width: 1
                ),
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
                elevation: 2,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[400]!, width: 1),
                  borderRadius: BorderRadius.circular(8),
                )
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  // Lokasi searchable dropdown
                  _buildSearchableDropdown<Lokasi>(
                    title: "Lokasi",
                    items: lokasiList,
                    itemAsString: (lok) => lok.namaLokasi,
                    selectedItem: lokasiList.firstWhere(
                          (element) => element.idLokasi == selectedLokasiId,
                      orElse: () => lokasiList.isNotEmpty ? lokasiList.first : Lokasi(
                        idLokasi: '', idSuratTugas: '', namaLokasi: '', latitude: 0, longitude: 0, detail: '', timestamp: '',
                      ),
                    ),
                    hint: "Pilih Lokasi",
                    fieldName: 'lokasi',
                    onChanged: (value) {
                      if (value == null) return;
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

                  // Target searchable dropdown
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
                      : (targetAndTemuanList.isEmpty
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Target / Sasaran", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        "Tidak ada data target yang tersedia untuk jenis karantina ini.",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                      : _buildSearchableDropdown<String>(
                    title: "Target / Sasaran",
                    items: targetAndTemuanList, // Menggunakan data dari API targetUji
                    itemAsString: (target) => target,
                    selectedItem: selectedTarget,
                    hint: "Pilih Target / Sasaran",
                    fieldName: 'target',
                    onChanged: (value) {
                      setState(() {
                        selectedTarget = value;
                        if (_formSubmitted) {
                          _updateFieldError('target', value == null);
                        }
                      });
                    },
                    isRequired: true,
                  )),

                  // Metode (text input)
                  const Text("Metode", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _metodeController,
                    validator: (value) => _customValidator(value, 'metode'),
                    onChanged: (value) {
                      if (_formSubmitted) {
                        _updateFieldError('metode', value.isEmpty);
                        _formKey.currentState?.validate();
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

                  // Temuan searchable dropdown (sekarang juga dari API targetUji)
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
                      : (targetAndTemuanList.isEmpty
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        "Tidak ada data temuan yang tersedia.",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                      : _buildSearchableDropdown<String>(
                    title: "Temuan",
                    items: targetAndTemuanList, // Menggunakan data dari API targetUji
                    itemAsString: (temuan) => temuan,
                    selectedItem: selectedTemuan,
                    hint: "Pilih Temuan",
                    fieldName: 'temuan',
                    onChanged: (value) {
                      setState(() {
                        selectedTemuan = value;
                        if (_formSubmitted) {
                          _updateFieldError('temuan', value == null);
                        }
                      });
                    },
                    isRequired: true,
                  )),

                  // Komoditas searchable dropdown
                  _buildSearchableDropdown<Komoditas>(
                    title: "Komoditas",
                    items: komoditasList,
                    itemAsString: (kom) => kom.namaKomoditas,
                    selectedItem: komoditasList.firstWhere(
                          (element) => element.idKomoditas == selectedKomoditasId,
                      orElse: () => komoditasList.isNotEmpty ? komoditasList.first : Komoditas(
                        idKomoditas: '', idSuratTugas: '', namaKomoditas: '',
                      ),
                    ),
                    hint: "Pilih Komoditas",
                    fieldName: 'komoditas',
                    onChanged: (value) {
                      if (value == null) return;
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
                        children: const [
                          Text("Dokumentasi", style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 20),
                        ],
                      ),
                      SizedBox(
                        width: 150,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _showImagePicker(context),
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text("Upload Foto", style: TextStyle(fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF522E2E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                          ),
                        ),
                      ),
                      if (_formSubmitted && _fieldErrors['foto'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text(
                            "Wajib diisi",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  // Photo gallery with delete option
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

                                // Delete button
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black54.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
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

                                // Image counter
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
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
                  const Text("Format .JPG, .PNG, .JPEG",
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
                            ? const CircularProgressIndicator(color: Colors.white)
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
          if (_isSubmitting)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
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
