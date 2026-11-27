import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/screens/tickets_screen.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La PWA no tiene plugin de sqflite: Soporte debe funcionar solo con la API.
void main() {
  setUp(() async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    await ApiService.guardarSesion('token-web', 'Ana', 'ana@test.com');
  });

  tearDown(() => ApiService.httpClient = http.Client());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TicketsScreen(usarSQLite: false))));
    await tester.pumpAndSettle();
  }

  testWidgets('la web lista tickets sin tocar SQLite', (tester) async {
    ApiService.httpClient = MockClient((_) async => http.Response(
          jsonEncode([
            {
              'id': 7,
              'asunto': 'No carga una portada',
              'descripcion': 'Revisión del catálogo',
              'prioridad': 'Media',
              'estado': 'Abierto',
              'fecha_creacion': '2026-11-27T10:00:00Z',
            }
          ]),
          200,
        ));

    await montar(tester);

    expect(find.text('Mis tickets'), findsOneWidget);
    expect(find.textContaining('No carga una portada'), findsOneWidget);
    expect(find.text('Consultando...'), findsNothing);
  });

  testWidgets('la web muestra error claro sin caer en SQLite offline',
      (tester) async {
    ApiService.httpClient =
        MockClient((_) async => http.Response('{"error":"sin servicio"}', 503));

    await montar(tester);

    expect(find.text('No fue posible obtener la información.'), findsWidgets);
    expect(
      find.text('Sin conexión: mostrando los tickets guardados.'),
      findsNothing,
    );
  });
}
