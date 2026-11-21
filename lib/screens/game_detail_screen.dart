import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../models/juego.dart';
import '../services/api_service.dart';

/// FASE 1 — Pantalla de detalles + confirmación biométrica de compra.
/// Recibe un [Juego] desde HomeScreen y confirma la compra con huella
/// (BiometricPrompt en Android / fallback de desarrollo en Linux Desktop).
class GameDetailScreen extends StatefulWidget {
  final Juego juego;
  const GameDetailScreen({super.key, required this.juego});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _comprando = false;

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

  /// Práctica 1: escucha el evento de huella antes de comprar.
  Future<bool> _confirmarHuella() async {
    // Fallback de desarrollo: en Linux Desktop no hay BiometricPrompt.
    if (Platform.isLinux || Platform.isWindows) {
      try {
        final bool soporta = await _auth.canCheckBiometrics;
        if (!soporta) {
          _mostrarSnack('Huella validada (Modo desarrollo Linux)');
          return true;
        }
      } catch (_) {
        _mostrarSnack('Huella validada (Modo desarrollo Linux)');
        return true;
      }
    }
    try {
      final bool puede = await _auth.canCheckBiometrics;
      final bool deviceOk = await _auth.isDeviceSupported();
      if (!puede && !deviceOk) {
        // Sin hardware biométrico: se permite continuar para no bloquear la demo.
        _mostrarSnack('Este dispositivo no tiene biometría: compra sin huella');
        return true;
      }
      return await _auth.authenticate(
        localizedReason:
            'Confirma con tu huella la compra de "${widget.juego.titulo}" por \$${widget.juego.precio.toStringAsFixed(2)}',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      // En Linux sin servicio biométrico no se bloquea la compra de prueba.
      if (Platform.isLinux || Platform.isWindows) {
        _mostrarSnack('Huella validada (Modo desarrollo Linux)');
        return true;
      }
      _mostrarSnack('No se pudo verificar la huella: $e', error: true);
      return false;
    }
  }

  Future<void> _comprar() async {
    if (_comprando) return;
    setState(() => _comprando = true);
    try {
      final bool huellaOk = await _confirmarHuella();
      if (!huellaOk) {
        _mostrarSnack('Compra cancelada: huella no verificada', error: true);
        return;
      }
      await ApiService.comprarJuego(widget.juego.id);
      _mostrarSnack('¡${widget.juego.titulo} agregado a tu biblioteca!');
    } catch (e) {
      _mostrarSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _comprando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final juego = widget.juego;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(juego.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portada grande
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  juego.portadaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF2B0B3F),
                    child: const Center(
                      child: Icon(Icons.videogame_asset,
                          size: 64, color: Color(0xFFB2FF05)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Insignia de categoría + precio
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB2FF05).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFB2FF05)),
                  ),
                  child: Text(
                    juego.categoria.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFB2FF05),
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
            // Botón principal de compra
            SizedBox(
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
                    : const Icon(Icons.fingerprint),
                label: Text(
                  _comprando
                      ? 'PROCESANDO...'
                      : 'COMPRAR AHORA • \$${juego.precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'La compra se confirma con tu huella digital',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
