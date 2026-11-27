import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/database/database_helper.dart';
import 'package:indiehud/models/juego.dart';
import 'package:indiehud/screens/game_detail_screen.dart';
import 'package:indiehud/screens/library_screen.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:indiehud/services/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// connectivity_plus no tiene canal nativo en pruebas: se simula con Wi-Fi.
class _ConnectivityMock extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    events.success(const <String>['wifi']);
  }

  @override
  void onCancel(Object? arguments) {}
}

void main() {
  late Juego juego;
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('indiehud_logic_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    await DatabaseHelper.database;
  });

  tearDownAll(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    await ApiService.cerrarSesion();
    SessionController.activa.value = false;
    SessionController.seccion.value = 0;
    juego = Juego(
      id: 8,
      titulo: 'Neon Requiem',
      descripcion: 'Un viaje neonado.',
      precio: 19.99,
      desarrollador: 'Indie Dev',
      portadaUrl: 'https://images.unsplash.com/ejemplo',
      categoria: 'Acción',
    );
  });

  tearDown(() => ApiService.httpClient = http.Client());

  test('sincronización SQLite directa', () async {
    await DatabaseHelper.sincronizarBiblioteca([juego]);
    expect(await DatabaseHelper.obtenerBibliotecaLocal(), hasLength(1));
  });

  testWidgets('la ficha abierta desde biblioteca no ofrece comprar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GameDetailScreen(juego: juego, enBiblioteca: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('YA ESTÁ EN TU BIBLIOTECA'), findsOneWidget);
    expect(find.text('Ver mi biblioteca'), findsOneWidget);
    expect(find.textContaining('COMPRAR AHORA'), findsNothing);
    expect(find.text('Este título ya está en tu biblioteca.'), findsOneWidget);
  });

  testWidgets('la ficha sin sesión ofrece acceso en vez de compra',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GameDetailScreen(juego: juego)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('INICIAR SESIÓN PARA COMPRAR'), findsOneWidget);
    expect(find.text('Inicia sesión para adquirir este título.'), findsOneWidget);
    expect(find.textContaining('COMPRAR AHORA'), findsNothing);

    await tester.ensureVisible(find.text('INICIAR SESIÓN PARA COMPRAR'));
    await tester.pump();
    await tester.tap(find.text('INICIAR SESIÓN PARA COMPRAR'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Iniciar sesión'), findsWidgets);
  });

  testWidgets('la ficha detecta los juegos ya comprados desde la Tienda',
      (tester) async {
    await ApiService.guardarSesion('token', 'Ana', 'ana@test.com');
    ApiService.httpClient =
        MockClient((_) async => http.Response('[4, 8]', 200));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GameDetailScreen(juego: juego)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('YA ESTÁ EN TU BIBLIOTECA'), findsOneWidget);
    expect(find.textContaining('COMPRAR AHORA'), findsNothing);
  });

  testWidgets('si falla la comprobación no ofrece compra y permite reintentar',
      (tester) async {
    await ApiService.guardarSesion('token', 'Ana', 'ana@test.com');
    var fallos = 1;
    ApiService.httpClient = MockClient((req) async {
      if (req.url.path.endsWith('/biblioteca/ids')) {
        if (fallos > 0) {
          fallos--;
          return http.Response('{"error":"servidor no disponible"}', 503);
        }
        return http.Response('[8]', 200);
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GameDetailScreen(juego: juego)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NO SE PUDO COMPROBAR TU BIBLIOTECA'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.textContaining('COMPRAR AHORA'), findsNothing);
    expect(
      find.text('No se pudo comprobar tu biblioteca. Reintenta antes de comprar.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Reintentar'));
    await tester.pump();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('YA ESTÁ EN TU BIBLIOTECA'), findsOneWidget);
    expect(find.textContaining('COMPRAR AHORA'), findsNothing);
  });

  testWidgets('la ficha ofrece compra si la sesión no tiene el juego',
      (tester) async {
    await ApiService.guardarSesion('token', 'Ana', 'ana@test.com');
    ApiService.httpClient = MockClient((_) async => http.Response('[]', 200));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GameDetailScreen(juego: juego)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('COMPRAR AHORA'), findsOneWidget);
    expect(find.text('YA ESTÁ EN TU BIBLIOTECA'), findsNothing);
  });

  testWidgets('la ficha muestra juegos similares recibidos', (tester) async {
    final otro = Juego(
      id: 9,
      titulo: 'Neon Drift',
      descripcion: 'Otro viaje neonado.',
      precio: 7.5,
      desarrollador: 'DriftTeam',
      portadaUrl: 'https://images.unsplash.com/otro',
      categoria: 'Acción',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GameDetailScreen(
          juego: juego,
          relacionados: [otro],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('JUEGOS SIMILARES'), findsOneWidget);
    expect(find.text('Neon Drift'), findsOneWidget);
  });

  testWidgets('la biblioteca alterna vista y filtra localmente',
      (tester) async {
    await ApiService.guardarSesion('token', 'Ana', 'ana@test.com');
    ApiService.httpClient = MockClient((req) async {
      if (req.url.path.endsWith('/biblioteca')) {
        return http.Response(
          jsonEncode([
            juego.toMap()
              ..['portada_url'] = juego.portadaUrl
              ..['es_favorito'] = 0,
            {
              'id': 9,
              'titulo': 'Neon Drift',
              'descripcion': 'Otro viaje neonado.',
              'precio': 7.5,
              'desarrollador': 'DriftTeam',
              'portada_url': 'https://images.unsplash.com/otro',
              'categoria': 'Acción',
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      _ConnectivityMock(),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LibraryScreen())),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.byIcon(Icons.view_list));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byIcon(Icons.more_horiz), findsNWidgets(2));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('biblioteca_vista_lista'), isTrue);

    await tester.enterText(find.byType(TextField).first, 'Requiem');
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Neon Requiem'), findsOneWidget);
    expect(find.text('Neon Drift'), findsNothing);
  });

  testWidgets('el menú de biblioteca elimina de verdad la compra',
      (tester) async {
    await ApiService.guardarSesion('token', 'Ana', 'ana@test.com');
    final peticiones = <http.Request>[];
    ApiService.httpClient = MockClient((req) async {
      peticiones.add(req);
      if (req.url.path.endsWith('/biblioteca')) {
        return http.Response(
          jsonEncode([
            {
              'id': 8,
              'titulo': 'Neon Requiem',
              'descripcion': 'Un viaje neonado.',
              'precio': 19.99,
              'desarrollador': 'Indie Dev',
              'portada_url': 'https://images.unsplash.com/ejemplo',
              'categoria': 'Acción',
            }
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      _ConnectivityMock(),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LibraryScreen())),
    );
    // SQLite FFI necesita tiempo real: se ejecuta fuera del zone de pruebas.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.byIcon(Icons.more_horiz));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Eliminar de biblioteca'), findsOneWidget);
    expect(find.text('Eliminar copia local'), findsNothing);
    expect(find.text('Ver información'), findsOneWidget);

    await tester.tap(find.text('Eliminar de biblioteca'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('¿Eliminar "Neon Requiem"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      peticiones.any((r) =>
          r.method == 'DELETE' && r.url.path.endsWith('/biblioteca/8')),
      isTrue,
    );
    expect(
      find.text('"Neon Requiem" eliminado de tu biblioteca'),
      findsOneWidget,
    );
  });
}
