class Komoditas {
  final String idKomoditas;
  final String idSuratTugas;
  final String namaKomoditas;
  final String? namaUmumTercetak;
  final String? namaLatin;
  final String? vol;
  final String? sat;
  final String? kdSat;
  final String? netto;
  final String? jantan;
  final String? betina;

  Komoditas({
    required this.idKomoditas,
    required this.idSuratTugas,
    required this.namaKomoditas,
    this.namaUmumTercetak,
    this.namaLatin,
    this.vol,
    this.sat,
    this.kdSat,
    this.netto,
    this.jantan,
    this.betina,
  });

  // fromMap
  factory Komoditas.fromMap(Map<String, dynamic> map) {
    return Komoditas(
      idKomoditas: map['id_komoditas'],
      idSuratTugas: map['id_surat_tugas'],
      namaKomoditas: map['nama_komoditas'],
      namaUmumTercetak: map['nama_umum_tercetak'],
      namaLatin: map['nama_latin'],
      vol: map['vol'],
      sat: map['sat'],
      kdSat: map['kd_sat'],
      netto: map['netto'],
      jantan: map['jantan'],
      betina: map['betina'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_komoditas': idKomoditas,
      'id_surat_tugas': idSuratTugas,
      'nama_komoditas': namaKomoditas,
      'nama_umum_tercetak': namaUmumTercetak,
      'nama_latin': namaLatin,
      'vol': vol,
      'sat': sat,
      'kd_sat': kdSat,
      'netto': netto,
      'jantan': jantan,
      'betina': betina,
    };
  }
}