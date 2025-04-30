import 'package:flutter/material.dart';
import 'st_aktif.dart';
import 'st_tertunda.dart';
import '../databases/db_helper.dart';
import 'detail_laporan.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';

class SuratTugasPage extends StatefulWidget {
  const SuratTugasPage({super.key});

  @override
  _SuratTugasPageState createState() => _SuratTugasPageState();
}

class _SuratTugasPageState extends State<SuratTugasPage> {
  bool hasActiveTask = false;
  bool _isLoading = false;
  StLengkap? suratTugasAktif;
  List<StLengkap> suratTugasTertunda = [];
  List<StLengkap> suratTugasSelesai = [];

  @override
  void initState() {
    super.initState();
    _loadSuratTugas();
  }

  Future<void> _loadSuratTugas() async {
    try {
      final db = DatabaseHelper();
      final data = await db.getData('Surat_Tugas');

      List<StLengkap> tertunda = [];
      StLengkap? aktif;
      List<StLengkap> selesai = [];

      for (var item in data) {
        final status = item['status'] ?? '';

        final futures = await Future.wait([
          db.getPetugasById(item['id_surat_tugas']),
          db.getLokasiById(item['id_surat_tugas']),
          db.getKomoditasById(item['id_surat_tugas']),
        ]);

        final tugas = StLengkap.fromMap(
          item,
          futures[0] as List<Map<String, dynamic>>,
          futures[1] as List<Map<String, dynamic>>,
          futures[2] as List<Map<String, dynamic>>,
        );

        if (status == 'aktif') {
          aktif = tugas;
        } else if (status == 'tertunda') {
          tertunda.add(tugas);
        } else if (status == 'selesai') {
          selesai.add(tugas);
        }
      }

      if (!mounted) return;

      setState(() {
        suratTugasAktif = aktif;
        hasActiveTask = aktif != null;
        suratTugasTertunda = tertunda;
        suratTugasSelesai = selesai;
      });
    } catch (e) {
      print('Error loading surat tugas: $e');
      if (!mounted) return;
      setState(() {
        suratTugasAktif = null;
        hasActiveTask = false;
        suratTugasTertunda = [];
        suratTugasSelesai = [];
      });
    }
  }

  Future<void> _terimaTugas(StLengkap tugas) async {
    setState(() => _isLoading = true); // Mulai loading

    try {
      final db = DatabaseHelper();
      await db.updateStatusTugas(tugas.idSuratTugas, 'aktif');

      await _loadSuratTugas(); // Tunggu surat tugas aktif selesai dimuat

      if (suratTugasAktif == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat surat tugas aktif')),
        );
        return;
      }

      if (!mounted) return;

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
      print('Error terima tugas: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menerima tugas')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Selesai loading
      }
    }
  }

  void _selesaikanTugas() async {
    if (suratTugasAktif != null) {
      final db = DatabaseHelper();
      await db.updateStatusTugas(suratTugasAktif!.idSuratTugas, 'selesai');
      _loadSuratTugas();
    }
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
          // Value
          Expanded(
            child: Text(value ?? ""),
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
      ),
      body: ListView(
        children: [
          ExpansionTile(
            title: const Text("Surat Tugas Aktif", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            leading: Icon(Icons.circle, color: Colors.green),
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
                                "${suratTugasAktif?.noSt ?? "-"}",
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
                                      setState(() {
                                        suratTugasAktif = suratTugasAktif!.copyWith(status: 'dikirim');
                                      });
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
                : [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Image.asset('images/not_found.png', height: 100, width: 100),
                    const SizedBox(height: 10),
                    const Text(
                      "Tidak ada surat tugas aktif saat ini",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          ExpansionTile(
            leading: Icon(Icons.circle, color: Colors.orange),
            title: const Text("Surat Tugas Tertunda", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            children: suratTugasTertunda.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Image.asset('images/not_found.png', height: 100, width: 100),
                        const SizedBox(height: 10),
                        const Text("Tidak ada surat tugas tertunda saat ini",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ]
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
                                "${tugas.noSt}",
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

          ExpansionTile(
            leading: Icon(Icons.circle, color: Colors.blue),
            title: const Text("Surat Tugas Selesai", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            children: suratTugasSelesai.isEmpty
                ? [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Image.asset('images/not_found.png', height: 100, width: 100),
                    const SizedBox(height: 10),
                    const Text("Tidak ada surat tugas selesai saat ini",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ]
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
                              "${tugas.noSt ?? "-"}",
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
                                    idSuratTugas: tugas.idSuratTugas, // ✅ gunakan ID dari data
                                    suratTugas: tugas,
                                    onSelesaiTugas: () {}, // boleh kosong di ST selesai
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
          Center(
            child: ElevatedButton(
              onPressed: () async {
                await DatabaseHelper().deleteDatabaseFile();
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Color(0xFF522E2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
              ),
              child: Text("Kirim", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
