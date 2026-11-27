import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/juego.dart';
import '../services/api_service.dart';
import '../services/descargas_web.dart';
import '../services/session_controller.dart';
import '../theme/app_palette.dart';
import '../widgets/responsive_container.dart';
import 'game_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final List<Juego> _misJuegos = [];
  final Set<int> _descargados = {};
  final Set<int> _descargando = {};

  bool _cargando = true;
  bool _modoOffline = false;
  String? _error;

  StreamSubscription<List<ConnectivityResult>>? _subRed;

  @override
  void initState() {
    super.initState();
    _cargarBiblioteca();
    // Comprar desde la Tienda debe reflejarse aunque esta pantalla ya esté
    // montada (los shells mantienen vivas sus pestañas).
    SessionController.bibliotecaActualizada.addListener(_recargar);

    // La red solo se monitorea en móvil: allí existe la copia SQLite offline.
    if (!kIsWeb) {
      _subRed = Connectivity().onConnectivityChanged.listen((resultados) {
        final sinRed = resultados.contains(ConnectivityResult.none);
        if ((sinRed && !_modoOffline) || (!sinRed && _modoOffline)) {
          if (mounted) _cargarBiblioteca();
        }
      });
    }
  }

  void _recargar() {
    if (mounted) _cargarBiblioteca();
  }

  @override
  void dispose() {
    SessionController.bibliotecaActualizada.removeListener(_recargar);
    _subRed?.cancel();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: error ? Colors.redAccent : const Color(0xFFB2FF05),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cargarBiblioteca() async {
    if (kIsWeb) {
      await _cargarWeb();
    } else {
      await _cargarMovil();
    }
  }

  /// Web: catálogo de la API + preferencias locales. No usa SQLite.
  Future<void> _cargarWeb() async {
    if (mounted) setState(() => _cargando = true);

    try {
      final juegos = await ApiService.obtenerBiblioteca();
      final resultado = <Juego>[];
      final descargados = <int>{};

      for (final juego in juegos) {
        final favorito = await DescargasWebService.esFavorito(juego.id);
        if (await DescargasWebService.estaDescargado(juego.id)) {
          descargados.add(juego.id);
        }
        resultado.add(juego.copyWith(esFavorito: favorito));
      }

      if (!mounted) return;
      setState(() {
        _misJuegos
          ..clear()
          ..addAll(resultado);
        _descargados
          ..clear()
          ..addAll(descargados);
        _modoOffline = false;
        _error = null;
        _cargando = false;
      });
    } on SesionExpiradaException catch (e) {
      await ApiService.cerrarSesion();
      if (!mounted) return;
      setState(() {
        _misJuegos.clear();
        _descargados.clear();
        _modoOffline = false;
        _error = null;
        _cargando = false;
      });
      _snack(e.toString(), error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No fue posible cargar tu biblioteca.';
        _cargando = false;
      });
    }
  }

  /// Móvil: API + sincronización SQLite, con copia local sin conexión.
  Future<void> _cargarMovil() async {
    if (mounted) setState(() => _cargando = true);

    try {
      final juegosOnline = await ApiService.obtenerBiblioteca();
      await DatabaseHelper.sincronizarBiblioteca(juegosOnline);
      final locales = await DatabaseHelper.obtenerBibliotecaLocal();
      final idsOnline = juegosOnline.map((j) => j.id).toSet();
      final soloLocal =
          locales.where((j) => !idsOnline.contains(j.id)).toList();

      if (!mounted) return;
      setState(() {
        _misJuegos
          ..clear()
          ..addAll([
            ...juegosOnline.map((j) {
              final fav = locales
                  .where((l) => l.id == j.id)
                  .map((l) => l.esFavorito)
                  .firstOrNull ??
                  false;
              return j.copyWith(esFavorito: fav);
            }),
            ...soloLocal,
          ]);
        _modoOffline = false;
        _error = null;
        _cargando = false;
      });
    } on SesionExpiradaException catch (e) {
      await ApiService.cerrarSesion();
      await DatabaseHelper.limpiarBibliotecaLocal();
      if (!mounted) return;
      setState(() {
        _misJuegos.clear();
        _modoOffline = false;
        _error = null;
        _cargando = false;
      });
      _snack(e.toString(), error: true);
    } catch (_) {
      try {
        final juegosLocales = await DatabaseHelper.obtenerBibliotecaLocal();
        if (!mounted) return;
        setState(() {
          _misJuegos
            ..clear()
            ..addAll(juegosLocales);
          _modoOffline = true;
          _error = null;
          _cargando = false;
        });
        if (juegosLocales.isEmpty) {
          _snack('Sin conexión y no hay copia local de tu biblioteca.',
              error: true);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _misJuegos.clear();
          _modoOffline = true;
          _cargando = false;
        });
      }
    }
  }

  void _abrirDetalle(Juego juego) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameDetailScreen(juego: juego, enBiblioteca: true),
      ),
    );
  }

  Future<void> _alternarFavorito(Juego juego) async {
    final nuevo = !juego.esFavorito;

    if (kIsWeb) {
      await DescargasWebService.alternarFavorito(juego.id, valor: nuevo);
    } else {
      await DatabaseHelper.alternarFavorito(juego.id, nuevo);
    }

    if (!mounted) return;
    setState(() {
      final i = _misJuegos.indexWhere((j) => j.id == juego.id);
      if (i != -1) _misJuegos[i] = juego.copyWith(esFavorito: nuevo);
    });
    _snack(nuevo
        ? '${juego.titulo} marcado como favorito'
        : '${juego.titulo} quitado de favoritos');
  }

  Future<void> _descargar(Juego juego) async {
    if (_descargando.contains(juego.id) || _descargados.contains(juego.id)) {
      return;
    }

    setState(() => _descargando.add(juego.id));
    // Descarga simulada: no existen archivos de juego en el proyecto.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    await DescargasWebService.marcarDescargado(juego.id);
    if (!mounted) return;
    setState(() {
      _descargando.remove(juego.id);
      _descargados.add(juego.id);
    });
    _snack('${juego.titulo} descargado en este navegador');
  }

  Future<void> _eliminarDescarga(Juego juego) async {
    await DescargasWebService.quitarDescarga(juego.id);
    if (!mounted) return;
    setState(() => _descargados.remove(juego.id));
    _snack('Descarga de "${juego.titulo}" eliminada');
  }

  Future<void> _eliminar(Juego juego) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.panel,
        title: Text('¿Eliminar "${juego.titulo}"?'),
        content: const Text(
          'Se quitará de tu biblioteca. Podrás volver a adquirirlo en la Tienda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    // Sin red no puede borrarse del servidor: se indica claramente.
    if (_modoOffline) {
      if (kIsWeb) {
        await DescargasWebService.quitarDescarga(juego.id);
      } else {
        await DatabaseHelper.eliminarJuegoLocal(juego.id);
      }
      if (!mounted) return;
      setState(() => _misJuegos.removeWhere((j) => j.id == juego.id));
      SessionController.notificarCambioBiblioteca();
      _snack('Se quitó solo la copia local; volverá al reconectar.');
      return;
    }

    try {
      await ApiService.eliminarDeBiblioteca(juego.id);
      if (kIsWeb) {
        await DescargasWebService.quitarDescarga(juego.id);
        await DescargasWebService.alternarFavorito(juego.id, valor: false);
      } else {
        await DatabaseHelper.eliminarJuegoLocal(juego.id);
      }
      if (!mounted) return;
      setState(() => _misJuegos.removeWhere((j) => j.id == juego.id));
      SessionController.notificarCambioBiblioteca();
      _snack('"${juego.titulo}" eliminado de tu biblioteca');
    } on SesionExpiradaException catch (e) {
      await ApiService.cerrarSesion();
      if (!mounted) return;
      _snack(e.toString(), error: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  void _menuOpciones(Juego juego) {
    final descargado = _descargados.contains(juego.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info_outline, color: AppPalette.acento),
              title: const Text('Ver información'),
              onTap: () {
                Navigator.pop(ctx);
                _abrirDetalle(juego);
              },
            ),
            ListTile(
              leading: Icon(
                juego.esFavorito ? Icons.favorite : Icons.favorite_border,
                color: AppPalette.acentoPrincipal,
              ),
              title: Text(juego.esFavorito
                  ? 'Quitar de favoritos'
                  : 'Marcar como favorito'),
              onTap: () {
                Navigator.pop(ctx);
                _alternarFavorito(juego);
              },
            ),
            if (kIsWeb)
              ListTile(
                leading: Icon(
                  descargado ? Icons.delete_outline : Icons.download,
                  color: descargado ? Colors.orangeAccent : AppPalette.acento,
                ),
                title: Text(descargado
                    ? 'Quitar descarga'
                    : 'Descargar juego'),
                subtitle: Text(descargado
                    ? 'Quita el estado guardado en este navegador'
                    : 'Guarda el juego en este navegador'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (descargado) {
                    _eliminarDescarga(juego);
                  } else {
                    _descargar(juego);
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.orangeAccent),
              title: const Text('Eliminar de biblioteca'),
              subtitle: Text(_modoOffline
                  ? 'Sin conexión: solo se quita la copia local'
                  : 'Se quita de tu cuenta y del dispositivo'),
              onTap: () {
                Navigator.pop(ctx);
                _eliminar(juego);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconoAccion({
    required IconData icono,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 15,
        backgroundColor: Colors.black54,
        child: Icon(icono, size: 16, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kIsWeb ? 'Tus juegos y descargas' : 'Mi biblioteca',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kIsWeb
                            ? '${_misJuegos.length} juegos · administra descargas y favoritos'
                            : '${_misJuegos.length} juegos en tu biblioteca',
                        style: TextStyle(
                          color: AppPalette.textoSuave,
                          fontSize: 13,
                        ),
                      ),
                      if (_modoOffline)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Sin conexión: mostrando la copia guardada en el dispositivo.',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar biblioteca',
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: _cargarBiblioteca,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFB2FF05),
                      ),
                    )
                  : _error != null && _misJuegos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off,
                                  size: 42, color: Colors.orangeAccent),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.acentoPrincipal,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: _cargarBiblioteca,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : _misJuegos.isEmpty
                          ? Center(
                              child: Text(
                                kIsWeb
                                    ? 'Aún no tienes juegos. Adquiere uno en la Tienda.'
                                    : 'Aún no tienes juegos en tu biblioteca.\nAdquiere uno en la Tienda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppPalette.textoSuave),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final ancho = constraints.maxWidth;
                                final columnas = ancho >= 1100
                                    ? 4
                                    : ancho >= 750 && (kIsWeb || ancho >= 1000)
                                        ? 3
                                        : 2;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columnas,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 20,
                                    childAspectRatio: 0.72,
                                  ),
                                  itemCount: _misJuegos.length,
                                  itemBuilder: (context, index) =>
                                      _buildLibraryCard(_misJuegos[index]),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryCard(Juego juego) {
    final descargado = kIsWeb && _descargados.contains(juego.id);
    final descargando = kIsWeb && _descargando.contains(juego.id);

    return GestureDetector(
      onTap: () => _abrirDetalle(juego),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    juego.portadaUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppPalette.borde, AppPalette.panelOscuro],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.videogame_asset,
                            size: 42, color: AppPalette.acentoPrincipal),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00000000),
                          Color(0xAA000000),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconoAccion(
                          icono: juego.esFavorito
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: juego.esFavorito
                              ? Colors.redAccent
                              : Colors.white,
                          onTap: () => _alternarFavorito(juego),
                        ),
                        const SizedBox(width: 6),
                        _iconoAccion(
                          icono: Icons.more_horiz,
                          color: Colors.white,
                          onTap: () => _menuOpciones(juego),
                        ),
                      ],
                    ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (juego.esFavorito)
                const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
            ],
          ),
          Text(
            juego.categoria,
            style: TextStyle(color: AppPalette.textoSuave, fontSize: 12),
          ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                descargando
                    ? 'Descargando…'
                    : descargado
                        ? 'Descargado en este navegador'
                        : 'Listo para descargar',
                style: TextStyle(
                  color: descargado
                      ? AppPalette.acentoPrincipal
                      : AppPalette.textoSuave,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Evita importar `collection` solo por firstOrNull en Flutter 3.27.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
