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

  /// Rol de la cuenta activa. Las cuentas staff solo existen en la web.
  static final ValueNotifier<String> rol = ValueNotifier<String>('usuario');

  static bool get esDesarrollador => rol.value == 'desarrollador';
  static bool get esSoporte => rol.value == 'soporte';
  static bool get esStaff => rol.value != 'usuario';

  /// Cambia al navegar entre secciones. Sin sesión solo existe la Tienda.
  /// Las cuentas staff no alcanzan ninguna otra sección: solo su panel.
  static void irA(int indice) {
    if (esStaff) {
      seccion.value = 0;
      return;
    }
    final destino = activa.value ? indice.clamp(0, 3) : 0;
    seccion.value = destino;
  }

  /// Abre la pantalla de acceso desde el botón explícito de la cabecera.
  /// No habilita las pestañas protegidas: solo permite mostrar el Perfil
  /// en modo login, igual que hace la Tienda móvil con Navigator.push.
  static void abrirAcceso() {
    seccion.value = esStaff ? 0 : 3;
  }

  /// Se llama después de comprar para que la biblioteca ya abierta se refresque.
  static void notificarCambioBiblioteca() {
    bibliotecaActualizada.value++;
  }

  static final ValueNotifier<int> bibliotecaActualizada =
      ValueNotifier<int>(0);
}
