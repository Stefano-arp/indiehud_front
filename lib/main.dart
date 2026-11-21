import 'package:flutter/material.dart';
import 'models/juego.dart';
import 'services/api_service.dart';
import 'screens/game_detail_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/tickets_screen.dart';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB2FF05), // Verde Neón
          secondary: Color(0xFF9D4EDD), // Morado
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          selectedItemColor: Color(0xFFB2FF05),
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: const MainNavigator(),
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const LibraryScreen(),
    const TicketsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: 'Soporte'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
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
  final List<String> _categorias = [
    'Todos',
    'Cyberpunk RPG',
    'Arcade racing',
    'Action Platformer',
  ];

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  Future<void> _cargarCatalogo({String? busqueda}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final juegos = await ApiService.obtenerJuegos(
        buscar: busqueda ?? _searchController.text,
        categoria: _categoriaSeleccionada,
      );
      setState(() {
        _juegos = juegos;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No fue posible obtener la información.';
        _cargando = false;
      });
    }
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISCOVER DIFFERENT',
                      style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1.5),
                    ),
                    Text(
                      'IndieHub',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFFB2FF05)),
                  onPressed: () => _cargarCatalogo(),
                )
              ],
            ),
            const SizedBox(height: 16),

            // Barra de Búsqueda Dinámica (Segundo Parcial)
            TextField(
              controller: _searchController,
              onChanged: (valor) => _cargarCatalogo(busqueda: valor),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search indie games...',
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

            // Barra de Filtros por Categoría (Segundo Parcial)
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

            // Contenido Dinámico (Cumple RF04, RF05 y RF06 de tu Práctica 3)
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
                              const Icon(Icons.wifi_off, size: 50, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _cargarCatalogo(),
                                child: const Text('Reintentar'),
                              )
                            ],
                          ),
                        )
                      : _juegos.isEmpty
                          ? const Center(child: Text('No se encontraron juegos.'))
                          : ListView(
                              children: [
                                const Text(
                                  'Featured worlds',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                // Destacamos el primer juego de la lista
                                _buildFeaturedCard(_juegos.first),
                                const SizedBox(height: 24),
                                const Text(
                                  'Trending now',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                // Lista con todos los juegos
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
      child: Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B0B3F), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '⚡ EDITOR\'S PICK',
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
            style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2),
          ),
          Text(
            juego.titulo,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${juego.precio.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB2FF05),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _abrirDetalle(juego),
                child: const Text('Get game ➔', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          )
        ],
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF2B0B3F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.videogame_asset, color: Color(0xFFB2FF05)),
        ),
        title: Text(juego.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
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