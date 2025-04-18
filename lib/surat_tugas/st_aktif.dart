import 'package:flutter/material.dart';
import 'form_periksa.dart';
import 'periksa_lokasi.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SuratTugasAktifPage extends StatelessWidget {
  final int? idSuratTugas;
  final Map<String, dynamic> suratTugas;
  final VoidCallback onSelesaiTugas;

  const SuratTugasAktifPage({
    Key? key,
    this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
  }) : super(key: key);

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Surat Tugas Aktif",
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF522E2E),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem("No Surat Tugas", Text(suratTugas['no_st'] ?? "")),
                      _buildDetailItem("Dasar", Text(suratTugas['dasar'] ?? "")),
                      _buildDetailItem("Nama", Text(suratTugas['nama'] ?? "")),
                      _buildDetailItem("NIP", Text(suratTugas['nip'] ?? "")),
                      _buildDetailItem("Golongan / Pangkat", Text("${suratTugas['gol']} / ${suratTugas['pangkat'] ?? ""}")),
                      _buildDetailItem("Komoditas", Text(suratTugas['komoditas'] ?? "")),
                      _buildDetailItem("Lokasi", Text(suratTugas['lok'] ?? "")),
                      _buildDetailItem("Tanggal Penugasan", Text(suratTugas['tgl_tugas'] ?? "")),
                      _buildDetailItem("Penandatangan", Text(suratTugas['ttd'] ?? "")),
                      _buildDetailItem("Perihal", Text(suratTugas['hal'] ?? "")),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Color(0xFF522E2E), width: 2),
                        ),
                        child: SizedBox(
                          height: 150,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(-6.200000, 106.816666),
                                    zoom: 14,
                                  ),
                                  zoomControlsEnabled: false,
                                  scrollGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  liteModeEnabled: true,
                                  onMapCreated: (GoogleMapController controller) {},
                                ),
                                Positioned.fill(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PeriksaLokasi(idSuratTugas: idSuratTugas!),
                                          ),
                                        );
                                      },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              Center(
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
                                idSuratTugas: idSuratTugas, // ⬅️ sekarang udah gak null
                                suratTugas: suratTugas,
                                onSelesaiTugas: onSelesaiTugas,
                              ),
                            ),
                          );
                          if (result == true) {
                            Navigator.pop(context, true); // ini ngirim balik ke SuratTugasPage
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Color(0xFFFEC559),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                          ),
                        ),
                        child: const Text(
                          "Buat Laporan Pemeriksaan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF522E2E),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
            )
          )
        );
      }
      Widget _buildDetailItem(String label, Widget value) {
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
              ),
            ),
            const Text(":", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(child: value),
          ],
        ),
      );
    }
  }