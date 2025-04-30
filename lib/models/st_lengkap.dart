import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'package:q_officer_barantin/models/lokasi.dart';

class StLengkap {
  final String idSuratTugas;
  final String noSt;
  final String dasar;
  final String tanggal;
  final String namaTtd;
  final String nipTtd;
  final String hal;
  final String status;
  final List<Petugas> petugas;
  final List<Lokasi> lokasi;
  final List<Komoditas> komoditas;

  StLengkap({
    required this.idSuratTugas,
    required this.noSt,
    required this.dasar,
    required this.tanggal,
    required this.namaTtd,
    required this.nipTtd,
    required this.hal,
    required this.status,
    required this.petugas,
    required this.lokasi,
    required this.komoditas,
  });

  StLengkap copyWith({
    String? status,
  }) {
    return StLengkap(
      idSuratTugas: idSuratTugas,
      noSt: noSt,
      dasar: dasar,
      tanggal: tanggal,
      namaTtd: namaTtd,
      nipTtd: nipTtd,
      hal: hal,
      status: status ?? this.status,
      petugas: petugas,
      lokasi: lokasi,
      komoditas: komoditas,
    );
  }

  factory StLengkap.fromMap(
      Map<String, dynamic> map,
      List<Map<String, dynamic>> petugasMaps,
      List<Map<String, dynamic>> lokasiMaps,
      List<Map<String, dynamic>> komoditasMaps,
      ) {
    return StLengkap(
      idSuratTugas: map['id_surat_tugas'],
      noSt: map['no_st'],
      dasar: map['dasar'],
      tanggal: map['tanggal'],
      namaTtd: map['nama_ttd'],
      nipTtd: map['nip_ttd'],
      hal: map['hal'],
      status: map['status'],
      petugas: petugasMaps.map((e) => Petugas.fromMap(e)).toList(),
      lokasi: lokasiMaps.map((e) => Lokasi.fromMap(e)).toList(),
      komoditas: komoditasMaps.map((e) => Komoditas.fromMap(e)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_surat_tugas': idSuratTugas,
      'no_st': noSt,
      'dasar': dasar,
      'tanggal': tanggal,
      'nama_ttd': namaTtd,
      'nip_ttd': nipTtd,
      'hal': hal,
      'status': status,
    };
  }
}
