import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/juego.dart';
import '../models/ticket.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    // Soporte automático para Escritorio Linux y Android
    // (NO eliminar: requerido por AGENTS.md para CachyOS + APK).
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'indiehub_offline.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE biblioteca_local(
            id INTEGER PRIMARY KEY,
            titulo TEXT NOT NULL,
            descripcion TEXT,
            precio REAL,
            desarrollador TEXT,
            portada_url TEXT,
            categoria TEXT,
            es_favorito INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE tickets_local(
            id INTEGER PRIMARY KEY,
            asunto TEXT NOT NULL,
            descripcion TEXT,
            prioridad TEXT,
            estado TEXT,
            fecha_creacion TEXT
          )
        ''');
      },
      // Migración sin borrar datos previos (Práctica 4).
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final cols = await db.rawQuery('PRAGMA table_info(biblioteca_local)');
          final existe = cols.any((c) => c['name'] == 'es_favorito');
          if (!existe) {
            await db.execute(
                'ALTER TABLE biblioteca_local ADD COLUMN es_favorito INTEGER DEFAULT 0');
          }
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tickets_local(
              id INTEGER PRIMARY KEY,
              asunto TEXT NOT NULL,
              descripcion TEXT,
              prioridad TEXT,
              estado TEXT,
              fecha_creacion TEXT
            )
          ''');
        }
      },
    );
  }

  // Sincronizar los juegos descargados de la API hacia SQLite local,
  // preservando los favoritos marcados en el dispositivo.
  static Future<void> sincronizarBiblioteca(List<Juego> juegos) async {
    final db = await database;
    // Lee favoritos actuales para no perderlos con la resincronización.
    final actuales = await db.query('biblioteca_local', columns: ['id', 'es_favorito']);
    final favs = <int, int>{
      for (final m in actuales)
        (m['id'] as int): ((m['es_favorito'] as int?) ?? 0),
    };
    await db.delete('biblioteca_local'); // Limpiamos caché anterior
    for (var juego in juegos) {
      final mapa = juego.toMap();
      // Si ya era favorito en local, se conserva.
      if (favs[juego.id] == 1) mapa['es_favorito'] = 1;
      await db.insert(
        'biblioteca_local',
        mapa,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Leer los juegos guardados en SQLite cuando no hay internet (Modo Offline)
  static Future<List<Juego>> obtenerBibliotecaLocal() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('biblioteca_local');
    return List.generate(maps.length, (i) => Juego.fromJson(maps[i]));
  }

  // UPDATE: marcar / desmarcar favorito (Práctica 4).
  static Future<void> alternarFavorito(int id, bool estado) async {
    final db = await database;
    await db.update(
      'biblioteca_local',
      {'es_favorito': estado ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE: desinstalar copia local del dispositivo (Práctica 4).
  static Future<void> eliminarJuegoLocal(int id) async {
    final db = await database;
    await db.delete('biblioteca_local', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> limpiarBibliotecaLocal() async {
    final db = await database;
    await db.delete('biblioteca_local');
  }

  // ===== TICKETS DE SOPORTE (caché offline) =====
  static Future<void> sincronizarTickets(List<Ticket> tickets) async {
    final db = await database;
    await db.delete('tickets_local');
    for (final t in tickets) {
      await db.insert(
        'tickets_local',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<List<Ticket>> obtenerTicketsLocal() async {
    final db = await database;
    final maps = await db.query('tickets_local',
        orderBy: 'fecha_creacion DESC');
    return List.generate(maps.length, (i) => Ticket.fromJson(maps[i]));
  }

  static Future<void> limpiarTicketsLocal() async {
    final db = await database;
    await db.delete('tickets_local');
  }
}
