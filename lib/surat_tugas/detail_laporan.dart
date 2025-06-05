import 'dart:async';
import 'dart:io';
import 'package:q_officer_barantin/main.dart';
import 'st_selesai.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../databases/db_helper.dart';
import 'form_periksa.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:q_officer_barantin/widgets/card_hasil_periksa.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:q_officer_barantin/services/history_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../dialog/selesai_tugas_dialog.dart';

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

  // CardHasilPeriksa dan tombol sinkronisasi
  final GlobalKey cardHasilPeriksaKey = GlobalKey();
  final GlobalKey tombolSinkronKey = GlobalKey();

  // GlobalKey untuk tombol "Buat Laporan Pemeriksaan" dan "Selesai Tugas"
  final GlobalKey buatLaporanButtonKey = GlobalKey();
  final GlobalKey selesaiTugasButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _monitorConnection();
    _initializePageAndTutorial();
  }

    Future<void> _initializePageAndTutorial() async {
      await _checkTutorialStatus();
      await _loadHasilPemeriksaan();

      if (mounted) {
        if (_hasilList.isNotEmpty) {
          _initTutorial();
        } else {
          _initTutorialWithoutHasilPeriksa();
        }

        if (!_hasSeenTutorial) {
          _showTutorial();
        }
      }
    }

    Future<void> _checkTutorialStatus() async {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) { // Periksa mounted setelah async gap
        setState(() {
          _hasSeenTutorial = prefs.getBool('seen_detail_laporan_tutorial_v2') ?? false;
        });
      }
    }

    Future<void> _saveTutorialStatus() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_detail_laporan_tutorial_v2', true);
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

    void _initTutorialWithoutHasilPeriksa() {
      tutorialCoachMark = TutorialCoachMark(
        targets: _createTargets(hasHasilPeriksa: false),
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
    if (mounted && tutorialCoachMark.targets.isNotEmpty) {
      // Periksa apakah widget masih terpasang sebelum menampilkan tutorial
      Future.delayed(Duration.zero, () {
        if (mounted) {
          tutorialCoachMark.show(context: context);
        }
      });
    } else if (mounted && tutorialCoachMark.targets.isEmpty) {
      debugPrint("Tidak ada target tutorial untuk ditampilkan.");
      _saveTutorialStatus(); // Simpan status jika tidak ada target, agar tidak muncul lagi
    }
  }

  List<TargetFocus> _createTargets({bool hasHasilPeriksa = true}) {
    List<TargetFocus> targets = [];

    // Target untuk Detail Surat Tugas
    if (suratTugasKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "suratTugasKey",
          keyTarget: suratTugasKey,
          alignSkip: Alignment.bottomRight, // Konsisten
          paddingFocus: 20.0,
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Detail Surat Tugas 📃",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
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
    }

    // Target untuk Card Hasil Periksa (hanya jika ada hasil periksa dan widget.showDetailHasil true)
    if (hasHasilPeriksa && widget.showDetailHasil && cardHasilPeriksaKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "cardHasilPeriksaKey",
          keyTarget: cardHasilPeriksaKey,
          alignSkip: Alignment.bottomRight, // Konsisten
          paddingFocus: 10.0,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Hasil Pemeriksaan 📄",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Ini adalah card hasil pemeriksaan. Tekan untuk melihat detail laporan pemeriksaan yang telah dibuat. Anda juga dapat melihat status sinkronisasi data di sini.",
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
    }

    // Target untuk Tombol Sinkronisasi (hanya jika ada hasil periksa dan !widget.isViewOnly)
    if (hasHasilPeriksa && !widget.isViewOnly && tombolSinkronKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "tombolSinkronKey",
          keyTarget: tombolSinkronKey,
          alignSkip: Alignment.bottomRight, // PERBAIKAN: Diubah dari topRight
          paddingFocus: 5.0,
          shape: ShapeLightFocus.RRect,
          radius: 5,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sinkronisasi Data 🔄",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Tombol ini menunjukkan status sinkronisasi laporan. Jika 'Sinkron Sekarang', tekan untuk mengirim data ke server. Jika 'Telah Sinkron', data sudah aman di server.",
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
    }

    // Target untuk tombol "Buat Laporan Pemeriksaan" (hanya jika !widget.isViewOnly)
    if (!widget.isViewOnly && buatLaporanButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "buatLaporanButtonKey",
          keyTarget: buatLaporanButtonKey,
          alignSkip: Alignment.bottomRight,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Buat Laporan Baru 📝",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Tekan tombol ini untuk membuat laporan pemeriksaan baru terkait surat tugas ini.",
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
    }

    // Target untuk tombol "Selesai Tugas" (hanya jika !widget.isViewOnly)
    if (!widget.isViewOnly && selesaiTugasButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "selesaiTugasButtonKey",
          keyTarget: selesaiTugasButtonKey,
          alignSkip: Alignment.bottomRight, // PERBAIKAN: Diubah dari topCenter
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Selesaikan Tugas ✅",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Jika semua laporan pemeriksaan telah dibuat dan disinkronkan, tekan tombol ini untuk menandai surat tugas sebagai selesai.",
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
    }

    return targets;
  }

  Future<void> _monitorConnection() async {
    _subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      bool nowOffline = result == ConnectivityResult.none;

      if (_isOffline && !nowOffline) {
        if (mounted) {
          setState(() {
            _isOffline = false;
            _showConnectionMessage = true;
          });
        }

        final ping = await getPingLatency();
        if (ping < 100) {
          final db = DatabaseHelper();
          if (mounted) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final userNip = authProvider.userNip;
            if (userNip != null) {
              await db.syncUnsentData(userNip);
              if (mounted) {
                _loadHasilPemeriksaan();
              }
            }
          }
        }
        _hideNotificationAfterDelay();
      } else if (!_isOffline && nowOffline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
            _showConnectionMessage = true;
          });
        }
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
      if (mounted) {
        setState(() {
          _showConnectionMessage = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    if (tutorialCoachMark.isShowing) {
      tutorialCoachMark.finish();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

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
        actions: [
          // Tombol untuk menampilkan tutorial lagi jika sudah pernah dilihat
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Reset status tutorial agar bisa ditampilkan lagi
              SharedPreferences.getInstance().then((prefs) => prefs.remove('seen_detail_laporan_tutorial_v2'));
              setState(() => _hasSeenTutorial = false);
              if (_hasilList.isNotEmpty) {
                _initTutorial();
              } else {
                _initTutorialWithoutHasilPeriksa();
              }
              _showTutorial();
            },
            tooltip: "Tampilkan Tutorial",
          ),
        ],
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
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 4),
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
                                padding: const EdgeInsets.all(20.0),
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

                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        final userNip = authProvider.userNip;
                        // Bangun daftar widget CardHasilPeriksa
                        // Kita hanya perlu satu cardHasilPeriksaKey untuk tutorial,
                        // jadi kita akan menerapkannya pada card pertama jika ada.
                        List<Widget> hasilPeriksaWidgets = [];
                        for (int i = 0; i < _hasilList.length; i++) {
                          final item = _hasilList[i];
                          hasilPeriksaWidgets.add(
                            HasilPeriksaCard(
                              // Terapkan GlobalKey ke card pertama untuk tutorial
                              key: (i == 0 && widget.showDetailHasil) ? cardHasilPeriksaKey : null,
                              item: item,
                              canTap: widget.showDetailHasil,
                              showSync: !widget.isViewOnly,
                              enableAutoSlide: true,
                              // Terapkan GlobalKey ke tombol sinkronisasi di card pertama untuk tutorial
                              syncButtonKey: (i == 0 && !widget.isViewOnly) ? tombolSinkronKey : null,
                              onTap: widget.showDetailHasil
                                  ? () async {
                                final fotoList = await DatabaseHelper().getImageBase64List(item['id_pemeriksaan']);
                                if (mounted) { // Pastikan widget masih terpasang
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
                              }
                                  : null,
                              onSyncPressed: widget.isViewOnly || userNip == null
                                  ? null
                                  : () async {
                                final db = DatabaseHelper();
                                await db.syncSingleData(item['id_pemeriksaan'], userNip);
                                await _loadHasilPemeriksaan();
                              },
                            ),
                          );
                        }

                        return Column(
                          children: hasilPeriksaWidgets,
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
                        buatLaporanKey: buatLaporanButtonKey,
                        selesaiTugasKey: selesaiTugasButtonKey,
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
                color: MyApp.karantinaBrown,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Text(
            " : ",
            style: TextStyle(
              color: MyApp.karantinaBrown,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Value text
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                color: MyApp.karantinaBrown,
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
                  color: MyApp.karantinaBrown.withOpacity(0.1),
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
                      color: MyApp.karantinaBrown
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Konfirmasi Selesai Tugas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: MyApp.karantinaBrown,
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
                          foregroundColor: MyApp.karantinaBrown,
                          side: const BorderSide(color: MyApp.karantinaBrown),
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
                          backgroundColor: MyApp.karantinaBrown,
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
  required GlobalKey buatLaporanKey,
  required GlobalKey selesaiTugasKey,
}) {
  return Consumer<AuthProvider>(
    builder: (context, authProvider, child) {
      final userNip = authProvider.userNip;
      return Center(
        child: Column(
          children: [
            SizedBox(
              width: 270,child: ElevatedButton(
              key: buatLaporanKey,
              onPressed: () async {
                if (!context.mounted) return;
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FormPeriksa(
                      idSuratTugas: suratTugas.idSuratTugas,
                      suratTugas: suratTugas,
                      onSelesaiTugas: onSelesaiTugas,
                      userNip: userNip ?? '',
                    ),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFFFEC559),
                foregroundColor: MyApp.karantinaBrown,
                elevation: 3,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              child: const Text(
                "Buat Laporan Pemeriksaan",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MyApp.karantinaBrown,
                ),
              ),
            ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 270,
              child: ElevatedButton(
                key: selesaiTugasKey,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: MyApp.karantinaBrown,
                  elevation: 3,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    side: BorderSide(color: MyApp.karantinaBrown, width: 2), // atau MyApp.karantinaBrown
                  ),
                ),
                // Perubahan API
                onPressed: () {
                  if (!context.mounted) return; //
                  showAnimatedSelesaikanTugasDialog( //
                    context: context, //
                    onConfirmed: () async { //
                      if (idSuratTugas == null || idSuratTugas.isEmpty) {
                        if (kDebugMode) print('Error: idSuratTugas null atau kosong saat selesaikan tugas.');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gagal selesaikan tugas: ID Surat Tugas tidak valid.'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      bool apiSuccess = await HistoryApiService.sendTaskStatusUpdate(
                        context: context,
                        idSuratTugas: idSuratTugas,
                        status: "selesai",
                        keterangan: "Menyelesaikan Surat Tugas No: ${suratTugas.noSt}",
                      );

                      if (apiSuccess) {
                        if (kDebugMode) print('✅ Status "selesai" berhasil dikirim ke API.');
                        onSelesaiTugas(); //
                        if (context.mounted) { //
                          Navigator.pop(context); //
                        }
                      } else {
                        if (kDebugMode) print('⚠️ Gagal mengirim status "selesai" ke API.');
                      }
                    },
                  );
                },
                // SAMPE SINI
                child: const Text(
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
