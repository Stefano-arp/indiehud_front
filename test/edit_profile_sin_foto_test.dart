import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indiehud/screens/edit_profile_screen.dart';

void main() {
  testWidgets('editar perfil ya no ofrece cambiar foto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EditProfileScreen(
          nombre: 'Ana',
          correo: 'ana@test.com',
          fotoUrl: '',
        ),
      ),
    );

    expect(find.byTooltip('Cambiar foto'), findsNothing);
    expect(find.byIcon(Icons.camera_alt), findsNothing);
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
  });
}
