import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paleta IndieHub única para todas las plataformas.
/// Web y Android comparten el negro, el verde neón y el morado cyberpunk.
/// Se exponen como constantes para poder usarlas también en estilos `const`.
class AppPalette {
  static bool get esWeb => kIsWeb;

  static const Color fondo = Color(0xFF121212);
  static const Color panel = Color(0xFF1E1E1E);
  static const Color panelOscuro = Color(0xFF1A1A1A);
  static const Color borde = Color(0xFF2B0B3F);
  static const Color texto = Colors.white;
  static const Color textoSuave = Colors.white54;

  /// Acento de navegación y enlaces (verde neón).
  static const Color acento = Color(0xFFB2FF05);

  /// Color de los botones principales.
  static const Color acentoPrincipal = Color(0xFFB2FF05);

  /// Acento secundario (morado cyberpunk).
  static const Color secundario = Color(0xFF9D4EDD);
}
