import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../models/juego.dart';
import '../services/api_service.dart';
import '../services/session_controller.dart';
import '../theme/app_palette.dart';
import '../widgets/responsive_container.dart';
import 'profile_screen.dart';

/// Ficha de un juego. La compra solo se ofrece cuando el título no está todavía
/// en la biblioteca del usuario; al abrirlo desde la biblioteca se muestra su
/// estado de propiedad en lugar de un botón de compra.
class GameDetailScreen extends StatefulWidget {
  final Juego juego;

  /// `true` cuando la ficha se abre desde la biblioteca.
  final bool enBiblioteca;

  const GameDetailScreen({
    super.key,
    required this.juego,
    this.enBiblioteca = false,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _comprando = false;
  bool _verificando = true;
  bool _conSesion = false;
  bool _enBiblioteca = false;
  bool _falloVerificacion = false;

  @override
  void initState() {
    super.initState();
    _verificarEstado();
  }

  Future<void> _verificarEstado() async {
    final token = await ApiService.leerToken();
    final conSesion = token != null && token.isNotEmpty;

    if (widget.enBiblioteca || !conSesion) {
      if (!mounted) return;
      setState(() {
        _conSesion = conSesion;
        _enBiblioteca = widget.enBiblioteca;
        _verificando = false;
      });
      return;
    }

    try {
      final ids = await ApiService.obtenerIdsBiblioteca();
      if (!mounted) return;
      setState(() {
        _conSesion = true;
        _enBiblioteca = ids.contains(widget.juego.id);
        _falloVerificacion = false;
        _verificando = false;
      });
    } catch (_) {
      // No ofrecer compra si no se pudo comprobar la propiedad: el backend
      // podría tener el juego y el usuario vería un error de compra confuso.
      if (!mounted) return;
      setState(() {
        _conSesion = true;
        _falloVerificacion = true;
        _verificando = false;
      });
    }
  }

  Future<void> _reintentarVerificacion() async {
    if (_verificando) return;
    setState(() {
      _verificando = true;
      _falloVerificacion = false;
    });
    await _verificarEstado();
  }

  void _mostrarSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: error ? Colors.redAccent : const Color(0xFFB2FF05),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Confirma la identidad antes de comprar. En web basta el JWT; en escritorio
  /// no hay lector biométrico y en Android se usa BiometricPrompt.
  Future<bool> _confirmarHuella() async {
    if (kIsWeb) return true;
    if (Platform.isLinux || Platform.isWindows) {
      _mostrarSnack('Compra confirmada en escritorio');
      return true;
    }
    try {
      final puede = await _auth.canCheckBiometrics;
      final dispositivo = await _auth.isDeviceSupported();
      if (!puede && !dispositivo) {
        _mostrarSnack('Tu dispositivo no permite confirmar la compra',
            error: true);
        return false;
      }
      return await _auth.authenticate(
        localizedReason:
            'Confirma tu identidad para comprar "${widget.juego.titulo}" por \$${widget.juego.precio.toStringAsFixed(2)}',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      _mostrarSnack('No se pudo verificar tu identidad', error: true);
      return false;
    }
  }

  Future<void> _comprar() async {
    if (_comprando || _verificando || _enBiblioteca || _falloVerificacion) {
      return;
    }
    setState(() => _comprando = true);
    try {
      final bool huellaOk = await _confirmarHuella();
      if (!huellaOk) {
        _mostrarSnack('Compra cancelada: huella no verificada', error: true);
        return;
      }
      await ApiService.comprarJuego(widget.juego.id);
      if (!mounted) return;
      setState(() => _enBiblioteca = true);
      SessionController.notificarCambioBiblioteca();
      _mostrarSnack('¡${widget.juego.titulo} agregado a tu biblioteca!');
    } on SesionExpiradaException catch (e) {
      await ApiService.cerrarSesion();
      if (!mounted) return;
      Navigator.of(context).pop();
      SessionController.irA(0);
      _mostrarSnack(e.toString(), error: true);
    } catch (e) {
      _mostrarSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _comprando = false);
    }
  }

  /// Cambia de pestaña y cierra la ficha (móvil y web comparten el notificador).
  void _irA(int seccion) {
    SessionController.irA(seccion);
    if (mounted) Navigator.of(context).pop();
  }

  /// Sin sesión, móvil abre el acceso como ruta (no hay pestaña de Perfil);
  /// la web sí usa la sección de su menú superior.
  void _irAlAcceso() {
    if (kIsWeb) {
      _irA(3);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Color(0xFF121212),
          body: ProfileScreen(devolverAlEntrar: true),
        ),
      ),
    );
  }

  Widget _botonInformativo(String texto, IconData icono) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white12,
          foregroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: null,
        icon: Icon(icono),
        label: Text(texto,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _accionPrincipal() {
    final juego = widget.juego;

    if (_verificando) {
      return _botonInformativo('COMPROBANDO TU BIBLIOTECA…', Icons.hourglass_empty);
    }

    if (_falloVerificacion) {
      return Column(
        children: [
          _botonInformativo(
              'NO SE PUDO COMPROBAR TU BIBLIOTECA', Icons.cloud_off),
          TextButton.icon(
            onPressed: _reintentarVerificacion,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (_enBiblioteca) {
      return Column(
        children: [
          _botonInformativo('YA ESTÁ EN TU BIBLIOTECA', Icons.check_circle_outline),
          TextButton.icon(
            onPressed: () => _irA(1),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Ver mi biblioteca'),
          ),
        ],
      );
    }

    if (!_conSesion) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB2FF05),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _irAlAcceso,
          icon: const Icon(Icons.login),
          label: const Text('INICIAR SESIÓN PARA COMPRAR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB2FF05),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _comprando ? null : _comprar,
        icon: _comprando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Icon(kIsWeb ? Icons.shopping_cart : Icons.fingerprint),
        label: Text(
          _comprando
              ? 'PROCESANDO…'
              : 'COMPRAR AHORA • \$${juego.precio.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  String _textoAyuda() {
    if (_verificando) return 'Comprobando si ya tienes este título…';
    if (_falloVerificacion) {
      return 'No se pudo comprobar tu biblioteca. Reintenta antes de comprar.';
    }
    if (_enBiblioteca) return 'Este título ya está en tu biblioteca.';
    if (!_conSesion) return 'Inicia sesión para adquirir este título.';
    if (kIsWeb) return 'La compra se confirma con tu sesión de IndieHub.';
    if (Platform.isLinux || Platform.isWindows) {
      return 'La compra se confirma en este dispositivo.';
    }
    return 'La compra se confirma con tu huella digital.';
  }

  @override
  Widget build(BuildContext context) {
    final juego = widget.juego;

    final portada = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          juego.portadaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppPalette.borde,
            child: Center(
              child: Icon(Icons.videogame_asset,
                  size: 64, color: AppPalette.acentoPrincipal),
            ),
          ),
        ),
      ),
    );

    final informacion = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppPalette.acento.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppPalette.acento),
              ),
              child: Text(
                juego.categoria.toUpperCase(),
                style: const TextStyle(
                  color: AppPalette.acento,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '\$${juego.precio.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(juego.titulo,
            style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Desarrollado por ${juego.desarrollador}',
            style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 16),
        const Text('SINOPSIS',
            style: TextStyle(
                color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text(
          juego.descripcion.isEmpty
              ? 'Sin sinopsis disponible para este título indie.'
              : juego.descripcion,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 28),
        _accionPrincipal(),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _textoAyuda(),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppPalette.panelOscuro,
        title: Text(juego.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(16),
        paddingEscritorio:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            if (ancho < 900) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    portada,
                    const SizedBox(height: 16),
                    informacion,
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: portada),
                  const SizedBox(width: 28),
                  Expanded(flex: 4, child: informacion),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
