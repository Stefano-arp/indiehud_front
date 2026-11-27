import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'models/juego.dart';
import 'services/api_service.dart';
import 'services/session_controller.dart';
import 'screens/game_detail_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/steam_web_shell.dart';
import 'screens/tickets_screen.dart';
import 'theme/app_palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // El menú debe reflejar la sesión guardada antes del primer frame.
  await ApiService.sincronizarSesion();
  // Render (plan gratuito) puede estar dormido: se despierta en segundo plano
  // mientras la interfaz inicializa, sin bloquear el arranque.
  ApiService.calentarBackend();
  runApp(const IndieHubApp());
}

class IndieHubApp extends StatelessWidget {
  const IndieHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IndieHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppPalette.fondo,
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.acento, // Verde neón
          secondary: AppPalette.secundario, // Morado cyberpunk
          surface: AppPalette.panel,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppPalette.panelOscuro,
          selectedItemColor: AppPalette.acento,
          unselectedItemColor: AppPalette.textoSuave,
        ),
      ),
      // Web: shell de escritorio IndieHub. Android: UI móvil original.
      home: kIsWeb ? const SteamWebShell() : const MainNavigator(),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  static const _etiquetas = ['Tienda', 'Biblioteca', 'Soporte', 'Perfil'];
  static const _iconos = [
    Icons.storefront_outlined,
    Icons.grid_view_rounded,
    Icons.support_agent,
    Icons.person_outline,
  ];

  final List<Widget> _screens = [
    const HomeScreen(),
    const LibraryScreen(),
    const TicketsScreen(),
    const ProfileScreen(),
  ];

  void _sesionCambiada() {
    // Si se cierra sesión desde otra pestaña, vuelve siempre a la Tienda.
    if (!SessionController.activa.value && _currentIndex != 0 && mounted) {
      setState(() => _currentIndex = 0);
    }
  }

  void _seccionCambiada() {
    final destino = SessionController.seccion.value;
    if (destino != _currentIndex && mounted) {
      setState(() => _currentIndex = destino);
    }
  }

  @override
  void initState() {
    super.initState();
    SessionController.activa.addListener(_sesionCambiada);
    SessionController.seccion.addListener(_seccionCambiada);
  }

  @override
  void dispose() {
    SessionController.activa.removeListener(_sesionCambiada);
    SessionController.seccion.removeListener(_seccionCambiada);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SessionController.activa,
      builder: (context, conSesion, _) {
        final indice = conSesion ? _currentIndex : 0;
        // Sin sesión solamente existe la Tienda; el acceso a Perfil se hace
        // desde el botón de la cabecera, nunca desde el menú.
        final items = <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(_iconos[0]), label: _etiquetas[0]),
          if (conSesion) ...[
            BottomNavigationBarItem(
                icon: Icon(_iconos[1]), label: _etiquetas[1]),
            BottomNavigationBarItem(
                icon: Icon(_iconos[2]), label: _etiquetas[2]),
            BottomNavigationBarItem(
                icon: Icon(_iconos[3]), label: _etiquetas[3]),
          ],
        ];

        return Scaffold(
          body: _screens[indice],
          // Sin sesión no hay menú: únicamente la Tienda y su botón de acceso.
          bottomNavigationBar: conSesion
              ? BottomNavigationBar(
                  currentIndex: indice,
                  type: BottomNavigationBarType.fixed,
                  onTap: (i) => SessionController.irA(i),
                  items: items,
                )
              : null,
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Juego> _juegos = [];
  bool _cargando = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _categoriaSeleccionada = 'Todos';
  List<String> _categorias = ['Todos'];
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo({String? busqueda}) async {
    final id = ++_requestId;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final juegos = await ApiService.obtenerJuegos(
        buscar: busqueda ?? _searchController.text,
        categoria: _categoriaSeleccionada,
      );
      if (id != _requestId || !mounted) return;
      setState(() {
        _juegos = juegos;
        final categorias = juegos
            .map((j) => j.categoria)
            .where((c) => c.isNotEmpty && c != 'General')
            .toSet()
            .toList()
          ..sort();
        _categorias = ['Todos', ...categorias];
        if (!_categorias.contains(_categoriaSeleccionada)) {
          _categoriaSeleccionada = 'Todos';
        }
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

  Future<void> _abrirPerfil() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(devolverAlEntrar: true),
      ),
    );
    // Al volver, el catálogo ya refleja la sesión activa.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIENDA · JUEGOS INDIE',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                            letterSpacing: 1.5),
                      ),
                      Text(
                        'IndieHub',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar catálogo',
                  icon: const Icon(Icons.refresh, color: Color(0xFFB2FF05)),
                  onPressed: () => _cargarCatalogo(),
                ),
              ],
            ),
            ValueListenableBuilder<bool>(
              valueListenable: SessionController.activa,
              builder: (context, conSesion, _) {
                if (conSesion) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB2FF05),
                        side: const BorderSide(color: Color(0xFFB2FF05)),
                      ),
                      onPressed: _abrirPerfil,
                      icon: const Icon(Icons.login),
                      label: const Text('Iniciar sesión'),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Barra de búsqueda dinámica (Segundo Parcial)
            TextField(
              controller: _searchController,
              onChanged: (valor) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _cargarCatalogo(busqueda: valor),
                );
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar juegos indie...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filtros por categoría (Segundo Parcial)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categorias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categorias[index];
                  final seleccionado = cat == _categoriaSeleccionada;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: seleccionado,
                    selectedColor: const Color(0xFFB2FF05),
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(
                      color: seleccionado ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      setState(() => _categoriaSeleccionada = cat);
                      _cargarCatalogo();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Contenido dinámico (Práctica 3)
            Expanded(
              child: _cargando
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFB2FF05)),
                          SizedBox(height: 12),
                          Text('Consultando...'),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_off,
                                  size: 50, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _cargarCatalogo(),
                                child: const Text('Reintentar'),
                              )
                            ],
                          ),
                        )
                      : _juegos.isEmpty
                          ? const Center(
                              child: Text('No se encontraron juegos.'))
                          : ListView(
                              children: [
                                const Text(
                                  'Juegos destacados',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                _buildFeaturedCard(_juegos.first),
                                const SizedBox(height: 24),
                                const Text(
                                  'Tendencias',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                ..._juegos.map((juego) => _buildTrendingItem(juego)),
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
      MaterialPageRoute(builder: (_) => GameDetailScreen(juego: juego)),
    );
  }

  Widget _buildFeaturedCard(Juego juego) {
    return GestureDetector(
      onTap: () => _abrirDetalle(juego),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 220,
          width: double.infinity,
          color: const Color(0xFF1A1A1A),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  juego.portadaUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  loadingBuilder: (context, child, progreso) {
                    if (progreso == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFB2FF05),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2B0B3F), Color(0xFF1A1A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x00000000), Color(0xDD12060D)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ELECCIÓN DEL EDITOR',
                          style: TextStyle(
                            color: Color(0xFFB2FF05),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        juego.categoria.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 1.2),
                      ),
                      Text(
                        juego.titulo,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${juego.precio.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB2FF05),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _abrirDetalle(juego),
                            child: const Text('Ver juego',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingItem(Juego juego) {
    return GestureDetector(
      onTap: () => _abrirDetalle(juego),
      child: Card(
        color: const Color(0xFF1E1E1E),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              juego.portadaUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              cacheWidth: 100,
              loadingBuilder: (context, child, progreso) {
                if (progreso == null) return child;
                return Container(
                  width: 50,
                  height: 50,
                  color: const Color(0xFF2B0B3F),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFB2FF05),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2B0B3F),
                child: const Icon(Icons.videogame_asset,
                    color: Color(0xFFB2FF05)),
              ),
            ),
          ),
          title: Text(juego.titulo,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${juego.categoria} • ${juego.desarrollador}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Text(
            '\$${juego.precio.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFB2FF05),
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
