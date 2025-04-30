import 'package:flutter/material.dart';
import 'periksa_lokasi.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';

class SuratTugasTertunda extends StatefulWidget {
  final StLengkap suratTugas;
  final Function onTerimaTugas;
  final bool hasActiveTask;

  const SuratTugasTertunda({
    Key? key,
    required this.suratTugas,
    required this.onTerimaTugas,
    required this.hasActiveTask,
  }) : super(key: key);

  @override
  _SuratTugasTertundaState createState() => _SuratTugasTertundaState();
}

class _SuratTugasTertundaState extends State<SuratTugasTertunda> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Surat Tugas Tertunda",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      _buildDetailItem("No Surat Tugas", Text(widget.suratTugas.noSt)),
                      _buildDetailItem("Dasar", Text(widget.suratTugas.dasar)),
                      _buildDetailItem(
                        "Petugas",
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SizedBox(
                            height: (widget.suratTugas.petugas.length > 2 ? 150 : widget.suratTugas.petugas.length * 15),
                            child: ListView.builder(
                              itemCount: widget.suratTugas.petugas.length,
                              itemBuilder: (context, index) {
                                final petugas = widget.suratTugas.petugas[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        petugas.namaPetugas,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        petugas.nipPetugas,
                                        style: TextStyle(fontSize: 10, color: Colors.black),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      _buildDetailItem("Tanggal Penugasan", Text(widget.suratTugas.tanggal)),
                      _buildDetailItem("Komoditas", Text(widget.suratTugas.komoditas.isNotEmpty ? widget.suratTugas.komoditas[0].namaKomoditas : "N/A")),
                      _buildDetailItem("Lokasi", Text(widget.suratTugas.lokasi.isNotEmpty ? widget.suratTugas.lokasi[0].namaLokasi : "N/A")),
                      _buildDetailItem("Penandatangan", Text(widget.suratTugas.namaTtd)),
                      _buildDetailItem("NIP Penandatangan", Text(widget.suratTugas.nipTtd)),
                      _buildDetailItem("Perihal", Text(widget.suratTugas.hal)),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF522E2E), width: 2),
                        ),
                        child: SizedBox(
                          height: 150,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: const CameraPosition(
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
                                            MaterialPageRoute(builder: (context) => PeriksaLokasi(
                                              idSuratTugas: widget.suratTugas.idSuratTugas,
                                            ),
                                        ));
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // Aksi saat diklik, misalnya unduh file
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                "Unduh PDF Permohonan",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 250,
                  child: ElevatedButton(
                    onPressed: widget.hasActiveTask
                        ? () => _showUnavailable(context)
                        : () async {
                      await widget.onTerimaTugas(); // Tunggu proses terima tugas selesai
                      if (context.mounted) {
                        Navigator.pop(context); // Setelah itu baru pop
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF522E2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                        side: const BorderSide(color: Color(0xFF522E2E), width: 2),
                      ),
                    ),
                    child: const Text(
                      "Terima Tugas",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
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

void _showUnavailable(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel, size: 48, color: Colors.brown[700]),
          const SizedBox(height: 16),
          Text(
            'Gagal Terima Surat Tugas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown[800]),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mohon maaf, Anda tidak dapat menerima surat tugas sebelum menyelesaikan surat tugas aktif.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    ),
  );
}