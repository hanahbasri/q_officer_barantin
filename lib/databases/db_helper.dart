import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:q_officer_barantin/models/hasil_pemeriksaan.dart';
import 'package:q_officer_barantin/services/surat_tugas_service.dart';
import 'package:http/http.dart' as http;

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
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS Dokumentasi_Periksa');
          await db.execute('DROP TABLE IF EXISTS Hasil_Pemeriksaan');
          await db.execute('DROP TABLE IF EXISTS Komoditas');
          await db.execute('DROP TABLE IF EXISTS Lokasi');
          await db.execute('DROP TABLE IF EXISTS Petugas');
          await db.execute('DROP TABLE IF EXISTS Surat_Tugas');
          await _createTables(db);
        }
        if (oldVersion < 3) {
          // Upgrade untuk versi 3 jika diperlukan
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE Surat_Tugas (
        id_surat_tugas TEXT NOT NULL PRIMARY KEY,
        ptk_id TEXT,
        no_st TEXT NOT NULL,
        dasar TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        nama_ttd TEXT NOT NULL,
        nip_ttd TEXT NOT NULL,
        hal TEXT NOT NULL,
        status TEXT NOT NULL,
        link TEXT NOT NULL,
        jenis_karantina TEXT
      )
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
        FOREIGN KEY (id_surat_tugas) REFERENCES Surat_Tugas(id_surat_tugas),
        FOREIGN KEY (id_lokasi) REFERENCES Lokasi(id_lokasi),
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
  }

  Future<void> syncSuratTugasFromApi(String nip) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting sync for NIP: $nip');
      }

      if (nip.isEmpty) {
        if (kDebugMode) {
          print('❌ NIP kosong, tidak dapat melakukan sync');
        }
        throw Exception('NIP tidak boleh kosong untuk sync data');
      }

      final suratTugasList = await SuratTugasService.getAllSuratTugasByNip(nip);

      if (kDebugMode) {
        print('📋 Received ${suratTugasList.length} surat tugas from API');
      }

      for (var suratTugas in suratTugasList) {
        if (kDebugMode) {
          print('💾 Processing surat tugas: ${suratTugas.idSuratTugas}');
        }

        // Simpan surat tugas
        await insertOrUpdateSuratTugas({
          'id_surat_tugas': suratTugas.idSuratTugas,
          'no_st': suratTugas.noSt,
          'dasar': suratTugas.dasar,
          'tanggal': suratTugas.tanggal,
          'nama_ttd': suratTugas.namaTtd,
          'nip_ttd': suratTugas.nipTtd,
          'hal': suratTugas.hal,
          'status': suratTugas.status,
          'link': suratTugas.link,
          'ptk_id': suratTugas.ptkId ?? '',
          'jenis_karantina': suratTugas.jenisKarantina ?? '',
        });

        // Simpan petugas
        for (var petugas in suratTugas.petugas) {
          await insertOrUpdatePetugas({
            'id_petugas': petugas.idPetugas,
            'id_surat_tugas': petugas.idSuratTugas,
            'nama_petugas': petugas.namaPetugas,
            'nip_petugas': petugas.nipPetugas,
            'gol': petugas.gol,
            'pangkat': petugas.pangkat,
          });
        }

        // Simpan lokasi
        for (var lokasi in suratTugas.lokasi) {
          await insertOrUpdateLokasi({
            'id_lokasi': lokasi.idLokasi,
            'id_surat_tugas': lokasi.idSuratTugas,
            'nama_lokasi': lokasi.namaLokasi,
            'latitude': lokasi.latitude,
            'longitude': lokasi.longitude,
            'detail': lokasi.detail,
            'timestamp': lokasi.timestamp,
          });
        }

        // Simpan komoditas
        for (var komoditas in suratTugas.komoditas) {
          await insertOrUpdateKomoditas({
            'id_komoditas': komoditas.idKomoditas,
            'id_surat_tugas': komoditas.idSuratTugas,
            'nama_komoditas': komoditas.namaKomoditas,
            'nama_umum_tercetak': komoditas.namaUmumTercetak,
            'nama_latin': komoditas.namaLatin,
            'vol': komoditas.vol,
            'sat': komoditas.sat,
            'kd_sat': komoditas.kdSat,
            'netto': komoditas.netto,
            'jantan': komoditas.jantan,
            'betina': komoditas.betina,
          });
        }
      }

      if (kDebugMode) {
        print('✅ Sync completed successfully');
      }
    } catch (e) {
      debugPrint('❌ Error sync data dari API: $e');
      if (kDebugMode) {
        print('❌ Stack trace: ${StackTrace.current}');
      }
      rethrow;
    }
  }

  Future<void> insertOrUpdateSuratTugas(Map<String, dynamic> data) async {
    final db = await database;
    try {
      await db.insert(
        'Surat_Tugas',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Error insert/update surat tugas: $e');
      rethrow;
    }
  }

  Future<void> insertOrUpdatePetugas(Map<String, dynamic> data) async {
    final db = await database;
    try {
      await db.insert(
        'Petugas',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Error insert/update petugas: $e');
      rethrow;
    }
  }

  Future<void> insertOrUpdateLokasi(Map<String, dynamic> data) async {
    final db = await database;
    try {
      await db.insert(
        'Lokasi',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Error insert/update lokasi: $e');
      rethrow;
    }
  }

  Future<void> insertOrUpdateKomoditas(Map<String, dynamic> data) async {
    final db = await database;
    try {
      await db.insert(
        'Komoditas',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Error insert/update komoditas: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSuratTugasWithSync(String nip) async {
    try {
      if (nip.isEmpty) {
        if (kDebugMode) {
          print('⚠️ NIP kosong, hanya mengambil data local tanpa sync');
        }
        return await getData('Surat_Tugas');
      }

      await syncSuratTugasFromApi(nip);

      return await getData('Surat_Tugas');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error dalam getSuratTugasWithSync: $e');
        print('⚠️ Fallback ke data local saja');
      }
      // Fallback ke data local jika sync gagal
      return await getData('Surat_Tugas');
    }
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

  Future<int> deleteImageFromDatabase(String imageId) async {
    final db = await database;
    return await db.delete(
      'Dokumentasi_Periksa',
      where: 'id_foto = ?',
      whereArgs: [imageId],
    );
  }

  // UPDATED: Menggunakan model HasilPemeriksaan yang baru
  Future<void> insertHasilPemeriksaan(HasilPemeriksaan hasil) async {
    final db = await database;
    try {
      await db.insert('Hasil_Pemeriksaan', hasil.toMap());
      if (kDebugMode) {
        print('✅ Hasil pemeriksaan berhasil disimpan: ${hasil.idPemeriksaan}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error insert hasil pemeriksaan: $e');
      }
      rethrow;
    }
  }

  // UPDATED: Mengembalikan List<HasilPemeriksaan> instead of raw Map
  Future<List<HasilPemeriksaan>> getHasilPemeriksaanById(String idSuratTugas) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'Hasil_Pemeriksaan',
        where: 'id_surat_tugas = ?',
        whereArgs: [idSuratTugas],
      );

      return List.generate(maps.length, (i) {
        return HasilPemeriksaan.fromMap(maps[i]);
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error get hasil pemeriksaan: $e');
      }
      return [];
    }
  }

  // DEPRECATED: Use getHasilPemeriksaanById instead
  @Deprecated('Use getHasilPemeriksaanById instead')
  Future<List<Map<String, dynamic>>> getPeriksaById(String idSuratTugas) async {
    final db = await database;
    return await db.query(
      'Hasil_Pemeriksaan',
      where: 'id_surat_tugas = ?',
      whereArgs: [idSuratTugas],
    );
  }

  Future<void> getImagetoDatabase(Uint8List imageBytes, String idPemeriksaan) async {
    final db = await database;
    final base64Image = base64Encode(imageBytes);
    await db.insert('Dokumentasi_Periksa', {
      'id_foto': const Uuid().v4(),
      'id_pemeriksaan': idPemeriksaan,
      'foto': base64Image,
    });
  }

  Future<List<Map<String, dynamic>>> getImageFromDatabase(String idPemeriksaan) async {
    try {
      final db = await database;

      if (idPemeriksaan.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> results = await db.query(
        'Dokumentasi_Periksa',
        where: 'id_pemeriksaan = ?',
        whereArgs: [idPemeriksaan],
      );

      final processedResults = results.map((map) {
        final processedMap = Map<String, dynamic>.from(map);
        if (processedMap.containsKey('id') && processedMap['id'] == null) {
          processedMap['id'] = 0;
        }
        return processedMap;
      }).toList();

      return processedResults;
    } catch (e) {
      if (kDebugMode) {
        print('Error in getImageFromDatabase: $e');
      }
      return [];
    }
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

  // UPDATED: Menggunakan SuratTugasService.submitHasilPemeriksaan yang sudah direvisi
  Future<bool> sendHasilPemeriksaanToServer(HasilPemeriksaan hasil, List<Uint8List> photos, String userNip) async {
    try {
      if (kDebugMode) {
        print('🔄 DatabaseHelper: Mengirim hasil pemeriksaan menggunakan SuratTugasService...');
      }

      // Gunakan service yang sudah direvisi
      bool success = await SuratTugasService.submitHasilPemeriksaan(hasil, photos, userNip);

      if (kDebugMode) {
        if (success) {
          print('✅ DatabaseHelper: Hasil pemeriksaan berhasil dikirim ke server');
        } else {
          print('❌ DatabaseHelper: Gagal mengirim hasil pemeriksaan ke server');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ DatabaseHelper Exception: $e');
      }
      return false;
    }
  }

  // UPDATED: Menggunakan HasilPemeriksaan model dan service yang baru
  Future<void> syncSingleData(String id, String userNip) async {
    try {
      // Validasi input
      if (id.isEmpty || userNip.isEmpty) {
        if (kDebugMode) {
          print('❌ Parameter tidak valid - ID: "$id", NIP: "$userNip"');
        }
        return;
      }

      final db = await database;
      final data = await db.query('Hasil_Pemeriksaan', where: 'id_pemeriksaan = ?', whereArgs: [id]);

      if (data.isNotEmpty) {
        // Convert ke HasilPemeriksaan model
        final hasilPemeriksaan = HasilPemeriksaan.fromMap(data.first);

        // Load foto sebagai Uint8List
        final photos = await loadImagesFromDb(id);

        if (kDebugMode) {
          print('🔄 Attempting to sync single data for ID: $id');
          print('📄 Hasil Pemeriksaan: ${hasilPemeriksaan.toString()}');
          print('📷 Photos Count: ${photos.length}');
        }

        // Kirim ke server menggunakan service yang sudah direvisi
        bool success = await sendHasilPemeriksaanToServer(hasilPemeriksaan, photos, userNip);

        if (success) {
          if (kDebugMode) print('✅ Server sync successful for ID: $id. Updating local syncdata status.');
          await db.update(
            'Hasil_Pemeriksaan',
            {'syncdata': 1},
            where: 'id_pemeriksaan = ?',
            whereArgs: [id],
          );
        } else {
          if (kDebugMode) print('❌ Server sync failed for ID: $id. Local syncdata status remains 0.');
        }
      } else {
        if (kDebugMode) print('❌ Data dengan ID $id tidak ditemukan di database');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Exception dalam syncSingleData: $e');
    }
  }

  Future<void> syncUnsentData(String userNip) async {
    try {
      // Validasi NIP
      if (userNip.isEmpty) {
        if (kDebugMode) {
          print('❌ userNip kosong, tidak dapat sync data yang belum terkirim');
        }
        return;
      }

      final db = await database;
      final unsynced = await db.query('Hasil_Pemeriksaan', where: 'syncdata = 0');

      if (kDebugMode) print('📊 Found ${unsynced.length} unsynced items for NIP: $userNip');

      for (final data in unsynced) {
        final id = data['id_pemeriksaan'];
        if (id != null && id.toString().isNotEmpty) {
          await syncSingleData(id.toString(), userNip);
        } else {
          if (kDebugMode) print('⚠️ Skipping data dengan id_pemeriksaan null/kosong: $data');
        }
      }

      if (kDebugMode) print('✅ Sync unsynced data completed for NIP: $userNip');
    } catch (e) {
      if (kDebugMode) print('❌ Exception dalam syncUnsentData: $e');
    }
  }

  // UPDATED: Method untuk mendapatkan data yang belum tersync
  Future<List<HasilPemeriksaan>> getUnsyncedData() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'Hasil_Pemeriksaan',
        where: 'syncdata = 0',
        orderBy: 'tgl_periksa DESC',
      );

      return List.generate(maps.length, (i) {
        return HasilPemeriksaan.fromMap(maps[i]);
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error get unsynced data: $e');
      }
      return [];
    }
  }

  // UPDATED: Method untuk update status sync
  Future<void> updateSyncStatus(String idPemeriksaan, int syncStatus) async {
    try {
      final db = await database;
      await db.update(
        'Hasil_Pemeriksaan',
        {'syncdata': syncStatus},
        where: 'id_pemeriksaan = ?',
        whereArgs: [idPemeriksaan],
      );

      if (kDebugMode) {
        print('✅ Update sync status untuk ID: $idPemeriksaan -> $syncStatus');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error update sync status: $e');
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
    _database = null; // Reset instance
    if (kDebugMode) {
      print('Database berhasil dihapus');
    }
  }
}