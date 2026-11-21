import 'package:flutter_test/flutter_test.dart';

// ==========================================================
// SIMULACIÓN DE TUS MÉTODOS 
// ==========================================================

// Método 2: Procesamiento o cálculo
List filtrarJuegos(List catalogo, String categoria) {
  if (categoria == 'Todos' || categoria.isEmpty) return catalogo;
  return catalogo.where((juego) => juego['categoria'] == categoria).toList();
}

// Método 3: Comunicación con un servicio 
Map procesarRespuestaServidor(int statusCode, Map body) {
  if (statusCode == 200 || statusCode == 201) {
    return {'exito': true, 'datos': body};
  } else if (statusCode == 401) {
    throw Exception('No autorizado: Verifica tus credenciales');
  } else {
    throw Exception('Error del servidor: $statusCode');
  }
}

// ==========================================================
// CASOS DE PRUEBA WHITE BOX
// ==========================================================

void main() {
  group('Pruebas WB - Método de Procesamiento', () {
    var catalogoMock = [
      {'id': 1, 'titulo': 'Neon Requiem', 'categoria': 'Cyberpunk RPG'},
      {'id': 2, 'titulo': 'Space Explorer', 'categoria': 'Aventura'},
      {'id': 3, 'titulo': 'Cyber Knight', 'categoria': 'Cyberpunk RPG'},
    ];

    test('Debe retornar todos los juegos si la categoria es "Todos"', () {
      var resultado = filtrarJuegos(catalogoMock, 'Todos');
      expect(resultado.length, 3);
    });

    test('Debe retornar solo los juegos de la categoria solicitada', () {
      var resultado = filtrarJuegos(catalogoMock, 'Cyberpunk RPG');
      expect(resultado.length, 2);
      expect(resultado.first['titulo'], 'Neon Requiem');
    });
  });

  group('Pruebas WB - Método de Comunicación', () {
    test('Debe retornar exito cuando el codigo HTTP es 200', () {
      var jsonMock = {'mensaje': 'Login exitoso', 'token': 'abc.123'};
      var resultado = procesarRespuestaServidor(200, jsonMock);
      
      expect(resultado['exito'], true);
      expect(resultado['datos']['token'], 'abc.123');
    });

    test('Debe lanzar excepcion de "No autorizado" con codigo 401', () {
      var jsonMock = {'error': 'Credenciales invalidas'};
      
      expect(
        () => procesarRespuestaServidor(401, jsonMock),
        throwsA(isA<Exception>().having((e) => e.toString(), 'mensaje', contains('No autorizado'))),
      );
    });
  });
}