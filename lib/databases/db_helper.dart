import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:q_officer_barantin/additional/tanggal.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:q_officer_barantin/models/hasil_pemeriksaan.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Surat_Tugas (
            id_surat_tugas TEXT NOT NULL PRIMARY KEY,
            ptk_id TEXT NOT NULL,
            no_st TEXT NOT NULL,
            dasar TEXT NOT NULL,
            tanggal TEXT NOT NULL,
            nama_ttd TEXT NOT NULL,
            nip_ttd TEXT NOT NULL,
            hal TEXT NOT NULL,
            status TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE Hasil_Pemeriksaan (
            id_pemeriksaan TEXT NOT NULL PRIMARY KEY,
            id_surat_tugas TEXT NOT NULL,
            id_lokasi TEXT NOT NULL,
            id_komoditas TEXT NOT NULL,
            nama_komoditas TEXT NOT NULL,
            nama_lokasi TEXT NOT NULL,
            lat TEXT NOT NULL,
            long TEXT NOT NULL,
            target TEXT NOT NULL,
            metode TEXT NOT NULL,
            temuan TEXT NOT NULL,
            catatan TEXT,
            tgl_periksa TEXT NOT NULL,
            syncdata INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas)
            FOREIGN KEY (id_lokasi) REFERENCES Lokasi(id_lokasi)
            FOREIGN KEY (id_komoditas) REFERENCES Komoditas(id_komoditas)
          )
        ''');

        await db.execute('''
          CREATE TABLE Dokumentasi_Periksa (
            id_foto TEXT NOT NULL PRIMARY KEY,
            id_pemeriksaan TEXT NOT NULL,
            foto TEXT NOT NULL,
            FOREIGN KEY (id_pemeriksaan) REFERENCES Hasil_Pemeriksaan(id_pemeriksaan)
          );
        ''');

        await db.execute('''
          CREATE TABLE Petugas (
            id_petugas TEXT NOT NULL PRIMARY KEY,
            id_surat_tugas TEXT NOT NULL,
            nama_petugas TEXT NOT NULL,
            nip_petugas TEXT NOT NULL,
            gol TEXT NOT NULL,
            pangkat TEXT NOT NULL,
            FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE Lokasi (
            id_lokasi TEXT NOT NULL PRIMARY KEY,
            id_surat_tugas TEXT NOT NULL,
            nama_lokasi TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            detail TEXT,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE Komoditas (
            id_komoditas TEXT NOT NULL PRIMARY KEY,
            id_surat_tugas TEXT NOT NULL,
            nama_komoditas TEXT NOT NULL,
            nama_umum_tercetak TEXT,
            nama_latin TEXT,
            vol TEXT,
            sat TEXT,
            kd_sat TEXT,
            netto TEXT,
            jantan TEXT,
            betina TEXT,
            FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas) ON DELETE CASCADE
          )
        ''');

        await db.insert('Surat_Tugas', {
          'id_surat_tugas': 'ST090393',
          'ptk_id': '131095',
          'no_st': '2025.2.0000.MN.000002',
          'dasar': 'UU No. 12',
          'tanggal': '2024-04-01',
          'nama_ttd': 'Aan Suraan, S.Kom.',
          'nip_ttd': '197913192040141001',
          'hal': 'Penugasan Monitoring Lapangan',
          'status': 'tertunda',
        });

        await db.insert('Petugas', {
          'id_petugas': 'P001',
          'id_surat_tugas': 'ST090393',
          'nama_petugas': 'Mochamad Ridwan, S.Kom.',
          'nip_petugas': '199412082020121001',
          'gol': 'III/A',
          'pangkat': 'Penata Muda',
        });

        await db.insert('Petugas', {
          'id_petugas': 'P002',
          'id_surat_tugas': 'ST090393',
          'nama_petugas': 'Toto Suroto S.Kom.',
          'nip_petugas': '197013071020131001',
          'gol': 'III/A',
          'pangkat': 'Penata Muda',
        });

        await db.insert('Surat_Tugas', {
          'id_surat_tugas': 'ST010997',
          'ptk_id': '311295',
          'no_st': '2025.2.0000.MN.000003',
          'dasar': 'UU No. 12',
          'tanggal': '2024-04-01',
          'nama_ttd': 'Ichwan Alif, S.Kom.',
          'nip_ttd': '198024556120821001',
          'hal': 'Pengecekan Sampel',
          'status': 'tertunda',
        });

        await db.insert('Petugas', {
          'id_petugas': 'P003',
          'id_surat_tugas': 'ST010997',
          'nama_petugas': 'Arie Hasan, S.Kom.',
          'nip_petugas': '199212132420221001',
          'gol': 'III/A',
          'pangkat': 'Penata Muda',
        });

        await db.insert('Petugas', {
          'id_petugas': 'P004',
          'id_surat_tugas': 'ST010997',
          'nama_petugas': 'Dadang Sudrajat, S.Kom.',
          'nip_petugas': '197314135421421001',
          'gol': 'III/A',
          'pangkat': 'Penata Muda',
        });

        await db.insert('Lokasi', {
          'id_lokasi': 'B01',
          'id_surat_tugas': 'ST090393',
          'nama_lokasi': 'Gedung A Bogor',
          'latitude': -6.5960,
          'longitude': 106.7963,
          'detail': 'Pemeriksaan Sampel',
          'timestamp': formatTanggal(DateTime.now()),
        });

        await db.insert('Lokasi', {
          'id_lokasi': 'B02',
          'id_surat_tugas': 'ST090393',
          'nama_lokasi': 'Gedung B Bogor',
          'latitude': -6.7114,
          'longitude': 106.9881,
          'detail': 'Pemeriksaan Lanjutan',
          'timestamp': formatTanggal(DateTime.now()),
        });

        await db.insert('Lokasi', {
          'id_lokasi': 'BAO1',
          'id_surat_tugas': 'ST010997',
          'nama_lokasi': 'Gedung A Bandung',
          'latitude': -6.9218,
          'longitude': 107.6079,
          'detail': 'Pemeriksaan Sampel',
          'timestamp': formatTanggal(DateTime.now()),
        });

        await db.insert('Lokasi', {
          'id_lokasi': 'BAO2',
          'id_surat_tugas': 'ST010997',
          'nama_lokasi': 'Gedung B Bandung',
          'latitude': -6.9307,
          'longitude': 107.6080,
          'detail': 'Pemeriksaan Lanjutan',
          'timestamp': formatTanggal(DateTime.now()),
        });

// Contoh insert Komoditas
        await db.insert('Komoditas', {
          'id_komoditas': 'K001',
          'id_surat_tugas': 'ST090393',
          'nama_komoditas': 'Perikanan Budidaya',
          'nama_umum_tercetak': 'Ikan Nila',
          'nama_latin': 'Oreochromis niloticus',
          'vol': '100',
          'sat': 'ekor',
          'kd_sat': 'EKR',
          'netto': '50',
          'jantan': '60',
          'betina': '40',
        });

        await db.insert('Komoditas', {
          'id_komoditas': 'K002',
          'id_surat_tugas': 'ST010997',
          'nama_komoditas': 'Perikanan Tangkap',
          'nama_umum_tercetak': 'Ikan Tuna',
          'nama_latin': 'Thunnus sp.',
          'vol': '200',
          'sat': 'kg',
          'kd_sat': 'KG',
          'netto': '190',
          'jantan': '20',
          'betina': '10',
        });
      },
    );
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> getData(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<int> update(String table, Map<String, dynamic> data, String whereClause, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update(table, data, where: whereClause, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String whereClause, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: whereClause, whereArgs: whereArgs);
  }

  Future<void> insertHasilPemeriksaan(HasilPemeriksaan hasil) async {
    final db = await database;
    await db.insert('Hasil_Pemeriksaan', hasil.toMap());
  }

  Future<List<Map<String, dynamic>>> getPeriksaById(String idSuratTugas) async {
    final db = await database;
    return await db.query(
      'Hasil_Pemeriksaan',
      where: 'id_surat_tugas = ?',
      whereArgs: [idSuratTugas],
    );
  }

  Future<void> getImagetoDatabase(Uint8List imageBytes, String idPemeriksaan) async {
    final db = await DatabaseHelper().database;
    final base64Image = base64Encode(imageBytes); // <-- Konversi ke Base64 String
    await db.insert('Dokumentasi_Periksa', {
      'id_foto': const Uuid().v4(),
      'id_pemeriksaan': idPemeriksaan,
      'foto': base64Image,
    });
  }


  Future<List<Map<String, dynamic>>> getImageFromDatabase(String idPemeriksaan) async {
    final db = await DatabaseHelper().database;
    return await db.query(
      'Dokumentasi_Periksa',
      where: 'id_pemeriksaan = ?',
      whereArgs: [idPemeriksaan],
    );
  }

  Future<List<Uint8List>> loadImagesFromDb(String idPemeriksaan) async {
    final db = DatabaseHelper();
    final rows = await db.getImageFromDatabase(idPemeriksaan);
    return rows.map((e) => base64Decode(e['foto'] as String)).toList();
  }

  Future<List<String>> getImageBase64List(String idPemeriksaan) async {
    final db = await database;
    final result = await db.query(
      'Dokumentasi_Periksa',
      columns: ['foto'],
      where: 'id_pemeriksaan = ?',
      whereArgs: [idPemeriksaan],
    );
    return result.map((row) => row['foto'] as String).toList();
  }


  Future<Position?> getLocation() async {
    Position? currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      currentPosition = null;
      rethrow;
    }
    return currentPosition;
  }

  Future<List<Map<String, dynamic>>> getLokasiById(String idSuratTugas) async {
    final db = await database;
    return await db.query(
      'Lokasi',
      where: 'id_surat_tugas = ?',
      whereArgs: [idSuratTugas],
    );
  }

  Future<List<Map<String, dynamic>>> getPetugasById(String idSuratTugas) async {
    final db = await database;
    return await db.query(
      'Petugas',
      where: 'id_surat_tugas = ?',
      whereArgs: [idSuratTugas],
    );
  }

  Future<List<Map<String, dynamic>>> getKomoditasById(String idSuratTugas) async {
    final db = await database;
    return await db.query(
      'Komoditas',
      where: 'id_surat_tugas = ?',
      whereArgs: [idSuratTugas],
    );
  }

  Future<void> syncSingleData(String id) async {
    final db = await database;
    final data = await db.query('Hasil_Pemeriksaan', where: 'id_pemeriksaan = ?', whereArgs: [id]);

    if (data.isNotEmpty) {
      await Future.delayed(Duration(seconds: 1));

      await db.update(
        'Hasil_Pemeriksaan',
        {'syncdata': 1},
        where: 'id_pemeriksaan = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> syncUnsentData() async {
    final db = await database;
    final unsynced = await db.query('Hasil_Pemeriksaan', where: 'syncdata = 0');

    for (final data in unsynced) {
      final id = data['id_pemeriksaan'];
      if (id != null) {
        await syncSingleData(id.toString());
      } else {
        debugPrint('❗ id_pemeriksaan null ditemukan di data: $data');
      }
    }
  }

  Future<void> updateStatusTugas(String id, String status) async {
    final dbClient = await database;
    await dbClient.update(
      'Surat_Tugas',
      {'status': status},
      where: 'id_surat_tugas = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDatabaseFile() async {
    final path = join(await getDatabasesPath(), 'app_database.db');
    await deleteDatabase(path);
    if (kDebugMode) {
      print('Database berhasil dihapus');
    }
  }
}