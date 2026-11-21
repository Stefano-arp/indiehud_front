import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indiehud/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Caso defensivo: una base marcada como v1 que ya contiene es_favorito.
/// Cubre la rama en la que onUpgrade detecta que la columna ya existe.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('indiehud_wb_mig1c_');
    await databaseFactory.setDatabasesPath(tempDir.path);

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
              categoria TEXT,
              es_favorito INTEGER DEFAULT 0
            )
          ''');
        },
      ),
    );
    await legacy.insert('biblioteca_local', {
      'id': 3,
      'titulo': 'Juego v1 con columna',
      'es_favorito': 1,
    });
    await legacy.close();

    await DatabaseHelper.database;
  });

  tearDownAll(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('no duplica la columna y conserva los datos', () async {
    final db = await DatabaseHelper.database;
    final columnas = await db.rawQuery('PRAGMA table_info(biblioteca_local)');
    expect(columnas.where((c) => c['name'] == 'es_favorito').length, 1);

    final filas = await DatabaseHelper.obtenerBibliotecaLocal();
    expect(filas.single.titulo, 'Juego v1 con columna');
    expect(filas.single.esFavorito, isTrue);
  });
}
