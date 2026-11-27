import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:indiehud/services/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pruebas White Box de ApiService usando MockClient.
/// Cubren caminos de éxito, error HTTP, token ausente, JSON inválido y timeout.
void main() {
  final peticiones = <http.Request>[];

  void responder(
    Future<http.Response> Function(http.Request) handler, {
    Duration? timeout,
  }) {
    peticiones.clear();
    ApiService.baseUrl = 'http://pruebas.local/api';
    ApiService.timeout = timeout ?? const Duration(milliseconds: 500);
    ApiService.httpClient = MockClient((request) async {
      peticiones.add(request);
      return handler(request);
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiService.httpClient = http.Client();
  });

  group('obtenerJuegos', () {
    test('200 devuelve la lista mapeada', () async {
      responder((_) async => http.Response(
            jsonEncode([
              {'id': 1, 'titulo': 'Neon Requiem', 'precio': 19.99},
              {'id': 2, 'titulo': 'Midnight Drift', 'precio': 9.99},
            ]),
            200,
          ));

      final juegos = await ApiService.obtenerJuegos();
      expect(juegos.length, 2);
      expect(juegos.first.titulo, 'Neon Requiem');
    });

    test('acepta el envelope paginado del backend', () async {
      responder((_) async => http.Response(
            jsonEncode({
              'total_registros': 1,
              'pagina_actual': 1,
              'total_paginas': 1,
              'datos': [
                {'id': 7, 'titulo': 'Neon Requiem', 'precio': 19.99},
              ],
            }),
            200,
          ));

      final juegos = await ApiService.obtenerJuegos();
      expect(juegos.length, 1);
      expect(juegos.first.titulo, 'Neon Requiem');
    });

    test('envía buscar y categoria como query params (con trim)', () async {
      responder((_) async => http.Response('[]', 200));

      await ApiService.obtenerJuegos(
        buscar: '  cyber  ',
        categoria: '  Cyberpunk RPG  ',
      );

      expect(peticiones.single.url.queryParameters['buscar'], 'cyber');
      expect(peticiones.single.url.queryParameters['categoria'],
          'Cyberpunk RPG');
    });

    test('omite parámetros vacíos y la categoría Todos', () async {
      responder((_) async => http.Response('[]', 200));

      await ApiService.obtenerJuegos(buscar: '   ', categoria: 'Todos');

      expect(peticiones.single.url.queryParameters, isEmpty);
    });

    test('status distinto de 200 lanza Exception', () async {
      responder((_) async => http.Response('{"error":"x"}', 500));
      expect(
        () => ApiService.obtenerJuegos(),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'mensaje', contains('No fue posible'))),
      );
    });

    test('JSON inválido se convierte en error de usuario', () async {
      responder((_) async => http.Response('no-es-json', 200));
      expect(
        () => ApiService.obtenerJuegos(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje',
            contains('No fue posible obtener la información.'))),
      );
    });

    test('sin respuesta dentro del timeout lanza TimeoutException', () async {
      responder(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('[]', 200);
        },
        timeout: const Duration(milliseconds: 20),
      );
      expect(() => ApiService.obtenerJuegos(), throwsA(isA<TimeoutException>()));
    });
  });

  group('registrar', () {
    test('201 completa sin excepción', () async {
      responder((_) async => http.Response('{"mensaje":"ok"}', 201));
      await ApiService.registrar('Ana', 'ana@test.com', 'secreta');
      expect(peticiones.single.method, 'POST');
    });

    test('400 usa el mensaje del backend', () async {
      responder((_) async =>
          http.Response('{"error":"El correo ya está registrado"}', 400));
      expect(
        () => ApiService.registrar('Ana', 'ana@test.com', 'x'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje',
            contains('El correo ya está registrado'))),
      );
    });

    test('400 sin campo error usa mensaje genérico', () async {
      responder((_) async => http.Response('{}', 400));
      expect(
        () => ApiService.registrar('Ana', 'ana@test.com', 'x'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje',
            contains('Error al registrar usuario'))),
      );
    });
  });

  group('login', () {
    test('200 guarda token y usuario en SharedPreferences', () async {
      responder((_) async => http.Response(
            jsonEncode({
              'token': 'jwt.abc',
              'usuario': {'nombre': 'Ana', 'correo': 'ana@test.com'},
            }),
            200,
          ));

      final data = await ApiService.login('ana@test.com', 'secreta');

      expect(data['token'], 'jwt.abc');
      expect(await ApiService.leerToken(), 'jwt.abc');
      final usuario = await ApiService.leerUsuario();
      expect(usuario['nombre'], 'Ana');
      expect(usuario['correo'], 'ana@test.com');
    });

    test('401 lanza el mensaje del backend', () async {
      responder((_) async => http.Response(
          '{"error":"Correo o contraseña incorrectos"}', 401));
      expect(
        () => ApiService.login('ana@test.com', 'mala'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje',
            contains('Correo o contraseña incorrectos'))),
      );
    });
  });

  group('obtenerBiblioteca', () {
    test('sin token lanza Exception antes de hacer red', () async {
      responder((_) async => http.Response('[]', 200));
      expect(() => ApiService.obtenerBiblioteca(), throwsA(isA<Exception>()));
      expect(peticiones, isEmpty);
    });

    test('con token envía Authorization y parsea 200', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response(
            jsonEncode([
              {'id': 1, 'titulo': 'Neon Requiem', 'es_favorito': 1}
            ]),
            200,
          ));

      final libros = await ApiService.obtenerBiblioteca();
      expect(libros.single.esFavorito, isTrue);
      expect(peticiones.single.headers['Authorization'], 'Bearer token-1');
    });

    test('status 500 lanza Exception', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response('{}', 500));
      expect(
          () => ApiService.obtenerBiblioteca(), throwsA(isA<Exception>()));
    });
  });

  group('comprarJuego', () {
    test('sin token lanza Exception', () async {
      responder((_) async => http.Response('{}', 201));
      expect(
        () => ApiService.comprarJuego(1),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje',
            contains('Inicia sesión para comprar'))),
      );
      expect(peticiones, isEmpty);
    });

    test('201 completa y envía juego_id', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response('{"compra":{}}', 201));

      await ApiService.comprarJuego(8);
      expect(jsonDecode(peticiones.single.body)['juego_id'], 8);
    });

    test('error 409 propaga mensaje del backend', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response(
          '{"error":"Ya tienes este juego en tu biblioteca"}', 409));
      expect(
        () => ApiService.comprarJuego(8),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje',
            contains('Ya tienes este juego'))),
      );
    });
  });

  group('biblioteca: propiedad y borrado', () {
    test('obtenerIdsBiblioteca parsea los ids con Bearer', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((req) async {
        expect(req.headers['Authorization'], 'Bearer token-1');
        return http.Response('[3, 7]', 200);
      });

      expect(await ApiService.obtenerIdsBiblioteca(), <int>{3, 7});
      expect(peticiones.single.url.path, endsWith('/biblioteca/ids'));
    });

    test('eliminarDeBiblioteca envía DELETE al juego correcto', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((req) async {
        expect(req.method, 'DELETE');
        return http.Response('{"mensaje":"Juego eliminado de tu biblioteca"}', 200);
      });

      await ApiService.eliminarDeBiblioteca(12);
      expect(peticiones.single.url.path, endsWith('/biblioteca/12'));
    });

    test('eliminarDeBiblioteca propaga el error del servidor', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async =>
          http.Response('{"error":"Ese juego no está en tu biblioteca"}', 404));
      expect(
        () => ApiService.eliminarDeBiblioteca(12),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje',
            contains('no está en tu biblioteca'))),
      );
    });
  });

  group('crearTicket', () {
    test('sin token lanza Exception', () async {
      responder((_) async => http.Response('{}', 201));
      expect(
        () => ApiService.crearTicket(
            asunto: 'Error', descripcion: 'Descripción', prioridad: 'Alta'),
        throwsA(isA<Exception>()),
      );
      expect(peticiones, isEmpty);
    });

    test('201 con envoltura ticket parsea el objeto', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response(
            jsonEncode({
              'ticket': {
                'id': 4,
                'asunto': 'Error',
                'descripcion': 'No compra',
                'prioridad': 'Alta',
                'estado': 'Abierto',
              }
            }),
            201,
          ));

      final t = await ApiService.crearTicket(
          asunto: 'Error', descripcion: 'No compra', prioridad: 'Alta');
      expect(t.id, 4);
      expect(t.prioridad, 'Alta');
    });

    test('201 sin envoltura también parsea el objeto directo', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response(
          jsonEncode({'id': 5, 'asunto': 'Directo'}), 201));

      final t = await ApiService.crearTicket(
          asunto: 'Directo', descripcion: 'Descripción', prioridad: 'Baja');
      expect(t.id, 5);
    });

    test('400 usa el mensaje del backend', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response(
          '{"error":"Asunto y descripción son obligatorios"}', 400));
      expect(
        () => ApiService.crearTicket(
            asunto: '', descripcion: '', prioridad: 'Media'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje',
            contains('obligatorios'))),
      );
    });
  });

  group('obtenerTickets', () {
    test('sin token lanza Exception', () async {
      responder((_) async => http.Response('[]', 200));
      expect(() => ApiService.obtenerTickets(), throwsA(isA<Exception>()));
      expect(peticiones, isEmpty);
    });

    test('200 parsea la lista', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response(
          jsonEncode([
            {'id': 1, 'asunto': 'Uno'},
            {'id': 2, 'asunto': 'Dos'}
          ]),
          200));

      final tickets = await ApiService.obtenerTickets();
      expect(tickets.length, 2);
      expect(tickets.last.asunto, 'Dos');
    });

    test('500 lanza Exception', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      responder((_) async => http.Response('{}', 500));
      expect(() => ApiService.obtenerTickets(), throwsA(isA<Exception>()));
    });
  });

  group('sesión local', () {
    test('guardar, leer y cerrar sesión', () async {
      await ApiService.guardarSesion('t', 'Ana', 'ana@test.com');
      expect(await ApiService.leerToken(), 't');

      await ApiService.cerrarSesion();
      expect(await ApiService.leerToken(), isNull);
      final u = await ApiService.leerUsuario();
      expect(u['nombre'], isNull);
    });

    test('cerrar sesión conserva la sesión biométrica', () async {
      await ApiService.guardarBiometria('bio-token', 'Ana', 'ana@test.com');
      await ApiService.guardarSesion('t', 'Ana', 'ana@test.com');

      await ApiService.cerrarSesion();

      expect(await ApiService.biometriaActiva(), isTrue);
      expect(await ApiService.restaurarSesionBiometrica(), isTrue);
      expect(await ApiService.leerToken(), 'bio-token');

      await ApiService.olvidarBiometria();
      expect(await ApiService.biometriaActiva(), isFalse);
    });

    test('guardar y cerrar sesión actualizan el menú compartido', () async {
      SessionController.activa.value = false;

      await ApiService.guardarSesion('t', 'Ana', 'ana@test.com');
      expect(SessionController.activa.value, isTrue);

      await ApiService.cerrarSesion();
      expect(SessionController.activa.value, isFalse);
    });

    test('sincronizarSesion restaura el menú desde el token guardado',
        () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token-1'});
      SessionController.activa.value = false;

      await ApiService.sincronizarSesion();

      expect(SessionController.activa.value, isTrue);
    });
  });
}
