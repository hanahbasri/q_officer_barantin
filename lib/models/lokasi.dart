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

  // Constructor untuk memparsing dari respons API
  factory Lokasi.fromApiResponseMap(Map<String, dynamic> map) {
    return Lokasi(
      idLokasi: map['id'] ?? '', // API uses 'id'
      idSuratTugas: map['id_surat_tugas'] ?? '',
      namaLokasi: map['locationName'] ?? '', // API uses 'locationName'
      latitude: double.tryParse(map['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(map['longitude']?.toString() ?? '0') ?? 0.0,
      detail: map['detail'] ?? '',
      timestamp: map['created_at'] ?? '', // API uses 'created_at'
    );
  }

  // Constructor untuk memparsing dari database lokal
  factory Lokasi.fromDbMap(Map<String, dynamic> map) {
    return Lokasi(
      idLokasi: map['id_lokasi']?.toString() ?? '', // DB uses 'id_lokasi'
      idSuratTugas: map['id_surat_tugas']?.toString() ?? '',
      namaLokasi: map['nama_lokasi']?.toString() ?? '', // DB uses 'nama_lokasi'
      latitude: double.tryParse(map['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(map['longitude']?.toString() ?? '0') ?? 0.0,
      detail: map['detail']?.toString() ?? '',
      timestamp: map['timestamp']?.toString() ?? '', // DB uses 'timestamp'
    );
  }

  Map<String, dynamic> toMap() {
    // Digunakan saat menyimpan ke database lokal
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