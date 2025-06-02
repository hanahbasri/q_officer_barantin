import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_officer_barantin/beranda/akun_saya.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';
import 'dart:io';
import 'package:q_officer_barantin/dialog/logout_dialog.dart';

import '../databases/db_helper.dart';
import '../models/lokasi.dart';
import '../models/st_lengkap.dart';
import '../surat_tugas/st_tertunda.dart';

const Color darkBrown = Color(0xFF522E2E);
const Color lightBackground = Color(0xFFF7F4EF);
const Color darkerText = Color(0xFF2E1C1C);

class SideBar extends StatelessWidget {
  const SideBar({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final namaLengkap = authProvider.userFullName ?? "Pengguna";
    final nipPengguna = authProvider.userNip ?? "NIP tidak tersedia";

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      backgroundColor: lightBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarHeader(
            nama: namaLengkap,
            nip: nipPengguna,
            authProvider: authProvider,
          ),
          const SizedBox(height: 12),
          _SidebarTile(
            icon: Icons.person_outline,
            title: "Akun Saya",
            iconColor: darkerText,
            textColor: darkerText,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AkunSayaPage()),
              );
            },
          ),
          _SidebarTile(
            icon: Icons.help_outline,
            title: "Tutorial Aplikasi",
            iconColor: darkerText,
            textColor: darkerText,
            onTap: () {
              _showTutorialOptions(context);
            },
          ),
          AnimatedLogoutButton(
            onTap: () => showAnimatedLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menampilkan opsi tutorial
  void _showTutorialOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Pilih Tutorial",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
              const SizedBox(height: 20),

              _TutorialOptionItem(
                title: "Surat Tugas Tertunda",
                description: "Tutorial tentang halaman detail surat tugas yang belum diterima",
                icon: Icons.assignment_outlined,
                onTap: () async {
                  Navigator.pop(context);

                  Navigator.pop(context);

                  try {
                    final db = DatabaseHelper();
                    final data = await db.getData('Surat_Tugas');

                    StLengkap? suratTugasTertunda;

                    for (var item in data) {
                      final status = item['status'] ?? '';

                      if (status == 'tertunda' || status == 'Proses') {

                        final futures = await Future.wait([
                          db.getPetugasById(item['id_surat_tugas']),
                          db.getLokasiById(item['id_surat_tugas']),
                          db.getKomoditasById(item['id_surat_tugas']),
                        ]);

                        final petugasList = (futures[0] as List).map((p) => Petugas.fromDbMap(p)).toList();
                        final lokasiList = (futures[1] as List).map((l) => Lokasi.fromDbMap(l)).toList();
                        final komoditasList = (futures[2] as List).map((k) => Komoditas.fromDbMap(k)).toList();

                        suratTugasTertunda = StLengkap.fromDbMap(
                          item,
                          petugasList,
                          lokasiList,
                          komoditasList,
                        );
                        break;
                      }
                    }

                    if (suratTugasTertunda != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SuratTugasTertunda(
                            suratTugas: suratTugasTertunda!,
                            onTerimaTugas: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ini adalah mode tutorial - tombol tidak aktif'),
                                  backgroundColor: Color(0xFF522E2E),
                                ),
                              );
                            },
                            hasActiveTask: false,
                            showTutorialImmediately: true,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tidak ada surat tugas tertunda untuk tutorial'),
                          backgroundColor: Color(0xFF522E2E),
                        ),
                      );
                    }
                  } catch (e) {
                    // Error handling
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal memuat data untuk tutorial: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

class _TutorialOptionItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _TutorialOptionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: darkBrown.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: darkBrown.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: darkBrown,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: darkBrown,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: darkBrown,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final String nama;
  final String nip;
  final AuthProvider authProvider;

  const _SidebarHeader({
    required this.nama,
    required this.nip,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = authProvider.userPhotoPath != null &&
        File(authProvider.userPhotoPath!).existsSync();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      color: darkBrown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: hasPhoto
                ? FileImage(File(authProvider.userPhotoPath!))
                : null,
            child: !hasPhoto
                ? const Icon(Icons.person, size: 36, color: darkBrown)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            nama,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            nip,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  const _SidebarTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = darkBrown,
    this.textColor = darkBrown,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: darkBrown.withOpacity(0.06),
    );
  }
}
