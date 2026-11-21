import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indiehud/database/database_helper.dart';
import 'package:indiehud/models/juego.dart';
import 'package:indiehud/models/ticket.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pruebas White Box de la capa de persistencia SQLite (modo offline).
/// Ejercitan INSERT, SELECT, UPDATE, DELETE, restricciones y concurrencia.
void main() {
  late Directory tempDir;

  Juego juego(int id, {String? titulo, bool favorito = false}) => Juego(
        id: id,
        titulo: titulo ?? 'Juego $id',
        descripcion: 'Descripción $id',
        precio: 10.0 + id,
        desarrollador: 'Dev $id',
        portadaUrl: 'https://img/$id.png',
        categoria: 'Categoria $id',
        esFavorito: favorito,
      );

  Ticket ticket(int id, {String fecha = '2026-11-12T02:00:00'}) => Ticket(
        id: id,
        asunto: 'Asunto $id',
        descripcion: 'Descripción $id',
        prioridad: 'Media',
        estado: 'Abierto',
        fechaCreacion: fecha,
      );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('indiehud_wb_db_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.database; // crea el esquema versión 3
  });

  tearDownAll(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await DatabaseHelper.limpiarBibliotecaLocal();
    await DatabaseHelper.limpiarTicketsLocal();
  });

  group('biblioteca_local', () {
    test('INSERT + SELECT: sincroniza y recupera modelos', () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1), juego(2)]);

      final locales = await DatabaseHelper.obtenerBibliotecaLocal();
      expect(locales.length, 2);
      expect(locales.first.titulo, 'Juego 1');
      expect(locales.first.precio, 11.0);
      expect(locales.first.esFavorito, isFalse);
    });

    test('UPDATE: alterna favorito en ambos sentidos', () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1)]);

      await DatabaseHelper.alternarFavorito(1, true);
      var locales = await DatabaseHelper.obtenerBibliotecaLocal();
      expect(locales.single.esFavorito, isTrue);

      await DatabaseHelper.alternarFavorito(1, false);
      locales = await DatabaseHelper.obtenerBibliotecaLocal();
      expect(locales.single.esFavorito, isFalse);
    });

    test('la resincronización conserva el favorito local', () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1), juego(2)]);
      await DatabaseHelper.alternarFavorito(1, true);

      // La nube devuelve el juego 1 con otro título y agrega el 3.
      await DatabaseHelper.sincronizarBiblioteca(
          [juego(1, titulo: 'Juego 1 actualizado'), juego(3)]);

      final locales = await DatabaseHelper.obtenerBibliotecaLocal();
      expect(locales.length, 2);
      final uno = locales.firstWhere((j) => j.id == 1);
      expect(uno.titulo, 'Juego 1 actualizado');
      expect(uno.esFavorito, isTrue,
          reason: 'El favorito del dispositivo no debe perderse');
      expect(locales.any((j) => j.id == 2), isFalse);
    });

    test('DELETE: elimina solo el registro solicitado', () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1), juego(2)]);

      await DatabaseHelper.eliminarJuegoLocal(1);

      final locales = await DatabaseHelper.obtenerBibliotecaLocal();
      expect(locales.length, 1);
      expect(locales.single.id, 2);
    });

    test('DELETE inexistente no lanza excepción', () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1)]);
      await DatabaseHelper.eliminarJuegoLocal(12345);
      expect((await DatabaseHelper.obtenerBibliotecaLocal()).length, 1);
    });

    test('sincronizar lista vacía limpia la caché', () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1)]);
      await DatabaseHelper.sincronizarBiblioteca([]);
      expect(await DatabaseHelper.obtenerBibliotecaLocal(), isEmpty);
    });

    test('NOT NULL: rechaza título nulo', () async {
      final db = await DatabaseHelper.database;
      await expectLater(
        db.insert('biblioteca_local', {
          'id': 99,
          'titulo': null,
          'precio': 1.0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('PRIMARY KEY: rechaza id duplicado', () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1)]);
      final db = await DatabaseHelper.database;
      await expectLater(
        db.insert('biblioteca_local', juego(1).toMap()),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('concurrencia: dos UPDATE simultáneos no corrompen la fila',
        () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1)]);

      await Future.wait([
        DatabaseHelper.alternarFavorito(1, true),
        DatabaseHelper.alternarFavorito(1, false),
      ]);

      final locales = await DatabaseHelper.obtenerBibliotecaLocal();
      expect(locales.length, 1);
      expect(locales.single.esFavorito, anyOf(isTrue, isFalse));
    });

    test('limpiarBibliotecaLocal deja la tabla vacía', () async {
      await DatabaseHelper.sincronizarBiblioteca([juego(1), juego(2)]);
      await DatabaseHelper.limpiarBibliotecaLocal();
      expect(await DatabaseHelper.obtenerBibliotecaLocal(), isEmpty);
    });
  });

  group('tickets_local', () {
    test('INSERT + SELECT ordenado por fecha descendente', () async {
      await DatabaseHelper.sincronizarTickets([
        ticket(1, fecha: '2026-11-10T10:00:00'),
        ticket(2, fecha: '2026-11-12T10:00:00'),
      ]);

      final locales = await DatabaseHelper.obtenerTicketsLocal();
      expect(locales.length, 2);
      expect(locales.first.id, 2);
      expect(locales.last.id, 1);
    });

    test('la resincronización reemplaza la caché anterior', () async {
      await DatabaseHelper.sincronizarTickets([ticket(1), ticket(2)]);
      await DatabaseHelper.sincronizarTickets([ticket(3)]);

      final locales = await DatabaseHelper.obtenerTicketsLocal();
      expect(locales.single.id, 3);
    });

    test('NOT NULL: rechaza asunto nulo', () async {
      final db = await DatabaseHelper.database;
      await expectLater(
        db.insert('tickets_local', {'id': 9, 'asunto': null}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('limpiarTicketsLocal deja la tabla vacía', () async {
      await DatabaseHelper.sincronizarTickets([ticket(1)]);
      await DatabaseHelper.limpiarTicketsLocal();
      expect(await DatabaseHelper.obtenerTicketsLocal(), isEmpty);
    });
  });
}
