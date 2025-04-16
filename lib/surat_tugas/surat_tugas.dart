import 'package:flutter/material.dart';
import 'st_aktif.dart';
import 'st_tertunda.dart';
import 'st_selesai.dart';
import '../databases/db_helper.dart';
import 'detail_laporan.dart';

class SuratTugasPage extends StatefulWidget {
  const SuratTugasPage({super.key});

  @override
  _SuratTugasPageState createState() => _SuratTugasPageState();
}

class _SuratTugasPageState extends State<SuratTugasPage> {
  bool hasActiveTask = false;
  Map<String, String>? suratTugasAktif;
  List<Map<String, String>> suratTugasTertunda = [];

  @override
  void initState() {
    super.initState();
    _loadSuratTugas();
  }

  void _loadSuratTugas() async {
    final db = DatabaseHelper();
    final data = await db.getData('Surat_Tugas');
    print("Data surat tugas: $data"); // ← debug log

    setState(() {
      suratTugasTertunda = data.map((item) => item.map((key, value) => MapEntry(key, value.toString()))).toList();
    });
  }

  List<Map<String, String>> suratTugasSelesai = [];

  void _terimaTugas(Map<String, String> tugas) {
    setState(() {
      hasActiveTask = true;
      suratTugasAktif = tugas;
      suratTugasTertunda.remove(tugas);
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SuratTugasAktifPage(
          idSuratTugas: int.parse(suratTugasAktif!['id_surat_tugas']!),
          suratTugas: suratTugasAktif!,
          onSelesaiTugas: _selesaikanTugas,
        ),
      ),
    );
  }

  void _selesaikanTugas() {
    if (suratTugasAktif != null) {
      setState(() {
        hasActiveTask = false;
        suratTugasSelesai.add(suratTugasAktif!);
        suratTugasAktif = null;
      });
    }
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label (rata kiri, tapi pakai lebar tetap biar sejajar)
          SizedBox(
            width: 130, // lebar tetap supaya ":" sejajar
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.left, // ini dia yang kamu mau
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
                                "${suratTugasAktif?["no_st"] ?? "-"}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: suratTugasAktif?['status_laporan'] == 'dikirim'
                                      ? Colors.white
                                      : Color(0xFFD8F3DC),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                onPressed: () async {
                                  if (suratTugasAktif?['status_laporan'] == 'dikirim') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetailLaporan(
                                          idSuratTugas: int.parse(suratTugasAktif!['id_surat_tugas']!),
                                          suratTugas: suratTugasAktif!,
                                          onSelesaiTugas: _selesaikanTugas,
                                        ),
                                      ),
                                    );
                                  } else {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SuratTugasAktifPage(
                                          idSuratTugas: int.parse(suratTugasAktif!['id_surat_tugas']!),
                                          suratTugas: suratTugasAktif!,
                                          onSelesaiTugas: _selesaikanTugas,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      setState(() {
                                        suratTugasAktif!['status_laporan'] = 'dikirim';
                                      });
                                    }
                                  }
                                },
                              child: Text(
                                suratTugasAktif?['status_laporan'] == 'dikirim'
                                    ? "Lihat Detail"
                                    : "Buat Laporan",
                                style: TextStyle(color: suratTugasAktif?['status_laporan'] == 'dikirim'
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
                            _buildRow("Dasar", suratTugasAktif?["dasar"]),
                            _buildRow("Lokasi", suratTugasAktif?["lok"]),
                            _buildRow("Tanggal Tugas", suratTugasAktif?["tgl_tugas"]),
                            _buildRow("Perihal", suratTugasAktif?["hal"]),
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
                                "${tugas["no_st"]}",
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
                            _buildRow("Dasar", tugas["dasar"]),
                            _buildRow("Lokasi", tugas["lok"]),
                            _buildRow("Tanggal Tugas", tugas["tgl_tugas"]),
                            _buildRow("Perihal", tugas["hal"]),
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
                              "${tugas["no_st"] ?? "-"}",
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
                                    idSuratTugas: int.tryParse(tugas['id_surat_tugas'].toString()),
                                    suratTugas: tugas,
                                    onSelesaiTugas: () {}, // tidak digunakan
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
                          _buildRow("Dasar", tugas["dasar"]),
                          _buildRow("Lokasi", tugas["lok"]),
                          _buildRow("Tanggal Tugas", tugas["tgl_tugas"]),
                          _buildRow("Perihal", tugas["hal"]),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
