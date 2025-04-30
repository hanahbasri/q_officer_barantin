import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:q_officer_barantin/databases/db_helper.dart';

class SuratTugasSelesai extends StatefulWidget {
  final Map<String, dynamic> hasilPemeriksaan;

  const SuratTugasSelesai({Key? key, required this.hasilPemeriksaan}) : super(key: key);

  @override
  State<SuratTugasSelesai> createState() => _SuratTugasSelesaiState();
}

class _SuratTugasSelesaiState extends State<SuratTugasSelesai> {
  List<String> base64List = [];

  @override
  void initState() {
    super.initState();
    loadFoto();
  }

  Future<void> loadFoto() async {
    final id = widget.hasilPemeriksaan['id_pemeriksaan'];
    final db = DatabaseHelper();
    final list = await db.getImageBase64List(id);
    setState(() {
      base64List = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasil = widget.hasilPemeriksaan;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Pemeriksaan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (base64List.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      itemCount: base64List.length,
                      controller: PageController(viewportFraction: 0.9),
                      itemBuilder: (context, index) {
                        final bytes = base64Decode(base64List[index]);
                        return GestureDetector(
                          onTap: () => _showImagePreview(context, bytes),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(bytes, fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const Text("Belum ada foto"),
                const SizedBox(height: 16),
                _buildRow("Lokasi", hasil['nama_lokasi']),
                _buildRow("Target / Sasaran", hasil['target']),
                _buildRow("Metode", hasil['metode']),
                _buildRow("Komoditas", hasil['nama_komoditas']),
                _buildRow("Temuan", hasil['temuan']),
                _buildRow("Catatan", hasil['catatan']),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Text(" : "),
          Expanded(flex: 5, child: Text(value ?? "-")),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(imageBytes),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
        ),
      ),
    );
  }
}