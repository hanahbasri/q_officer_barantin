import 'package:flutter/material.dart';
import 'form_periksa.dart';
import 'periksa_lokasi.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';

class SuratTugasAktifPage extends StatefulWidget {
  final String idSuratTugas;
  final StLengkap suratTugas;
  final VoidCallback onSelesaiTugas;

  const SuratTugasAktifPage({
    Key? key,
    required this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
  }) : super(key: key);

  @override
  State<SuratTugasAktifPage> createState() => _SuratTugasAktifPageState();
}

class _SuratTugasAktifPageState extends State<SuratTugasAktifPage> {
  bool sudahPeriksa = false;

  void _selesaikanTugas() {
    setState(() {
      sudahPeriksa = true;
    });
    widget.onSelesaiTugas(); // Trigger callback
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
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Table(
                              border: TableBorder.all(color: Colors.grey),
                              columnWidths: const {
                                0: FlexColumnWidth(), // pakai FlexColumnWidth agar fleksibel
                                1: FlexColumnWidth(),
                              },
                              children: [
                                // Header
                                const TableRow(
                                  decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          "Nama Petugas",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          "NIP Petugas",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Isi petugas
                                ...widget.suratTugas.petugas.map((petugas) {
                                  return TableRow(
                                    children: [
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Text(
                                            petugas.namaPetugas,
                                            style: const TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Text(
                                            petugas.nipPetugas,
                                            style: const TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10,),
                      _buildDetailItem("No Surat Tugas", Text(widget.suratTugas.noSt)),
                      _buildDetailItem("Dasar", Text(widget.suratTugas.dasar)),
                      _buildDetailItem("Tanggal Penugasan", Text(widget.suratTugas.tanggal)),
                      _buildDetailItem("Komoditas", Text(widget.suratTugas.komoditas.isNotEmpty ? widget.suratTugas.komoditas[0].namaKomoditas : "N/A")),
                      _buildDetailItem("Lokasi", Text(widget.suratTugas.lokasi.isNotEmpty ? widget.suratTugas.lokasi[0].namaLokasi : "N/A")),
                      _buildDetailItem("Penandatangan", Text(widget.suratTugas.namaTtd)),
                      _buildDetailItem("NIP Penandatangan", Text(widget.suratTugas.nipTtd)),
                      _buildDetailItem("Perihal", Text(widget.suratTugas.hal)),
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
                                            builder: (context) => PeriksaLokasi(idSuratTugas: widget.idSuratTugas!),
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
                                idSuratTugas: widget.idSuratTugas,
                                suratTugas: widget.suratTugas,
                                onSelesaiTugas: widget.onSelesaiTugas,
                              ),
                            ),
                          );
                          if (result == true) {
                            Navigator.pop(context, true); // balik ke SuratTugasPage, trigger refresh
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