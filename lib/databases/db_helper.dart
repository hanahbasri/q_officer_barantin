import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:q_officer_barantin/surat_tugas/additional/tanggal.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
            id_surat_tugas INTEGER PRIMARY KEY AUTOINCREMENT,
            no_st TEXT NOT NULL,
            dasar TEXT NOT NULL,
            nama TEXT NOT NULL,
            nip TEXT NOT NULL,
            gol TEXT NOT NULL,
            pangkat TEXT NOT NULL,
            komoditas TEXT NOT NULL,
            lok TEXT NOT NULL,
            tgl_tugas TEXT NOT NULL,
            ttd TEXT NOT NULL,
            hal TEXT NOT NULL,
            link TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE Hasil_Pemeriksaan (
            id_pemeriksaan INTEGER PRIMARY KEY AUTOINCREMENT,
            id_surat_tugas INTEGER,
            komoditas TEXT NOT NULL,
            lokasi TEXT NOT NULL,
            fotoPaths TEXT NOT NULL,
            target TEXT NOT NULL,
            metode TEXT NOT NULL,
            temuan TEXT NOT NULL,
            catatan TEXT NOT NULL,
            tgl_periksa TEXT NOT NULL,
            FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE Petugas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_surat_tugas INTEGER,
            nama TEXT NOT NULL,
            NIP TEXT,
            jabatan TEXT,
            gol TEXT,
            pangkat TEXT,
            FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE Lokasi (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_surat_tugas INTEGER,
            locationName TEXT,
            latitude REAL,
            longitude REAL,
            detail TEXT,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE Komoditas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ptk_id INTEGER,
            id_surat_tugas INTEGER,
            nama_komoditas TEXT NOT NULL,
            nama_eng TEXT,
            nama_latin TEXT,
            vol REAL,
            sat TEXT,
            FOREIGN KEY (ptk_id) REFERENCES Petugas(id) ON DELETE CASCADE,
            FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas) ON DELETE CASCADE
          )
        ''');

        await db.insert('Surat_Tugas', {
          'no_st': '2025.2.0000.MN.000002',
          'dasar': 'UU No. 12',
          'nama': 'Mochamad Ridwan, S.Kom.',
          'nip': '199412082020121001',
          'gol': 'III/A',
          'pangkat': 'Penata Muda',
          'komoditas': 'Perikanan Budidaya',
          'lok': 'Kabupaten Bogor',
          'tgl_tugas': '2024-04-01',
          'ttd': 'Kepala Dinas',
          'hal': 'Penugasan Monitoring Lapangan',
          'link': 'MDcxYTQwMmYtZjIwYi00NmVjLWI0ZWMtMGRkMTkxYWUxMWEzX3ZpZXc='
        });

        await db.insert('Surat_Tugas', {
          'no_st': '2025.2.0000.MN.000003',
          'dasar': 'UU No. 12',
          'nama': 'Arie Hasan, S.Kom.',
          'nip': '199212132420221001',
          'gol': 'III/A',
          'pangkat': 'Penata Muda',
          'komoditas': 'Perikanan Budidaya',
          'lok': 'Kota Bandung',
          'tgl_tugas': '2024-04-01',
          'ttd': 'Kepala Dinas',
          'hal': 'Pengecekan Sampel',
          'link': 'MDcxYTQwMmYtZjIwYi00NmVjLWI0ZWMtMGRkMTkxYWUxMWEzX3ZpZXc='
        });

        await db.insert('Lokasi', {
          'id_surat_tugas': 1,
          'locationName': 'Gedung A',
          'latitude': -6.7114,
          'longitude': 106.9881,
          'detail': 'Monitoring Lanjutan',
          'timestamp': formatTanggal(DateTime.now()),
        });

        await db.insert('Lokasi', {
          'id_surat_tugas': 1,
          'locationName': 'Gedung B',
          'latitude': -6.5960, // Lokasi sedikit lebih dekat
          'longitude': 106.7963, // Lokasi sedikit lebih dekat
          'detail': 'Monitoring Lanjutan',
          'timestamp': formatTanggal(DateTime.now()),
        });

        await db.insert('Lokasi', {
          'id_surat_tugas': 2,
          'locationName': 'Gedung C',
          'latitude': -6.9218, // Lokasi sedikit lebih dekat
          'longitude': 107.6079, // Lokasi sedikit lebih dekat
          'detail': 'Pemeriksaan Lanjutan',
          'timestamp': formatTanggal(DateTime.now()),
        });

        await db.insert('Lokasi', {
          'id_surat_tugas': 2,
          'locationName': 'Gedung D',
          'latitude': -6.9307, // Lokasi sedikit lebih dekat
          'longitude': 107.6080, // Lokasi sedikit lebih dekat
          'detail': 'Pemeriksaan Lanjutan',
          'timestamp': formatTanggal(DateTime.now()),
        });
      },
    );
  }

  Future<void> insertPeriksa(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('Hasil_Pemeriksaan', data);
  }

  Future<List<Map<String, dynamic>>> getAllPeriksa() async {
    final db = await database;
    return await db.query('Hasil_Pemeriksaan');
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

  Future<List<Map<String, dynamic>>> getLocations() async {
    final db = await database;
    return await db.query('Lokasi');
  }

  Future<void> deleteDatabaseFile() async {
    final path = join(await getDatabasesPath(), 'app_database.db');
    await deleteDatabase(path);
    if (kDebugMode) {
      print('Database berhasil dihapus');
    }
  }

  Future<List<int>> _getAllIdSuratTugas() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    final database = await openDatabase(path, version: 1);

    // Query untuk mendapatkan semua id_surat_tugas yang unik
    final List<Map<String, dynamic>> results = await database.query('Surat_Tugas', columns: ['id_surat_tugas']);

    // Ekstrak id_surat_tugas dari hasil query
    List<int> idList = results.map((row) => row['id_surat_tugas'] as int).toList();

    return idList;
  }

  Future<List<Map<String, dynamic>>> getLocationsBySuratTugas(int idSuratTugas) async {
    final db = await database;
    return await db.query(
      'Lokasi',
      where: 'id_surat_tugas = ?',
      whereArgs: [idSuratTugas],
    );
  }
}

