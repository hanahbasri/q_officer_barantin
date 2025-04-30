class Lokasi {
  final String idLokasi;
  final String idSuratTugas;
  final String namaLokasi;
  final double latitude;
  final double longitude;
  final String detail;
  final String timestamp;

  Lokasi({
    required this.idLokasi,
    required this.idSuratTugas,
    required this.namaLokasi,
    required this.latitude,
    required this.longitude,
    required this.detail,
    required this.timestamp,
  });

  factory Lokasi.fromMap(Map<String, dynamic> map) {
    return Lokasi(
      idLokasi: map['id_lokasi'],
      idSuratTugas: map['id_surat_tugas'],
      namaLokasi: map['nama_lokasi'],
      latitude: map['latitude'] is double ? map['latitude'] : (map['latitude'] as num).toDouble(),
      longitude: map['longitude'] is double ? map['longitude'] : (map['longitude'] as num).toDouble(),
      detail: map['detail'],
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_lokasi': idLokasi,
      'id_surat_tugas': idSuratTugas,
      'nama_lokasi': namaLokasi,
      'latitude': latitude,
      'longitude': longitude,
      'detail': detail,
      'timestamp': timestamp,
    };
  }
}
