import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../models/juego.dart';
import '../services/api_service.dart';
import '../database/database_helper.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Juego> _misJuegos = [];
  bool _cargando = true;
  bool _modoOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _subRed;

  @override
  void initState() {
    super.initState();
    _cargarBiblioteca();
    // FASE 3 (real): monitoreo automático de red → cambia a OFFLINE al instante.
    _subRed = Connectivity().onConnectivityChanged.listen((resultados) {
      final sinRed = resultados.contains(ConnectivityResult.none);
      if (sinRed && !_modoOffline && mounted) {
        _cargarBiblioteca();
      } else if (!sinRed && _modoOffline && mounted) {
        // Volvió la red: intenta resincronizar solo.
        _cargarBiblioteca();
      }
    });
  }

  @override
  void dispose() {
    _subRed?.cancel();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: error ? Colors.redAccent : const Color(0xFFB2FF05),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cargarBiblioteca() async {
    if (mounted) setState(() => _cargando = true);

    try {
      // 1. Intentamos descargar de la API en Node.js
      final juegosOnline = await ApiService.obtenerBiblioteca();
      // 2. Guardamos copia en SQLite local para el modo offline
      await DatabaseHelper.sincronizarBiblioteca(juegosOnline);
      // Relee desde SQLite para incluir columna es_favorito local.
      final locales = await DatabaseHelper.obtenerBibliotecaLocal();
      // Combina: si la API no trae un juego local (eliminado en nube),
      // se muestran los online + favoritos preservados.
      final idsOnline = juegosOnline.map((j) => j.id).toSet();
      final soloLocal =
          locales.where((j) => !idsOnline.contains(j.id)).toList();
      if (mounted) {
        setState(() {
          _misJuegos = [...juegosOnline.map((j) {
            final fav = locales
                .where((l) => l.id == j.id)
                .map((l) => l.esFavorito)
                .firstOrNull ??
                false;
            return j.copyWith(esFavorito: fav);
          }), ...soloLocal];
          _modoOffline = false;
          _cargando = false;
        });
      }
    } catch (e) {
      // 3. Si falla el internet o el servidor está apagado, leemos de SQLite
      try {
        final juegosLocales = await DatabaseHelper.obtenerBibliotecaLocal();
        if (mounted) {
          setState(() {
            _misJuegos = juegosLocales;
            _modoOffline = true;
            _cargando = false;
          });
        }
        if (juegosLocales.isEmpty) {
          _snack('Sin conexión: activa tu backend en 192.168.1.78:3000',
              error: true);
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _misJuegos = [];
            _modoOffline = true;
            _cargando = false;
          });
        }
      }
    }
  }

  // UPDATE local (Práctica 4): corazón de favorito.
  Future<void> _alternarFavorito(Juego juego) async {
    final nuevo = !juego.esFavorito;
    await DatabaseHelper.alternarFavorito(juego.id, nuevo);
    setState(() {
      final i = _misJuegos.indexWhere((j) => j.id == juego.id);
      if (i != -1) _misJuegos[i] = juego.copyWith(esFavorito: nuevo);
    });
    _snack(nuevo
        ? '❤ ${juego.titulo} marcado como favorito'
        : '${juego.titulo} quitado de favoritos');
  }

  // DELETE local (Práctica 4): desinstalar copia del dispositivo.
  Future<void> _eliminarLocal(Juego juego) async {
    await DatabaseHelper.eliminarJuegoLocal(juego.id);
    setState(() => _misJuegos.removeWhere((j) => j.id == juego.id));
    _snack('Copia local de "${juego.titulo}" desinstalada');
  }

  void _menuOpciones(Juego juego) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  juego.esFavorito ? Icons.favorite : Icons.favorite_border,
                  color: const Color(0xFFB2FF05)),
              title: Text(juego.esFavorito
                  ? 'Quitar de favoritos'
                  : 'Marcar como favorito'),
              onTap: () {
                Navigator.pop(context);
                _alternarFavorito(juego);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Desinstalar copia local'),
              subtitle: const Text('Elimina el registro SQLite del dispositivo'),
              onTap: () {
                Navigator.pop(context);
                _eliminarLocal(juego);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera idéntica a tu mockup de avances.pdf
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_misJuegos.length} games • ${_misJuegos.length} installed',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                Row(
                  children: [
                    if (_modoOffline)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orangeAccent),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cloud_off,
                                size: 14, color: Colors.orangeAccent),
                            SizedBox(width: 4),
                            Text('OFFLINE SQLite',
                                style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: _cargarBiblioteca,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFB2FF05)))
                  : _misJuegos.isEmpty
                      ? const Center(
                          child: Text(
                            'Aún no tienes juegos en tu biblioteca.\nInicia sesión en Profile y adquiere uno en Home.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _misJuegos.length,
                          itemBuilder: (context, index) {
                            final juego = _misJuegos[index];
                            return _buildLibraryCard(juego);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryCard(Juego juego) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF2B0B3F), Color(0xFF1A1A1A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              image: DecorationImage(
                image: NetworkImage(juego.portadaUrl),
                fit: BoxFit.cover,
                onError: (_, __) {}, // En modo offline sin caché no rompe la UI
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Corazón de favorito (UPDATE SQLite)
                    GestureDetector(
                      onTap: () => _alternarFavorito(juego),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          juego.esFavorito
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 16,
                          color: juego.esFavorito
                              ? Colors.redAccent
                              : Colors.white,
                        ),
                      ),
                    ),
                    // Menú de 3 puntos funcional (DELETE SQLite)
                    GestureDetector(
                      onTap: () => _menuOpciones(juego),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.more_horiz,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFB2FF05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow,
                          size: 14, color: Colors.black),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'INSTALLED',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                juego.titulo,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (juego.esFavorito)
              const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
          ],
        ),
        Text(
          '${juego.categoria} ✓',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

// Evita importar collection solo por firstOrNull en Flutter 3.27.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
