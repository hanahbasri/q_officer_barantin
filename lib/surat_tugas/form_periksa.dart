import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../databases/db_helper.dart';
import 'detail_laporan.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'dart:convert';
import 'package:q_officer_barantin/models/hasil_pemeriksaan.dart';

class FormPeriksa extends StatefulWidget {
  final StLengkap suratTugas;
  final String idSuratTugas;
  final VoidCallback onSelesaiTugas;

  const FormPeriksa({
    Key? key,
    required this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
  }) : super(key: key);

  @override
  _FormPeriksaState createState() => _FormPeriksaState();
}

class _FormPeriksaState extends State<FormPeriksa> {
  final _formKey = GlobalKey<FormState>();
  final uuid = Uuid();
  late String idPemeriksaan;
  List<Map<String, dynamic>> lokasiList = [];

  String? selectedTarget;
  String? selectedTemuan;
  String? selectedLokasiId;
  String? selectedLokasiName;
  String? selectedKomoditasId;
  String? selectedKomoditasName;
  double? latitude;
  double? longitude;
  Position? devicePosition;
  String? waktuAmbilPosisi;
  String? selectedKomoditas;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _metodeController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    idPemeriksaan = uuid.v4();
    ambilPosisiAwal();
  }

  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }


  Future<void> ambilPosisiAwal() async {
    final granted = await requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Izin lokasi diperlukan untuk mengambil posisi")),
      );
      return;
    }

    try {
      final db = DatabaseHelper();
      final posisi = await db.getLocation();
      if (posisi != null) {
        setState(() {
          devicePosition = posisi;
          latitude = posisi.latitude;
          longitude = posisi.longitude;
          waktuAmbilPosisi = DateTime.now().toIso8601String();
        });

        if (!mounted) return;
        print("Lokasi berhasil: lat=$latitude, long=$longitude");
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❗ Gagal mengambil lokasi")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> pickImages(BuildContext context, ImageSource source, {bool isMulti = false}) async {
    const maxTotalSizeInBytes = 2 * 1024 * 1024;
    List<XFile> tempImages = [];

    if (isMulti) {
      final List<XFile>? selectedImages = await _picker.pickMultiImage();
      if (selectedImages != null && selectedImages.isNotEmpty) {
        tempImages = selectedImages;
      } else {
        return;
      }
    } else {
      final XFile? singleImage = await _picker.pickImage(source: source, imageQuality: 15);
      if (singleImage != null) {
        tempImages = [singleImage];
      } else {
        return;
      }
    }

    int totalSize = 0;

    for (var image in tempImages) {
      final file = File(image.path);
      final bytes = await file.readAsBytes();

      totalSize += bytes.length;

      if (totalSize > maxTotalSizeInBytes) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Total ukuran gambar melebihi 2MB')),
        );
        return;
      }

      await DatabaseHelper().getImagetoDatabase(bytes, idPemeriksaan);
    }

    setState(() {});
  }

  void _handleSubmit(BuildContext context) async {
    if (_formKey.currentState!.validate() &&
        selectedLokasiId != null &&
        selectedTarget != null &&
        selectedTemuan != null &&
        selectedKomoditasId != null) {

      final hasil = HasilPemeriksaan(
        idPemeriksaan: idPemeriksaan,
        idSuratTugas: widget.idSuratTugas,
        idKomoditas: selectedKomoditasId!,
        namaKomoditas: selectedKomoditasName!,
        idLokasi: selectedLokasiId!,
        namaLokasi: selectedLokasiName!,
        lat: latitude?.toString() ?? '',
        long: longitude?.toString() ?? '',
        target: selectedTarget!,
        metode: _metodeController.text,
        temuan: selectedTemuan!,
        catatan: _catatanController.text,
        tanggal: waktuAmbilPosisi ?? DateTime.now().toIso8601String(),
      );

      await DatabaseHelper().insertHasilPemeriksaan(hasil);

      _formKey.currentState!.reset();
      _metodeController.clear();
      _catatanController.clear();

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Berhasil Dikirim"),
          content: const Text("Hasil pemeriksaan berhasil dikirim!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DetailLaporan(
            idSuratTugas: widget.suratTugas.idSuratTugas,
            suratTugas: widget.suratTugas,
            onSelesaiTugas: widget.onSelesaiTugas,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap lengkapi seluruh isian")),
      );
    }
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => Wrap(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Sumber Foto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: "Kamera",
                      onTap: () {
                        Navigator.pop(context);
                        pickImages(context, ImageSource.camera);

                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: "Galeri",
                      onTap: () {
                        Navigator.pop(context);
                        pickImages(context, ImageSource.gallery, isMulti: true);
                      },
                    ),
                  ],
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
    return Scaffold(
      appBar: AppBar(title: const Text("Form Pemeriksaan")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  "Lokasi",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: DatabaseHelper().getLokasiById(widget.idSuratTugas),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Text('Tidak ada lokasi tersedia');
                    }

                    List<Map<String, dynamic>> lokasiList = snapshot.data!;
                    return DropdownButtonFormField<String>(
                      value: selectedLokasiName,
                      onChanged: (String? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          selectedLokasiName = newValue;
                          final selected = lokasiList.firstWhere(
                                (lok) => lok['nama_lokasi'] == newValue,
                            orElse: () => {'id_lokasi': null},
                          );
                          selectedLokasiId = selected['id_lokasi']?.toString() ?? '';
                        });
                      },
                      items: lokasiList
                          .where((lok) => lok['nama_lokasi'] != null)
                          .map<DropdownMenuItem<String>>((lokasi) {
                        final namaLokasi = lokasi['nama_lokasi'] ?? 'Tidak diketahui';
                        return DropdownMenuItem<String>(
                          value: namaLokasi,
                          child: Text(namaLokasi),
                        );
                      }).toList(),
                      decoration: const InputDecoration(
                        hintText: 'Pilih Lokasi',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? "Wajib pilih lokasi" : null,
                    );
                  },
                ),

              SizedBox(height: 16),
              Text("Target / Sasaran", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownSearch<String>(
                items: (filter, _) => ["Gudang A", "Gudang B", "Kantor Pusat", "Cabang Jakarta", "Cabang Bandung"],
                onChanged: (value) => setState(() => selectedTarget = value),
                selectedItem: selectedTarget,
                validator: (value) => selectedTarget == null ? "Wajib diisi" : null,
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(border: OutlineInputBorder()),
                ),
                popupProps: PopupProps.menu(showSearchBox: true),
              ),
              SizedBox(height: 16),

              Text("Metode", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _metodeController,
                validator: (value) => value!.isEmpty ? "Wajib diisi" : null,
                decoration: InputDecoration(border: OutlineInputBorder()),
              ),
              SizedBox(height: 16),

              Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownSearch<String>(
                items: (filter, _) => ["Kerusakan Barang", "Kelebihan Stok", "Kekurangan Stok", "Barang Kadaluarsa"],
                onChanged: (value) => setState(() => selectedTemuan = value),
                selectedItem: selectedTemuan,
                validator: (value) => selectedTemuan == null ? "Wajib diisi" : null,
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(border: OutlineInputBorder()),
                ),
                popupProps: PopupProps.menu(showSearchBox: true),
              ),
              SizedBox(height: 16),

                Text(
                  "Komoditas",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: DatabaseHelper().getKomoditasById(widget.idSuratTugas),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Text('Tidak ada komoditas tersedia');
                    }

                    List<Map<String, dynamic>> komoditasList = snapshot.data!;
                    return DropdownButtonFormField<String>(
                      value: selectedKomoditasName,
                      onChanged: (String? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          selectedKomoditasName = newValue;
                          final selected = komoditasList.firstWhere(
                                (kom) => kom['nama_komoditas'] == newValue,
                            orElse: () => {'id_komoditas': null},
                          );
                          selectedKomoditasId = selected['id_komoditas']?.toString() ?? '';
                        });
                      },
                      items: komoditasList
                          .where((kom) => kom['nama_komoditas'] != null)
                          .map<DropdownMenuItem<String>>((komoditas) {
                        final namaKomoditas = komoditas['nama_komoditas'] ?? 'Tidak diketahui';
                        return DropdownMenuItem<String>(
                          value: namaKomoditas,
                          child: Text(namaKomoditas),
                        );
                      }).toList(),
                      decoration: const InputDecoration(
                        hintText: 'Pilih Komoditas',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? "Wajib diisi" : null,
                    );
                  },
                ),

              SizedBox(height: 16),

              Text("Catatan", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _catatanController,
                decoration: InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text("Dokumentasi"),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: DatabaseHelper().getImageFromDatabase(idPemeriksaan),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text("Belum ada foto");
                    }
                    final fotoList = snapshot.data!;

                    return SizedBox(
                      height: 150,
                      child: PageView.builder(
                        itemCount: fotoList.length,
                        controller: PageController(viewportFraction: 0.8),
                        itemBuilder: (context, index) {
                          final base64Str = fotoList[index]['foto'] as String;
                          print("Base64 foto [$index]: ${base64Str.substring(0, 30)}...");
                          final bytes = base64Decode(base64Str);
                          return GestureDetector(
                            onTap: () => showImagePreview(context, bytes),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(bytes, fit: BoxFit.cover),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                ElevatedButton.icon(
                icon: Icon(Icons.upload),
                label: const Text("Upload Foto"),
                onPressed: () => _showImagePicker(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _handleSubmit(context),
                child: const Text("Kirim"),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          child: Icon(icon, color: const Color(0xFF522E2E), size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

void showImagePreview(BuildContext context, Uint8List imageBytes) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: InteractiveViewer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(imageBytes),
        ),
      ),
    ),
  );
}