import 'package:flutter_test/flutter_test.dart';

class RespuestaHttp {
  final int statusCode;
  final Map body;

  const RespuestaHttp(this.statusCode, this.body);
}

class ClienteApiSimulado {
  final bool simularCaida;
  final int codigoForzado;

  const ClienteApiSimulado({
    this.simularCaida = false,
    this.codigoForzado = 200,
  });

  Future getJuegos({int pagina = 1, int limite = 10}) async {
    if (simularCaida) {
      throw Exception('Sin conexion al servidor');
    }
    if (codigoForzado != 200) {
      return RespuestaHttp(codigoForzado, {'error': 'Error interno'});
    }
    return RespuestaHttp(200, {
      'total_registros': 2,
      'pagina_actual': pagina,
      'total_paginas': 1,
      'datos': [
        {'id': 1, 'titulo': 'Neon Requiem', 'categoria': 'Cyberpunk RPG'},
        {'id': 2, 'titulo': 'Drift Zero', 'categoria': 'Arcade racing'},
      ],
    });
  }
}

class RepositorioBiblioteca {
  final List _almacen = [];

  bool guardarJuego(Map juego) {
    final existe = _almacen.any((item) => item['id'] == juego['id']);
    if (existe) {
      return false;
    }
    _almacen.add(juego);
    return true;
  }

  List obtenerTodos() => List.unmodifiable(_almacen);
}

class ServicioIndieHub {
  final ClienteApiSimulado api;
  final RepositorioBiblioteca biblioteca;

  ServicioIndieHub(this.api, this.biblioteca);

  Future cargarCatalogo() async {
    try {
      final respuesta = await api.getJuegos(pagina: 1, limite: 10);
      if (respuesta.statusCode == 200) {
        return {
          'exito': true,
          'status': 200,
          'juegos': respuesta.body['datos'],
          'pagina': respuesta.body['pagina_actual'],
        };
      }
      return {
        'exito': false,
        'status': respuesta.statusCode,
        'mensaje': 'No fue posible obtener la informacion.',
      };
    } catch (_) {
      return {
        'exito': false,
        'status': 0,
        'mensaje': 'No fue posible obtener la informacion.',
      };
    }
  }
}

void main() {
  group('Fase 3 - Pruebas de Integracion y Persistencia IndieHub', () {
    test('AUT-04 Integracion: recibe HTTP 200 y parsea catalogo paginado', () async {
      final servicio = ServicioIndieHub(
        const ClienteApiSimulado(codigoForzado: 200),
        RepositorioBiblioteca(),
      );

      final resultado = await servicio.cargarCatalogo();

      expect(resultado['exito'], isTrue);
      expect(resultado['status'], 200);
      expect(resultado['pagina'], 1);
      expect((resultado['juegos'] as List).length, 2);
    });

    test('AUT-05 Integracion: muestra mensaje controlado cuando el servidor falla', () async {
      final servicioCaido = ServicioIndieHub(
        const ClienteApiSimulado(simularCaida: true),
        RepositorioBiblioteca(),
      );
      final servicioError500 = ServicioIndieHub(
        const ClienteApiSimulado(codigoForzado: 500),
        RepositorioBiblioteca(),
      );

      final resCaido = await servicioCaido.cargarCatalogo();
      final res500 = await servicioError500.cargarCatalogo();

      expect(resCaido['exito'], isFalse);
      expect(resCaido['mensaje'], 'No fue posible obtener la informacion.');
      expect(res500['exito'], isFalse);
      expect(res500['status'], 500);
    });

    test('AUT-06 Persistencia: guarda juego en biblioteca y evita duplicados', () {
      final repo = RepositorioBiblioteca();
      final juego = {'id': 10, 'titulo': 'Cyber Knight'};

      final primerGuardado = repo.guardarJuego(juego);
      final segundoGuardado = repo.guardarJuego(juego);

      expect(primerGuardado, isTrue);
      expect(segundoGuardado, isFalse);
      expect(repo.obtenerTodos().length, 1);
    });
  });
}