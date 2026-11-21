import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indiehud/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Cubre la rama oldVersion >= 2 de onUpgrade (esquema v2 sin tickets_local).
void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('indiehud_wb_mig2_');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final legacy = await databaseFactory.openDatabase(
      p.join(tempDir.path, 'indiehub_offline.db'),
      options: OpenDatabaseOptions(
        version: 2,
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
        },
      ),
    );
    await legacy.insert('biblioteca_local', {
      'id': 2,
      'titulo': 'Juego v2',
      'precio': 7.5,
      'es_favorito': 1,
    });
    await legacy.close();

    await DatabaseHelper.database; // ejecuta onUpgrade(2 -> 3)
  });

  tearDownAll(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('no altera la columna existente y conserva el favorito', () async {
    final filas = await DatabaseHelper.obtenerBibliotecaLocal();
    expect(filas.single.id, 2);
    expect(filas.single.esFavorito, isTrue);
  });

  test('crea tickets_local desde la versión 2', () async {
    final db = await DatabaseHelper.database;
    final tablas = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tickets_local'");
    expect(tablas.length, 1);
  });
}
