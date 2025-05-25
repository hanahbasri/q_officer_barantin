import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/lokasi.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'package:q_officer_barantin/services/surat_tugas_service.dart'; // Import SuratTugasService
import 'st_aktif.dart';
import 'st_tertunda.dart';
import '../databases/db_helper.dart';
import '../services/auth_provider.dart';
import 'detail_laporan.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';

class SuratTugasPage extends StatefulWidget {
  const SuratTugasPage({super.key});

  @override
  _SuratTugasPageState createState() => _SuratTugasPageState();
}

class _SuratTugasPageState extends State<SuratTugasPage> with SingleTickerProviderStateMixin {
  bool hasActiveTask = false;
  StLengkap? suratTugasAktif;
  List<StLengkap> suratTugasTertunda = [];
  List<StLengkap> suratTugasSelesai = [];
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Load data saat init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuratTugas();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSuratTugas();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuratTugas() async {
    if (_isLoading) {
      if (kDebugMode) print('🔄 _loadSuratTugas: Sudah memuat, melewati.');
      return;
    }

    setState(() {
      _isLoading = true;
      suratTugasAktif = null;
      hasActiveTask = false;
      suratTugasTertunda.clear();
      suratTugasSelesai.clear();
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userNip = authProvider.userNip;

      if (userNip == null) {
        throw Exception('NIP Pengguna tidak ditemukan');
      }

      final db = DatabaseHelper();

      // PERBAIKAN: Ambil status lokal SEBELUM sync
      final localDataBeforeSync = await db.getData('Surat_Tugas');
      Map<String, String> localStatuses = {};
      for (var item in localDataBeforeSync) {
        localStatuses[item['id_surat_tugas']] = item['status'];
      }

      if (kDebugMode) print('🔄 _loadSuratTugas: Menyinkronkan data dari API untuk NIP: $userNip');
      await db.syncSuratTugasFromApi(userNip);
      if (kDebugMode) print('✅ _loadSuratTugas: Sinkronisasi API selesai.');

      final data = await db.getData('Surat_Tugas');

      if (kDebugMode) {
        print('📋 Total surat tugas di database (setelah sync): ${data.length}');
      }

      StLengkap? tempSuratTugasAktif;
      List<StLengkap> tempSuratTugasTertunda = [];
      List<StLengkap> tempSuratTugasSelesai = [];

      for (var item in data) {
        String currentStatus = item['status'] ?? '';
        final idSuratTugas = item['id_surat_tugas'];

        // PERBAIKAN: Preservasi status lokal yang penting
        if (localStatuses.containsKey(idSuratTugas)) {
          final localStatus = localStatuses[idSuratTugas]!;

          // Prioritaskan status lokal jika sudah 'aktif', 'dikirim', atau 'selesai'
          if (localStatus == 'aktif' || localStatus == 'dikirim' || localStatus == 'selesai') {
            currentStatus = localStatus;

            // Update database untuk mempertahankan status lokal
            if (currentStatus != item['status']) {
              await db.updateStatusTugas(idSuratTugas, currentStatus);
              if (kDebugMode) print('💡 Mempertahankan status lokal "$currentStatus" untuk ${item['no_st']}');
            }
          }
        }

        if (kDebugMode) {
          print('🔍 Memproses surat tugas: $idSuratTugas dengan status akhir: $currentStatus');
        }

        try {
          final petugasData = (await db.getPetugasById(idSuratTugas)).map((p) => Petugas.fromDbMap(p)).toList();
          final lokasiData = (await db.getLokasiById(idSuratTugas)).map((l) => Lokasi.fromDbMap(l)).toList();
          final komoditasData = (await db.getKomoditasById(idSuratTugas)).map((k) => Komoditas.fromDbMap(k)).toList();

          final tugas = StLengkap.fromDbMap(item, petugasData, lokasiData, komoditasData);
          final tugasWithCorrectedStatus = tugas.copyWith(status: currentStatus);

          // PERBAIKAN: Status 'dikirim' dan 'aktif' masuk kategori aktif
          if (currentStatus == 'aktif' || currentStatus == 'dikirim') {
            if (tempSuratTugasAktif != null) {
              if (kDebugMode) print('⚠️ Ditemukan beberapa tugas aktif/dikirim. Menimpa tugas aktif.');
            }
            tempSuratTugasAktif = tugasWithCorrectedStatus;
          } else if (currentStatus == 'tertunda' || currentStatus == 'Proses') {
            tempSuratTugasTertunda.add(tugasWithCorrectedStatus);
          } else if (currentStatus == 'selesai') {
            tempSuratTugasSelesai.add(tugasWithCorrectedStatus);
          }
        } catch (innerError) {
          if (kDebugMode) {
            print('❌ Error memproses data terkait untuk $idSuratTugas: $innerError');
            print('❌ Stack trace untuk error internal: ${StackTrace.current}');
          }
        }
      }

      if (!mounted) return;

      setState(() {
        suratTugasAktif = tempSuratTugasAktif;
        hasActiveTask = tempSuratTugasAktif != null;
        suratTugasTertunda = tempSuratTugasTertunda;
        suratTugasSelesai = tempSuratTugasSelesai;

        if (kDebugMode) {
          print('📊 Setelah memuat: hasActiveTask = $hasActiveTask');
          print('📊 Tugas aktif: ${suratTugasAktif?.noSt ?? 'Tidak ada'} (Status: ${suratTugasAktif?.status ?? 'N/A'})');
          print('📊 Jumlah tugas tertunda: ${suratTugasTertunda.length}');
          print('📊 Jumlah tugas selesai: ${suratTugasSelesai.length}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error memuat surat tugas: $e');
        print('❌ Stack trace untuk error pemuatan: ${StackTrace.current}');
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        suratTugasAktif = null;
        hasActiveTask = false;
        suratTugasTertunda = [];
        suratTugasSelesai = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _terimaTugas(StLengkap tugas) async {
    try {
      // Perbarui database lokal
      final db = DatabaseHelper();
      if (kDebugMode) print('✅ Memperbarui database lokal: ${tugas.idSuratTugas} menjadi aktif');
      await db.updateStatusTugas(tugas.idSuratTugas, 'aktif');

      // Muat ulang data untuk mencerminkan perubahan status dan mendapatkan tugas yang baru aktif
      if (kDebugMode) print('🔄 Memuat ulang surat tugas setelah menerima tugas...');
      await _loadSuratTugas();

      // Pastikan widget masih mounted sebelum mengakses context atau navigasi
      if (!mounted) {
        if (kDebugMode) print('Widget tidak lagi mounted setelah _loadSuratTugas selesai.');
        return;
      }

      if (suratTugasAktif == null) {
        if (kDebugMode) print('❗ Gagal memuat surat tugas aktif setelah pembaruan status lokal.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas berhasil diterima, namun gagal memuat tampilan tugas aktif. Coba refresh halaman.')),
        );
        return;
      }

      if (kDebugMode) print('✅ Tugas berhasil diterima. Navigasi ke SuratTugasAktifPage.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SuratTugasAktifPage(
            idSuratTugas: suratTugasAktif!.idSuratTugas,
            suratTugas: suratTugasAktif!,
            onSelesaiTugas: _selesaikanTugas,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saat menerima tugas: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
      if (!mounted) return; // Pastikan mounted sebelum show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menerima tugas. Terjadi kesalahan.')),
      );
    }
  }

  void _selesaikanTugas() async {
    if (suratTugasAktif != null) {
      final db = DatabaseHelper();
      // Perbarui lokal
      if (kDebugMode) print('✅ Menyelesaikan tugas: ${suratTugasAktif!.idSuratTugas}');
      await db.updateStatusTugas(suratTugasAktif!.idSuratTugas, 'selesai');
      if (kDebugMode) print('🔄 Memuat ulang surat tugas setelah menyelesaikan tugas...');
      _loadSuratTugas(); // Muat ulang untuk memperbarui UI
    }
  }

  Future<void> _refreshData() async {
    if (kDebugMode) print('🔄 Memperbarui data...');
    await _loadSuratTugas();
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.left,
            ),
          ),
          const Text(":", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value ?? ""),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundText(String text) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animation.value,
                child: child,
              );
            },
            child: Image.asset('images/not_found.png', height: 100, width: 100),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pemeriksaan Lapangan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Perbarui Data',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF522E2E)),
            ),
            SizedBox(height: 16),
            Text('Memuat data surat tugas...'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          children: [
            // ---- AKTIF ----
            ExpansionTile(
              title: Text("Surat Tugas Aktif", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF522E2E),),),
              leading: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _animation.value,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.circle,
                  color: Colors.green,
                ),
              ),
              children: hasActiveTask
                  ? [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  suratTugasAktif?.noSt ?? "-",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: suratTugasAktif?.status == 'dikirim'
                                        ? Colors.white
                                        : Color(0xFFD8F3DC),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (suratTugasAktif?.status == 'dikirim') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailLaporan(
                                            idSuratTugas: suratTugasAktif!.idSuratTugas,
                                            suratTugas: suratTugasAktif!,
                                            onSelesaiTugas: _selesaikanTugas,
                                            isViewOnly: false,
                                            showDetailHasil: false,
                                          ),
                                        ),
                                      );
                                    } else {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SuratTugasAktifPage(
                                            idSuratTugas: suratTugasAktif!.idSuratTugas,
                                            suratTugas: suratTugasAktif!,
                                            onSelesaiTugas: _selesaikanTugas,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        _loadSuratTugas();
                                      }
                                    }
                                  },
                                  child: Text(
                                    suratTugasAktif?.status == 'dikirim'
                                        ? "Lihat Detail"
                                        : "Buat Laporan",
                                    style: TextStyle(color: suratTugasAktif?.status == 'dikirim'
                                        ? Colors.green
                                        : Color(0xFF1B4332)),
                                  )
                              ),
                            ],
                          ),
                        ),
                        // BODY
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRow("Dasar", suratTugasAktif?.dasar),
                              _buildRow(
                                "Lokasi",
                                suratTugasAktif?.lokasi.isNotEmpty == true
                                    ? suratTugasAktif!.lokasi[0].namaLokasi
                                    : "-",
                              ),
                              _buildRow("Tanggal Tugas", suratTugasAktif?.tanggal),
                              _buildRow("Perihal", suratTugasAktif?.hal),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ]
                  : [_buildNotFoundText("Tidak ada surat tugas aktif saat ini")],
            ),

            ExpansionTile(
              title: const Text("Surat Tugas Tertunda", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF522E2E),),),
              leading: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _animation.value,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.circle,
                  color: Colors.orange,
                ),
              ),
              children: suratTugasTertunda.isEmpty
                  ? [_buildNotFoundText("Tidak ada surat tugas tertunda saat ini")]
                  : suratTugasTertunda.map((tugas) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  tugas.noSt,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                ),
                                onPressed: () {
                                  Navigator.push(context,
                                    MaterialPageRoute(
                                      builder: (context) => SuratTugasTertunda(
                                        suratTugas: tugas,
                                        onTerimaTugas: () => _terimaTugas(tugas),
                                        hasActiveTask: hasActiveTask,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text("Lihat Detail", style: TextStyle(color: Colors.orange)),
                              )
                            ],
                          ),
                        ),
                        // BODY
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRow("Dasar", tugas.dasar),
                              _buildRow(
                                "Lokasi",
                                tugas.lokasi.isNotEmpty ? tugas.lokasi[0].namaLokasi : "-",
                              ),
                              _buildRow("Tanggal Tugas", tugas.tanggal),
                              _buildRow("Perihal", tugas.hal),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // --- SELESAI ---
            ExpansionTile(
              title: const Text("Surat Tugas Selesai", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF522E2E),),),
              leading: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _animation.value,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.circle,
                  color: Colors.blue,
                ),
              ),
              children: suratTugasSelesai.isEmpty
                  ? [_buildNotFoundText("Tidak ada surat tugas selesai saat ini")]
                  : suratTugasSelesai.map((tugas) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[800],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                tugas.noSt,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailLaporan(
                                      idSuratTugas: tugas.idSuratTugas,
                                      suratTugas: tugas,
                                      onSelesaiTugas: () {},
                                      isViewOnly: true,
                                      showDetailHasil: true,
                                      customTitle: "Surat Tugas Selesai",
                                    ),
                                  ),
                                );
                              },
                              child: const Text("Lihat Detail", style: TextStyle(color: Colors.blue)),
                            )
                          ],
                        ),
                      ),
                      // BODY
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRow("Dasar", tugas.dasar),
                            _buildRow(
                              "Lokasi",
                              tugas.lokasi.isNotEmpty ? tugas.lokasi[0].namaLokasi : "-",
                            ),
                            _buildRow("Tanggal Tugas", tugas.tanggal),
                            _buildRow("Perihal", tugas.hal),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // Tombol Sinkronisasi Data (hanya tampil jika ada data yang belum disinkronkan)
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                          try {
                            setState(() {
                              _isLoading = true;
                            });

                            final db = DatabaseHelper();
                            final userNip = authProvider.userId; // Ambil NIP pengguna

                            if (userNip == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gagal sinkronisasi: NIP pengguna tidak ditemukan.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            await db.syncUnsentData(userNip); // Teruskan NIP

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Data berhasil disinkronkan'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            await _loadSuratTugas();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal sinkronisasi: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          backgroundColor: Color(0xFF522E2E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
                        ),
                        child: Text(
                            _isLoading ? "Mengirim..." : "Sinkronisasi Data",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)
                        ),
                      ),
                      if (kDebugMode) ...[
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await DatabaseHelper().deleteDatabaseFile();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Database berhasil dihapus (Mode Debug)')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: Text("Debug: Hapus Database", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
