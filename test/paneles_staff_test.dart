import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/screens/steam_web_shell.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:indiehud/services/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _base64(Map<String, dynamic> datos) =>
    base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');

String _token(String rol, String correo) =>
    '${_base64({'alg': 'HS256', 'typ': 'JWT'})}.'
    '${_base64({'id': 9, 'nombre': 'Staff', 'correo': correo, 'rol': rol})}.firma';

const _catalogo = [
  {
    'id': 1001,
    'titulo': 'Neon Requiem',
    'descripcion': 'Un RPG cyberpunk.',
    'precio': 19.99,
    'desarrollador': 'Null Signal Studio',
    'portada_url': 'https://picsum.photos/seed/neon/600/338',
    'categoria': 'Cyberpunk RPG',
  },
];

const _tickets = [
  {
    'id': 7,
    'asunto': 'No puedo iniciar sesión',
    'descripcion': 'El botón no responde en la PWA.',
    'prioridad': 'Alta',
    'estado': 'Abierto',
    'fecha_creacion': '2026-11-27T10:00:00',
    'respuesta': null,
    'usuarios': {'id': 3, 'nombre': 'Ana', 'correo': 'ana@test.com'},
  },
];

const _estadisticas = {
  'juegos_publicados': 30,
  'ventas': 12480,
  'visitas': 58920,
  'ingresos': 96435.5,
  'valoracion_media': 4.7,
  'tendencia': [
    {'mes': 'Oct', 'juegos': 9},
    {'mes': 'Nov', 'juegos': 12},
  ],
};

void main() {
  final publicados = <http.Request>[];
  final actualizados = <http.Request>[];
  final eliminados = <http.Request>[];
  final respuestas = <String>[];
  var errorTickets = '';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    publicados.clear();
    actualizados.clear();
    eliminados.clear();
    respuestas.clear();
    errorTickets = '';
    ApiService.httpClient = MockClient((req) async {
      final ruta = req.url.path;
      if (ruta.endsWith('/rol-acceso')) {
        final cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
        final correo = cuerpo['correo']?.toString() ?? '';
        final rol = correo.contains('soporte') ? 'soporte' : 'desarrollador';
        return http.Response(jsonEncode({'rol': rol}), 200);
      }
      if (ruta.endsWith('/login')) {
        final cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
        final correo = cuerpo['correo']?.toString() ?? '';
        final rol = correo.contains('soporte') ? 'soporte' : 'desarrollador';
        return http.Response(
          jsonEncode({
            'token': _token(rol, correo),
            'usuario': {
              'id': 9,
              'nombre': 'Staff',
              'correo': correo,
              'rol': rol,
            },
          }),
          200,
        );
      }
      if (ruta.endsWith('/desarrollador/estadisticas')) {
        return http.Response(jsonEncode(_estadisticas), 200);
      }
      if (ruta.contains('/juegos/')) {
        if (req.method == 'PUT') {
          actualizados.add(req);
          return http.Response(
            jsonEncode({'mensaje': 'Juego actualizado', 'juego': _catalogo[0]}),
            200,
          );
        }
        if (req.method == 'DELETE') {
          eliminados.add(req);
          return http.Response(jsonEncode({'mensaje': 'Juego eliminado'}), 200);
        }
      }
      if (ruta.endsWith('/juegos')) {
        if (req.method == 'POST') {
          publicados.add(req);
          return http.Response(
            jsonEncode({'mensaje': 'Juego publicado', 'juego': _catalogo[0]}),
            201,
          );
        }
        return http.Response(jsonEncode(_catalogo), 200);
      }
      if (ruta.contains('/soporte/tickets')) {
        if (errorTickets.isNotEmpty) {
          return http.Response(jsonEncode({'error': errorTickets}), 503);
        }
        if (req.method == 'PATCH') {
          respuestas.add(req.body);
          return http.Response(jsonEncode({'mensaje': 'Ticket actualizado'}), 200);
        }
        return http.Response(jsonEncode(_tickets), 200);
      }
      return http.Response('[]', 200);
    });
  });

  tearDown(() {
    ApiService.httpClient = http.Client();
    SessionController.activa.value = false;
    SessionController.seccion.value = 0;
    SessionController.rol.value = 'usuario';
  });

  Future<void> montar(WidgetTester tester, String rol) async {
    final correo = rol == 'soporte'
        ? 'soporte@indiehud.local'
        : 'desarrollador@indiehud.local';
    SharedPreferences.setMockInitialValues({
      'jwt_token': _token(rol, correo),
      'usuario_nombre': 'Staff',
    });
    SessionController.activa.value = true;
    SessionController.rol.value = rol;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SteamWebShell()));
    await tester.pumpAndSettle();
  }

  testWidgets('el desarrollador solo ve su panel y puede publicar',
      (WidgetTester tester) async {
    await montar(tester, 'desarrollador');

    expect(find.text('PANEL'), findsOneWidget);
    expect(find.text('TIENDA'), findsNothing);
    expect(find.text('BIBLIOTECA'), findsNothing);
    expect(find.text('SOPORTE'), findsNothing);
    expect(find.text('PERFIL'), findsNothing);
    expect(find.text('Catálogo'), findsNothing);
    expect(find.text('Buscar juegos...'), findsNothing);
    // Seis campos del formulario más el buscador interno del catálogo.
    expect(find.byType(TextField), findsNWidgets(7));
    expect(find.text('Ventas'), findsOneWidget);
    expect(find.text('Simulados'), findsNothing);
    expect(find.text('Neon Requiem'), findsOneWidget);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Nuevo juego indie');
    await tester.enterText(campos.at(1), 'Descripción del juego');
    await tester.enterText(campos.at(2), 'Puzzle');
    await tester.enterText(campos.at(5), 'https://ejemplo.test/portada.png');
    final botonPublicar = find.widgetWithText(ElevatedButton, 'Publicar juego');
    final panelDesplazable = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView && widget.scrollDirection == Axis.vertical,
    );
    await tester.drag(panelDesplazable, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(botonPublicar);
    await tester.pumpAndSettle();

    expect(publicados, hasLength(1));
    expect(publicados.single.body, contains('Nuevo juego indie'));
    expect(publicados.single.body, contains('Puzzle'));
    expect(
      publicados.single.body,
      contains('https://ejemplo.test/portada.png'),
    );
  });

  testWidgets('soporte solo ve tickets, filtra y responde',
      (WidgetTester tester) async {
    await montar(tester, 'soporte');

    expect(find.text('TICKETS'), findsOneWidget);
    expect(find.text('TIENDA'), findsNothing);
    expect(find.text('BIBLIOTECA'), findsNothing);
    expect(find.text('PERFIL'), findsNothing);
    expect(find.text('Catálogo'), findsNothing);
    expect(find.text('Atender tickets'), findsOneWidget);
    expect(find.textContaining('No puedo iniciar sesión'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Cerrado'));
    await tester.pumpAndSettle();
    expect(find.text('No hay tickets en este estado.'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('No puedo iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Guardar respuesta'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Revisaremos el caso.');
    await tester.tap(find.text('Guardar respuesta'));
    await tester.pumpAndSettle();

    expect(respuestas, hasLength(1));
    expect(respuestas.single, contains('"estado":"En proceso"'));
    expect(respuestas.single, contains('Revisaremos el caso.'));
  });

  testWidgets('soporte muestra el error del backend y no cierra sin respuesta',
      (WidgetTester tester) async {
    errorTickets = 'Falta ejecutar la migración SQL de roles y tickets';
    await montar(tester, 'soporte');

    expect(find.text(errorTickets), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    errorTickets = '';
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('No puedo iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrado').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar respuesta'));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe una respuesta antes de cerrar el ticket.'),
      findsOneWidget,
    );
    expect(respuestas, isEmpty);
  });

  testWidgets('el desarrollador edita y elimina juegos del catálogo',
      (WidgetTester tester) async {
    await montar(tester, 'desarrollador');

    final desplazable = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView && widget.scrollDirection == Axis.vertical,
    );
    await tester.drag(desplazable, const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Editar juego'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    final campos = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(campos.at(0)).controller?.text,
      'Neon Requiem',
    );
    await tester.enterText(campos.at(0), 'Neon Requiem Redux');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(actualizados, hasLength(1));
    expect(actualizados.single.method, 'PUT');
    expect(actualizados.single.url.path, contains('/juegos/1001'));
    expect(actualizados.single.body, contains('Neon Requiem Redux'));

    await tester.drag(desplazable, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar juego'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(eliminados, hasLength(1));
    expect(eliminados.single.method, 'DELETE');
    expect(eliminados.single.url.path, contains('/juegos/1001'));
  });

  test('las cuentas staff no alcanzan las secciones protegidas', () {
    SessionController.activa.value = true;

    SessionController.rol.value = 'desarrollador';
    SessionController.irA(3);
    expect(SessionController.seccion.value, 0);
    SessionController.abrirAcceso();
    expect(SessionController.seccion.value, 0);

    SessionController.rol.value = 'soporte';
    SessionController.irA(1);
    expect(SessionController.seccion.value, 0);

    SessionController.rol.value = 'usuario';
    SessionController.seccion.value = 0;
    SessionController.abrirAcceso();
    expect(SessionController.seccion.value, 3);
    SessionController.irA(2);
    expect(SessionController.seccion.value, 2);
  });

  test('el rol del JWT se restaura y el login staff no usa biometría', () async {
    final res = await ApiService.login('soporte@indiehud.local', 'IndieHub2026!');
    expect(res['usuario']['rol'], 'soporte');
    expect(SessionController.rol.value, 'soporte');

    final datos = await ApiService.leerUsuario();
    expect(datos['rol'], 'soporte');

    await ApiService.sincronizarSesion();
    expect(SessionController.rol.value, 'soporte');

    expect(
      await ApiService.consultarRolAcceso('soporte@indiehud.local', 'clave'),
      'soporte',
    );
    expect(
      await ApiService.consultarRolAcceso('desarrollador@indiehud.local', 'clave'),
      'desarrollador',
    );
  });

  test('el backend separa roles y prohíbe la biometría staff', () {
    final servidor = File('../indiehub-backend/server.js').readAsStringSync();
    expect(servidor, contains("requerirRol('desarrollador')"));
    expect(servidor, contains("requerirRol('soporte')"));
    expect(servidor, contains("plataforma !== 'web'"));
    expect(servidor, contains('Esta cuenta no usa verificación biométrica'));
    expect(servidor, contains("app.post(\n  '/api/juegos'"));
    expect(servidor, contains("app.put(\n  '/api/juegos/:id'"));
    expect(servidor, contains("app.delete(\n  '/api/juegos/:id'"));
    expect(servidor, contains("app.patch(\n  '/api/soporte/tickets/:id'"));
    expect(servidor, contains('Escribe una respuesta antes de cerrar el ticket'));
    expect(servidor, isNot(contains('simuladas')));

    final migracion = File(
      '../indiehub-backend/sql/2026-11-27_roles_panel.sql',
    ).readAsStringSync();
    expect(migracion, contains('desarrollador@indiehud.local'));
    expect(migracion, contains('soporte@indiehud.local'));
    expect(migracion, contains("default 'usuario'"));
    expect(migracion, contains("'portadas'"));

    final perfil = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(perfil, contains('ApiService.consultarRolAcceso(correo, password)'));
    expect(perfil, contains('Esta cuenta solo está disponible en la web'));
  });
}
