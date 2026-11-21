import 'package:flutter_test/flutter_test.dart';
import 'package:indiehud/models/juego.dart';
import 'package:indiehud/models/ticket.dart';

/// Pruebas White Box de los modelos: normalización, valores límite y
/// conversión de/ hacia SQLite. No requieren red ni base de datos.
void main() {
  group('Juego.fromJson / toMap', () {
    test('parsea un JSON completo de la API', () {
      final j = Juego.fromJson({
        'id': 7,
        'titulo': 'Neon Requiem',
        'descripcion': 'RPG',
        'precio': 19.99,
        'desarrollador': 'NeonStudios',
        'portada_url': 'https://img/1.png',
        'categoria': 'Cyberpunk RPG',
        'es_favorito': 1,
      });

      expect(j.id, 7);
      expect(j.titulo, 'Neon Requiem');
      expect(j.precio, 19.99);
      expect(j.esFavorito, isTrue);
      expect(j.toMap()['es_favorito'], 1);
    });

    test('acepta id String y precio numérico String', () {
      final j = Juego.fromJson({'id': '15', 'precio': '9.50'});
      expect(j.id, 15);
      expect(j.precio, 9.50);
    });

    test('usa valores por defecto cuando faltan campos', () {
      final j = Juego.fromJson({});
      expect(j.id, 0);
      expect(j.titulo, 'Sin título');
      expect(j.descripcion, '');
      expect(j.precio, 0.0);
      expect(j.desarrollador, 'Indie Dev');
      expect(j.categoria, 'General');
      expect(j.esFavorito, isFalse);
    });

    test('interpreta es_favorito en sus tres representaciones', () {
      expect(Juego.fromJson({'es_favorito': 1}).esFavorito, isTrue);
      expect(Juego.fromJson({'es_favorito': 0}).esFavorito, isFalse);
      expect(Juego.fromJson({'es_favorito': true}).esFavorito, isTrue);
      expect(Juego.fromJson({'es_favorito': false}).esFavorito, isFalse);
      expect(Juego.fromJson({'es_favorito': '1'}).esFavorito, isTrue);
      expect(Juego.fromJson({'es_favorito': 'true'}).esFavorito, isTrue);
      expect(Juego.fromJson({'es_favorito': 'TRUE'}).esFavorito, isTrue);
      expect(Juego.fromJson({'es_favorito': '0'}).esFavorito, isFalse);
      expect(Juego.fromJson({'es_favorito': 'otro'}).esFavorito, isFalse);
    });

    test('copyWith conserva el resto de campos', () {
      final original = Juego(
        id: 1,
        titulo: 'T',
        descripcion: 'D',
        precio: 1.0,
        desarrollador: 'Dev',
        portadaUrl: 'url',
        categoria: 'Cat',
      );
      final copia = original.copyWith(esFavorito: true);
      expect(copia.id, original.id);
      expect(copia.titulo, original.titulo);
      expect(copia.esFavorito, isTrue);
      expect(original.esFavorito, isFalse);

      // Rama en la que copyWith no recibe esFavorito (usa el valor actual).
      expect(original.copyWith().esFavorito, isFalse);
    });
  });

  group('Ticket.fromJson / toMap / fechaCorta', () {
    test('parsea JSON completo y conserva tipos', () {
      final t = Ticket.fromJson({
        'id': 3,
        'asunto': 'Error',
        'descripcion': 'No compra',
        'prioridad': 'Alta',
        'estado': 'Abierto',
        'fecha_creacion': '2026-11-12T02:00:00',
      });
      expect(t.id, 3);
      expect(t.prioridad, 'Alta');
      expect(t.toMap()['fecha_creacion'], '2026-11-12T02:00:00');
    });

    test('valores por defecto y id String', () {
      final t = Ticket.fromJson({'id': '9'});
      expect(t.id, 9);
      expect(t.asunto, 'Sin asunto');
      expect(t.prioridad, 'Media');
      expect(t.estado, 'Abierto');
      expect(t.fechaCreacion, '');
    });

    test('fechaCorta formatea una fecha válida', () {
      final t = Ticket.fromJson({'fecha_creacion': '2026-11-12T02:05:00'});
      expect(t.fechaCorta, contains('12/11/2026'));
      expect(t.fechaCorta, contains('02:05'));
    });

    test('fechaCorta devuelve el texto original si la fecha es inválida', () {
      final t = Ticket.fromJson({'fecha_creacion': 'no-es-fecha'});
      expect(t.fechaCorta, 'no-es-fecha');
    });
  });
}
