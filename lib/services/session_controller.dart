import 'package:flutter/foundation.dart';

/// Estado compartido por la app móvil y la versión web.
///
/// ApiService actualiza [activa] al guardar o cerrar la sesión, y los shells
/// lo escuchan para mostrar u ocultar menús sin depender de reconstrucciones
/// manuales. [seccion] permite que una ficha lleve al usuario a otra pestaña
/// y [bibliotecaActualizada] fuerza recargar la biblioteca tras una compra.
class SessionController {
  static final ValueNotifier<bool> activa = ValueNotifier<bool>(false);

  /// Pestaña activa: 0 Tienda, 1 Biblioteca, 2 Soporte, 3 Perfil.
  static final ValueNotifier<int> seccion = ValueNotifier<int>(0);

  /// Cambia al navegar entre secciones. Sin sesión solo existe la Tienda.
  static void irA(int indice) {
    final destino = activa.value ? indice.clamp(0, 3) : 0;
    seccion.value = destino;
  }

  /// Se llama después de comprar para que la biblioteca ya abierta se refresque.
  static void notificarCambioBiblioteca() {
    bibliotecaActualizada.value++;
  }

  static final ValueNotifier<int> bibliotecaActualizada =
      ValueNotifier<int>(0);
}
