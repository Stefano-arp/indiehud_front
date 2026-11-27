import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/main.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:indiehud/services/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const portada =
      'https://images.unsplash.com/photo-1605806616949-1e87b487cb2a?q=80&w=600';

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    SessionController.activa.value = false;
    ApiService.httpClient = MockClient((request) async {
      if (request.url.path.contains('/juegos')) {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'titulo': 'Neon Requiem',
              'descripcion': 'RPG cyberpunk',
              'categoria': 'Cyberpunk RPG',
              'precio': 19.99,
              'portada_url': portada,
              'desarrollador': 'NeonStudios',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('[]', 200, headers: {'content-type': 'application/json'});
    });
  });

  tearDown(() {
    ApiService.httpClient = http.Client();
    SessionController.activa.value = false;
  });

  testWidgets('la Tienda móvil usa la portada de la API', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainNavigator()));
    // No pumpAndSettle: en tests las imágenes de red fallan y el errorBuilder
    // sustituye el widget Image. Solo necesitamos verificar que se crea.
    await tester.pump();
    await tester.pump();

    expect(find.text('Neon Requiem'), findsWidgets);

    final imagenes = find.byWidgetPredicate((widget) => widget is Image);
    expect(imagenes, findsWidgets);

    // cacheWidth envuelve el NetworkImage en ResizeImage.
    final proveedores = imagenes.evaluate().map((element) {
      final provider = (element.widget as Image).image;
      final original = provider is ResizeImage ? provider.imageProvider : provider;
      return original.toString();
    }).toList();
    expect(proveedores.any((provider) => provider.contains(portada)), isTrue);
  });
}
