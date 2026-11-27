import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/screens/steam_web_shell.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:indiehud/services/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalogoPrueba = [
  {
    'id': 1,
    'titulo': 'Neon Requiem',
    'descripcion': 'Un viaje neonado.',
    'precio': 19.99,
    'desarrollador': 'Indie Dev',
    'portada_url': 'https://images.unsplash.com/ejemplo',
    'categoria': 'Acción',
  },
  {
    'id': 2,
    'titulo': 'Midnight Drift',
    'descripcion': 'Carreras nocturnas.',
    'precio': 9.99,
    'desarrollador': 'DriftTeam',
    'portada_url': 'https://images.unsplash.com/ejemplo2',
    'categoria': 'Arcade racing',
  },
];

void main() {
  setUp(() {
    ApiService.httpClient = MockClient(
      (_) async => http.Response(jsonEncode(_catalogoPrueba), 200),
    );
  });

  tearDown(() {
    ApiService.httpClient = http.Client();
    SessionController.activa.value = false;
  });

  Future<void> montar(WidgetTester tester, {double ancho = 1200}) async {
    tester.view.physicalSize = Size(ancho, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SteamWebShell()));
    await tester.pumpAndSettle();
  }

  testWidgets('sin sesión la web solo ofrece la Tienda y el acceso',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    SessionController.activa.value = false;

    await montar(tester);

    expect(find.text('BIBLIOTECA'), findsNothing);
    expect(find.text('SOPORTE'), findsNothing);
    expect(find.text('PERFIL'), findsNothing);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    // El lateral es de filtros, nunca un segundo menú de navegación.
    expect(find.text('NAVEGACIÓN'), findsNothing);
    expect(find.text('CATEGORÍAS'), findsOneWidget);
  });

  testWidgets('con sesión hay una sola barra de navegación',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'token-1',
      'usuario_nombre': 'Ana',
    });
    SessionController.activa.value = true;

    await montar(tester);

    expect(find.text('TIENDA'), findsOneWidget);
    expect(find.text('BIBLIOTECA'), findsOneWidget);
    expect(find.text('SOPORTE'), findsOneWidget);
    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('NAVEGACIÓN'), findsNothing);
    expect(find.text('Mi cuenta'), findsNothing);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('la Tienda web tiene un buscador, secciones y pie',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    SessionController.activa.value = false;

    await montar(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Destacados para ti'), findsOneWidget);
    expect(find.text('Novedades'), findsOneWidget);
    expect(find.text('IndieHub · Juegos independientes'), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);
  });

  testWidgets('el pie con sesión ofrece ayuda sin duplicar el menú',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'token-1',
      'usuario_nombre': 'Ana',
    });
    SessionController.activa.value = true;

    await montar(tester);

    expect(find.text('Centro de ayuda'), findsOneWidget);
    expect(find.text('Mi cuenta'), findsNothing);
    expect(find.text('BIBLIOTECA'), findsOneWidget);
  });

  testWidgets('el distribución mantiene un solo buscador de 800 a 1920 px',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    SessionController.activa.value = false;

    for (final ancho in [800.0, 1024.0, 1440.0, 1920.0]) {
      await montar(tester, ancho: ancho);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Desbordamiento o error en $ancho px',
      );
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'Buscador duplicado en $ancho px',
      );
    }
  });
}
