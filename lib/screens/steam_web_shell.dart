import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/juego.dart';
import '../services/api_service.dart';
import '../services/session_controller.dart';
import '../theme/app_palette.dart';
import '../widgets/store_sections.dart';
import 'game_detail_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'tickets_screen.dart';

// La web comparte exactamente la paleta de Android: negro + verde neón + morado.
const Color _fondo = AppPalette.fondo;
const Color _panel = AppPalette.panel;
const Color _panelClaro = AppPalette.panelOscuro;
const Color _borde = AppPalette.borde;
const Color _texto = AppPalette.texto;
const Color _acento = AppPalette.acento;
const Color _neon = AppPalette.acentoPrincipal;
const Color _morado = AppPalette.secundario;

/// Filtros compartidos entre la barra lateral y el catálogo.
class FiltrosTienda {
  final ValueNotifier<String> categoria = ValueNotifier<String>('Todos');
  final ValueNotifier<List<String>> categorias =
      ValueNotifier<List<String>>(['Todos']);

  /// Un solo buscador para toda la web: vive en la cabecera y el catálogo
  /// escucha este valor, evitando dos campos de búsqueda simultáneos.
  final ValueNotifier<String> busqueda = ValueNotifier<String>('');
  final TextEditingController controlBusqueda = TextEditingController();

  /// Último catálogo cargado por la Tienda; se reutiliza en la biblioteca para
  /// ofrecer juegos similares sin otra petición.
  List<Juego> ultimoCatalogo = const [];

  void dispose() {
    categoria.dispose();
    categorias.dispose();
    busqueda.dispose();
    controlBusqueda.dispose();
  }
}

/// Shell web: una única barra superior de navegación y, solo en la Tienda,
/// una barra lateral de categorías. No hay menú duplicado.
class SteamWebShell extends StatefulWidget {
  const SteamWebShell({super.key});

  @override
  State<SteamWebShell> createState() => _SteamWebShellState();
}

class _SteamWebShellState extends State<SteamWebShell> {
  int _indice = 0;
  bool _teniaSesion = false;
  String _nombreUsuario = '';
  final FiltrosTienda _filtros = FiltrosTienda();

  static const _etiquetas = ['Tienda', 'Biblioteca', 'Soporte', 'Perfil'];
  static const _iconos = [
    Icons.storefront_outlined,
    Icons.grid_view_rounded,
    Icons.support_agent,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    _teniaSesion = SessionController.activa.value;
    ApiService.sincronizarSesion().then((_) => _cargarNombre());
    SessionController.activa.addListener(_onSesion);
    SessionController.seccion.addListener(_onSeccion);
    _cargarNombre();
  }

  @override
  void dispose() {
    SessionController.activa.removeListener(_onSesion);
    SessionController.seccion.removeListener(_onSeccion);
    _filtros.dispose();
    super.dispose();
  }

  void _onSesion() {
    final activo = SessionController.activa.value;
    if (activo != _teniaSesion && mounted) {
      // Al entrar o salir, vuelve siempre a la Tienda.
      setState(() {
        _indice = 0;
        _teniaSesion = activo;
      });
      SessionController.seccion.value = 0;
    }
    _cargarNombre();
  }

  void _onSeccion() {
    final destino = SessionController.activa.value
        ? SessionController.seccion.value
        : 0;
    if (destino != _indice && mounted) {
      setState(() => _indice = destino);
    }
  }

  Future<void> _cargarNombre() async {
    final datos = await ApiService.leerUsuario();
    final nombre = datos['nombre'] ?? '';
    if (mounted && nombre != _nombreUsuario) {
      setState(() => _nombreUsuario = nombre);
    }
  }

  void _irA(int indice) {
    SessionController.irA(indice);
    if (mounted) setState(() => _indice = SessionController.seccion.value);
  }

  Future<void> _cerrarSesion() async {
    await ApiService.cerrarSesion();
    try {
      await DatabaseHelper.limpiarBibliotecaLocal();
    } catch (_) {
      // La web no siempre dispone de SQLite; no bloquea el cierre de sesión.
    }
    if (mounted) setState(() => _indice = 0);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SessionController.activa,
      builder: (context, conSesion, _) {
        final ancho = MediaQuery.sizeOf(context).width;
        final enTienda = _indice == 0;
        final pantalla = switch (_indice) {
          1 => LibraryScreen(
              catalogo: _filtros.ultimoCatalogo,
            ),
          2 => const TicketsScreen(),
          3 => const ProfileScreen(),
          _ => SteamWebHome(filtros: _filtros, mostrarChips: ancho < 900),
        };

        return Scaffold(
          backgroundColor: _fondo,
          body: Column(
            children: [
              _barraSuperior(ancho, conSesion),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (enTienda && ancho >= 900) _barraLateralFiltros(),
                    if (enTienda && ancho >= 900)
                      Container(width: 1, color: _borde),
                    Expanded(child: pantalla),
                  ],
                ),
              ),
              _pie(conSesion),
            ],
          ),
        );
      },
    );
  }

  Widget _barraSuperior(double ancho, bool conSesion) {
    final conEtiquetas = ancho >= 1100;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _panelClaro,
        border: Border(bottom: BorderSide(color: _borde)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ancho < 700 ? 12 : 28),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  color: _neon,
                  child: const Icon(Icons.sports_esports,
                      color: Colors.black, size: 21),
                ),
                const SizedBox(width: 10),
                if (ancho >= 760)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IndieHub',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      Text('TIENDA INDIE',
                          style: TextStyle(
                              color: _morado, fontSize: 9, letterSpacing: 2)),
                    ],
                  ),
                const SizedBox(width: 18),
                if (conSesion)
                  Flexible(
                    flex: 3,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_etiquetas.length, (i) {
                          return _botonNavegacion(i, conEtiquetas);
                        }),
                      ),
                    ),
                  ),
                if (_indice == 0)
                  Flexible(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 130,
                          maxWidth: 320,
                        ),
                        child: _campoBusqueda(),
                      ),
                    ),
                  ),
                const Spacer(),
                if (conSesion) ...[
                  if (ancho >= 900 && _nombreUsuario.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          _nombreUsuario,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _texto, fontSize: 12),
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _cerrarSesion,
                    icon: const Icon(Icons.logout, size: 16),
                    label: ancho >= 600
                        ? const Text('Cerrar sesión',
                            style: TextStyle(fontSize: 12))
                        : const SizedBox.shrink(),
                    style: TextButton.styleFrom(foregroundColor: _texto),
                  ),
                ] else
                  ElevatedButton.icon(
                    onPressed: () => _irA(3),
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Iniciar sesión',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neon,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonNavegacion(int indice, bool conEtiquetas) {
    final activo = _indice == indice;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: activo ? _neon : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: TextButton.icon(
          onPressed: () => _irA(indice),
          icon: Icon(_iconos[indice], size: 15),
          label: conEtiquetas
              ? Text(
                  _etiquetas[indice].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                )
              : const SizedBox.shrink(),
          style: TextButton.styleFrom(
            foregroundColor: activo ? _acento : _texto,
            backgroundColor:
                activo ? _borde.withValues(alpha: 0.5) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    );
  }

  Widget _campoBusqueda() {
    return ValueListenableBuilder<String>(
      valueListenable: _filtros.busqueda,
      builder: (context, valor, _) {
        return TextField(
          controller: _filtros.controlBusqueda,
          onChanged: (texto) => _filtros.busqueda.value = texto,
          style: const TextStyle(color: _texto, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar juegos...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: _acento, size: 18),
            suffixIcon: valor.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.close, size: 16, color: _texto),
                    onPressed: () {
                      _filtros.controlBusqueda.clear();
                      _filtros.busqueda.value = '';
                    },
                  ),
            filled: true,
            fillColor: _panel,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _borde),
            ),
          ),
        );
      },
    );
  }

  Widget _pie(bool conSesion) {
    final ancho = MediaQuery.sizeOf(context).width;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _panelClaro,
        border: Border(top: BorderSide(color: _borde)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ancho < 700 ? 12 : 28),
            child: Row(
              children: [
                const Text(
                  'IndieHub · Juegos independientes',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _irA(0),
                  child: const Text('Catálogo',
                      style: TextStyle(fontSize: 11, color: _texto)),
                ),
                if (conSesion && ancho >= 700)
                  TextButton(
                    onPressed: () => _irA(2),
                    child: const Text('Centro de ayuda',
                        style: TextStyle(fontSize: 11, color: _texto)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraLateralFiltros() {
    return Container(
      width: 232,
      color: _panel,
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text('CATEGORÍAS',
                style: TextStyle(
                    color: _morado,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<String>>(
            valueListenable: _filtros.categorias,
            builder: (context, categorias, _) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final cat in categorias)
                      ValueListenableBuilder<String>(
                        valueListenable: _filtros.categoria,
                        builder: (context, seleccionada, _) {
                          final activo = cat == seleccionada;
                          return InkWell(
                            onTap: () => _filtros.categoria.value = cat,
                            hoverColor: _acento.withValues(alpha: 0.08),
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18),
                              decoration: BoxDecoration(
                                color: activo
                                    ? _borde.withValues(alpha: 0.6)
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: activo ? _acento : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  cat,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: activo ? _acento : _texto,
                                    fontSize: 12,
                                    fontWeight: activo
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Catálogo web: hero, secciones tipo escaparate y grilla responsive.
/// El buscador y las categorías viven en [filtros] para que la cabecera,
/// el lateral y el catálogo compartan exactamente el mismo estado.
class SteamWebHome extends StatefulWidget {
  final FiltrosTienda filtros;
  final bool mostrarChips;

  const SteamWebHome({
    super.key,
    required this.filtros,
    this.mostrarChips = false,
  });

  @override
  State<SteamWebHome> createState() => _SteamWebHomeState();
}

class _SteamWebHomeState extends State<SteamWebHome> {
  List<Juego> _juegos = [];
  bool _cargando = true;
  String? _error;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    widget.filtros.categoria.addListener(_alCambiarCategoria);
    widget.filtros.busqueda.addListener(_alCambiarBusqueda);
    _cargar();
  }

  @override
  void dispose() {
    widget.filtros.categoria.removeListener(_alCambiarCategoria);
    widget.filtros.busqueda.removeListener(_alCambiarBusqueda);
    _debounce?.cancel();
    super.dispose();
  }

  void _alCambiarCategoria() => _cargar();

  void _alCambiarBusqueda() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _cargar);
  }

  static bool _mismasCategorias(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _cargar() async {
    final id = ++_requestId;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final juegos = await ApiService.obtenerJuegos(
        buscar: widget.filtros.busqueda.value,
        categoria: widget.filtros.categoria.value,
      );
      if (id != _requestId || !mounted) return;
      final nuevas = [
        'Todos',
        ...juegos
            .map((j) => j.categoria)
            .where((c) => c.isNotEmpty && c != 'General')
            .toSet()
            .toList()
          ..sort(),
      ];
      if (!_mismasCategorias(nuevas, widget.filtros.categorias.value)) {
        widget.filtros.categorias.value = nuevas;
      }
      if (!nuevas.contains(widget.filtros.categoria.value)) {
        widget.filtros.categoria.value = 'Todos';
        return;
      }
      widget.filtros.ultimoCatalogo = juegos;
      setState(() {
        _juegos = juegos;
        _cargando = false;
      });
    } catch (_) {
      if (id != _requestId || !mounted) return;
      setState(() {
        _error = 'No fue posible obtener la información.';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = ancho >= 1400
            ? 5
            : ancho >= 1050
                ? 4
                : ancho >= 720
                    ? 3
                    : 2;

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ancho < 700 ? 16 : 32,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hero(ancho),
                    const SizedBox(height: 24),
                    if (widget.mostrarChips) _chips(),
                    if (widget.mostrarChips) const SizedBox(height: 24),
                    if (widget.filtros.busqueda.value.isEmpty &&
                        widget.filtros.categoria.value == 'Todos') ...[
                      SeccionesTienda(
                        juegos: _juegos,
                        onAbrir: (juego) => _abrirDetalle(juego),
                      ),
                      const SizedBox(height: 28),
                    ],
                    Row(
                      children: [
                        const Text('EXPLORA EL CATÁLOGO',
                            style: TextStyle(
                                color: _texto,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const SizedBox(width: 12),
                        Text('${_juegos.length} títulos',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _contenido(columnas),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hero(double ancho) {
    final destacado = _juegos.isNotEmpty ? _juegos.first : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: ancho < 700 ? 230 : 300,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_panelClaro, _fondo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            if (destacado != null)
              Positioned.fill(
                child: Image.network(
                  destacado.portadaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _fondo.withValues(alpha: 0.15),
                      _fondo.withValues(alpha: 0.96),
                    ],
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: ancho < 700 ? 18 : 34,
              bottom: ancho < 700 ? 18 : 30,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: ancho < 700 ? ancho - 36 : 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DESTACADO DE LA SEMANA',
                        style: TextStyle(
                            color: _morado,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      destacado?.titulo ?? 'IndieHub',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: ancho < 700 ? 26 : 38,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      destacado?.descripcion ??
                          'Descubre y gestiona videojuegos independientes.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _texto, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _neon,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        if (destacado != null) _abrirDetalle(destacado);
                      },
                      child: const Text('Ver detalles'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// En pantallas estrechas no hay lateral: los filtros van aquí.
  /// El buscador vive en la cabecera, así que aquí solo hay categorías.
  Widget _chips() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: widget.filtros.categorias,
      builder: (context, categorias, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categorias.map((cat) {
            return ValueListenableBuilder<String>(
              valueListenable: widget.filtros.categoria,
              builder: (context, seleccionada, _) {
                final activo = cat == seleccionada;
                return ChoiceChip(
                  label: Text(cat),
                  selected: activo,
                  selectedColor: _neon,
                  backgroundColor: _panel,
                  side: const BorderSide(color: _borde),
                  labelStyle: TextStyle(
                    color: activo ? Colors.black : _texto,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => widget.filtros.categoria.value = cat,
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _contenido(int columnas) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: _neon),
              SizedBox(height: 14),
              Text('Consultando...', style: TextStyle(color: _texto)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.wifi_off, size: 46, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: _texto)),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _neon, foregroundColor: Colors.black),
                onPressed: () => _cargar(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_juegos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
            child: Text('No se encontraron juegos.',
                style: TextStyle(color: Colors.white38))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        crossAxisSpacing: 16,
        mainAxisSpacing: 18,
        childAspectRatio: 1.25,
      ),
      itemCount: _juegos.length,
      itemBuilder: (context, index) => _tarjeta(_juegos[index]),
    );
  }

  Widget _tarjeta(Juego juego) {
    return InkWell(
      onTap: () => _abrirDetalle(juego),
      hoverColor: _acento.withValues(alpha: 0.10),
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.network(
                juego.portadaUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _panelClaro,
                  child: const Center(
                      child: Icon(Icons.gamepad, color: _acento)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    juego.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    juego.categoria,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _acento, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Text('\$${juego.precio.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: _neon,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDetalle(Juego juego) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameDetailScreen(
          juego: juego,
          relacionados: _juegos
              .where((otro) => otro.id != juego.id)
              .take(6)
              .toList(),
        ),
      ),
    );
  }
}
