import 'package:flutter/material.dart';
import 'package:q_officer_barantin/main.dart';
import 'dart:async';
import 'package:q_officer_barantin/dialog/q_declare_confirm.dart';
import 'package:q_officer_barantin/dialog/q_declare_success.dart';

class BarangBawaanScreen extends StatefulWidget {
  const BarangBawaanScreen({super.key});

  @override
  State<BarangBawaanScreen> createState() => _BarangBawaanScreenState();
}

class _BarangBawaanScreenState extends State<BarangBawaanScreen> {
  String? _selectedAction;

  final passengerData = {
    'nama': 'Delia Sara',
    'statusKepemilikan': 'Pemilik',
    'noPenerbangan': 'SQ956',
    'noPaspor': 'T4123XXX',
    'tanggalIsi': '11 Jun 2025, 13:35 WIB',
    'barangBawaan': [
      {
        'nama': 'Daging Sapi Kobe',
        'jumlah': '2 kg',
        'komoditas': 'Produk Hewani',
        'negaraAsal': 'Jepang',
      },
      {
        'nama': 'Benih Bunga Matahari',
        'jumlah': '5 paket',
        'komoditas': 'Produk Tumbuhan',
        'negaraAsal': 'Rusia',
      },
    ],
  };

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor:
                  AlwaysStoppedAnimation<Color>(MyApp.karantinaBrown),
                ),
                const SizedBox(width: 20),
                Text(message, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConfirmationDialog() {
    String message;
    IconData icon;
    Color iconColor;

    switch (_selectedAction) {
      case 'periksa lanjutan':
        message =
        'Barang bawaan akan diteruskan untuk proses pemeriksaan lebih lanjut oleh petugas terkait.';
        icon = Icons.search_rounded;
        iconColor = Colors.blue.shade700;
        break;
      case 'Ditolak':
        message =
        'Barang bawaan akan ditolak masuk dan akan diproses sesuai prosedur penolakan.';
        icon = Icons.block_rounded;
        iconColor = Colors.red.shade700;
        break;
      case 'disposal bin':
        message =
        'Barang bawaan akan dibuang ke disposal bin sesuai prosedur yang berlaku.';
        icon = Icons.delete_sweep_rounded;
        iconColor = MyApp.karantinaBrown;
        break;
      default:
        return;
    }

    showAnimatedConfirmationDialog(
      context: context,
      title: 'Konfirmasi Tindakan',
      message: message,
      icon: icon,
      iconColor: iconColor,
      onConfirm: () async {
        debugPrint('Tindakan "$_selectedAction" telah dikonfirmasi.');

        _showLoadingDialog('Mengirim data...');
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          showAnimatedSuccessDialog(
              context: context,
              title: "Berhasil Dikirim",
              message:
              'Tindakan "$_selectedAction" telah berhasil dicatat dan dikirim.',
              onDismiss: () {
                if (mounted) Navigator.of(context).pop();
              });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deklarasi Barang Bawaan'),
        backgroundColor: MyApp.karantinaBrown,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPassengerInfoCard(),
            const SizedBox(height: 24),
            const Text('Rincian Barang Bawaan',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MyApp.karantinaBrown)),
            const SizedBox(height: 8),
            _buildBaggageList(),
            const SizedBox(height: 24),
            const Text('Pilih Tindakan Karantina',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MyApp.karantinaBrown)),
            const SizedBox(height: 16),
            _buildActionOption(
              title: 'Pemeriksaan Lanjutan',
              value: 'periksa lanjutan',
              icon: Icons.search_rounded,
            ),
            _buildActionOption(
              title: 'Tolak',
              value: 'Ditolak',
              icon: Icons.block_rounded,
            ),
            _buildActionOption(
              title: 'Disposal Bin',
              value: 'disposal bin',
              icon: Icons.delete_sweep_rounded,
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 250,
                child: ElevatedButton.icon(
                  onPressed:
                  _selectedAction == null ? null : _showConfirmationDialog,
                  label: const Text('Kirim'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyApp.karantinaBrown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_pin_rounded, color: MyApp.karantinaBrown),
                SizedBox(width: 8),
                Text('Data Penumpang',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: MyApp.karantinaBrown)),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow('Nama Lengkap', passengerData['nama'].toString()),
            _buildInfoRow('No. Paspor', passengerData['noPaspor'].toString()),
            _buildInfoRow('Status Kepemilikan',
                passengerData['statusKepemilikan'].toString()),
            _buildInfoRow(
                'No. Penerbangan', passengerData['noPenerbangan'].toString()),
            _buildInfoRow(
                'Tanggal Pengisian', passengerData['tanggalIsi'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildBaggageList() {
    final List<Map<String, String>> baggage =
    passengerData['barangBawaan'] as List<Map<String, String>>;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: baggage.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = baggage[index];
        return Card(
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['nama']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                _buildInfoRow('Komoditas', item['komoditas']!),
                _buildInfoRow('Jumlah', item['jumlah']!),
                _buildInfoRow('Negara Asal', item['negaraAsal']!),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label, style: TextStyle(color: Colors.grey[700]))),
          const Text(': '),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildActionOption({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final bool isSelected = _selectedAction == value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedAction = value;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? MyApp.karantinaBrown.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? MyApp.karantinaBrown : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: MyApp.karantinaBrown),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ),
              Radio<String>(
                value: value,
                groupValue: _selectedAction,
                onChanged: (val) {
                  setState(() {
                    _selectedAction = val;
                  });
                },
                activeColor: MyApp.karantinaBrown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}