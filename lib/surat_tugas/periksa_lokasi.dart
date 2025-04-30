import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:custom_info_window/custom_info_window.dart';
import '../databases/db_helper.dart';

class PeriksaLokasi extends StatefulWidget {
  final int idSuratTugas;

  const PeriksaLokasi({super.key, required this.idSuratTugas});

  @override
  _PeriksaLokasiState createState() => _PeriksaLokasiState();
}


class _PeriksaLokasiState extends State<PeriksaLokasi> {
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();
  GoogleMapController? _mapController;


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
            onTap: () {
              _customInfoWindowController.addInfoWindow!(
                Container(
                  width: 250,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 5),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("🕒 $timestamp", style: TextStyle(fontSize: 12)),
                      Text("📄 $detail", style: TextStyle(fontSize: 12)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _openGoogleMaps(position),
                          child: Text("Buka di Maps", style: TextStyle(color: Colors.blue)),
                        ),
                      ),
                    ],
                  ),
                ),
                position,
              );
            },
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
  if (_mapController != null && positions.isNotEmpty) {
      if (positions.length == 1) {
      // Fokus ke 1 marker
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: positions.first, zoom: 16),
        ),
      );
      } else {
      // Fokus ke semua marker (fit bounds)
      final bounds = LatLngBounds(
        southwest: LatLng(
          positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
          positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
          positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
        ),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      }
    }
  }

  // Fungsi untuk membuka Google Maps
  void _openGoogleMaps(LatLng position) async {
    final Uri url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (kDebugMode) {
        print("Tidak dapat membuka Google Maps.");
      }
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
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(-6.2088, 106.8456), zoom: 12),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              _customInfoWindowController.googleMapController = controller;
            },
            onTap: (position) => _customInfoWindowController.hideInfoWindow!(),
            onCameraMove: (_) => _customInfoWindowController.onCameraMove!(),
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 130,
            width: 250,
            offset: 50,
          ),
        ],
      ),
    );
  }
}