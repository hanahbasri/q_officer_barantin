import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_officer_barantin/main.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/lokasi.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'st_aktif.dart';
import 'st_masuk.dart';
import '../databases/db_helper.dart';
import '../services/auth_provider.dart';
import 'detail_laporan.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';

class SuratTugasPage extends StatefulWidget {
  const SuratTugasPage({super.key});

  @override
  SuratTugasPageState createState() => SuratTugasPageState();
}

class SuratTugasPageState extends State<SuratTugasPage> with SingleTickerProviderStateMixin {
  bool hasActiveTask = false;
  StLengkap? suratTugasAktif;
  List<StLengkap> suratTugasTertunda = [];
  List<StLengkap> suratTugasSelesai = [];
  bool _isLoading = true;
  bool _isSyncingApi = false;
  bool _isFirstLoad = true;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isFirstLoad) {
        _loadSuratTugas(syncWithApi: true); // Sync dengan API hanya saat pertama kali
        _isFirstLoad = false;
      } else {
        _loadSuratTugas(syncWithApi: false); // Load dari DB lokal untuk pemanggilan berikutnya
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //_loadSuratTugas();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuratTugas({bool syncWithApi = false}) async {
    if (!mounted) return;
    if (!syncWithApi && _isLoading && !_isSyncingApi) {
      if (kDebugMode) print('🔄 _loadSuratTugas: Load biasa sudah berjalan, melewati.');
      return;
    }
    if (syncWithApi && _isSyncingApi) {
      if (kDebugMode) print('🔄 _loadSuratTugas: Sinkronisasi API sudah berjalan, melewati.');
      return;
    }

    setState(() {
      if (syncWithApi) _isSyncingApi = true;
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userNip = authProvider.userNip;

      if (userNip == null) {
        throw Exception('NIP Pengguna tidak ditemukan');
      }

      final db = DatabaseHelper();

      if (syncWithApi) {
        if (kDebugMode) print('🔄 _loadSuratTugas: Menyinkronkan data dari API untuk NIP: $userNip');
        try {
          await db.syncSuratTugasFromApi(userNip);
          if (kDebugMode) print('✅ _loadSuratTugas: Sinkronisasi API selesai.');
        } catch (e) {
          if (kDebugMode) print('⚠️ _loadSuratTugas: Gagal sinkronisasi API, lanjut dengan data lokal. Error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal sinkronisasi dengan server: ${e.toString().substring(0, (e.toString().length > 50 ? 50 : e.toString().length))}... Cek koneksi Anda.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      final data = await db.getData('Surat_Tugas');
      if (kDebugMode) {
        print('📋 Total surat tugas di database (setelah potensi sync): ${data.length}');
      }

      StLengkap? tempPrioritasUtama; // Untuk 'dikirim' atau 'tersimpan_offline'
      StLengkap? tempPrioritasKedua;    // Untuk 'aktif'
      List<StLengkap> tempSuratTugasTertunda = [];
      List<StLengkap> tempSuratTugasSelesai = [];
      List<StLengkap> allTasksFromDb = [];

      final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day); // Tanggal hari ini tanpa jam

      for (var item in data) {
        // String currentStatus = item['status'] ?? ''; // Tidak digunakan langsung di sini
        // final idSuratTugas = item['id_surat_tugas']; // Tidak digunakan langsung di sini

        // if (kDebugMode) { // Tidak digunakan langsung di sini
        //   print('🔍 Memproses ST dari DB: $idSuratTugas, Status DB: $currentStatus'); // Tidak digunakan langsung di sini
        // } // Tidak digunakan langsung di sini

        try {
          final petugasData = (await db.getPetugasById(item['id_surat_tugas'])).map((p) => Petugas.fromDbMap(p)).toList(); //
          final lokasiData = (await db.getLokasiById(item['id_surat_tugas'])).map((l) => Lokasi.fromDbMap(l)).toList(); //
          final komoditasData = (await db.getKomoditasById(item['id_surat_tugas'])).map((k) => Komoditas.fromDbMap(k)).toList(); //
          allTasksFromDb.add(StLengkap.fromDbMap(item, petugasData, lokasiData, komoditasData)); //
        } catch (innerError) {
          if (kDebugMode) {
            print('Error building StLengkap for item ${item['id_surat_tugas']}: $innerError');
          }
        }
      }

      // Proses kategorisasi
      for (var tugas in allTasksFromDb) {
        String currentDbStatus = tugas.status; //
        DateTime? tanggalTugasDateOnly;

        try {
          if (tugas.tanggal.isNotEmpty) { //
            DateTime parsedTanggal = DateTime.parse(tugas.tanggal); //
            tanggalTugasDateOnly = DateTime(parsedTanggal.year, parsedTanggal.month, parsedTanggal.day);
          }
        } catch (e) {
          if (kDebugMode) {
            print("⚠️ Gagal parse tanggal ST ${tugas.noSt} ('${tugas.tanggal}'). Error: $e"); //
          }
        }

        // LOGIKA BARU: Filter ST Masuk yang kedaluwarsa (> 7 hari)
        if (currentDbStatus == 'tertunda' || currentDbStatus == 'Proses') { //
          bool isExpired = false;
          if (tanggalTugasDateOnly != null) {
            if (today.difference(tanggalTugasDateOnly).inDays > 7) {
              isExpired = true;
            }
          } else {
            if (kDebugMode) {
              print("🤔 ST Masuk ${tugas.noSt} tidak memiliki tanggal yang valid untuk cek kedaluwarsa atau tanggal kosong."); //
            }
            // Jika tanggal tidak valid atau kosong, kita bisa memilih untuk tidak menganggapnya kedaluwarsa
            // atau bisa juga menganggapnya kedaluwarsa tergantung kebijakan.
            // Untuk saat ini, jika tanggal tidak bisa diproses, tidak dianggap expired.
          }

          // --- AWAL BAGIAN YANG DIKOMENTARI UNTUK DEBUGGING KADALUWARSA ---
          /*
          if (isExpired) {
            if (kDebugMode) {
              print("👻 ST Masuk ${tugas.noSt} (tanggal: ${tugas.tanggal}) kedaluwarsa (>7 hari) dan akan disembunyikan (LOGIKA ASLI, SEKARANG DIKOMEN).");
            }
            if (currentDbStatus == 'Proses') {
              await db.updateStatusTugas(tugas.idSuratTugas, 'tertunda');
            }
            continue; // Jangan proses lebih lanjut untuk ST Masuk yang kedaluwarsa (LOGIKA ASLI, SEKARANG DIKOMEN)
          }
          */
          // --- AKHIR BAGIAN YANG DIKOMENTARI UNTUK DEBUGGING KADALUWARSA ---

          // Untuk debugging, kita bisa tambahkan log jika sebuah ST seharusnya expired tapi tetap diproses
          if (isExpired && kDebugMode) {
            print("🐞 DEBUG: ST Masuk ${tugas.noSt} (tanggal: ${tugas.tanggal}) SEHARUSNYA kedaluwarsa, tapi tetap diproses karena logika kadaluwarsa dikomentari.");
          }
        }

        if (currentDbStatus == 'dikirim' || currentDbStatus == 'tersimpan_offline') { //
          if (tempPrioritasUtama == null) {
            tempPrioritasUtama = tugas;
          } else {
            tempSuratTugasTertunda.add(tugas.copyWith(status: 'tertunda')); //
            if (currentDbStatus != 'tertunda') {
              await db.updateStatusTugas(tugas.idSuratTugas, 'tertunda'); //
            }
          }
        } else if (currentDbStatus == 'aktif') { //
          if (tempPrioritasKedua == null) {
            tempPrioritasKedua = tugas;
          } else {
            tempSuratTugasTertunda.add(tugas.copyWith(status: 'tertunda')); //
            if (currentDbStatus != 'tertunda') {
              await db.updateStatusTugas(tugas.idSuratTugas, 'tertunda'); //
            }
          }
        } else if (currentDbStatus == 'tertunda' || currentDbStatus == 'Proses') { //
          // Hanya ST Masuk yang tidak kedaluwarsa yang akan sampai di sini
          tempSuratTugasTertunda.add(tugas.copyWith(status: 'tertunda')); //
          if (currentDbStatus == 'Proses') { //
            await db.updateStatusTugas(tugas.idSuratTugas, 'tertunda'); //
          }
        } else if (currentDbStatus == 'selesai') { //
          tempSuratTugasSelesai.add(tugas);
        }
      }

      StLengkap? finalSuratTugasAktif;
      if (tempPrioritasUtama != null) {
        finalSuratTugasAktif = tempPrioritasUtama;
        if (tempPrioritasKedua != null) {
          tempSuratTugasTertunda.add(tempPrioritasKedua.copyWith(status: 'tertunda')); //
          if (tempPrioritasKedua.status != 'tertunda') { //
            await db.updateStatusTugas(tempPrioritasKedua.idSuratTugas, 'tertunda'); //
          }
        }
      } else if (tempPrioritasKedua != null) {
        finalSuratTugasAktif = tempPrioritasKedua;
      }

      if (finalSuratTugasAktif != null) {
        tempSuratTugasTertunda.removeWhere((st) => st.idSuratTugas == finalSuratTugasAktif!.idSuratTugas); //
      }

      if (!mounted) return;

      setState(() {
        suratTugasAktif = finalSuratTugasAktif;
        hasActiveTask = finalSuratTugasAktif != null;
        suratTugasTertunda = tempSuratTugasTertunda..sort((a, b) => (a.noSt).compareTo(b.noSt)); //
        suratTugasSelesai = tempSuratTugasSelesai..sort((a,b) => (b.tanggal).compareTo(a.tanggal)); //

        if (kDebugMode) {
          print('📊 Setelah memuat (logika prioritas & filter kedaluwarsa): hasActiveTask = $hasActiveTask');
          print('📊 Tugas aktif: ${suratTugasAktif?.noSt ?? 'Tidak ada'} (Status: ${suratTugasAktif?.status ?? 'N/A'})'); //
          print('📊 Jumlah tugas tertunda (setelah filter): ${suratTugasTertunda.length}');
          suratTugasTertunda.forEach((st) => print('   - Tertunda (UI): ${st.noSt} (Status: ${st.status}, Tanggal: ${st.tanggal})')); //
          print('📊 Jumlah tugas selesai: ${suratTugasSelesai.length}');
        }
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error memuat surat tugas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data surat tugas: ${e.toString().substring(0, (e.toString().length > 30 ? 30 : e.toString().length))}...'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (syncWithApi) _isSyncingApi = false;
        });
      }
    }
  }

  Future<void> _terimaTugas(StLengkap tugas) async {
    if (!mounted) return;

    // Tampilkan dialog loading singkat
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(MyApp.karantinaBrown),
                ),
                const SizedBox(width: 20),
                const Text("Menerima tugas...", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );

    // Beri jeda agar dialog terlihat oleh pengguna
    await Future.delayed(const Duration(milliseconds: 700)); // Sesuaikan durasi jika perlu

    if (mounted) {
      Navigator.pop(context);
    } else {
      return;
    }


    // Update status di DB SEBELUM navigasi atau setidaknya sebelum _loadSuratTugas berikutnya
    await _updateDatabaseForTerimaTugas(tugas.idSuratTugas);
    StLengkap tugasYangDiterima = tugas.copyWith(status: 'aktif');

    setState(() {
      suratTugasAktif = tugasYangDiterima;
      hasActiveTask = true;
      suratTugasTertunda.removeWhere((item) => item.idSuratTugas == tugas.idSuratTugas);
    });

    final result = await Navigator.pushReplacement(// atau push jika ingin tombol back berfungsi normal
      context,
      MaterialPageRoute(
        builder: (context) => SuratTugasAktifPage(
          idSuratTugas: tugasYangDiterima.idSuratTugas,
          suratTugas: tugasYangDiterima,
          onSelesaiTugas: _selesaikanTugas,
        ),
      ),
    );

    // Setelah kembali dari SuratTugasAktifPage (jika pushReplacement tidak sepenuhnya menghalangi ini)
    // atau jika flow-nya memungkinkan kembali ke sini.
    if (mounted) {
      // Muat ulang dari DB untuk memastikan konsistensi penuh
      _loadSuratTugas(syncWithApi: false);
    }
  }


  Future<void> _updateDatabaseForTerimaTugas(String idSuratTugas) async {
    try {
      final db = DatabaseHelper();
      if (kDebugMode) print('✅ Memperbarui database lokal: $idSuratTugas menjadi aktif');
      await db.updateStatusTugas(idSuratTugas, 'aktif');
      // Tidak perlu _loadSuratTugas() lagi di sini karena UI sudah diupdate secara optimis
      // dan navigasi sudah terjadi. Reload data akan ditangani oleh _refreshData atau load saat halaman utama muncul lagi.
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saat memperbarui status tugas di DB: $e');
      }
    }
  }


  void _selesaikanTugas() async {
    if (suratTugasAktif != null) {
      final db = DatabaseHelper();
      StLengkap tugasYangSelesai = suratTugasAktif!.copyWith(status: 'selesai');

      if (kDebugMode) print('✅ Menyelesaikan tugas secara lokal: ${suratTugasAktif!.idSuratTugas}');
      await db.updateStatusTugas(suratTugasAktif!.idSuratTugas, 'selesai');

      if (mounted) {
        setState(() {
          suratTugasSelesai.add(tugasYangSelesai);
          suratTugasAktif = null;
          hasActiveTask = false;
        });
        // Muat ulang dari DB lokal untuk memastikan konsistensi, tapi jangan block UI
        _loadSuratTugas(syncWithApi: false);
      }
    }
  }

  Future<void> _refreshData() async {
    if (kDebugMode) print('🔄 Memperbarui data pengguna...');
    // Panggil _loadSuratTugas dengan sync API true untuk refresh penuh
    await _loadSuratTugas(syncWithApi: true);
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
        backgroundColor: MyApp.karantinaBrown,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: (_isLoading || _isSyncingApi) ? null : _refreshData,
            tooltip: 'Perbarui Data',
          ),
        ],
      ),
      body: (_isLoading && suratTugasAktif == null && suratTugasTertunda.isEmpty && suratTugasSelesai.isEmpty) // Tampilkan loader utama hanya jika semua list kosong dan sedang loading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF522E2E)),
            ),
            SizedBox(height: 16),
            Text(_isSyncingApi ? 'Sinkronisasi data dari server...' : 'Memuat data surat tugas...'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          children: [
            // ---- ST MASUK ----
            ExpansionTile(
              initiallyExpanded: true, // Biar ST Masuk terbuka secara default
              title: const Text("Surat Tugas Masuk", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF522E2E),),),
              leading: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _animation.value.abs() * 0.2,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.circle,
                  color: suratTugasTertunda.isNotEmpty ? Colors.orange : Colors.grey, // Warna berdasarkan ada/tidaknya ST
                  size: 12,
                ),
              ),
              trailing: Row( // Tambahkan jumlah ST Masuk
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (suratTugasTertunda.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${suratTugasTertunda.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down),
                ],
              ),
              children: suratTugasTertunda.isEmpty
                  ? [_buildNotFoundText("Tidak ada surat tugas masuk saat ini")]
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                ),
                                onPressed: () async {
                                  // Ketika kembali dari halaman detail ST Tertunda, refresh data jika ada perubahan
                                  final result = await Navigator.push(context,
                                    MaterialPageRoute(
                                      builder: (context) => SuratTugasTertunda(
                                        suratTugas: tugas,
                                        onTerimaTugas: () => _terimaTugas(tugas),
                                        hasActiveTask: hasActiveTask,
                                      ),
                                    ),
                                  );
                                  // Jika ada hasil (misal true jika tugas diterima), refresh list
                                  if (result == true || mounted) {
                                    _loadSuratTugas(syncWithApi: false);
                                  }
                                },
                                child: const Text("Lihat Detail", style: TextStyle(color: Colors.orange)),
                              )
                            ],
                          ),
                        ),
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

            // ---- ST AKTIF ----
            ExpansionTile(
              initiallyExpanded: true,
              title: Text("Surat Tugas Aktif", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: MyApp.karantinaBrown,),),
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
                  color: hasActiveTask ? Colors.green : Colors.grey,
                  size: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasActiveTask) // Hanya tampilkan badge jika ada tugas aktif
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '1', // Selalu 1 jika ada tugas aktif
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down),
                ],
              ),
              children: hasActiveTask && suratTugasAktif != null
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
                                  overflow: TextOverflow.ellipsis,
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
                                    if (suratTugasAktif == null) return;

                                    bool refreshNeeded = false;
                                    // Jika statusnya 'dikirim' atau 'tersimpan_offline', navigasi ke DetailLaporan
                                    if (suratTugasAktif!.status == 'dikirim' || suratTugasAktif!.status == 'tersimpan_offline') {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailLaporan(
                                            idSuratTugas: suratTugasAktif!.idSuratTugas,
                                            suratTugas: suratTugasAktif!,
                                            onSelesaiTugas: _selesaikanTugas,
                                            isViewOnly: false, // Agar tombol aksi (buat laporan & selesai) muncul
                                            showDetailHasil: true,
                                          ),
                                        ),
                                      );

                                      if (result == true) refreshNeeded = true;
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
                                      if (result == true) refreshNeeded = true;
                                    }
                                  },
                                child: Text(
                                  (suratTugasAktif?.status == 'dikirim' || suratTugasAktif?.status == 'tersimpan_offline')
                                      ? "Lihat Detail" // Tombol untuk ST yang sudah ada laporannya
                                      : "Buat Laporan", // Tombol untuk ST yang belum ada laporannya
                                  style: TextStyle(color: (suratTugasAktif?.status == 'dikirim' || suratTugasAktif?.status == 'tersimpan_offline')
                                      ? Colors.green // Warna untuk "Lihat Detail"
                                      : const Color(0xFF1B4332)), // Warna untuk "Buat Laporan"
                                )  ),
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

            // --- SELESAI ---
            ExpansionTile(
              title: const Text("Surat Tugas Selesai", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: MyApp.karantinaBrown,),),
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
                  color: suratTugasSelesai.isNotEmpty ? Colors.blue : Colors.grey,
                  size: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (suratTugasSelesai.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${suratTugasSelesai.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down),
                ],
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
                            final userNip = authProvider.userId;

                            if (userNip == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gagal sinkronisasi: NIP pengguna tidak ditemukan.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            await db.syncUnsentData(userNip);

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
