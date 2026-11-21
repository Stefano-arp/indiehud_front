import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indiehud/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Verifica la migración v1 -> v3 de DatabaseHelper sin perder datos.
/// Archivo separado para que el singleton de DatabaseHelper arranque limpio.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('indiehud_wb_mig_');
    await databaseFactory.setDatabasesPath(tempDir.path);

    // Crea una base "legacy" versión 1 sin es_favorito ni tickets_local.
    final legacy = await databaseFactory.openDatabase(
      p.join(tempDir.path, 'indiehub_offline.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE biblioteca_local(
              id INTEGER PRIMARY KEY,
              titulo TEXT NOT NULL,
              descripcion TEXT,
              precio REAL,
              desarrollador TEXT,
              portada_url TEXT,
              categoria TEXT
            )
          ''');
        },
      ),
    );
    await legacy.insert('biblioteca_local', {
      'id': 1,
      'titulo': 'Juego legado',
      'precio': 5.0,
      'categoria': 'Aventura',
    });
    await legacy.close();

    // Al abrir con DatabaseHelper se ejecuta onUpgrade(oldVersion: 1).
    await DatabaseHelper.database;
  });

  tearDownAll(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('agrega la columna es_favorito y conserva la fila existente', () async {
    final db = await DatabaseHelper.database;
    final columnas = await db.rawQuery('PRAGMA table_info(biblioteca_local)');
    expect(columnas.any((c) => c['name'] == 'es_favorito'), isTrue);

    final filas = await db.query('biblioteca_local');
    expect(filas.length, 1);
    expect(filas.single['titulo'], 'Juego legado');
    expect(filas.single['es_favorito'], 0);
  });

  test('crea la tabla tickets_local durante la migración', () async {
    final db = await DatabaseHelper.database;
    final tablas = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tickets_local'");
    expect(tablas.length, 1);
  });

  test('el esquema migrado admite las operaciones de tickets', () async {
    await DatabaseHelper.sincronizarTickets([]);
    expect(await DatabaseHelper.obtenerTicketsLocal(), isEmpty);
  });
}
