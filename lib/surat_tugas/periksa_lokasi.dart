import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../databases/db_helper.dart'; // Pastikan ini diimport untuk memanggil getLocations()

class PeriksaLokasi extends StatefulWidget {
  final int idSuratTugas; // ⬅️ tambahkan ini

  const PeriksaLokasi({Key? key, required this.idSuratTugas}) : super(key: key);

  @override
  _PeriksaLokasiState createState() => _PeriksaLokasiState();
}


class _PeriksaLokasiState extends State<PeriksaLokasi> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Database? _database;

  @override
  void initState() {
    super.initState();
    _fetchLocationsFromDb();
  }

  // Ambil lokasi menggunakan method getLocations() dari DatabaseHelper
  Future<void> _fetchLocationsFromDb() async {
    // Mendapatkan daftar lokasi dari DatabaseHelper
    final locations = await DatabaseHelper().getLocationsBySuratTugas(widget.idSuratTugas);

    List<LatLng> positions = [];

    setState(() {
      _markers.clear();
      _polylines.clear();

      for (var row in locations) {
        final lat = row['latitude'] as double;
        final lng = row['longitude'] as double;
        final name = row['locationName'] ?? 'Tanpa Nama';
        final detail = row['detail'] ?? '-';
        final timestamp = row['timestamp'] ?? '-';

        final position = LatLng(lat, lng);
        positions.add(position);

        _markers.add(
          Marker(
            markerId: MarkerId(row['id'].toString()),
            position: position,
            infoWindow: InfoWindow(
              title: name,
              snippet: "🕒 $timestamp\n📍 📄 $detail",
              onTap: () => _openGoogleMaps(position),
            ),
          ),
        );
      }

      // Menambahkan polyline jika lebih dari satu lokasi
      if (positions.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: PolylineId("route"),
            color: Colors.blue,
            width: 5,
            points: positions,
          ),
        );
      }
    });
  }

  // Fungsi untuk membuka Google Maps
  void _openGoogleMaps(LatLng position) async {
    final Uri url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      print("Tidak dapat membuka Google Maps.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Lacak Lokasi Penugasan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(-6.2088, 106.8456), zoom: 12),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
    );
  }
}