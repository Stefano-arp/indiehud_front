import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/screens/profile_screen.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    await ApiService.cerrarSesion();
    ApiService.httpClient = MockClient((_) async => http.Response('[]', 200));
  });

  tearDown(() => ApiService.httpClient = http.Client());

  testWidgets('el acceso dice Crear cuenta y no muestra estado de red',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
    await tester.pump();

    expect(find.text('Iniciar sesión'), findsWidgets);
    final titulo = tester.widget<Text>(find.text('Iniciar sesión').first);
    expect(titulo.style?.decoration, TextDecoration.none);

    await tester.tap(find.text('¿No tienes cuenta? Crear cuenta'));
    await tester.pump();

    expect(find.text('Crear cuenta'), findsWidgets);
    expect(find.text('Crear cuenta en IndieHub'), findsNothing);
    expect(find.textContaining('Conectado por'), findsNothing);
    expect(find.textContaining('Sin conexión'), findsNothing);
  });

  testWidgets('con sesión no hay bloqueo ni vista de desbloqueo',
      (tester) async {
    await ApiService.guardarSesion('token', 'Ana', 'ana@test.com');

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
    await tester.pump();

    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('Bloquear sesión'), findsNothing);
    expect(find.text('Sesión protegida con Biometría'), findsNothing);
    expect(find.text('Desbloquear con Huella'), findsNothing);
  });

  testWidgets('el enlace Bluetooth usa la guía sin canal nativo',
      (tester) async {
    await ApiService.guardarSesion('token', 'Ana', 'ana@test.com');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProfileScreen(sinBluetoothNativo: true)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vincular Control Indie (Bluetooth)').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('El escaneo BLE está disponible en la app de Android.'),
      findsOneWidget,
    );
  });
}
