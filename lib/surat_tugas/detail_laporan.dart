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

class DetailLaporan extends StatefulWidget {
  final StLengkap suratTugas;
  final String? idSuratTugas;
  final String? customTitle;
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
  List<Map<String, dynamic>> _hasilList = [];
  var uuid = Uuid();

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
          await db.syncUnsentData();
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

  Future<Map<String, dynamic>?> getSuratTugasLengkap(String idSuratTugas) async {
    final db = DatabaseHelper();

    final suratList = await db.getData('Surat_Tugas');
    final surat = suratList.firstWhere(
          (e) => e['id_surat_tugas'] == idSuratTugas,
      orElse: () => {},
    );

    if (surat.isEmpty) return null;

    final periksaList = await db.getPeriksaById(idSuratTugas);
    final filteredPeriksa = periksaList.where((e) => e['id_surat_tugas'] == idSuratTugas).toList();

    return {
      'surat': surat,
      'pemeriksaan': filteredPeriksa,
    };
  }

  Future<int> getPingLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      final result = await InternetAddress.lookup('google.com');
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return 9999;
    }
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
          widget.customTitle ?? "Riwayat Pemeriksaan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: widget.idSuratTugas == null
          ? Center(child: Text('ID Surat Tugas tidak tersedia'))
          : FutureBuilder(
        future: getSuratTugasLengkap(widget.idSuratTugas!),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Surat tugas tidak ditemukan'));
          }

          final suratTugas = snapshot.data as Map<String, dynamic>;
          if (_hasilList.isEmpty) {
            _hasilList = List<Map<String, dynamic>>.from(suratTugas['pemeriksaan']);
          }

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
                            "${widget.suratTugas.noSt ?? '-'}",
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
                                    _buildInfoRow("Dasar", widget.suratTugas.dasar),
                                    _buildInfoRow("Nama", widget.suratTugas.petugas.first.namaPetugas),
                                    _buildInfoRow("NIP", widget.suratTugas.petugas.first.nipPetugas),
                                    _buildInfoRow("Gol / Pangkat",
                                        "${widget.suratTugas.petugas.first.gol ?? '-'} / ${widget.suratTugas.petugas.first.pangkat ?? '-'}"),
                                    _buildInfoRow("Komoditas", widget.suratTugas.komoditas.first.namaKomoditas),
                                    _buildInfoRow("Lokasi", widget.suratTugas.lokasi.first.namaLokasi),
                                    _buildInfoRow("Tgl Penugasan", widget.suratTugas.tanggal),
                                    _buildInfoRow("Penandatangan", widget.suratTugas.namaTtd),
                                    _buildInfoRow("Perihal", widget.suratTugas.hal),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._hasilList.map((item) {
                          return HasilPeriksaCard(
                            item: item,
                            pageController: _pageController!,
                            canTap: widget.showDetailHasil,
                            showSync: !widget.isViewOnly,
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
                            onSyncPressed: widget.isViewOnly
                                ? null
                                : () async {
                              final db = DatabaseHelper();
                              await db.syncSingleData(item['id_pemeriksaan']);
                              item['syncdata'] = 1;
                              setState(() {
                                final index = _hasilList.indexWhere((e) => e['id_pemeriksaan'] == item['id_pemeriksaan']);
                                if (index != -1) _hasilList[index] = item;
                              });
                            },
                          );
                        }).toList(),
                        const SizedBox(height: 24),
                        if (!widget.isViewOnly)
                          buildLaporanFooter(
                            context: context,
                            idSuratTugas: widget.idSuratTugas,
                            suratTugas: widget.suratTugas, // ✅ Ini yang bener
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
              value?.toString() ?? '-',
              style: const TextStyle(color: Color(0xFF522E2E)),
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
  required String? idSuratTugas,
  required StLengkap suratTugas,
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
                    idSuratTugas: suratTugas.idSuratTugas,
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