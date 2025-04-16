import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image;
  final picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Akun Saya", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showImagePicker,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _image != null ? FileImage(_image!) : null,
                child: _image == null
                    ? Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(height: 20),
            Text("Nama Lengkap", style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              decoration: InputDecoration(
                hintText: "Cth: Abdullah Rasyid",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            Text("Username", style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              decoration: InputDecoration(
                hintText: "Masukkan tempat dan tanggal lahir Anda",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(labelText: 'No. Handphone'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}
