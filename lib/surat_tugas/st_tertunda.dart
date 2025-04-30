import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:flutter/material.dart';
import 'periksa_lokasi.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SuratTugasTertunda extends StatefulWidget {
  final Map<String, String> suratTugas;
  final Function onTerimaTugas;
  final bool hasActiveTask;

  const SuratTugasTertunda({
    super.key,
    required this.suratTugas,
    required this.onTerimaTugas,
    required this.hasActiveTask,
  });

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
                      _buildDetailItem("No Surat Tugas", Text(widget.suratTugas['no_st'] ?? "")),
                      _buildDetailItem("Dasar", Text(widget.suratTugas['dasar'] ?? "")),
                      _buildDetailItem("Nama", Text(widget.suratTugas['nama'] ?? "")),
                      _buildDetailItem("NIP", Text(widget.suratTugas['nip'] ?? "")),
                      _buildDetailItem("Golongan / Pangkat",
                        Text("${widget.suratTugas['gol']} / ${widget.suratTugas['pangkat'] ?? ""}"),
                      ),
                      _buildDetailItem("Komoditas", Text(widget.suratTugas['komoditas'] ?? "")),
                      _buildDetailItem("Lokasi", Text(widget.suratTugas['lok'] ?? "")),
                      _buildDetailItem("Tanggal Penugasan", Text(widget.suratTugas['tgl_tugas'] ?? "")),
                      _buildDetailItem("Penandatangan", Text(widget.suratTugas['ttd'] ?? "")),
                      _buildDetailItem("Perihal", Text(widget.suratTugas['hal'] ?? "")),
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
                                            MaterialPageRoute(builder: (context) => PeriksaLokasi(idSuratTugas: int.parse(widget.suratTugas['id_surat_tugas']!)),
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
                          onTap: () async {
                            final link = widget.suratTugas['link'];
                            if (kDebugMode) {
                              print("🧾 LINK DITERIMA: $link");
                            }

                            if (link == null || link.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link PDF tidak tersedia')),
                              );
                              return;
                            }

                            final url = 'https://cert.karantinaindonesia.go.id/print_cert/penugasan/k22/$link';
                            if (kDebugMode) {
                              print("🌐 URL: $url");
                            }

                            try {
                              final success = await launchUrlString(url);
                              if (!success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal membuka link PDF.')),
                                );
                              }
                            } catch (e) {
                              if (kDebugMode) {
                                print('❌ ERROR saat buka URL: $e');
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Terjadi kesalahan saat membuka link')),
                              );
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                "Unduh PDF Surat Tugas",
                                style: TextStyle(
                                  fontSize: 14,
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
                        : () {
                      widget.onTerimaTugas();
                      Navigator.pop(context);
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
          const Icon(Icons.cancel_outlined, size: 48, color: Color(0xFF522E2E)),
          const SizedBox(height: 16),
          const Text(
            'Gagal Terima Tugas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF522E2E)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Anda masih memiliki surat tugas yang aktif.\nSilakan selesaikan terlebih dahulu.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF522E2E),
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
