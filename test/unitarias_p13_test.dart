import 'package:flutter_test/flutter_test.dart';

class JuegoMock {
  final int id;
  final String titulo;
  final String categoria;
  final double precio;

  const JuegoMock(this.id, this.titulo, this.categoria, this.precio);
}

bool validarCorreo(String? correo) {
  if (correo == null || correo.trim().isEmpty) {
    return false;
  }
  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return regex.hasMatch(correo.trim());
}

List filtrarJuegosPorCategoria(List catalogo, String? categoria) {
  if (categoria == null || categoria.trim().isEmpty || categoria == 'Todos') {
    return catalogo;
  }
  return catalogo
      .where((j) =>
          (j as JuegoMock).categoria.toLowerCase() ==
          categoria.trim().toLowerCase())
      .toList();
}

int calcularOffsetPaginacion(int pagina, int limite) {
  if (pagina < 1 || limite < 1 || limite > 100) {
    throw RangeError('Parametros de paginacion fuera de rango');
  }
  return (pagina - 1) * limite;
}

Map procesarRespuestaApi(int statusCode, dynamic body) {
  if (statusCode == 200 || statusCode == 201) {
    return {'ok': true, 'data': body};
  }
  if (statusCode == 401 || statusCode == 403) {
    throw Exception('Acceso no autorizado');
  }
  throw Exception('Error del servidor: $statusCode');
}

void main() {
  group('Fase 2 - Pruebas Unitarias IndieHub', () {
    const catalogoMock = [
      JuegoMock(1, 'Neon Requiem', 'Cyberpunk RPG', 299.0),
      JuegoMock(2, 'Drift Zero', 'Arcade racing', 199.0),
      JuegoMock(3, 'Cyber Knight', 'Cyberpunk RPG', 349.0),
    ];

    test('AUT-01 Entrada valida: correo con formato correcto', () {
      expect(validarCorreo('dair@uteq.edu.mx'), isTrue);
    });

    test('AUT-01 Entrada vacia o nula: rechaza correo nulo o en blanco', () {
      expect(validarCorreo(null), isFalse);
      expect(validarCorreo('   '), isFalse);
    });

    test('AUT-02 Valores fuera de rango: lanza RangeError en paginacion invalida', () {
      expect(() => calcularOffsetPaginacion(0, 10), throwsRangeError);
      expect(() => calcularOffsetPaginacion(1, 150), throwsRangeError);
    });

    test('AUT-02 Resultado esperado: filtra correctamente por categoria', () {
      final resultado = filtrarJuegosPorCategoria(catalogoMock, 'Cyberpunk RPG');
      expect(resultado.length, 2);
      expect((resultado.first as JuegoMock).titulo, 'Neon Requiem');
    });

    test('AUT-03 Manejo de excepciones: captura error HTTP 401 y 500', () {
      expect(() => procesarRespuestaApi(401, null), throwsException);
      expect(() => procesarRespuestaApi(500, null), throwsException);
    });
  });
}