import 'dart:convert';
import 'package:flutter/material.dart';
import '../databases/db_helper.dart';
import 'package:q_officer_barantin/additional/tanggal.dart';

class HasilPeriksaCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final PageController pageController;
  final bool canTap;
  final bool showSync;
  final VoidCallback? onTap;
  final Future<void> Function()? onSyncPressed;

  const HasilPeriksaCard({
    super.key,
    required this.item,
    required this.pageController,
    this.canTap = false,
    this.showSync = false,
    this.onTap,
    this.onSyncPressed,
  });

  @override
  State<HasilPeriksaCard> createState() => _HasilPeriksaCardState();
}

class _HasilPeriksaCardState extends State<HasilPeriksaCard> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTap: widget.canTap ? widget.onTap : null,
      child: Card(
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Container(
              decoration: BoxDecoration(
                color: Colors.brown[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['nama_lokasi'] ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(formatTanggal(item['tgl_periksa'] ?? ''), style: const TextStyle(color: Colors.white),)
                ],
              ),
            ),

            // FOTO & DETAIL
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: DatabaseHelper().getImageFromDatabase(item['id_pemeriksaan']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                        } else if (snapshot.hasError || snapshot.data!.isEmpty) {
                          return const SizedBox(height: 100, child: Center(child: Text("Tidak ada foto")));
                        }
                        final fotoList = snapshot.data!;
                        return SizedBox(
                          height: 100,
                          child: PageView.builder(
                            controller: widget.pageController,
                            itemCount: fotoList.length,
                            itemBuilder: (context, index) {
                              final bytes = base64Decode(fotoList[index]['foto'] as String);
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(bytes, fit: BoxFit.cover),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Komoditas", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(item['nama_komoditas'] ?? '-'),
                        const SizedBox(height: 8),
                        const Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(item['temuan'] ?? '-'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showSync)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 12),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: OutlinedButton.icon(
                    onPressed: item['syncdata'] == 1 || _isSyncing
                        ? null
                        : () async {
                      setState(() => _isSyncing = true);
                      if (widget.onSyncPressed != null) await widget.onSyncPressed!();
                      setState(() => _isSyncing = false);
                    },
                    icon: _isSyncing
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.brown),
                        )
                        : Icon(
                      item['syncdata'] == 1 ? Icons.check_circle : Icons.sync,
                      color: Colors.brown,
                    ),
                    label: Text(
                      _isSyncing
                          ? 'Menyinkron...'
                          : item['syncdata'] == 1
                          ? 'Telah Sinkron'
                          : 'Sinkron Sekarang',
                      style: const TextStyle(color: Colors.brown),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.brown),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}