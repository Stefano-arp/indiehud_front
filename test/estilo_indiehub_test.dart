import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indiehud/screens/steam_web_shell.dart';
import 'package:indiehud/services/api_service.dart';
import 'package:indiehud/services/session_controller.dart';
import 'package:indiehud/theme/app_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('la paleta es única y usa negro, verde neón y morado', () {
    expect(AppPalette.fondo, const Color(0xFF121212));
    expect(AppPalette.panel, const Color(0xFF1E1E1E));
    expect(AppPalette.panelOscuro, const Color(0xFF1A1A1A));
    expect(AppPalette.borde, const Color(0xFF2B0B3F));
    expect(AppPalette.acento, const Color(0xFFB2FF05));
    expect(AppPalette.acentoPrincipal, const Color(0xFFB2FF05));
    expect(AppPalette.secundario, const Color(0xFF9D4EDD));
  });

  test('la PWA usa el fondo oscuro y sus propios iconos', () {
    final manifest = File('web/manifest.json').readAsStringSync();
    expect(manifest, contains('"background_color": "#121212"'));
    expect(manifest, contains('"theme_color": "#121212"'));
    expect(manifest, isNot(contains('#0B1118')));

    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('content="#121212"'));
    expect(index, contains('background: #121212'));

    for (final ruta in [
      'web/favicon.png',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    ]) {
      expect(File(ruta).existsSync(), isTrue, reason: 'Falta $ruta');
    }

    final splash =
        File('android/app/src/main/res/drawable/launch_background.xml')
            .readAsStringSync();
    expect(splash, contains('@color/indiehub_fondo'));

    final serviceWorker = File('web/pwa_service_worker.js').readAsStringSync();
    expect(serviceWorker, contains("const CACHE = 'indiehub-shell-v3';"));
  });

  testWidgets('el shell web usa el fondo de la app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SessionController.activa.value = false;
    ApiService.httpClient = MockClient((_) async => http.Response('[]', 200));
    addTearDown(() => ApiService.httpClient = http.Client());

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SteamWebShell()));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppPalette.fondo);
  });
}
