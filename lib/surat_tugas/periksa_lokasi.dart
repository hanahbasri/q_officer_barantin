import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../databases/db_helper.dart';
import 'package:q_officer_barantin/models/lokasi.dart';

class PeriksaLokasi extends StatefulWidget {
  final String idSuratTugas;

  const PeriksaLokasi({Key? key, required this.idSuratTugas}) : super(key: key);

  @override
  _PeriksaLokasiState createState() => _PeriksaLokasiState();
}


class _PeriksaLokasiState extends State<PeriksaLokasi> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isMapReady = false;
  List<LatLng> _pendingPositions = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationsFromDb();
  }

  Future<void> _fetchLocationsFromDb() async {
    final locationMaps = await DatabaseHelper().getLokasiById(widget.idSuratTugas);
    final locations = locationMaps.map((map) => Lokasi.fromMap(map)).toList();

    List<LatLng> positions = [];

    setState(() {
      _markers.clear();
      _polylines.clear();

      for (var lokasi in locations) {
        final position = LatLng(lokasi.latitude, lokasi.longitude);
        positions.add(position);

        _markers.add(
          Marker(
            markerId: MarkerId(lokasi.idLokasi),
            position: position,
            infoWindow: InfoWindow(
              title: lokasi.namaLokasi,
              snippet: "🕒 ${lokasi.timestamp}\n📍 ${lokasi.detail}",
              onTap: () => _openGoogleMaps(position),
            ),
          ),
        );
      }

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

      if (_isMapReady && positions.isNotEmpty) {
        _moveCameraToFitMarkers(positions);
      } else {
        _pendingPositions = positions;
      }
    });
  }

  void _moveCameraToFitMarkers(List<LatLng> positions) {
    if (_mapController == null) return;

    LatLngBounds bounds;
    if (positions.length == 1) {
      bounds = LatLngBounds(
        southwest: LatLng(positions[0].latitude - 0.01, positions[0].longitude - 0.01),
        northeast: LatLng(positions[0].latitude + 0.01, positions[0].longitude + 0.01),
      );
    } else {
      final latitudes = positions.map((p) => p.latitude);
      final longitudes = positions.map((p) => p.longitude);

      bounds = LatLngBounds(
        southwest: LatLng(latitudes.reduce((a, b) => a < b ? a : b), longitudes.reduce((a, b) => a < b ? a : b)),
        northeast: LatLng(latitudes.reduce((a, b) => a > b ? a : b), longitudes.reduce((a, b) => a > b ? a : b)),
      );
    }

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

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
          _isMapReady = true;

          if (_pendingPositions.isNotEmpty) {
            _moveCameraToFitMarkers(_pendingPositions);
            _pendingPositions = [];
          }
        },
      ),
    );
  }
}