class HasilPemeriksaan {
  final String idPemeriksaan;
  final String idSuratTugas;
  final String idKomoditas;
  final String namaKomoditas;
  final String idLokasi;
  final String namaLokasi;
  final String lat;
  final String long;
  final String target;
  final String metode;
  final String temuan;
  final String? catatan;
  final String tanggal;
  final int syncData;

  HasilPemeriksaan({
    required this.idPemeriksaan,
    required this.idSuratTugas,
    required this.idKomoditas,
    required this.namaKomoditas,
    required this.idLokasi,
    required this.namaLokasi,
    required this.lat,
    required this.long,
    required this.target,
    required this.metode,
    required this.temuan,
    this.catatan,
    required this.tanggal,
    this.syncData = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_pemeriksaan': idPemeriksaan,
      'id_surat_tugas': idSuratTugas,
      'id_komoditas': idKomoditas,
      'nama_komoditas': namaKomoditas,
      'id_lokasi': idLokasi,
      'nama_lokasi': namaLokasi,
      'lat': lat,
      'long': long,
      'target': target,
      'metode': metode,
      'temuan': temuan,
      'catatan': catatan,
      'tgl_periksa': tanggal,
      'syncdata': syncData,
    };
  }

  factory HasilPemeriksaan.fromMap(Map<String, dynamic> map) {
    return HasilPemeriksaan(
      idPemeriksaan: map['id_pemeriksaan'],
      idSuratTugas: map['id_surat_tugas'],
      idKomoditas: map['id_komoditas'],
      namaKomoditas: map['nama_komoditas'],
      idLokasi: map['id_lokasi'],
      namaLokasi: map['nama_lokasi'],
      lat: map['lat'],
      long: map['long'],
      target: map['target'],
      metode: map['metode'],
      temuan: map['temuan'],
      catatan: map['catatan'],
      tanggal: map['tgl_periksa'],
      syncData: map['syncdata'] ?? 0,
    );
  }
}
