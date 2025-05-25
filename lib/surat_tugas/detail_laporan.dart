import 'dart:async';
import 'dart:io';
import 'st_selesai.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../databases/db_helper.dart';
import 'form_periksa.dart';
import 'package:uuid/uuid.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:q_officer_barantin/widgets/card_hasil_periksa.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // Import provider
import '../services/auth_provider.dart'; // Import AuthProvider

class DetailLaporan extends StatefulWidget {
  final StLengkap suratTugas;
  final String? idSuratTugas;
  final String? customTitle;
  final VoidCallback onSelesaiTugas;
  final bool isViewOnly;
  final bool showDetailHasil;

  const DetailLaporan({
    super.key,
    this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
    this.isViewOnly = false,
    this.showDetailHasil = false,
    this.customTitle,
  });

  @override
  _DetailLaporanState createState() => _DetailLaporanState();
}


class _DetailLaporanState extends State<DetailLaporan> with SingleTickerProviderStateMixin{
  late StreamSubscription<ConnectivityResult> _subscription;
  bool _isOffline = false;
  bool _showConnectionMessage = false;
  List<Map<String, dynamic>> _hasilList = [];
  var uuid = Uuid();
  bool _hasSeenTutorial = false;

  // Tutorial coach mark
  late TutorialCoachMark tutorialCoachMark;
  final GlobalKey suratTugasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _monitorConnection();
    _checkTutorialStatus();
    _loadHasilPemeriksaan(); // Memuat hasil pemeriksaan saat initState

    // Initialize tutorial after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTutorial();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!_hasSeenTutorial) {
          _showTutorial();
        }
      });
    });
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSeenTutorial = prefs.getBool('seen_detail_laporan_tutorial') ?? false;
    });
  }

  Future<void> _saveTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_detail_laporan_tutorial', true);
  }

  void _initTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: const Color(0xFF522E2E),
      textSkip: "LEWATI",
      textStyleSkip: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        debugPrint("Tutorial selesai");
        _saveTutorialStatus();
      },
      onSkip: () {
        _saveTutorialStatus();
        return true;
      },
    );
  }

  void _showTutorial() {
    tutorialCoachMark.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "suratTugasKey",
        keyTarget: suratTugasKey,
        alignSkip: Alignment.bottomRight,
        paddingFocus: 20.0, // Increased padding to focus on entire area
        shape: ShapeLightFocus.RRect,
        radius: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Detail Surat Tugas 📃", // Changed emoji
                      style: TextStyle(
                        color: Color(0xFF522E2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tekan untuk melihat detail lengkap surat tugas. Di dalamnya terdapat informasi dasar, petugas, lokasi dan komoditas yang diperiksa.",
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }

  Future<void> _monitorConnection() async {
    _subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      bool nowOffline = result == ConnectivityResult.none;

      if (_isOffline && !nowOffline) {
        setState(() {
          _isOffline = false;
          _showConnectionMessage = true;
        });

        final ping = await getPingLatency();
        if (ping < 100) {
          final db = DatabaseHelper();
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final userNip = authProvider.userNip; // ✅ GANTI: userId -> userNip
          if (userNip != null) {
            await db.syncUnsentData(userNip);
          }
        }

        _hideNotificationAfterDelay();
      } else if (!_isOffline && nowOffline) {
        setState(() {
          _isOffline = true;
          _showConnectionMessage = true;
        });
        _hideNotificationAfterDelay();
      }
    });
  }


  Future<void> _loadHasilPemeriksaan() async {
    if (widget.idSuratTugas == null) return;
    final db = DatabaseHelper();
    final periksaList = await db.getPeriksaById(widget.idSuratTugas!);
    if (mounted) {
      setState(() {
        _hasilList = periksaList.where((e) => e['id_surat_tugas'] == widget.idSuratTugas).toList();
      });
    }
  }

  // Removed getSuratTugasLengkap as it's redundant.
  // The widget.suratTugas already contains the StLengkap object.

  Future<int> getPingLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      final _ = await InternetAddress.lookup('google.com');
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return 9999;
    }
  }

  void _hideNotificationAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _showConnectionMessage = false;
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Directly use widget.suratTugas as it's already available
    final suratTugasData = widget.suratTugas;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.customTitle ?? "Riwayat Pemeriksaan",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: widget.idSuratTugas == null
          ? const Center(child: Text('ID Surat Tugas tidak tersedia'))
          : Column(
        children: [
          if (_showConnectionMessage)
            buildConnectionStatus(isConnected: !_isOffline),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
                      child: Container(
                        // Add shadow with BoxDecoration
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 4), // Shadow position
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          key: suratTugasKey,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Increased vertical padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: const Color(0xFF522E2E).withOpacity(0.2), width: 1),
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: const Color(0xFF522E2E).withOpacity(0.2), width: 1),
                          ),
                          backgroundColor: Colors.white,
                          collapsedBackgroundColor: const Color(0xFFF8F8F8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF522E2E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.assignment_outlined,
                              color: Color(0xFF522E2E),
                            ),
                          ),
                          title: Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: Text(
                              suratTugasData.noSt,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF522E2E)),
                            ),
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 1.0),
                            child: Text(
                              "Tekan untuk melihat detail",
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                          children: [
                            Card(
                              margin: const EdgeInsets.all(12),
                              color: const Color(0xFFFEC559),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow("Dasar", suratTugasData.dasar),
                                    _buildInfoRow("Nama", suratTugasData.petugas.first.namaPetugas),
                                    _buildInfoRow("NIP", suratTugasData.petugas.first.nipPetugas),
                                    _buildInfoRow("Gol / Pangkat",
                                        "${suratTugasData.petugas.first.gol} / ${suratTugasData.petugas.first.pangkat}"),
                                    _buildInfoRow("Komoditas", suratTugasData.komoditas.first.namaKomoditas),
                                    _buildInfoRow("Lokasi", suratTugasData.lokasi.first.namaLokasi),
                                    _buildInfoRow("Tgl Penugasan", suratTugasData.tanggal),
                                    _buildInfoRow("Penandatangan", suratTugasData.namaTtd),
                                    _buildInfoRow("Perihal", suratTugasData.hal),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    // Menggunakan Consumer untuk mendapatkan AuthProvider
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        final userNip = authProvider.userNip;
                        return Column(
                          children: _hasilList.map((item) {
                            return HasilPeriksaCard(
                              item: item,
                              canTap: widget.showDetailHasil,
                              showSync: !widget.isViewOnly,
                              enableAutoSlide: true, // Enable auto slide for images
                              onTap: widget.showDetailHasil
                                  ? () async {
                                final fotoList = await DatabaseHelper().getImageBase64List(item['id_pemeriksaan']);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SuratTugasSelesai(
                                      hasilPemeriksaan: {
                                        ...item,
                                        'fotoBase64List': fotoList,
                                      },
                                    ),
                                  ),
                                );
                              }
                                  : null,
                              onSyncPressed: widget.isViewOnly || userNip == null
                                  ? null
                                  : () async {
                                final db = DatabaseHelper();
                                await db.syncSingleData(item['id_pemeriksaan'], userNip); // Teruskan userNip
                                // Setelah sync, muat ulang hasil pemeriksaan untuk memperbarui UI
                                await _loadHasilPemeriksaan();
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    if (!widget.isViewOnly)
                      buildLaporanFooter(
                        context: context,
                        idSuratTugas: widget.idSuratTugas,
                        suratTugas: widget.suratTugas,
                        onSelesaiTugas: widget.onSelesaiTugas,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    const double labelWidth = 90.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF522E2E),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Text(
            " : ",
            style: TextStyle(
              color: Color(0xFF522E2E),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Value text
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                color: Color(0xFF522E2E),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedConfirmationDialog extends StatefulWidget {
  final VoidCallback onConfirmed;

  const _AnimatedConfirmationDialog({required this.onConfirmed});

  @override
  State<_AnimatedConfirmationDialog> createState() => _AnimatedConfirmationDialogState();
}

class _AnimatedConfirmationDialogState extends State<_AnimatedConfirmationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _iconAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_iconController);

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeOut,
    ));

    _iconController.forward();

    _iconController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _iconController.reset();
            _iconController.forward();
          }
        });
      }
    });
  }


  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF522E2E).withOpacity(0.1),
                ),
                child: AnimatedBuilder(
                  animation: _iconAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _iconAnimation.value,
                      child: child,
                    );
                  },
                  child: const Icon(
                      Icons.question_mark_rounded,
                      size: 52,
                      color: Color(0xFF522E2E)
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Konfirmasi Selesai Tugas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF522E2E),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Apakah Anda yakin ingin menyelesaikan Surat Tugas ini?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF522E2E),
                          side: const BorderSide(color: Color(0xFF522E2E)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Tidak',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF522E2E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onConfirmed();
                        },
                        child: const Text(
                          'Ya',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

Widget buildConnectionStatus({required bool isConnected}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    color: isConnected ? Colors.green : Colors.red,
    child: Row(
      children: [
        Icon(
          isConnected ? Icons.wifi : Icons.wifi_off,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isConnected
                ? "Koneksi internet terhubung. Data berhasil disinkronkan."
                : "Koneksi internet terputus. Data akan disimpan sementara.",
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

void showConfirmation({
  required BuildContext context,
  required VoidCallback onConfirmed,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: _AnimatedConfirmationDialog(onConfirmed: onConfirmed),
      );
    },
  );
}

Widget buildLaporanFooter({
  required BuildContext context,
  required String? idSuratTugas,
  required StLengkap suratTugas,
  required VoidCallback onSelesaiTugas,
}) {
  return Consumer<AuthProvider>( // ✅ TAMBAH: Wrap dengan Consumer
    builder: (context, authProvider, child) {
      final userNip = authProvider.userNip; // ✅ TAMBAH: Ambil userNip

      return Center(
        child: Column(
          children: [
            SizedBox(
              width: 270,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.note_add, color: Color(0xFF522E2E)),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormPeriksa(
                        idSuratTugas: suratTugas.idSuratTugas,
                        suratTugas: suratTugas,
                        onSelesaiTugas: onSelesaiTugas,
                        userNip: userNip ?? '', // ✅ GANTI: Teruskan userNip yang benar
                      ),
                    ),
                  );
                  if (result == true) {
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFFFEC559),
                  foregroundColor: const Color(0xFF522E2E),
                  elevation: 3,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                label: const Text(
                  "Buat Laporan Pemeriksaan",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF522E2E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 270,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                onPressed: () {
                  showConfirmation(
                    context: context,
                    onConfirmed: () {
                      onSelesaiTugas();
                      Navigator.pop(context);
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF522E2E),
                  elevation: 3,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    side: BorderSide(color: Color(0xFF522E2E), width: 2),
                  ),
                ),
                label: const Text(
                  "Selesai Tugas",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    },
  );
}
