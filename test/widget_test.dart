import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/main.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:indiehud/services/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    ApiService.httpClient = http.Client();
    SessionController.activa.value = false;
  });

  testWidgets('IndieHub arranca en la Tienda', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiService.httpClient = MockClient((_) async => http.Response('[]', 200));
    SessionController.activa.value = false;

    await tester.pumpWidget(const IndieHubApp());
    await tester.pump();

    expect(find.text('IndieHub'), findsOneWidget);
    expect(find.text('TIENDA · JUEGOS INDIE'), findsOneWidget);
  });

  testWidgets('sin sesión solo se muestra la Tienda', (WidgetTester tester) async {
    ApiService.httpClient = MockClient((_) async => http.Response('[]', 200));
    SessionController.activa.value = false;

    await tester.pumpWidget(const MaterialApp(home: MainNavigator()));
    await tester.pump();

    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.text('Biblioteca'), findsNothing);
    expect(find.text('Soporte'), findsNothing);
    expect(find.text('Perfil'), findsNothing);
    // La Tienda ofrece la única puerta de acceso al inicio de sesión.
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('con sesión se muestran todas las secciones',
      (WidgetTester tester) async {
    ApiService.httpClient = MockClient((_) async => http.Response('[]', 200));
    SessionController.activa.value = true;

    await tester.pumpWidget(const MaterialApp(home: MainNavigator()));
    await tester.pump();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Tienda'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });
}
