import 'dart:async';
import 'dart:io';
import 'st_selesai.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../databases/db_helper.dart';
import 'form_periksa.dart';
import 'additional/tanggal.dart';

class DetailLaporan extends StatefulWidget {
  final int? idSuratTugas;
  final String? customTitle;
  final Map<String, dynamic> suratTugas;
  final VoidCallback onSelesaiTugas;
  final bool isViewOnly;
  final bool showDetailHasil;

  const DetailLaporan({
    Key? key,
    this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
    this.isViewOnly = false,
    this.showDetailHasil = false,
    this.customTitle,
  }) : super(key: key);

  @override
  _DetailLaporanState createState() => _DetailLaporanState();
}


class _DetailLaporanState extends State<DetailLaporan> {
  late StreamSubscription<ConnectivityResult> _subscription;
  bool _isOffline = false;
  bool _showConnectionMessage = false;

  PageController? _pageController;
  Timer? _pageTimer;

  @override
  void initState() {
    super.initState();
    _monitorConnection();

    _pageController = PageController();
    _pageTimer = Timer.periodic(Duration(seconds: 3), (Timer timer) {
      if (_pageController!.hasClients) {
        int nextPage = _pageController!.page!.round() + 1;
        _pageController!.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _monitorConnection() {
    _subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      bool nowOffline = result == ConnectivityResult.none;

      if (_isOffline && !nowOffline) {
        // Baru saja reconnect
        setState(() {
          _isOffline = false;
          _showConnectionMessage = true;
        });
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


  Future<List<Map<String, dynamic>>> getPemeriksaanData() async {
    final db = DatabaseHelper();
    final data = await db.getAllPeriksa();

    final idSurat = widget.idSuratTugas ?? widget.suratTugas['id_surat_tugas'];
    return data.where((e) => e['id_surat_tugas'] == idSurat).toList();
  }


  Future<Map<String, dynamic>?> getSuratTugas() async {
    final db = DatabaseHelper();
    final all = await db.getData('Surat_Tugas');

    final idSurat = widget.idSuratTugas ?? widget.suratTugas['id_surat_tugas'];
    final filtered = all.where((e) => e['id_surat_tugas'] == idSurat);

    return filtered.isNotEmpty ? filtered.first : null;
  }


  void _hideNotificationAfterDelay() {
    Future.delayed(Duration(seconds: 3), () {
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

  void _showConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: const Color(0xFFFBF2F2),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.question_mark_rounded, size: 60, color: Color(0xFF522E2E)),
            const SizedBox(height: 10),
            Text(
              'Konfirmasi Selesai Tugas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.brown[800],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Apakah Anda yakin ingin menyelesaikan Surat Tugas ini?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tidak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSelesaiTugas();
                      Navigator.pop(context);
                    },
                    child: const Text('Ya'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.customTitle ?? "Riwayat Pemeriksaan", // ⬅️ kalau null, fallback ke default
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: Future.wait([
          getSuratTugas(),
          getPemeriksaanData(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data![0] == null) {
            return Center(child: Text('Surat tugas tidak ditemukan'));
          }

          final suratTugas = snapshot.data![0] as Map<String, dynamic>;
          final hasilList = snapshot.data![1] as List<Map<String, dynamic>>;

          return Column(
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
                        ExpansionTile(
                          title: Text(
                            "${suratTugas['no_st'] ?? '-'}",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Card(
                              color: Color(0xFFFEC559),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow("Dasar", suratTugas['dasar']),
                                    _buildInfoRow("Nama", suratTugas['nama']),
                                    _buildInfoRow("NIP", suratTugas['nip']),
                                    _buildInfoRow("Gol / Pangkat",
                                        "${suratTugas['gol'] ?? '-'} / ${suratTugas['pangkat'] ?? '-'}"),
                                    _buildInfoRow("Komoditas", suratTugas['komoditas']),
                                    _buildInfoRow("Lokasi", suratTugas['lok']),
                                    _buildInfoRow("Tgl Penugasan", suratTugas['tgl_tugas']),
                                    _buildInfoRow("Penandatangan", suratTugas['ttd']),
                                    _buildInfoRow("Perihal", suratTugas['hal']),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...hasilList.map((item) {
                          return buildHasilPeriksaCard(
                            item: item,
                            pageController: _pageController!,
                            enableTap: widget.showDetailHasil,
                            onTap: () {
                              if (widget.showDetailHasil) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SuratTugasSelesai(
                                      hasilPemeriksaan: item,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        }).toList(),

                        const SizedBox(height: 24),
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
          );
        },
      ),
    );
  }
  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF522E2E), fontWeight: FontWeight.bold),
            ),
          ),
          const Text(":", style: TextStyle(color: Color(0xFF522E2E), fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value?.toString() ?? '-',  // Mengecek null dan memberi default '-'
              style: const TextStyle(color: Color(0xFF522E2E)),  // Menentukan warna teks
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildConnectionStatus({required bool isConnected}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    color: isConnected ? Colors.green : Colors.red,
    child: Text(
      isConnected
          ? "Koneksi internet terhubung. Data berhasil disinkronkan."
          : "Koneksi internet terputus. Data akan disimpan sementara.",
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}

Widget buildLaporanFooter({
  required BuildContext context,
  required int? idSuratTugas,
  required Map<String, dynamic> suratTugas,
  required VoidCallback onSelesaiTugas,
}) {
  return Center(
    child: Column(
      children: [
        SizedBox(
          width: 250,
          child: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FormPeriksa(
                    idSuratTugas: idSuratTugas,
                    suratTugas: suratTugas,
                    onSelesaiTugas: onSelesaiTugas,
                  ),
                ),
              );
              if (result == true) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: const Color(0xFFFEC559),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
            ),
            child: const Text(
              "Buat Laporan Pemeriksaan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF522E2E),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 250,
          child: ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  backgroundColor: const Color(0xFFFBF2F2),
                  contentPadding: const EdgeInsets.all(20),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.question_mark_rounded, size: 60, color: Color(0xFF522E2E)),
                      const SizedBox(height: 10),
                      Text(
                        'Konfirmasi Selesai Tugas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Apakah Anda yakin ingin menyelesaikan Surat Tugas ini?",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Tidak'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                onSelesaiTugas();
                                Navigator.pop(context);
                              },
                              child: const Text('Ya'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: const Color(0xFF522E2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
                side: const BorderSide(color: Color(0xFF522E2E), width: 2),
              ),
            ),
            child: const Text(
              "Selesai Tugas",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildHasilPeriksaCard({
  required Map<String, dynamic> item,
  required PageController pageController,
  required bool enableTap,
  required VoidCallback? onTap,
  bool autoSlide = true,
}) {
  final List<String> fotoList = (item['fotoPaths'] as String).split('|');
  final pageController = PageController();
  Timer? timer;

  if (autoSlide && fotoList.length > 1) {
    timer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (pageController.hasClients) {
        int nextPage = pageController.page!.round() + 1;
        if (nextPage >= fotoList.length) nextPage = 0;
        pageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  return GestureDetector(
    onTap: enableTap ? onTap : null,
    child: Card(
      margin: EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.brown[700],
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${item['lokasi'] ?? '-'}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(formatTanggal(item['tgl_periksa'] ?? '-'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fotoList.isNotEmpty)
                  Container(
                    width: 100,
                    height: 100,
                    margin: EdgeInsets.only(right: 12),
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: fotoList.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(fotoList[index]),
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Komoditas", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(item['komoditas'] ?? '-'),
                      SizedBox(height: 8),
                      Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(item['temuan'] ?? '-'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
