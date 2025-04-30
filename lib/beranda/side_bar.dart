import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_officer_barantin/beranda/akun_saya.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';
import 'dart:io';

const Color darkBrown = Color(0xFF522E2E);
const Color lightBackground = Color(0xFFF7F4EF);
const Color darkerText = Color(0xFF2E1C1C);

class SideBar extends StatelessWidget {
  const SideBar({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final namaLengkap = authProvider.userFullName ?? "Pengguna";
    final nipPengguna = authProvider.userId ?? "NIP tidak tersedia";

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
            icon: Icons.logout_rounded,
            title: "Keluar",
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, size: 48, color: darkBrown),
            const SizedBox(height: 16),
            const Text(
              'Keluar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkBrown),
            ),
            const SizedBox(height: 8),
            const Text(
              'Apakah Anda yakin ingin keluar dari akun?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: darkBrown,
                    side: const BorderSide(color: darkBrown),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tidak'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBrown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await authProvider.logout();
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                  child: const Text('Ya'),
                ),
              ],
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
