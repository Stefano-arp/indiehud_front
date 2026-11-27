import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/screens/steam_web_shell.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:indiehud/services/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    ApiService.httpClient = MockClient((_) async => http.Response('[]', 200));
  });

  tearDown(() {
    ApiService.httpClient = http.Client();
    SessionController.activa.value = false;
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SteamWebShell()));
    await tester.pump();
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
}
