import 'dart:io';
import 'package:flutter/material.dart';

class SuratTugasSelesai extends StatelessWidget {
  final Map<String, dynamic> hasilPemeriksaan;

  SuratTugasSelesai({required this.hasilPemeriksaan});

  @override
  Widget build(BuildContext context) {
    // Ambil foto dari DB
    final fotoString = hasilPemeriksaan['fotoPaths'] as String?;
    final imagePaths = fotoString != null && fotoString.isNotEmpty
        ? fotoString.split('|')
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text("Hasil Pemeriksaan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF522E2E),
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
                if (imagePaths.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      itemCount: imagePaths.length,
                      controller: PageController(viewportFraction: 0.9),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showImagePreview(context, imagePaths[index]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(imagePaths[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(height: 16),

                // Tabel hasil pemeriksaan
                _buildRow("Lokasi", hasilPemeriksaan['lokasi']),
                _buildRow("Target / Sasaran", hasilPemeriksaan['target']),
                _buildRow("Metode", hasilPemeriksaan['metode']),
                _buildRow("Komoditas", hasilPemeriksaan['komoditas']),
                _buildRow("Temuan", hasilPemeriksaan['temuan']),
                _buildRow("Catatan", hasilPemeriksaan['catatan']),
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
          Expanded(flex: 3, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold))),
          Text(" : "),
          Expanded(flex: 5, child: Text(value ?? "-")),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(imagePath)),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Tutup"),
            ),
          ],
        ),
      ),
    );
  }
}