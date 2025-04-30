import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../databases/db_helper.dart';
import 'detail_laporan.dart';

class FormPeriksa extends StatefulWidget {
  final int? idSuratTugas;
  final Map<String, dynamic> suratTugas;
  final VoidCallback onSelesaiTugas;

  const FormPeriksa({
    super.key,
    this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
  });

  @override
  State<FormPeriksa> createState() => _FormPeriksaState();
}

class _FormPeriksaState extends State<FormPeriksa> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String? selectedTarget;
  String? selectedTemuan;
  String? selectedLokasi;
  String? selectedKomoditas;
  List<XFile>? _images = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _metodeController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  late AnimationController _searchController;
  late Animation<Offset> _searchOffset;

  @override
  void initState() {
    super.initState();
    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _searchOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.05, 0),
    ).animate(CurvedAnimation(
      parent: _searchController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> pickImages(BuildContext context, ImageSource source, {bool isMulti = false}) async {
    const maxTotalSizeInBytes = 2 * 1024 * 1024; // 2MB
    List<XFile> tempImages = [];

    if (isMulti) {
      final List<XFile> selectedImages = await _picker.pickMultiImage();
      if (selectedImages.isNotEmpty) {
        tempImages = [...?_images, ...selectedImages];
      } else {
        return;
      }
    } else {
      final XFile? singleImage = await _picker.pickImage(source: source, imageQuality: 15);
      if (singleImage != null) {
        tempImages = [...?_images, singleImage];
      } else {
        return;
      }
    }

    int totalSize = 0;
    for (var image in tempImages) {
      final file = File(image.path);
      totalSize += await file.length();
    }

    if (totalSize > maxTotalSizeInBytes) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total ukuran gambar melebihi 2MB'),
        ),
      );
      return;
    }

    setState(() {
      _images = tempImages;
    });
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

  Future<void> _showSuccessPopup(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Color(0xFFFBF2F2),
          contentPadding: EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 60, color: Color(0xFF522E2E)),
              SizedBox(height: 10),
              Text(
                "Berhasil Dikirim",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF522E2E)),
              ),
              SizedBox(height: 8),
              Text(
                "Hasil pemeriksaan kesehatan telah berhasil dikirim!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailLaporan(
                          idSuratTugas: widget.idSuratTugas ?? widget.suratTugas['id_surat_tugas'] as int,
                          suratTugas: widget.suratTugas,
                          onSelesaiTugas: widget.onSelesaiTugas,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF522E2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Periksa Hasil", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormPeriksa(
                          idSuratTugas: widget.idSuratTugas,
                          suratTugas: widget.suratTugas,
                          onSelesaiTugas: widget.onSelesaiTugas,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEC559),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Isi Form Kembali", style: TextStyle(color: Color(0xFF522E2E))),
                ),
              ),
            ],
          ),
        );
      },

    );
  }

  void _handleSubmit(BuildContext context) async {
    if (_formKey.currentState!.validate() &&
        selectedLokasi != null &&
        selectedTarget != null &&
        selectedTemuan != null &&
        selectedKomoditas != null &&
        _images!.isNotEmpty) {

      final fotoPaths = _images!.map((e) => e.path).toList().join('|');
      final now = DateTime.now();

      final data = {
        'id_surat_tugas': widget.idSuratTugas ?? widget.suratTugas['id_surat_tugas'] as int,
        'lokasi': selectedLokasi!,
        'target': selectedTarget!,
        'metode': _metodeController.text,
        'temuan': selectedTemuan!,
        'komoditas': selectedKomoditas!,
        'catatan': _catatanController.text,
        'fotoPaths': fotoPaths,
        'tgl_periksa': now.toIso8601String(),
      };

      await DatabaseHelper().insertPeriksa(data);

      // Reset form dan state setelah berhasil simpan
      _formKey.currentState!.reset();
      _metodeController.clear();
      _catatanController.clear();
      setState(() {
        selectedLokasi = null;
        selectedTarget = null;
        selectedTemuan = null;
        selectedKomoditas = null;
        _images = [];
      });

      await _showSuccessPopup(context);
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Harap lengkapi seluruh isian laporan pemeriksaan!")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Form Pemeriksaan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Lokasi", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownSearch<String>(
                items: (filter, _) => ["Jawa Barat", "Gudang B", "Kantor Pusat", "Cabang Jakarta", "Cabang Bandung"],
                onChanged: (value) => setState(() => selectedLokasi = value),
                selectedItem: selectedLokasi,
                validator: (value) => selectedLokasi == null ? "Wajib diisi" : null,
                decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )
                ),
                popupProps: PopupProps.dialog(
                  showSearchBox: true,
                  dialogProps: DialogProps(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      prefixIcon: _buildAnimatedSearchIcon(),
                      hintText: 'Cari...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF522E2E)),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              Text("Target / Sasaran", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownSearch<String>(
                items: (filter, _) => ["Gudang A", "Gudang B", "Kantor Pusat", "Cabang Jakarta", "Cabang Bandung"],
                onChanged: (value) => setState(() => selectedTarget = value),
                selectedItem: selectedTarget,
                validator: (value) => selectedTarget == null ? "Wajib diisi" : null,
                decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )
                ),
                popupProps: PopupProps.dialog(
                  showSearchBox: true,
                  dialogProps: DialogProps(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      prefixIcon: _buildAnimatedSearchIcon(),
                      hintText: 'Cari...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF522E2E)),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              Text("Metode", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _metodeController,
                validator: (value) => value!.isEmpty ? "Wajib diisi" : null,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  )
              ),
              SizedBox(height: 16),

              Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownSearch<String>(
                items: (filter, _) => ["Kerusakan Barang", "Kelebihan Stok", "Kekurangan Stok", "Barang Kadaluarsa"],
                onChanged: (value) => setState(() => selectedTemuan = value),
                selectedItem: selectedTemuan,
                validator: (value) => selectedTemuan == null ? "Wajib diisi" : null,
                decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )
                ),
                popupProps: PopupProps.dialog(
                  showSearchBox: true,
                  dialogProps: DialogProps(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      prefixIcon: _buildAnimatedSearchIcon(),
                      hintText: 'Cari...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF522E2E)),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              Text("Komoditas", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownSearch<String>(
                items: (filter, _) => ["Hewan", "Ikan", "Tumbuhan"],
                onChanged: (value) => setState(() => selectedKomoditas = value),
                selectedItem: selectedKomoditas,
                validator: (value) => selectedKomoditas == null ? "Wajib diisi" : null,
                decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )
                ),
                popupProps: PopupProps.dialog(
                  showSearchBox: true,
                  dialogProps: DialogProps(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      prefixIcon: _buildAnimatedSearchIcon(),
                      hintText: 'Cari...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF522E2E)),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              Text("Catatan", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _catatanController,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF522E2E), width: 1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  )
              ),
              SizedBox(height: 16),

              Text("Dokumentasi", style: TextStyle(fontWeight: FontWeight.bold)),
              _images!.isNotEmpty
                  ? SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: _images!.length,
                  controller: PageController(viewportFraction: 0.9),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.file(File(_images![index].path)),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Tutup'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_images![index].path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
                  : Text("Belum ada foto", style: TextStyle(fontSize: 12, color: Colors.red)),

              ElevatedButton.icon(
                onPressed: () => _showImagePicker(context),
                icon: Icon(Icons.upload),
                label: Text("Upload Foto"),
              ),
              SizedBox(height: 5),
              Text("Format .JPG, .PNG, .JPEG", style: TextStyle(fontSize: 12, color: Colors.red)),
              SizedBox(height: 20),

              Center(
                child: SizedBox(
                  width: 250,
                  child: ElevatedButton(
                    onPressed: () => _handleSubmit(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF522E2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                        side: const BorderSide(color: Color(0xFF522E2E), width: 1),
                      ),
                    ),
                    child: const Text(
                      "Kirim",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSearchIcon() {
    return SlideTransition(
      position: _searchOffset,
      child: const Icon(Icons.search, color: Colors.grey),
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