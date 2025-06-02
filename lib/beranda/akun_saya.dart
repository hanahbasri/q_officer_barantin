import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:q_officer_barantin/main.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';

class AkunSayaPage extends StatefulWidget {
  const AkunSayaPage({super.key});

  @override
  State<AkunSayaPage> createState() => _AkunSayaPageState();
}

class _AkunSayaPageState extends State<AkunSayaPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBar = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.loadPhotoFromDB().then((_) {
      if (authProvider.userPhotoPath != null) {
        setState(() {
          _imageFile = File(authProvider.userPhotoPath!);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 220 && !_showAppBar) {
      setState(() => _showAppBar = true);
    } else if (_scrollController.offset <= 220 && _showAppBar) {
      setState(() => _showAppBar = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxHeight: 800,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.savePhotoToDB(pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih Sumber Foto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Galeri',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Kamera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              if (_imageFile != null)
                TextButton(
                  onPressed: () async {
                    setState(() => _imageFile = null);
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await authProvider.savePhotoToDB('');
                    Navigator.pop(context);
                  },
                  child: const Text('Hapus Foto',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
    });
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.brown.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: MyApp.karantinaBrown, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCopyableInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(title,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          subtitle: Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
              overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.content_copy, size: 18, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      String namaLengkap, String nip, String email, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 35,
        bottom: 32,
      ),
      color: MyApp.karantinaBrown,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: _imageFile != null
                    ? CircleAvatar(
                  radius: 48,
                  backgroundImage: FileImage(_imageFile!),
                )
                    : const CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person,
                      size: 52, color: MyApp.karantinaBrown),
                ),
              ),
              GestureDetector(
                onTap: _showImageSourceActionSheet,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        spreadRadius: 1,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: MyApp.karantinaBrown, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(namaLengkap,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('NIP: $nip',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(email,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final namaLengkap = authProvider.userFullName ?? 'Nama tidak tersedia';
    final nip = authProvider.userNip ?? 'NIP tidak tersedia';
    final email = authProvider.userEmail ?? 'Email tidak tersedia';

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor:
        _showAppBar ? MyApp.karantinaBrown : Colors.transparent,
        elevation: _showAppBar ? 4 : 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _showAppBar
            ? Text(namaLengkap,
            style: const TextStyle(color: Colors.white, fontSize: 16))
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: [
              _buildProfileHeader(namaLengkap, nip, email, context),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      (MediaQuery.of(context).padding.top + 280),
                ),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  child: Column(
                    children: [
                      _buildCopyableInfoCard(
                        icon: Icons.person_outline,
                        title: 'Nama Lengkap',
                        value: namaLengkap,
                        iconColor: Colors.blue,
                        onTap: () => _copyToClipboard(namaLengkap),
                      ),
                      _buildCopyableInfoCard(
                        icon: Icons.badge_outlined,
                        title: 'NIP',
                        value: nip,
                        iconColor: Colors.orange,
                        onTap: () => _copyToClipboard(nip),
                      ),
                      _buildCopyableInfoCard(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        value: email,
                        iconColor: Colors.green,
                        onTap: () => _copyToClipboard(email),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
